#!/bin/bash

# Default configurations
KEY_NAME="adb"
AMI_ID="ami-08a6efd148b1f7504"
REPO_URL="https://github.com/Trainings-TechEazy/test-repo-for-devops"

# Stage-specific configurations
STAGE=$1

case $STAGE in
  "Dev")
    INSTANCE_TYPE="t2.micro" # Free tier eligible
    ;;
  "Prod")
    INSTANCE_TYPE="t2.small" # Example for production
    ;;
  *)
    echo "Usage: $0 [Dev|Prod]"
    echo "Defaulting to Dev stage."
    INSTANCE_TYPE="t2.micro"
    ;;
esac

# Export variables to be used by other scripts
export KEY_NAME
export AMI_ID
export REPO_URL
export INSTANCE_TYPE
export STAGE
