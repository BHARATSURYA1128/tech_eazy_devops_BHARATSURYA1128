#!/bin/bash
# Update and install dependencies
yum update -y
yum install -y java-21-amazon-corretto-devel git maven

# Navigate to home, clone repo, and build
cd /home/ec2-user
git clone https://github.com/Trainings-TechEazy/test-repo-for-devops
cd test-repo-for-devops
mvn clean package

# ⬇️ MODIFIED LINE ⬇️
# Run the app with sudo privileges for port 80
sudo -E nohup java -jar target/hellomvc-0.0.1-SNAPSHOT.jar > /home/ec2-user/app.log 2>&1 &

# Give the app a moment to start and log
sleep 60

# Upload logs to S3. The BUCKET_NAME is passed in by Terraform.
aws s3 cp /home/ec2-user/app.log s3://${bucket_name}/app/logs/app.log
aws s3 cp /var/log/cloud-init.log s3://${bucket_name}/ec2/logs/cloud-init.log
