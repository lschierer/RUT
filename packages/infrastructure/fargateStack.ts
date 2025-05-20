import * as pulumi from "@pulumi/pulumi";
import * as aws from "@pulumi/aws";
import * as fs from "fs";
import * as path from "path";

const config = new pulumi.Config("schierer.org");
const domainName = config.require("domainName");
const rootDomainName = config.require("rootDomainName"); // e.g. schierer.org
const mojoLogLevel = config.get("mojoLogLevel") || "warn";
const logRetention = config.get("logRetentionDays") || "30";
const region = aws.config.region || "us-east-2";

import { type NetworkStackReturn } from "./network";
export type ContainerCluster = {
  lb: aws.lb.LoadBalancer;
  cluster: aws.ecs.Cluster;
  service: aws.ecs.Service;
  certificate: aws.acm.Certificate;
};

const fgstackName = pulumi.getStack().toLowerCase().replaceAll("\.", "");

export const setupContainerCluster = (
  repository: aws.ecr.Repository,
  accountId: Promise<string>,
  network: NetworkStackReturn,
): ContainerCluster => {
  // Create an ECS cluster
  const cluster = new aws.ecs.Cluster(`${fgstackName}-cluster`, {
    name: `${fgstackName}-cluster`,
    settings: [
      {
        name: "containerInsights",
        value: "enabled",
      },
    ],
  });

  // Create a VPC for the ECS service if you don't have one already

  // Create a security group for the load balancer
  const lbSecurityGroup = new aws.ec2.SecurityGroup(`${fgstackName}-lb-sg`, {
    vpcId: network.vpc.id,
    description: "Security group for the load balancer",
    ingress: [
      {
        protocol: "tcp",
        fromPort: 80,
        toPort: 80,
        cidrBlocks: ["0.0.0.0/0"],
      },
      {
        protocol: "tcp",
        fromPort: 443,
        toPort: 443,
        cidrBlocks: ["0.0.0.0/0"],
      },
    ],
    egress: [
      {
        protocol: "-1",
        fromPort: 0,
        toPort: 0,
        cidrBlocks: ["0.0.0.0/0"],
      },
    ],
  });

  // Create a security group for the ECS tasks
  const ecsSecurityGroup = new aws.ec2.SecurityGroup(`${fgstackName}-ecs-sg`, {
    vpcId: network.vpc.id,
    description: "Security group for the ECS tasks",
    ingress: [
      {
        protocol: "tcp",
        fromPort: 3000,
        toPort: 3000,
        securityGroups: [lbSecurityGroup.id],
      },
    ],
    egress: [
      {
        protocol: "-1",
        fromPort: 0,
        toPort: 0,
        cidrBlocks: ["0.0.0.0/0"],
      },
    ],
  });

  // Create an Application Load Balancer
  const lb = new aws.lb.LoadBalancer(`${fgstackName}-lb`, {
    internal: false,
    loadBalancerType: "application",
    securityGroups: [lbSecurityGroup.id],
    subnets: network.publicSubnets.map((subnet) => subnet.id),
    enableDeletionProtection: false,
  });

  // Create a target group for the load balancer
  const targetGroup = new aws.lb.TargetGroup(`${fgstackName}-tg`, {
    port: 3000,
    protocol: "HTTP",
    targetType: "ip",
    vpcId: network.vpc.id,
    healthCheck: {
      enabled: true,
      path: "/",
      port: "3000",
      protocol: "HTTP",
      healthyThreshold: 3,
      unhealthyThreshold: 3,
      timeout: 5,
      interval: 30,
      matcher: "200-399",
    },
  });

  // Create an IAM role for the ECS task execution
  const taskExecutionRole = new aws.iam.Role(
    `${fgstackName}-task-execution-role`,
    {
      assumeRolePolicy: aws.iam.assumeRolePolicyForPrincipal({
        Service: "ecs-tasks.amazonaws.com",
      }),
    },
  );

  new aws.iam.RolePolicyAttachment(`${fgstackName}-task-execution-policy`, {
    role: taskExecutionRole.name,
    policyArn:
      "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy",
  });

  // Create an IAM role for the ECS task
  const taskRole = new aws.iam.Role(`${fgstackName}-task-role`, {
    assumeRolePolicy: aws.iam.assumeRolePolicyForPrincipal({
      Service: "ecs-tasks.amazonaws.com",
    }),
  });

  // Create a task definition for your container
  const taskDefinition = new aws.ecs.TaskDefinition(`${fgstackName}-task`, {
    family: `${fgstackName}-web`,
    cpu: "256",
    memory: "512",
    networkMode: "awsvpc",
    requiresCompatibilities: ["FARGATE"],
    executionRoleArn: taskExecutionRole.arn,
    taskRoleArn: taskRole.arn,
    containerDefinitions: pulumi
      .all([repository.repositoryUrl])
      .apply(([repoUrl]) =>
        JSON.stringify([
          {
            name: `${fgstackName}-web`,
            image: `${repoUrl}:latest`,
            essential: true,
            environment: [
              {
                name: "MOJO_LOG_LEVEL",
                value: mojoLogLevel,
              },
              {
                name: "MOJO_REVERSE_PROXY",
                value: "1",
              },
            ],
            portMappings: [
              {
                containerPort: 3000,
                hostPort: 3000,
                protocol: "tcp",
              },
            ],
            logConfiguration: {
              logDriver: "awslogs",
              options: {
                "awslogs-group": `/ecs/${fgstackName}-web`,
                "awslogs-region": region,
                "awslogs-stream-prefix": "ecs",
                "awslogs-create-group": "true",
              },
            },
          },
        ]),
      ),
  });

  // Create a CloudWatch log group for the container logs
  const logGroup = new aws.cloudwatch.LogGroup(`${fgstackName}-logs`, {
    name: `/ecs/${fgstackName}-web`,
    retentionInDays: 30,
  });

  // Create an ECS service to run your task
  const service = new aws.ecs.Service(
    `${fgstackName}-service`,
    {
      cluster: cluster.arn,
      desiredCount: 1,
      launchType: "FARGATE",
      taskDefinition: taskDefinition.arn,
      networkConfiguration: {
        subnets: network.publicSubnets.map((subnet) => subnet.id),
        securityGroups: [ecsSecurityGroup.id],
        assignPublicIp: true,
      },
      loadBalancers: [
        {
          targetGroupArn: targetGroup.arn,
          containerName: `${fgstackName}-web`,
          containerPort: 3000,
        },
      ],
      forceNewDeployment: true,
      deploymentCircuitBreaker: {
        enable: true,
        rollback: true,
      },
      // This is key for auto-updates - always use the latest revision
      deploymentController: {
        type: "ECS",
      },
    },
    { dependsOn: [taskDefinition] },
  );

  // Create a CloudWatch event rule to trigger a deployment when a new image is pushed
  const ecrEventRule = new aws.cloudwatch.EventRule(
    `${fgstackName}-ecr-event`,
    {
      eventPattern: JSON.stringify({
        source: ["aws.ecr"],
        detail: {
          "action-type": ["PUSH"],
          "repository-name": [repository.name],
          "image-tag": ["latest"],
        },
      }),
    },
  );

  // Create an IAM role for the CloudWatch event
  const eventRole = new aws.iam.Role(`${fgstackName}-event-role`, {
    assumeRolePolicy: aws.iam.assumeRolePolicyForPrincipal({
      Service: "events.amazonaws.com",
    }),
  });

  // Allow the event to update the ECS service
  accountId
    .then((id) => {
      return new aws.iam.RolePolicy(`${fgstackName}-event-policy`, {
        role: eventRole.name,
        policy: pulumi
          .all([service.name, cluster.name])
          .apply(([serviceName, clusterName]) =>
            JSON.stringify({
              Version: "2012-10-17",
              Statement: [
                {
                  Effect: "Allow",
                  Action: "ecs:UpdateService",
                  Resource: `arn:aws:ecs:${region}:${id}:service/${clusterName}/${serviceName}`,
                },
              ],
            }),
          ),
      });
    })
    .catch((error: unknown) => {
      console.error(JSON.stringify(error));
    });

  // Create a CloudWatch event target to update the ECS service
  const ecrEventTarget = new aws.cloudwatch.EventTarget(
    `${fgstackName}-ecr-event-target`,
    {
      rule: ecrEventRule.name,
      arn: cluster.arn,
      roleArn: eventRole.arn,
      ecsTarget: {
        taskCount: 1,
        taskDefinitionArn: taskDefinition.arn,
        launchType: "FARGATE",
        networkConfiguration: {
          subnets: network.publicSubnets.map((subnet) => subnet.id),
          securityGroups: [ecsSecurityGroup.id],
          assignPublicIp: true,
        },
      },
    },
  );

  // Create a Route53 record for your domain if you have one
  const zone = aws.route53.getZone({
    name: rootDomainName,
  });

  new aws.route53.Record(`${fgstackName}-record`, {
    zoneId: zone.then((zone) => zone.zoneId),
    name: domainName,
    type: "A",
    aliases: [
      {
        name: lb.dnsName,
        zoneId: lb.zoneId,
        evaluateTargetHealth: true,
      },
    ],
  });

  const certificate = new aws.acm.Certificate(`${fgstackName}-cert`, {
    domainName: domainName,
    validationMethod: "DNS",
  });

  const httpsListener = new aws.lb.Listener(`${fgstackName}-https-listener`, {
    loadBalancerArn: lb.arn,
    port: 443,
    protocol: "HTTPS",
    sslPolicy: "ELBSecurityPolicy-2016-08",
    certificateArn: certificate.arn, // Use your ACM certificate
    defaultActions: [
      {
        type: "forward",
        targetGroupArn: targetGroup.arn,
      },
    ],
  });

  // Redirect HTTP to HTTPS
  const httpListener = new aws.lb.Listener(`${fgstackName}-http-listener`, {
    loadBalancerArn: lb.arn,
    port: 80,
    defaultActions: [
      {
        type: "redirect",
        redirect: {
          port: "443",
          protocol: "HTTPS",
          statusCode: "HTTP_301",
        },
      },
    ],
  });

  // DNS validation record
  const certValidationRecord = new aws.route53.Record(
    `${fgstackName}-cert-validation`,
    {
      name: certificate.domainValidationOptions[0].resourceRecordName,
      zoneId: zone.then((zone) => zone.zoneId),
      type: certificate.domainValidationOptions[0].resourceRecordType,
      records: [certificate.domainValidationOptions[0].resourceRecordValue],
      ttl: 60,
    },
  );

  // Certificate validation
  const certValidation = new aws.acm.CertificateValidation(
    `${fgstackName}-cert-validation-step`,
    {
      certificateArn: certificate.arn,
      validationRecordFqdns: [certValidationRecord.fqdn],
    },
  );

  return {
    lb,
    cluster,
    service,
    certificate,
  };
};
