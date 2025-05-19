// Import the AWS SDK v3 CodeBuild client
import { CodeBuildClient, StartBuildCommand } from "@aws-sdk/client-codebuild";

// Create client in the same region as your resources
const codebuild = new CodeBuildClient({ region: process.env.AWS_REGION });

type Record = {
  eventVersion: string;
  eventSource: string;
  awsRegion: string;
  eventTime: string | Date;
  eventName: string;
  userIdentity: {
    principalId: string;
  };
  requestParameters: {
    sourceIPAddress: string;
  };
  responseElements: {
    "x-amz-request-id": string;
    "x-amz-id-2": string;
  };
  s3: {
    s3SchemaVersion: string;
    configurationId: string;
    bucket: {
      name: string;
      ownerIdentity: {
        principalId: string;
      };
      arn: string;
    };
    object: {
      key: string;
      size: number | string;
      eTag: string;
      sequencer: string;
    };
  };
};
type S3TriggerEvent = {
  Records: Record[];
};

export const handler = async (event: S3TriggerEvent | Event) => {
  console.log("S3 event:", JSON.stringify(event, null, 2));

  // Only trigger build for specific paths
  const records = "Records" in event ? event.Records : [];
  const shouldTrigger = records.length
    ? records.some((record) => {
        const key = record.s3.object.key;
        return (
          key.startsWith("frontend/") ||
          key.startsWith("luke/") ||
          key.startsWith("archives/")
        );
      })
    : false;

  if (!shouldTrigger) {
    console.log("Ignoring event - not a content change");
    return { statusCode: 200, body: "Ignored" };
  }

  try {
    const command = new StartBuildCommand({
      projectName: process.env.CODEBUILD_PROJECT_NAME,
    });

    const response = await codebuild.send(command);
    if (response.build && response.build.id) {
      console.log("Build started:", response.build.id);
      return {
        statusCode: 200,
        body: "Build started: " + response.build.id,
      };
    } else {
      console.log("Build ID not available");
      return {
        statusCode: 400,
        body: "Build ID not available. " + JSON.stringify(response),
      };
    }
  } catch (error) {
    console.error("Error starting build:", error);
    return {
      statusCode: 500,
      body: "Failed to start build: " + error.message,
    };
  }
};
