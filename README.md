# DevOps Assignment: Automated EC2 Deployment

This project contains a set of Bash scripts to automate the deployment of a Java application to an AWS EC2 instance. The automation handles infrastructure creation, dependency installation, application build, and execution, with support for different deployment stages (Dev/Prod).

---

## Project Structure

```bash
├── config.sh       # Configuration file for instance types, AMI IDs, etc.
├── deploy.sh       # Main deployment script to be run locally.
├── setup.sh        # User-data script that runs on the EC2 instance.
└── README.md       # This file.
```

---

## How It Works

1.  **`deploy.sh`**: This is the master script run on a local machine. It reads configurations from `config.sh`, creates an AWS Security Group, launches a new EC2 instance, and passes the `setup.sh` script as user data.
2.  **`setup.sh`**: This script automatically runs on the new EC2 instance at first boot. It installs Java 21, Maven, and Git. It then clones the application repository, builds the `.jar` file using Maven, and runs it on port 80.
3.  **`config.sh`**: This file centralizes all configurations. It sets different instance types for `Dev` and `Prod` stages and holds variables for the AMI ID and repository URL, making the deployment script reusable and easy to manage.

---

## Prerequisites for Running the Script

* AWS CLI installed and configured (`aws configure`).
* An EC2 Key Pair created in your AWS account.
* The EC2 Key Pair name must be updated in the `config.sh` file.

---

## How to Run

1.  Make the scripts executable:
    ```bash
    chmod +x *.sh
    ```

2.  Execute the main deployment script by passing the desired stage (`Dev` or `Prod`) as an argument.

    **For Development:**
    ```bash
    ./deploy.sh Dev
    ```

    **For Production:**
    ```bash
    ./deploy.sh Prod
    ```

The script will provide real-time output as it creates the resources, deploys the app, tests the endpoint, and finally stops the instance to save costs.
