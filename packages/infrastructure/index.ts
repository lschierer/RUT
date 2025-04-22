import * as pulumi from "@pulumi/pulumi";
import * as aws from "@pulumi/aws";
import * as docker from "@pulumi/docker";

// Get configuration values
const config = new pulumi.Config();
const domainName = config.require("domainName");
const rootDomainName = config.require("rootDomainName");
const createHostedZone = config.getBoolean("createHostedZone") || false;
const logRetentionDays = config.getNumber("logRetentionDays") || 7; // Default to 7 days if not specified

// Define the AWS ECS cluster
const cluster = new aws.ecs.Cluster("my-cluster");

// Create CloudWatch log group for container logs with environment-specific retention
const logGroup = new aws.cloudwatch.LogGroup("app-log-group", {
  retentionInDays: logRetentionDays,
  tags: {
    Application: "schierer-org",
    Environment: pulumi.getStack(),
  },
});

// Create an ECR repository
const repository = new aws.ecr.Repository("my-repo");

// Define the Docker image
const image = new docker.Image("my-frontend-image", {
  build: {
    context: "../../",
    dockerfile: "./Dockerfile",
    platform: "linux/amd64", // Explicitly set the platform to linux/amd64
  },
  imageName: pulumi.interpolate`${repository.repositoryUrl}:latest`,
  registry: {
    server: repository.repositoryUrl,
    username: aws.ecr.getAuthorizationToken().then((token) => token.userName),
    password: aws.ecr.getAuthorizationToken().then((token) => token.password),
  },
});

// Create an IAM role for ECS task execution
const ecsTaskExecutionRole = new aws.iam.Role("ecsTaskExecutionRole", {
  assumeRolePolicy: {
    Version: "2012-10-17",
    Statement: [
      {
        Action: "sts:AssumeRole",
        Principal: {
          Service: "ecs-tasks.amazonaws.com",
        },
        Effect: "Allow",
      },
    ],
  },
});

// Attach the AmazonECSTaskExecutionRolePolicy to the role
new aws.iam.RolePolicyAttachment("ecsTaskExecutionRolePolicyAttachment", {
  role: ecsTaskExecutionRole.name,
  policyArn:
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy",
});

// Create an ECS task definition with logging enabled
const taskDefinition = new aws.ecs.TaskDefinition("my-task", {
  family: "my-task-family",
  containerDefinitions: pulumi.all([image.imageName, logGroup.name]).apply(
    ([imageName, logGroupName]) =>
      JSON.stringify([
        {
          name: "my-frontend",
          image: imageName,
          essential: true,
          portMappings: [
            {
              containerPort: 3000, // Container listens on port 3000
              hostPort: 3000,      // Host maps to the same port
              protocol: "tcp",
            },
          ],
          // Add logging configuration
          logConfiguration: {
            logDriver: "awslogs",
            options: {
              "awslogs-group": logGroupName,
              "awslogs-region": aws.config.region,
              "awslogs-stream-prefix": "ecs",
            },
          },
        },
      ])
  ),
  networkMode: "awsvpc",
  requiresCompatibilities: ["FARGATE"],
  cpu: "256",
  memory: "512",
  executionRoleArn: ecsTaskExecutionRole.arn,
  taskRoleArn: ecsTaskExecutionRole.arn,
});

// Retrieve subnet IDs for the default VPC
const defaultVpc = aws.ec2.getVpc({ default: true });
const subnets = defaultVpc.then((vpc) =>
  aws.ec2.getSubnets({ filters: [{ name: "vpc-id", values: [vpc.id] }] }),
);

// Create a security group for the ALB
const albSecurityGroup = new aws.ec2.SecurityGroup("alb-security-group", {
  vpcId: defaultVpc.then((vpc) => vpc.id),
  ingress: [
    { protocol: "tcp", fromPort: 80, toPort: 80, cidrBlocks: ["0.0.0.0/0"] },
    { protocol: "tcp", fromPort: 443, toPort: 443, cidrBlocks: ["0.0.0.0/0"] },
  ],
  egress: [
    { protocol: "-1", fromPort: 0, toPort: 0, cidrBlocks: ["0.0.0.0/0"] },
  ],
});

// Create a security group for the ECS tasks
const ecsSecurityGroup = new aws.ec2.SecurityGroup("ecs-security-group", {
  vpcId: defaultVpc.then(vpc => vpc.id),
  ingress: [
    // Allow inbound traffic from ALB on port 3000
    { 
      protocol: "tcp", 
      fromPort: 3000, 
      toPort: 3000, 
      securityGroups: [albSecurityGroup.id],
    },
  ],
  egress: [
    // Allow all outbound traffic
    { protocol: "-1", fromPort: 0, toPort: 0, cidrBlocks: ["0.0.0.0/0"] },
  ],
});

// Get or create Route53 hosted zone
let hostedZone: aws.route53.GetZoneResult | aws.route53.Zone;

if (createHostedZone) {
  hostedZone = new aws.route53.Zone("hosted-zone", {
    name: rootDomainName,
  });
} else {
  hostedZone = await aws.route53.getZone({
    name: rootDomainName,
  });
}

// Create an ACM certificate
const certificate = new aws.acm.Certificate("certificate", {
  domainName: domainName,
  subjectAlternativeNames: [`www.${domainName}`], // Add www subdomain to certificate
  validationMethod: "DNS",
});

// Create DNS records for certificate validation
const certificateValidationDomain = new aws.route53.Record(
  "certificate-validation-record",
  {
    name: certificate.domainValidationOptions[0].resourceRecordName,
    zoneId: createHostedZone
      ? (hostedZone as aws.route53.Zone).zoneId
      : (hostedZone as aws.route53.GetZoneResult).zoneId,
    type: certificate.domainValidationOptions[0].resourceRecordType,
    records: [certificate.domainValidationOptions[0].resourceRecordValue],
    ttl: 60,
  },
);

// Create DNS validation record for the www subdomain
const wwwCertificateValidationDomain = new aws.route53.Record(
  "www-certificate-validation-record",
  {
    name: certificate.domainValidationOptions[1].resourceRecordName,
    zoneId: createHostedZone
      ? (hostedZone as aws.route53.Zone).zoneId
      : (hostedZone as aws.route53.GetZoneResult).zoneId,
    type: certificate.domainValidationOptions[1].resourceRecordType,
    records: [certificate.domainValidationOptions[1].resourceRecordValue],
    ttl: 60,
  },
);

// Wait for certificate validation
const certificateValidation = new aws.acm.CertificateValidation(
  "certificate-validation",
  {
    certificateArn: certificate.arn,
    validationRecordFqdns: [
      certificateValidationDomain.fqdn,
      wwwCertificateValidationDomain.fqdn,
    ],
  },
);

// Create a load balancer
const alb = new aws.lb.LoadBalancer("my-load-balancer", {
  internal: false,
  loadBalancerType: "application",
  securityGroups: [albSecurityGroup.id],
  subnets: subnets.then((subnet) => subnet.ids),
});

// Create a target group
const targetGroup = new aws.lb.TargetGroup("my-target-group", {
  port: 3000,           // Target group connects to container on port 3000
  protocol: "HTTP",
  targetType: "ip",
  vpcId: defaultVpc.then((vpc) => vpc.id),
  healthCheck: {
    path: "/",
    port: "3000",       // Health check on port 3000
    protocol: "HTTP",
    matcher: "200-399",
    interval: 30,       // Check every 30 seconds
    timeout: 5,         // 5 second timeout
    healthyThreshold: 2,    // 2 successful checks to be considered healthy
    unhealthyThreshold: 3,  // 3 failed checks to be considered unhealthy
  },
});

// Create HTTP listener (will redirect to HTTPS)
const httpListener = new aws.lb.Listener("http-listener", {
  loadBalancerArn: alb.arn,
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

// Create HTTPS listener
const httpsListener = new aws.lb.Listener("https-listener", {
  loadBalancerArn: alb.arn,
  port: 443,
  protocol: "HTTPS",
  sslPolicy: "ELBSecurityPolicy-2016-08",
  certificateArn: certificateValidation.certificateArn,
  defaultActions: [
    {
      type: "forward",
      targetGroupArn: targetGroup.arn,
    },
  ],
});

// Create an ECS service
const service = new aws.ecs.Service("my-service", {
  cluster: cluster.arn,
  taskDefinition: taskDefinition.arn,
  desiredCount: 1,
  launchType: "FARGATE",
  networkConfiguration: {
    subnets: subnets.then((subnet) => subnet.ids),
    assignPublicIp: true,
    securityGroups: [ecsSecurityGroup.id], // Use the ECS security group
  },
  loadBalancers: [
    {
      targetGroupArn: targetGroup.arn,
      containerName: "my-frontend",
      containerPort: 3000,  // Container port is 3000
    },
  ],
});

// Create Route53 record for the domain pointing to the ALB
const dnsRecord = new aws.route53.Record("dns-record", {
  zoneId: createHostedZone
    ? (hostedZone as aws.route53.Zone).zoneId
    : (hostedZone as aws.route53.GetZoneResult).zoneId,
  name: domainName,
  type: "A",
  aliases: [
    {
      name: alb.dnsName,
      zoneId: alb.zoneId,
      evaluateTargetHealth: true,
    },
  ],
});

// Create www alias record if this is the root domain
const isRootDomain = domainName === rootDomainName;
const wwwDomainName = isRootDomain 
  ? `www.${rootDomainName}` 
  : `www.${domainName}`;

const wwwDnsRecord = new aws.route53.Record("www-dns-record", {
  zoneId: createHostedZone
    ? (hostedZone as aws.route53.Zone).zoneId
    : (hostedZone as aws.route53.GetZoneResult).zoneId,
  name: wwwDomainName,
  type: "A",
  aliases: [
    {
      name: alb.dnsName,
      zoneId: alb.zoneId,
      evaluateTargetHealth: true,
    },
  ],
});

// Export the URLs of the deployed service
export const httpUrl = pulumi.interpolate`http://${domainName}`;
export const httpsUrl = pulumi.interpolate`https://${domainName}`;
export const albDnsName = alb.dnsName;
export const logGroupName = logGroup.name;
