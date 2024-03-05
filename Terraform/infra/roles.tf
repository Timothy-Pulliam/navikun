resource "aws_iam_role" "ecs_task_execution_role_attachment" {
  name        = "ecsTaskExecutionRole"
  description = "Provides access to other AWS service resources that are required to run Amazon ECS tasks"
  path        = "/service-role/"
  assume_role_policy = jsonencode({
    "Version" : "2008-10-17",
    "Statement" : [
      {
        "Sid" : "",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "ecs-tasks.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_attachment" {
  role       = aws_iam_role.ecs_task_execution_role_attachment.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_bedrock_invoker" {
  name = "ecs_bedrock_invoker"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_policy" "ecs_bedrock_invoker_policy" {
  name        = "ecs_bedrock_invoker_policy"
  description = "Policy for ECS to invoke Bedrock Runtime"

  policy = jsonencode({
    Version = "2012-10-17"
    "Statement" : [
      {
        "Sid" : "AmazonBedrockAgentBedrockFoundationModelPolicyProd",
        "Effect" : "Allow",
        "Action" : "bedrock:InvokeModel",
        "Resource" : [
          "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-instant-v1"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_bedrock_invoker_policy_attachment" {
  role       = aws_iam_role.ecs_bedrock_invoker.name
  policy_arn = aws_iam_policy.ecs_bedrock_invoker_policy.arn
}
