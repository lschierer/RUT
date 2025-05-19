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

const identity = aws.getCallerIdentity({});
const accountId = identity.then((i) => i.accountId);

// Create S3 bucket for content using V2 resources
const contentBucket = new aws.s3.BucketV2("schierer-content", {
  forceDestroy: true,
});

// Configure versioning using BucketVersioningV2
const contentBucketVersioning = new aws.s3.BucketVersioningV2(
  "schierer-content-versioning",
  {
    bucket: contentBucket.id,
    versioningConfiguration: {
      status: "Enabled",
    },
  },
);

// Add lifecycle configuration to manage old versions
const contentBucketLifecycle = new aws.s3.BucketLifecycleConfigurationV2(
  "schierer-content-lifecycle",
  {
    bucket: contentBucket.id,
    rules: [
      {
        id: "expire-old-versions",
        status: "Enabled",
        noncurrentVersionExpiration: {
          noncurrentDays: 30,
        },
        abortIncompleteMultipartUpload: {
          daysAfterInitiation: 7,
        },
      },
    ],
  },
);

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

// Grant CodeBuild access to the content bucket
new aws.iam.RolePolicy("codebuild-s3-content-access", {
  role: codeBuildRole.name,
  policy: pulumi.all([contentBucket.arn]).apply(([bucketArn]) =>
    JSON.stringify({
      Version: "2012-10-17",
      Statement: [
        {
          Effect: "Allow",
          Action: ["s3:GetObject", "s3:GetObjectVersion", "s3:ListBucket"],
          Resource: [bucketArn, `${bucketArn}/*`],
        },
      ],
    }),
  ),
});

// CodeBuild Project
const codeBuildProject = new aws.codebuild.Project("schierer-build", {
  name: "schierer-web-build",
  serviceRole: codeBuildRole.arn,
  artifacts: { type: "NO_ARTIFACTS" },
  environment: {
    computeType: "BUILD_GENERAL1_SMALL",
    image: "aws/codebuild/amazonlinux2-x86_64-standard:4.0",
    type: "LINUX_CONTAINER",
    privilegedMode: true,
    environmentVariables: [
      {
        name: "REPOSITORY_URI",
        value: repository.repositoryUrl,
      },
      { name: "REGION", value: region },
      {
        name: "CONTENT_BUCKET",
        value: contentBucket.id,
      },
    ],
  },
  source: {
    type: "NO_SOURCE",
    buildspec: fs.readFileSync("./buildspec.yml", "utf-8"),
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

// Create a Lambda function to trigger the build when content changes in S3
const triggerLambdaRole = new aws.iam.Role("trigger-lambda-role", {
  assumeRolePolicy: aws.iam.assumeRolePolicyForPrincipal({
    Service: "lambda.amazonaws.com",
  }),
});

new aws.iam.RolePolicyAttachment("lambda-basic-execution", {
  role: triggerLambdaRole.name,
  policyArn: aws.iam.ManagedPolicy.AWSLambdaBasicExecutionRole,
});

new aws.iam.RolePolicy("lambda-codebuild-start", {
  role: triggerLambdaRole.name,
  policy: codeBuildProject.arn.apply((arn) =>
    JSON.stringify({
      Version: "2012-10-17",
      Statement: [
        {
          Effect: "Allow",
          Action: ["codebuild:StartBuild"],
          Resource: arn,
        },
      ],
    }),
  ),
});

const triggerLambda = new aws.lambda.Function("build-trigger", {
  runtime: aws.lambda.Runtime.NodeJS18dX,
  handler: "index.handler",
  role: triggerLambdaRole.arn,
  code: new pulumi.asset.AssetArchive({
    "index.js": new pulumi.asset.StringAsset(`
      const AWS = require('aws-sdk');
      const codebuild = new AWS.CodeBuild();

      exports.handler = async (event) => {
        console.log('S3 event:', JSON.stringify(event, null, 2));

        // Only trigger build for specific paths
        const records = event.Records || [];
        const shouldTrigger = records.some(record => {
          const key = record.s3.object.key;
          return key.startsWith('frontend/') ||
                 key.startsWith('luke/') ||
                 key.startsWith('archives/');
        });

        if (!shouldTrigger) {
          console.log('Ignoring event - not a content change');
          return { statusCode: 200, body: 'Ignored' };
        }

        try {
          const result = await codebuild.startBuild({
            projectName: '${codeBuildProject.name}'
          }).promise();

          console.log('Build started:', result.build.id);
          return {
            statusCode: 200,
            body: 'Build started: ' + result.build.id
          };
        } catch (error) {
          console.error('Error starting build:', error);
          return {
            statusCode: 500,
            body: 'Failed to start build: ' + error.message
          };
        }
      };
    `),
  }),
});

// Set up S3 notification to trigger Lambda when objects are created/updated
new aws.s3.BucketNotification("content-notification", {
  bucket: contentBucket.id,
  lambdaFunctions: [
    {
      lambdaFunctionArn: triggerLambda.arn,
      events: ["s3:ObjectCreated:*"],
    },
  ],
});

// Allow S3 to invoke the Lambda
new aws.lambda.Permission("s3-invoke-lambda", {
  action: "lambda:InvokeFunction",
  function: triggerLambda.name,
  principal: "s3.amazonaws.com",
  sourceArn: contentBucket.arn,
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
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
        ],
        Resource: "*",
      },
    ],
  }),
});

// Outputs
export const repositoryUrl = repository.repositoryUrl;
export const codeBuildProjectName = codeBuildProject.name;
export const contentBucketName = contentBucket.bucket;
export const certificateArn = certificate.arn;
