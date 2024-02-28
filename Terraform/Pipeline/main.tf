terraform {
  # Terraform Version
  required_version = ">= 1.7.4"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment after creating the backend, then run `terraform init`
  #   backend "s3" {
  #     bucket         = "tfstate-6021620e"
  #     key            = "Pipeline/terraform.tfstate"
  #     region         = "us-east-1"
  #     dynamodb_table = "terraform-state-locks"
  #     encrypt        = true
  #   }
}

# Configure the AWS Provider
provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

resource "aws_ecr_repository" "this" {
  name = var.app_name
  # The repository policy can be defined here if necessary.
  tags = {
    Owner       = "DevOps team"
    Environment = "dev"
    Terraform   = true
  }
}

resource "aws_codecommit_repository" "this" {
  repository_name = var.app_name            # Specify the name of your repository
  description     = "Git repository in AWS" # Add a description for your repository

  tags = {
    Owner       = "DevOps team"
    Environment = "dev"
    Terraform   = true
  }
}

resource "aws_iam_role" "codebuild_role" {
  name = "codebuild-${var.app_name}-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/codebuild/${var.app_name}"
  retention_in_days = 1

  skip_destroy = false

}

resource "aws_iam_policy" "codebuild_policy" {
  depends_on  = [aws_cloudwatch_log_group.this]
  name        = "CodeBuildBasePolicy-${var.app_name}-${var.region}"
  path        = "/"
  description = "Policy for CodeBuild to push images to ECR"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Effect" : "Allow",
        "Resource" : [
          aws_cloudwatch_log_group.this.arn,
          "${aws_cloudwatch_log_group.this.arn}:*"
        ],
        "Action" : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
      },
      {
        "Effect" : "Allow",
        "Resource" : [
          "arn:aws:s3:::codepipeline-${var.region}-${var.app_name}-*"
        ],
        "Action" : [
          "s3:PutObject",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketAcl",
          "s3:GetBucketLocation"
        ]
      },
      {
        "Effect" : "Allow",
        "Resource" : [
          "arn:aws:codecommit:${var.region}:${data.aws_caller_identity.current.account_id}:${var.app_name}"
        ],
        "Action" : [
          "codecommit:GitPull"
        ]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "codebuild:CreateReportGroup",
          "codebuild:CreateReport",
          "codebuild:UpdateReport",
          "codebuild:BatchPutTestCases",
          "codebuild:BatchPutCodeCoverages"
        ],
        "Resource" : [
          "arn:aws:codebuild:${var.region}:${data.aws_caller_identity.current.account_id}:report-group/${var.app_name}-*"
        ]
      },
      {
        "Action" : [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:GetAuthorizationToken",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ],
        "Resource" : "*",
        "Effect" : "Allow"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "codebuild_ecr_attach" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = aws_iam_policy.codebuild_policy.arn
}


resource "aws_s3_bucket" "artifact_store" {
  #   bucket_prefix = "${var.app_name}-artifacts"
  bucket_prefix = "codepipeline-${var.region}-${var.app_name}-"
  force_destroy = var.s3_force_destroy

  tags = {
    Purpose = "Artifact Store for CodeBuild and CodePipeline"
  }
}

# resource "aws_s3_bucket_acl" "this" {
#   bucket = aws_s3_bucket.artifact_store.id
# }

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.artifact_store.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_codebuild_project" "this" {
  name         = var.app_name
  description  = "An example CodeBuild project"
  service_role = aws_iam_role.codebuild_role.arn

  source {
    type      = "CODECOMMIT"
    location  = aws_codecommit_repository.this.clone_url_http
    buildspec = "buildspec.yml"
  }

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:5.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"


    environment_variable {
      type  = "PLAINTEXT"
      name  = "AWS_DEFAULT_REGION"
      value = "us-east-1"
    }

    environment_variable {
      type  = "PLAINTEXT"
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
    }

    environment_variable {
      type  = "PLAINTEXT"
      name  = "IMAGE_TAG"
      value = "latest"
    }
    environment_variable {
      type  = "PLAINTEXT"
      name  = "IMAGE_REPO_NAME"
      value = var.app_name
    }

  }

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.this.name
    }
  }

  tags = {
    Environment = "example"
  }
}

resource "aws_iam_role" "codepipeline_role" {
  name = "AWSCodePipelineServiceRole-${var.region}-${var.app_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "codepipeline.amazonaws.com"
        },
        Action = "sts:AssumeRole",
      },
    ],
  })
}

resource "aws_iam_policy" "codepipeline_policy" {
  name        = "AWSCodePipelineServiceRole-${var.region}-${var.app_name}"
  description = "A policy that allows CodePipeline to access CodeBuild and S3"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        "Action" : [
          "iam:PassRole"
        ],
        "Resource" : "*",
        "Effect" : "Allow",
        "Condition" : {
          "StringEqualsIfExists" : {
            "iam:PassedToService" : [
              "cloudformation.amazonaws.com",
              "elasticbeanstalk.amazonaws.com",
              "ec2.amazonaws.com",
              "ecs-tasks.amazonaws.com"
            ]
          }
        }
      },
      {
        "Action" : [
          "codecommit:CancelUploadArchive",
          "codecommit:GetBranch",
          "codecommit:GetCommit",
          "codecommit:GetRepository",
          "codecommit:GetUploadArchiveStatus",
          "codecommit:UploadArchive"
        ],
        "Resource" : "*",
        "Effect" : "Allow"
      },
      {
        "Action" : [
          "codedeploy:CreateDeployment",
          "codedeploy:GetApplication",
          "codedeploy:GetApplicationRevision",
          "codedeploy:GetDeployment",
          "codedeploy:GetDeploymentConfig",
          "codedeploy:RegisterApplicationRevision"
        ],
        "Resource" : "*",
        "Effect" : "Allow"
      },
      {
        "Action" : [
          "codestar-connections:UseConnection"
        ],
        "Resource" : "*",
        "Effect" : "Allow"
      },
      {
        "Action" : [
          "elasticbeanstalk:*",
          "ec2:*",
          "elasticloadbalancing:*",
          "autoscaling:*",
          "cloudwatch:*",
          "s3:*",
          "sns:*",
          "cloudformation:*",
          "rds:*",
          "sqs:*",
          "ecs:*"
        ],
        "Resource" : "*",
        "Effect" : "Allow"
      },
      {
        "Action" : [
          "lambda:InvokeFunction",
          "lambda:ListFunctions"
        ],
        "Resource" : "*",
        "Effect" : "Allow"
      },
      {
        "Action" : [
          "opsworks:CreateDeployment",
          "opsworks:DescribeApps",
          "opsworks:DescribeCommands",
          "opsworks:DescribeDeployments",
          "opsworks:DescribeInstances",
          "opsworks:DescribeStacks",
          "opsworks:UpdateApp",
          "opsworks:UpdateStack"
        ],
        "Resource" : "*",
        "Effect" : "Allow"
      },
      {
        "Action" : [
          "cloudformation:CreateStack",
          "cloudformation:DeleteStack",
          "cloudformation:DescribeStacks",
          "cloudformation:UpdateStack",
          "cloudformation:CreateChangeSet",
          "cloudformation:DeleteChangeSet",
          "cloudformation:DescribeChangeSet",
          "cloudformation:ExecuteChangeSet",
          "cloudformation:SetStackPolicy",
          "cloudformation:ValidateTemplate"
        ],
        "Resource" : "*",
        "Effect" : "Allow"
      },
      {
        "Action" : [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild",
          "codebuild:BatchGetBuildBatches",
          "codebuild:StartBuildBatch"
        ],
        "Resource" : "*",
        "Effect" : "Allow"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "devicefarm:ListProjects",
          "devicefarm:ListDevicePools",
          "devicefarm:GetRun",
          "devicefarm:GetUpload",
          "devicefarm:CreateUpload",
          "devicefarm:ScheduleRun"
        ],
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "servicecatalog:ListProvisioningArtifacts",
          "servicecatalog:CreateProvisioningArtifact",
          "servicecatalog:DescribeProvisioningArtifact",
          "servicecatalog:DeleteProvisioningArtifact",
          "servicecatalog:UpdateProduct"
        ],
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "cloudformation:ValidateTemplate"
        ],
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "ecr:DescribeImages"
        ],
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "states:DescribeExecution",
          "states:DescribeStateMachine",
          "states:StartExecution"
        ],
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "appconfig:StartDeployment",
          "appconfig:StopDeployment",
          "appconfig:GetDeployment"
        ],
        "Resource" : "*"
      }
    ],
  })
}

resource "aws_iam_role_policy_attachment" "codepipeline_policy_attach" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = aws_iam_policy.codepipeline_policy.arn
}


resource "aws_codepipeline" "this" {
  name          = var.app_name
  role_arn      = aws_iam_role.codepipeline_role.arn
  pipeline_type = "V2"

  artifact_store {
    location = aws_s3_bucket.artifact_store.bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        BranchName           = "main"
        RepositoryName       = var.app_name
        PollForSourceChanges = false # use event based polling
      }
    }
  }

  stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.this.name
      }
    }
  }

  // Add more stages as needed, such as a Deploy stage
}

resource "aws_cloudwatch_event_rule" "codecommit_rule" {
  name_prefix = "codepipeline-${var.app_name}-main-"
  description = "Triggers on changes to the CodeCommit repository"

  event_pattern = jsonencode({
    source      = ["aws.codecommit"]
    detail-type = ["CodeCommit Repository State Change"]
    resources   = [aws_codecommit_repository.this.arn]
    detail = {
      event = ["referenceCreated", "referenceUpdated"]
      "referenceType" : ["branch"],
      "referenceName" : ["main"]
    }
  })
}

resource "aws_iam_role" "cloudwatch_event_role" {
  name = "cwe-role-${var.region}-${var.app_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "events.amazonaws.com"
        },
        Action = "sts:AssumeRole",
      },
    ],
  })
}

resource "aws_iam_policy" "cloudwatch_event_policy" {
  name        = "start-pipeline-execution-${var.region}-${var.app_name}"
  path        = "/"
  description = "Allows Amazon CloudWatch Events to automatically start a new execution in the ${aws_codepipeline.this.name} pipeline when a change occurs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Effect" : "Allow",
        "Action" : [
          "codepipeline:StartPipelineExecution"
        ],
        "Resource" : [
          aws_codepipeline.this.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cloudwatch_policy_attachment" {
  role       = aws_iam_role.cloudwatch_event_role.name
  policy_arn = aws_iam_policy.cloudwatch_event_policy.arn
}


resource "aws_cloudwatch_event_target" "codepipeline_target" {
  rule      = aws_cloudwatch_event_rule.codecommit_rule.name
  target_id = "CodePipelineTarget"
  arn       = aws_codepipeline.this.arn

  role_arn = aws_iam_role.cloudwatch_event_role.arn
}


output "clone_url_http" {
  description = "The URL to use for cloning the repository over HTTPS."
  value       = aws_codecommit_repository.this.clone_url_http
}

output "clone_url_ssh" {
  description = "The URL to use for cloning the repository over SSH."
  value       = aws_codecommit_repository.this.clone_url_ssh
}
