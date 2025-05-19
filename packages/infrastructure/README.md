# Infrastructure for RandomUnfinishedThoughts

This package contains the infrastructure code for deploying the RandomUnfinishedThoughts project.

## Architecture

The deployment architecture uses:

1. **S3** for content storage
2. **Lambda** for build triggers
3. **CodeBuild** for container building
4. **ECR** for container registry

## Workflow

The deployment workflow is:

1. Content is prepared locally and synced to S3
2. S3 upload triggers a Lambda function
3. Lambda starts a CodeBuild project
4. CodeBuild pulls content from S3, builds a Docker image, and pushes it to ECR

## Setup Instructions

### Prerequisites

- AWS CLI configured with appropriate credentials
- Pulumi CLI installed
- mise with required tools (as per project README)

### Deployment Steps

1. **Deploy the infrastructure**:
   ```
   pulumi up
   ```

2. **Prepare and sync content**:
   ```
   ./local-sync.sh
   ```

3. **Monitor the build**:
   ```
   aws codebuild list-builds-for-project --project-name schierer-web-build
   ```

## Troubleshooting

### Common Issues

- **S3 sync fails**: Check AWS credentials and bucket permissions
- **Build doesn't trigger**: Check Lambda logs and S3 event notifications
- **Docker build fails**: Check CodeBuild logs for errors

### Logs

- **Lambda logs**: CloudWatch Logs under `/aws/lambda/build-trigger`
- **CodeBuild logs**: CloudWatch Logs under `/aws/codebuild/schierer-web-build`

## Manual Operations

- **Manually trigger a build**:
  ```
  aws codebuild start-build --project-name schierer-web-build
  ```

- **Force content refresh**:
  ```
  ./local-sync.sh
  ```
