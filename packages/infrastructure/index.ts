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
import { stage2, type Stage2Outputs } from "./stage2";
import { networkStack } from "./network";

const resourceName = pulumi.getStack().toLowerCase().replaceAll("\.", "");

const stackNetwork = networkStack();

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

const containerCluster = setupContainerCluster(
  repository,
  accountId,
  stackNetwork,
);

const codeBuildLogGroup = new aws.cloudwatch.LogGroup(
  `${resourceName}-codebuild-logs`,
  {
    name: `/aws/codebuild/Project/${resourceName}`,
    retentionInDays: 3, // Set your desired retention period (e.g., 14 days)
  },
);

// Use the updated buildspec in your CodeBuild project// CodeBuild Project
const codeBuildProject = new aws.codebuild.Project(
  `${resourceName}-build`,
  {
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
    logsConfig: {
      cloudwatchLogs: {
        groupName: codeBuildLogGroup.name,
        status: "ENABLED",
      },
    },
    source: {
      type: "NO_SOURCE",
      buildspec: buildspec,
    },
  },
  { dependsOn: [containerCluster.cluster, containerCluster.service] },
);

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

const stage2outputs = stage2(
  containerCluster,
  codeBuildRole,
  codeBuildProject,
  codeBuildLogGroup,
);

// Outputs
export const repositoryUrl = repository.repositoryUrl;
export const codeBuildProjectName = codeBuildProject.name;
export const contentBucketName = contentBucket.bucket;
export const certificateArn = containerCluster.certificate.arn;
export const loadBalancerDns = containerCluster.lb.dnsName;
export const serviceUrl = pulumi.interpolate`http://${containerCluster.lb.dnsName}`;
