import * as pulumi from "@pulumi/pulumi";
import * as aws from "@pulumi/aws";
import { execSync } from "child_process";

/**
 * Creates an ECR repository and pushes a Perl base image to it
 * @param imageTag The Perl version tag to use (e.g. "5.40")
 * @returns The ECR repository and image URI
 */

const repoName = `perl-base${pulumi.getStack().toLowerCase()}`;

export function createPerlBaseImage(imageTag: string = "5.40"): {
  repositoryName: string;
  imageUri: pulumi.Output<string>;
} {
  // Create a unique repository name

  // Create the ECR repository using AWS CLI
  try {
    console.log(`Creating ECR repository: ${repoName}`);

    // Check if repository exists
    try {
      execSync(
        `aws --profile home ecr describe-repositories --repository-names ${repoName}`,
        { stdio: "pipe" },
      );
      console.log(`Repository ${repoName} already exists`);
    } catch (error) {
      // Repository doesn't exist, create it
      console.log(`Creating repository ${repoName}`);
      execSync(
        `aws --profile home ecr create-repository --repository-name ${repoName} --image-scanning-configuration scanOnPush=true`,
        {
          stdio: "inherit",
        },
      );
    }

    // Get the AWS account ID
    const accountId = execSync(
      'aws --profile home sts get-caller-identity --query "Account" --output text',
    )
      .toString()
      .trim();
    const region =
      aws.config.region ||
      execSync("aws --profile home configure get region").toString().trim();

    // Construct the repository URI
    const repositoryUri = `${accountId}.dkr.ecr.${region}.amazonaws.com/${repoName}`;

    // Pull, tag and push the Perl image
    console.log(`Pulling Perl ${imageTag} image...`);
    execSync(`podman pull  --platform=linux/amd64 perl:${imageTag}`, {
      stdio: "inherit",
    });

    console.log(`Tagging image for ECR: ${repositoryUri}:${imageTag}`);
    execSync(`podman tag perl:${imageTag} ${repositoryUri}:${imageTag}`, {
      stdio: "inherit",
    });

    console.log(`Logging in to ECR...`);
    execSync(
      `aws --profile home ecr get-login-password --region ${region} | podman login --username AWS --password-stdin ${accountId}.dkr.ecr.${region}.amazonaws.com`,
      {
        stdio: "inherit",
        shell: "/bin/bash",
      },
    );

    console.log(`Pushing image to ECR: ${repositoryUri}:${imageTag}`);
    execSync(`podman push ${repositoryUri}:${imageTag}`, { stdio: "inherit" });

    // Return the repository name and full image URI
    return {
      repositoryName: repoName,
      imageUri: pulumi.output(`${repositoryUri}:${imageTag}`),
    };
  } catch (error) {
    console.error("Error creating ECR repository or pushing image:", error);
    throw error;
  }
}
