#!/bin/bash

# Check if stage parameter is provided
if [ -z "$1" ]; then
  echo "❌ Error: Stage parameter is missing. Usage: ./deploy.sh [Dev|Prod]"
  exit 1
fi

STAGE=$1
source config.sh $STAGE

echo "🚀 Starting deployment for stage: $STAGE"
echo "Instance Type: $INSTANCE_TYPE"
echo "AMI ID: $AMI_ID"

# Create a unique name for the security group
SG_NAME="app-sg-$STAGE-$(date +%s)"
TAG_NAME="AppServer-$STAGE"

echo "--- Creating Security Group: $SG_NAME ---"
SG_ID=$(aws ec2 create-security-group --group-name "$SG_NAME" --description "Allow HTTP and SSH" --query 'GroupId' --output text)
if [ -z "$SG_ID" ]; then echo "❌ Error creating security group."; exit 1; fi
echo "✅ Security Group created with ID: $SG_ID"

# Get your public IP for secure SSH access
MY_IP=$(curl -s http://checkip.amazonaws.com)
echo "--- Authorizing ingress rules for your IP ($MY_IP) and HTTP ---"
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 22 --cidr "$MY_IP/32"
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 80 --cidr 0.0.0.0/0
echo "✅ Ingress rules added."

# Inject environment variables into the setup script for the instance to use
# This ensures secrets are not in the repo, but read from the environment
cat setup.sh | \
  sed "s|\${REPO_URL}|${REPO_URL}|" | \
  sed "s|\${STAGE}|${STAGE}|" > setup_with_vars.sh

echo "--- Launching EC2 Instance ($INSTANCE_TYPE) ---"
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type "$INSTANCE_TYPE" \
  --key-name "$KEY_NAME" \
  --security-group-ids "$SG_ID" \
  --user-data file://setup_with_vars.sh \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$TAG_NAME}]" \
  --query 'Instances[0].InstanceId' --output text)

if [ -z "$INSTANCE_ID" ]; then echo "❌ Error launching EC2 instance."; exit 1; fi
echo "✅ Instance launched with ID: $INSTANCE_ID"

echo "--- Waiting for instance to enter 'running' state ---"
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"

PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
echo "✅ Instance is running at Public IP: $PUBLIC_IP"

echo "--- Testing application endpoint (waiting up to 2 mins) ---"
for i in {1..24}; do
  STATUS_CODE=$(curl -o /dev/null -s -w "%{http_code}" "http://$PUBLIC_IP:80/hello")
  if [ "$STATUS_CODE" -eq 200 ]; then
    RESPONSE=$(curl -s "http://$PUBLIC_IP")
    echo "✅ Success! Application responded with: '$RESPONSE'"
    break
  else
    echo "Attempt $i/24: Application not ready yet (HTTP Status: $STATUS_CODE). Retrying in 5s..."
    sleep 5
  fi
done

if [ "$STATUS_CODE" -ne 200 ]; then
    echo "❌ Error: Application did not become reachable."
fi

echo "--- Automation complete. Stopping instance in 200 minutes for cost saving. ---"
sleep 12000
echo "--- Stopping instance $INSTANCE_ID ---"
aws ec2 stop-instances --instance-ids "$INSTANCE_ID"
echo "✅ Instance stopped."

# Clean up temporary files
rm setup_with_vars.sh
