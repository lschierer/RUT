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

import * as perlImage from "./perlImage";
import { setupContainerCluster, type ContainerCluster } from "./fargateStack";

const resourceName = pulumi.getStack().toLowerCase().replaceAll("\.", "");

// Create S3 bucket for content using V2 resources
const contentBucket = new aws.s3.BucketV2(`${resourceName}-content`, {
  forceDestroy: true,
});

// Configure versioning using BucketVersioningV2
const contentBucketVersioning = new aws.s3.BucketVersioningV2(
  `${resourceName}-content-versioning`,
  {
    bucket: contentBucket.id,
    versioningConfiguration: {
      status: "Enabled",
    },
  },
);

// Add lifecycle configuration to manage old versions
const contentBucketLifecycle = new aws.s3.BucketLifecycleConfigurationV2(
  `${resourceName}-content-lifecycle`,
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

// ECR repository
const repository = new aws.ecr.Repository(`${resourceName}-web-repo`);

// IAM Role for CodeBuild
const codeBuildRole = new aws.iam.Role(`${resourceName}-codebuild-role`, {
  assumeRolePolicy: aws.iam.assumeRolePolicyForPrincipal({
    Service: "codebuild.amazonaws.com",
  }),
});

new aws.iam.RolePolicyAttachment(`${resourceName}-codebuild-policy`, {
  role: codeBuildRole.name,
  policyArn: aws.iam.ManagedPolicy.AWSCodeBuildDeveloperAccess,
});

// Grant CodeBuild access to the content bucket
new aws.iam.RolePolicy(`${resourceName}-codebuild-s3-content-access`, {
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

// Create the Perl base image in ECR
const { imageUri: perlBaseImageUri } = perlImage.createPerlBaseImage("5.40");

// Now update your buildspec to use this image
const buildspec = perlBaseImageUri.apply((perlBaseImageUri) => {
  return fs
    .readFileSync("./buildspec.yml", "utf-8")
    .replace("FROM perl:5.40", `FROM ${perlBaseImageUri}`);
});

const containerCluster = setupContainerCluster(repository, accountId);
const ecsServiceArn = pulumi
  .all([
    aws.config.region,
    aws.getCallerIdentity({}),
    containerCluster.cluster.name,
    containerCluster.service.name,
  ])
  .apply(
    ([region, identity, clusterName, serviceName]) =>
      `arn:aws:ecs:${region}:${identity.accountId}:service/${clusterName}/${serviceName}`,
  );

// Use the updated buildspec in your CodeBuild project// CodeBuild Project
const codeBuildProject = new aws.codebuild.Project(`${resourceName}-build`, {
  name: `${resourceName}-web-build`,
  serviceRole: codeBuildRole.arn,
  artifacts: {
    type: "S3",
    location: contentBucket.bucket,
    path: "artifacts",
    namespaceType: "NONE",
    name: "build-artifacts",
  },
  environment: {
    computeType: "BUILD_GENERAL1_SMALL",
    image: "aws/codebuild/standard:7.0",
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
      {
        name: "CLUSTER_NAME",
        value: containerCluster.cluster.name.apply((name) => name),
      },
      {
        name: "SERVICE_NAME",
        value: containerCluster.service.name.apply((name) => name),
      },
    ],
  },
  source: {
    type: "NO_SOURCE",
    buildspec: buildspec,
  },
});

new aws.iam.RolePolicy("codebuild-ecs-update", {
  role: codeBuildRole.name,
  policy: pulumi
    .all([ecsServiceArn, containerCluster.cluster.arn])
    .apply(([serviceArn, clusterArn]) =>
      JSON.stringify({
        Version: "2012-10-17",
        Statement: [
          {
            Effect: "Allow",
            Action: [
              "ecs:UpdateService",
              "ecs:DescribeServices",
              "ecs:DescribeTaskDefinition",
              "ecs:RegisterTaskDefinition",
            ],
            Resource: "*", // or scope to serviceArn/clusterArn if you prefer
          },
          {
            Effect: "Allow",
            Action: ["iam:PassRole"],
            Resource: "*", // scope to your ECS task execution role if known
          },
        ],
      }),
    ),
});

new aws.iam.RolePolicy(`${resourceName}-codebuild-logging`, {
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
const triggerLambdaRole = new aws.iam.Role(
  `${resourceName}-trigger-lambda-role`,
  {
    assumeRolePolicy: aws.iam.assumeRolePolicyForPrincipal({
      Service: "lambda.amazonaws.com",
    }),
  },
);

new aws.iam.RolePolicyAttachment(`${resourceName}-lambda-basic-exec`, {
  role: triggerLambdaRole.name,
  policyArn: aws.iam.ManagedPolicy.AWSLambdaBasicExecutionRole,
});

new aws.iam.RolePolicy(`${resourceName}-lambda-codebuild-start`, {
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

const triggerLambda = new aws.lambda.Function(`${resourceName}-build-trigger`, {
  runtime: aws.lambda.Runtime.NodeJS22dX, // Updated to Node.js 22
  handler: "build-trigger.handler",
  role: triggerLambdaRole.arn,
  code: new pulumi.asset.AssetArchive({
    "build-trigger.js": new pulumi.asset.FileAsset("./dist/build-trigger.js"),
  }),
  environment: {
    variables: {
      CODEBUILD_PROJECT_NAME: codeBuildProject.name,
    },
  },
});

// Set up S3 notification to trigger Lambda when objects are created/updated
new aws.s3.BucketNotification(`${resourceName}-content-notification`, {
  bucket: contentBucket.id,
  lambdaFunctions: [
    {
      lambdaFunctionArn: triggerLambda.arn,
      events: ["s3:ObjectCreated:*"],
    },
  ],
});

// Allow S3 to invoke the Lambda
new aws.lambda.Permission(`${resourceName}-s3-invoke-lambda`, {
  action: "lambda:InvokeFunction",
  function: triggerLambda.name,
  principal: "s3.amazonaws.com",
  sourceArn: contentBucket.arn,
});

new aws.iam.RolePolicy(`${resourceName}-codebuild-ecr-access`, {
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
export const certificateArn = containerCluster.certificate.arn;
export const loadBalancerDns = containerCluster.lb.dnsName;
export const serviceUrl = pulumi.interpolate`http://${containerCluster.lb.dnsName}`;
