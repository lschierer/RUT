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
const githubToken = config.requireSecret("githubToken");
const githubOwner = config.require("githubOwner");
const githubRepo = config.require("githubRepo");

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

const deployEnvFile = "../../.env.deploy";

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

// ECR repository to receive built images
const repository = new aws.ecr.Repository("schierer-web-repo");

const buildspec = `version: 0.2
phases:
pre_build:
  commands:
    - echo Logging in to Amazon ECR...
    - aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $REPOSITORY_URI
build:
  commands:
    - echo Build started on $(date)
    - docker build -t $REPOSITORY_URI:latest .
    - docker push $REPOSITORY_URI:latest
post_build:
  commands:
    - echo Build completed on $(date)
`;

// CodeBuild project
const codeBuildProject = new aws.codebuild.Project("schierer-build", {
  name: "schierer-web-build",
  serviceRole: codeBuildRole.arn,
  artifacts: {
    type: "NO_ARTIFACTS",
  },
  projectVisibility: "PRIVATE",
  environment: {
    computeType: "BUILD_GENERAL1_SMALL",
    image: "aws/codebuild/standard:7.0",
    type: "LINUX_CONTAINER",
    privilegedMode: true, // Needed to run Docker
    environmentVariables: [
      { name: "REPOSITORY_URI", value: repository.repositoryUrl },
      { name: "REGION", value: region },
    ],
  },
  source: {
    type: "GITHUB",
    location: pulumi.interpolate`${githubOwner}/${githubRepo}`,
    buildspec: buildspec,
  },
});

// IAM role for CodePipeline
const pipelineRole = new aws.iam.Role("pipeline-role", {
  assumeRolePolicy: aws.iam.assumeRolePolicyForPrincipal({
    Service: "codepipeline.amazonaws.com",
  }),
});

new aws.iam.RolePolicyAttachment("pipeline-policy", {
  role: pipelineRole.name,
  policyArn: aws.iam.ManagedPolicy.CodePipeline_FullAccess,
});

// CodePipeline
const pipeline = new aws.codepipeline.Pipeline("schierer-pipeline", {
  roleArn: pipelineRole.arn,
  artifactStores: [
    {
      location: repository.repositoryUrl.apply((url) => url.split("/")[0]),
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
          owner: "ThirdParty",
          provider: "GitHub",
          version: "1",
          outputArtifacts: ["source_output"],
          configuration: {
            Owner: githubOwner,
            Repo: githubRepo,
            Branch: "perlv1",
            OAuthToken: githubToken,
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

// Outputs
export const repositoryUrl = repository.repositoryUrl;
export const codeBuildProjectName = codeBuildProject.name;
export const pipelineName = pipeline.name;
export const certificateArn = certificate.arn;
