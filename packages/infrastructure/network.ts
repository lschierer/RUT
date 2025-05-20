import * as pulumi from "@pulumi/pulumi";
import * as aws from "@pulumi/aws";

const config = new pulumi.Config("schierer.org");
const region = aws.config.region || "us-east-2";
const fgstackName = pulumi.getStack().toLowerCase().replaceAll("\.", "");

export type NetworkStackReturn = {
  vpc: aws.ec2.Vpc;
  publicSubnets: aws.ec2.Subnet[];
};

export const networkStack = () => {
  const vpc = new aws.ec2.Vpc(`${fgstackName}-vpc`, {
    cidrBlock: "10.0.0.0/16",
    enableDnsHostnames: true,
    enableDnsSupport: true,
  });

  // Create subnets in different availability zones
  const publicSubnets = [
    new aws.ec2.Subnet(`${fgstackName}-subnet-1`, {
      vpcId: vpc.id,
      cidrBlock: "10.0.1.0/24",
      availabilityZone: `${region}a`,
      mapPublicIpOnLaunch: true,
    }),
    new aws.ec2.Subnet(`${fgstackName}-subnet-2`, {
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

  return {
    vpc,
    publicSubnets,
  } as NetworkStackReturn;
};
