terraform {
  # Terraform Version
  required_version = ">= 1.7.4"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

# resource "aws_lightsail_instance" "my_micro_linux_instance" {
#   name              = "MyMicroLinuxInstance"
#   availability_zone = "us-east-1a"
#   blueprint_id      = "micro_amazon_linux_2" # This is a placeholder value
#   bundle_id         = "micro_2_0"            # Adjust this to the specific bundle for a micro instance

#   tags = {
#     "Name" = "MyMicroLinuxInstance"
#   }
# }


resource "aws_vpc" "this" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "vpc-navikun-dev"
    env  = "dev"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "ig-navikun-dev"
    env  = "dev"
  }
}

resource "aws_subnet" "this" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.0.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "snet-navikun-dev"
    env  = "dev"
  }
}

resource "aws_security_group" "this" {
  vpc_id = aws_vpc.this.id

  description = "Allow HTTP and HTTPS inbound traffic"
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecr_repository" "this" {
  name = "ecr-navikun-dev"
  # The repository policy can be defined here if necessary.
}

resource "aws_s3_bucket" "this" {
  bucket = "s3-navikun-dev"
  acl    = "private"

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  public_access_block_configuration {
    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
  }
}

output "VPCId" {
  value = aws_vpc.this.id
}

output "SubnetId" {
  value = aws_subnet.this.id
}

output "SecurityGroupId" {
  value = aws_security_group.this.id
}

output "ECRRepositoryARN" {
  value = aws_ecr_repository.this.arn
}

output "ECRRepositoryName" {
  value = aws_ecr_repository.this.name
}

output "BucketName" {
  value = aws_s3_bucket.this.bucket
}

output "BucketURL" {
  value = aws_s3_bucket.this.bucket_domain_name
}
