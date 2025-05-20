import * as pulumi from "@pulumi/pulumi";
import * as aws from "@pulumi/aws";
import * as fs from "fs";
import * as path from "path";

// these resources cannot be built until after there is an image created

import { type ContainerCluster } from "./fargateStack";

export type Stage2Outputs = {};

// Configuration
const config = new pulumi.Config("schierer.org");
const domainName = config.require("domainName");
const rootDomainName = config.require("rootDomainName"); // e.g. schierer.org
const mojoLogLevel = config.get("mojoLogLevel") || "warn";
const region = aws.config.region || "us-east-2";

const identity = aws.getCallerIdentity({});
const accountId = identity.then((i) => i.accountId);
const resourceName = pulumi.getStack().toLowerCase().replaceAll("\.", "");

export const stage2 = (
  containerCluster: ContainerCluster,
  codeBuildRole: aws.iam.Role,
  codeBuildProject: aws.codebuild.Project,
  codeBuildLogGroup: aws.cloudwatch.LogGroup,
) => {
  const Policies = new Array<aws.iam.RolePolicy>();

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

  new aws.iam.RolePolicy(`${resourceName}-codebuild-ecs-update`, {
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
      .all([codeBuildLogGroup.name, accountId])
      .apply(([logGroupName, id]) =>
        JSON.stringify({
          Version: "2012-10-17",
          Statement: [
            {
              Effect: "Allow",
              Action: [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents",
              ],
              Resource: [
                `arn:aws:logs:${region}:${id}:log-group:${logGroupName}`,
                `arn:aws:logs:${region}:${id}:log-group:${logGroupName}:*`,
              ],
            },
          ],
        }),
      ),
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

  return {} as Stage2Outputs;
};
