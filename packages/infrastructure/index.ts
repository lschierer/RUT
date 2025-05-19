import * as pulumi from "@pulumi/pulumi";
import * as aws from "@pulumi/aws";
import * as fs from "fs";
import * as path from "path";

// Configuration
const config = new pulumi.Config("schierer.org");
const domainName = config.require("domainName");
const rootDomainName = config.require("rootDomainName"); // e.g. schierer.org
const mojoLogLevel = config.get("mojoLogLevel") || "warn";
const region = aws.config.region || "us-east-2";
const githubOwner = config.require("githubOwner");
const githubRepo = config.require("githubRepo");

const identity = aws.getCallerIdentity({});
const accountId = identity.then((i) => i.accountId);

// ACM certificate for domain (must be in us-east-1 for use with CloudFront)
const certificate = new aws.acm.Certificate("schierer-cert", {
  domainName: domainName,
  validationMethod: "DNS",
});

// Hosted zone lookup
const hostedZone = aws.route53.getZone({
  name: rootDomainName,
  privateZone: false,
});

// DNS validation record
const certValidationRecord = new aws.route53.Record(
  "schierer-cert-validation",
  {
    name: certificate.domainValidationOptions[0].resourceRecordName,
    zoneId: hostedZone.then((zone) => zone.zoneId),
    type: certificate.domainValidationOptions[0].resourceRecordType,
    records: [certificate.domainValidationOptions[0].resourceRecordValue],
    ttl: 60,
  },
);

// Certificate validation
const certValidation = new aws.acm.CertificateValidation(
  "schierer-cert-validation-step",
  {
    certificateArn: certificate.arn,
    validationRecordFqdns: [certValidationRecord.fqdn],
  },
);

// ECR repository
const repository = new aws.ecr.Repository("schierer-web-repo");

// IAM Role for CodeBuild
const codeBuildRole = new aws.iam.Role("codebuild-role", {
  assumeRolePolicy: aws.iam.assumeRolePolicyForPrincipal({
    Service: "codebuild.amazonaws.com",
  }),
});

new aws.iam.RolePolicyAttachment("codebuild-policy", {
  role: codeBuildRole.name,
  policyArn: aws.iam.ManagedPolicy.AWSCodeBuildDeveloperAccess,
});

// CodeBuild buildspec
const buildspec = fs.readFileSync("./buildspec.yml", "utf-8");

// CodeBuild Project
const codeBuildProject = new aws.codebuild.Project("schierer-build", {
  name: "schierer-web-build",
  serviceRole: codeBuildRole.arn,
  artifacts: { type: "CODEPIPELINE" },
  environment: {
    computeType: "BUILD_GENERAL1_SMALL",
    image: "aws/codebuild/standard:7.0",
    type: "LINUX_CONTAINER",
    privilegedMode: true,
    environmentVariables: [
      {
        name: "REPOSITORY_URI",
        value: repository.repositoryUrl.apply(
          (uri) => uri,
        ) /* <-- unwrap Output<string> */,
      },
      { name: "REGION", value: region },
    ],
  },
  source: {
    type: "CODEPIPELINE",
    buildspec: buildspec,
  },
});

new aws.iam.RolePolicy("codebuild-logging", {
  role: codeBuildRole.name,
  policy: pulumi
    .all([codeBuildProject.name, accountId])
    .apply(([project, id]) =>
      JSON.stringify({
        Statement: [
          {
            Effect: "Allow",
            Action: [
              "logs:CreateLogGroup",
              "logs:CreateLogStream",
              "logs:PutLogEvents",
            ],
            Resource: [
              `arn:aws:logs:${region}:${id}:log-group:/aws/codebuild/${project}`,
              `arn:aws:logs:${region}:${id}:log-group:/aws/codebuild/${project}:*`,
            ],
          },
        ],
      }),
    ),
});

// IAM role for CodePipeline
const pipelineRole = new aws.iam.Role("pipeline-role", {
  assumeRolePolicy: aws.iam.assumeRolePolicyForPrincipal({
    Service: "codepipeline.amazonaws.com",
  }),
});

new aws.iam.RolePolicyAttachment("pipeline-policy", {
  role: pipelineRole.name,
  policyArn: "arn:aws:iam::aws:policy/AWSCodePipeline_FullAccess",
});

// Artifact store S3 bucket
const artifactBucket = new aws.s3.Bucket("schierer-artifacts", {
  forceDestroy: true,
});

new aws.iam.RolePolicy("codebuild-artifacts-access", {
  role: codeBuildRole.name,
  policy: pulumi.all([artifactBucket.arn]).apply(([bucketArn]) =>
    JSON.stringify({
      Version: "2012-10-17",
      Statement: [
        {
          Effect: "Allow",
          Action: [
            "s3:GetObject",
            "s3:GetObjectVersion",
            "s3:GetBucketVersioning",
            "s3:GetBucketLocation",
            "s3:PutObject",
          ],
          Resource: [bucketArn, `${bucketArn}/*`],
        },
      ],
    }),
  ),
});

new aws.iam.RolePolicy("pipeline-s3-access", {
  role: pipelineRole.name,
  policy: artifactBucket.arn.apply((bucketArn) =>
    JSON.stringify({
      Version: "2012-10-17",
      Statement: [
        {
          Effect: "Allow",
          Action: [
            "s3:GetObject",
            "s3:GetObjectVersion",
            "s3:PutObject",
            "s3:ListBucket",
          ],
          Resource: [bucketArn, `${bucketArn}/*`],
        },
      ],
    }),
  ),
});

new aws.iam.RolePolicy("pipeline-codestar-access", {
  role: pipelineRole.name,
  policy: JSON.stringify({
    Version: "2012-10-17",
    Statement: [
      {
        Effect: "Allow",
        Action: "codestar-connections:UseConnection",
        Resource:
          "arn:aws:codeconnections:us-east-2:699040795025:connection/063f4f0b-e814-4954-8808-57d689663522",
      },
    ],
  }),
});

new aws.iam.RolePolicy("pipeline-codebuild-access", {
  role: pipelineRole.name,
  policy: codeBuildProject.arn.apply((arn) =>
    JSON.stringify({
      Version: "2012-10-17",
      Statement: [
        {
          Effect: "Allow",
          Action: ["codebuild:StartBuild", "codebuild:BatchGetBuilds"],
          Resource: arn,
        },
      ],
    }),
  ),
});

const GitHubConnection = new aws.codeconnections.Connection(
  "GitHubConnection",
  {
    name: "Github lschierer connection",
    providerType: "GitHub",
  },
  {
    protect: true,
  },
);

// CodePipeline
const pipeline = new aws.codepipeline.Pipeline("schierer-pipeline", {
  roleArn: pipelineRole.arn,
  pipelineType: "V2",
  triggers: [
    {
      providerType: "CodeStarSourceConnection",
      gitConfiguration: {
        sourceActionName: "Source",
        pushes: [
          {
            branches: {
              includes: ["perlv1"],
            },
            filePaths: {
              includes: [
                "packages/frontend/**",
                "packages/infrastructure/Dockerfile",
                "packages/infrastructure/buildspec.yml",
              ],
            },
          },
        ],
      },
    },
  ],
  artifactStores: [
    {
      location: artifactBucket.bucket,
      type: "S3",
    },
  ],
  stages: [
    {
      name: "Source",
      actions: [
        {
          name: "Source",
          category: "Source",
          owner: "AWS",
          provider: "CodeStarSourceConnection",
          version: "1",
          outputArtifacts: ["source_output"],
          configuration: {
            ConnectionArn: GitHubConnection.arn,
            FullRepositoryId: `${githubOwner}/${githubRepo}`,
            BranchName: "perlv1",
            OutputArtifactFormat: "CODE_ZIP",
          },
          runOrder: 1,
        },
      ],
    },
    {
      name: "Build",
      actions: [
        {
          name: "Build",
          category: "Build",
          owner: "AWS",
          provider: "CodeBuild",
          inputArtifacts: ["source_output"],
          version: "1",
          outputArtifacts: [],
          configuration: {
            ProjectName: codeBuildProject.name,
          },
          runOrder: 1,
        },
      ],
    },
  ],
});

new aws.iam.RolePolicy("codebuild-ecr-access", {
  role: codeBuildRole.name,
  policy: JSON.stringify({
    Version: "2012-10-17",
    Statement: [
      {
        Effect: "Allow",
        Action: [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
        ],
        Resource: "*",
      },
    ],
  }),
});

// Outputs
export const repositoryUrl = repository.repositoryUrl;
export const codeBuildProjectName = codeBuildProject.name;
export const pipelineName = pipeline.name;
export const certificateArn = certificate.arn;
