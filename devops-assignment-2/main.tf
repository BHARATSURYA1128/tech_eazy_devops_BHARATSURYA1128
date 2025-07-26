terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1" # You can change this if needed
}

variable "log_bucket_name" {
  description = "A unique name for the S3 log bucket."
  type        = string
}

# --- S3 Bucket for Logs ---
resource "aws_s3_bucket" "log_bucket" {
  bucket = var.log_bucket_name
}

# ⬇️ FIX: This block has been removed as it's no longer needed for private buckets.
# resource "aws_s3_bucket_acl" "log_bucket_acl" { ... }

# ⬇️ FIX: Added the 'filter' block inside the rule.
resource "aws_s3_bucket_lifecycle_configuration" "log_lifecycle" {
  bucket = aws_s3_bucket.log_bucket.id

  rule {
    id     = "delete-logs-after-7-days"
    status = "Enabled"

    filter {
      prefix = "" # An empty prefix applies this rule to all objects
    }

    expiration {
      days = 7
    }
  }
}

# --- IAM Role for EC2 (Upload Permission) ---
# ... (The rest of your file remains exactly the same) ...
data "aws_iam_policy_document" "ec2_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_s3_upload_role" {
  name               = "ec2-s3-upload-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role_policy.json
}

data "aws_iam_policy_document" "s3_upload_policy_doc" {
  statement {
    actions = [
      "s3:PutObject",
      "s3:PutObjectAcl"
    ]
    resources = ["${aws_s3_bucket.log_bucket.arn}/*"]
  }
  statement {
    actions   = ["s3:CreateBucket"]
    resources = [aws_s3_bucket.log_bucket.arn]
  }
}

resource "aws_iam_policy" "s3_upload_policy" {
  name   = "S3-Upload-Policy"
  policy = data.aws_iam_policy_document.s3_upload_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "upload_policy_attach" {
  role       = aws_iam_role.ec2_s3_upload_role.name
  policy_arn = aws_iam_policy.s3_upload_policy.arn
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-s3-upload-instance-profile"
  role = aws_iam_role.ec2_s3_upload_role.name
}


# --- IAM Role for Verification (Read-Only) ---
data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "verify_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}

resource "aws_iam_role" "s3_readonly_role" {
  name               = "s3-readonly-verify-role"
  assume_role_policy = data.aws_iam_policy_document.verify_assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "readonly_policy_attach" {
  role       = aws_iam_role.s3_readonly_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

# --- EC2 Instance and Security Group ---
data "template_file" "setup_script" {
  template = file("setup_and_log.sh")
  vars = {
    bucket_name = aws_s3_bucket.log_bucket.id
  }
}

resource "aws_security_group" "app_sg" {
  name        = "app-server-sg"
  description = "Allow HTTP and SSH inbound traffic"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "app_server" {
  ami           = "ami-08a6efd148b1f7504" # Amazon Linux 2023 for ap-south-1
  instance_type = "t2.micro"
  key_name      = "adb" # IMPORTANT: Replace with your actual key pair name

  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  user_data              = data.template_file.setup_script.rendered

  tags = {
    Name = "DevOps-Assignment-2-Instance"
  }
}

output "instance_public_ip" {
  value = aws_instance.app_server.public_ip
}
output "verification_role_arn" {
  description = "The ARN of the S3 read-only role for verification."
  value       = aws_iam_role.s3_readonly_role.arn
}

