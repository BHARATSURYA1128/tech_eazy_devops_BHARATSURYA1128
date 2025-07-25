#!/bin/bash -ex

# Redirect all output to a log file for debugging
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "--- Starting EC2 Setup ---"

# Update packages and install dependencies
sudo yum update -y
sudo yum install -y java-21-amazon-corretto-devel git maven

# Navigate to the user's home directory
cd /home/ec2-user

# Clone the repository (REPO_URL is passed from the deploy script)
echo "--- Cloning repository: https://github.com/Trainings-TechEazy/test-repo-for-devops ---"
git clone "https://github.com/Trainings-TechEazy/test-repo-for-devops"
cd test-repo-for-devops

# Build the application with Maven
echo "--- Building application with Maven ---"
mvn clean package

# Run the application in the background using 'sudo -E' for port 80
# The STAGE variable is passed to let the app know its environment
echo "--- Running Java application for stage: Dev on port 80 ---"
sudo -E nohup java -jar target/hellomvc-0.0.1-SNAPSHOT.jar --spring.profiles.active=Dev > /home/ec2-user/app.log 2>&1 &

echo "--- EC2 Setup Complete ---"
