#!/usr/bin/env node
// cspell: disable
import * as cdk from "aws-cdk-lib/core";
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import path from 'path';
import { fileURLToPath } from 'url';

import {
  ApplicationStack,
  type ApplicationStackProps,
} from '../../PAGI-WebServer/lib/Infrastructure/index.ts';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = new cdk.App();

import { execSync } from "child_process";

try {
  const stdout = execSync(
    "podman machine inspect --format 'unix://{{.ConnectionInfo.PodmanSocket.Path}}'",
    { encoding: "utf-8" },
  ).trim();

  process.env.DOCKER_HOST = stdout;
  process.env.CDK_DOCKER = "podman";
} catch (error) {
  console.error(`Failed to get podman socket: ${error as string}`);
  process.exit(1);
}

const mode = !process.env.MODE?.localeCompare("prod") ? "prod" : "dev";
const region = process.env.REGION ?? "us-east-2";

type EnvConfig = {
  subdomain: string;
  instanceSize: ec2.InstanceSize;
};

const envConfigs: Record<string, EnvConfig> = {
  dev: {
    subdomain: 'dev',
    instanceSize: ec2.InstanceSize.SMALL,
  },
  prod: {
    subdomain: 'www',
    instanceSize: ec2.InstanceSize.SMALL,
  },
};

const config = envConfigs[mode];

const props: ApplicationStackProps = {
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region,
  },
  mode,
  prefix: "SchiererOrg",
  appSubdomain: config.subdomain,
  domainName: "schierer.org",
  hostedZoneId: "ZOB4NXMJR2BZF",
  zoneName: 'schierer.org',
  instanceSize: config.instanceSize,
  appPort: 3004,
  mainPerlDistro: 'Schierer-Org',
  appCodePath: path.join(__dirname, '..'),
  appCodeExcludes: [
    'node_modules',
    'infrastructure',
    'cdk.out',
    '.git',
  ],
  crossRegionReferences: true,
  tags: {
    Environment: mode,
    Application: 'SchiererOrg',
  },
};

new ApplicationStack(app, `SchiererOrg-${mode}`, props);

app.synth();
