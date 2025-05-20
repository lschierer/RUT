#!/bin/bash
# Script to prepare content locally and sync to S3

set -e  # Exit on any error

# Get the bucket name from Pulumi stack
BUCKET_NAME=$(pulumi stack output contentBucketName)
if [ -z "$BUCKET_NAME" ]; then
  echo "Error: Could not get bucket name from Pulumi stack"
  exit 1
fi

echo "Using S3 bucket: $BUCKET_NAME"

# Sync frontend code to S3
echo "Syncing frontend code to S3..."
aws --profile home s3 sync --exclude Build --exclude '_build/*' --exclude 'blib/*' --exclude '*.o' --exclude .DS_Store ../frontend/ "s3://$BUCKET_NAME/frontend/" --delete

# Sync archives to S3
echo "Syncing archives to S3..."
aws --profile home s3 sync ../archives/ "s3://$BUCKET_NAME/archives/" --delete

aws --profile home s3 cp ../../mise.toml "s3://$BUCKET_NAME/mise.toml"

echo "Content sync complete!"

# Get the CodeBuild project name
PROJECT_NAME=$(pulumi stack output codeBuildProjectName)
if [ -n "$PROJECT_NAME" ]; then
  echo "Triggering build for project: $PROJECT_NAME"
  AWS_PAGER="" aws --profile home codebuild start-build --no-paginate --output text --project-name "$PROJECT_NAME" | egrep "^(BUILD|ENVIRONMENT)"
else
  echo "Could not determine CodeBuild project name"
fi
