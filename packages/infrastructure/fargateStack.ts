import * as pulumi from "@pulumi/pulumi";
import * as aws from "@pulumi/aws";
import * as fs from "fs";
import * as path from "path";

const config = new pulumi.Config("schierer.org");
const domainName = config.require("domainName");
const rootDomainName = config.require("rootDomainName"); // e.g. schierer.org
const mojoLogLevel = config.get("mojoLogLevel") || "warn";
const region = aws.config.region || "us-east-2";

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
): ContainerCluster => {
  // Create an ECS cluster
  const cluster = new aws.ecs.Cluster("schierer-cluster", {
    name: "schierer-cluster",
    settings: [
      {
        name: "containerInsights",
        value: "enabled",
      },
    ],
  });

  // Create a VPC for the ECS service if you don't have one already
  const vpc = new aws.ec2.Vpc("schierer-vpc", {
    cidrBlock: "10.0.0.0/16",
    enableDnsHostnames: true,
    enableDnsSupport: true,
  });

  // Create subnets in different availability zones
  const publicSubnets = [
    new aws.ec2.Subnet("schierer-subnet-1", {
      vpcId: vpc.id,
      cidrBlock: "10.0.1.0/24",
      availabilityZone: `${region}a`,
      mapPublicIpOnLaunch: true,
    }),
    new aws.ec2.Subnet("schierer-subnet-2", {
      vpcId: vpc.id,
      cidrBlock: "10.0.2.0/24",
      availabilityZone: `${region}b`,
      mapPublicIpOnLaunch: true,
    }),
  ];

  // Create an internet gateway
  const gateway = new aws.ec2.InternetGateway(`${fgstackName}-gw`, {
    vpcId: vpc.id,
  });

  // Create a route table
  const routeTable = new aws.ec2.RouteTable(`${fgstackName}-rt`, {
    vpcId: vpc.id,
    routes: [
      {
        cidrBlock: "0.0.0.0/0",
        gatewayId: gateway.id,
      },
    ],
  });

  // Associate the route table with the subnets
  const routeTableAssociations = publicSubnets.map((subnet, i) => {
    return new aws.ec2.RouteTableAssociation(
      `${fgstackName}-route-table-association-${i}`,
      {
        subnetId: subnet.id,
        routeTableId: routeTable.id,
      },
    );
  });

  // Create a security group for the load balancer
  const lbSecurityGroup = new aws.ec2.SecurityGroup(`${fgstackName}-lb-sg`, {
    vpcId: vpc.id,
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
    vpcId: vpc.id,
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
    subnets: publicSubnets.map((subnet) => subnet.id),
    enableDeletionProtection: false,
  });

  // Create a target group for the load balancer
  const targetGroup = new aws.lb.TargetGroup(`${fgstackName}-tg`, {
    port: 3000,
    protocol: "HTTP",
    targetType: "ip",
    vpcId: vpc.id,
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
  const taskRole = new aws.iam.Role("schierer-task-role", {
    assumeRolePolicy: aws.iam.assumeRolePolicyForPrincipal({
      Service: "ecs-tasks.amazonaws.com",
    }),
  });

  // Create a task definition for your container
  const taskDefinition = new aws.ecs.TaskDefinition(`${fgstackName}-task`, {
    family: "schierer-web",
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
            name: "schierer-web",
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
                "awslogs-group": "/ecs/schierer-web",
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
  const logGroup = new aws.cloudwatch.LogGroup("schierer-logs", {
    name: "/ecs/schierer-web",
    retentionInDays: 30,
  });

  // Create an ECS service to run your task
  const service = new aws.ecs.Service(`${fgstackName}-service`, {
    cluster: cluster.arn,
    desiredCount: 1,
    launchType: "FARGATE",
    taskDefinition: taskDefinition.arn,
    networkConfiguration: {
      subnets: publicSubnets.map((subnet) => subnet.id),
      securityGroups: [ecsSecurityGroup.id],
      assignPublicIp: true,
    },
    loadBalancers: [
      {
        targetGroupArn: targetGroup.arn,
        containerName: "schierer-web",
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
  });

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
    "schierer-ecr-event-target",
    {
      rule: ecrEventRule.name,
      arn: cluster.arn,
      roleArn: eventRole.arn,
      ecsTarget: {
        taskCount: 1,
        taskDefinitionArn: taskDefinition.arn,
        launchType: "FARGATE",
        networkConfiguration: {
          subnets: publicSubnets.map((subnet) => subnet.id),
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
