terraform {
  # Terraform Version
  required_version = ">= 1.7.4"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  #   Uncomment after creating the backend, then run `terraform init`
  backend "s3" {
    bucket         = "tfstate-6021620e"
    key            = "infra/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-locks"
    encrypt        = true
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.region
}
