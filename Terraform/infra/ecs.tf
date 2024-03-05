resource "aws_service_discovery_http_namespace" "this" {
  name        = var.app_name
  description = ""
}

resource "aws_ecs_cluster" "this" {
  name = var.app_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  configuration {
    execute_command_configuration {
      logging = "DEFAULT"
      #   log_configuration {
      #     cloud_watch_encryption_enabled = false # default false
      #     cloud_watch_log_group_name     = aws_cloudwatch_log_group.this.name
      #   }
    }
  }

  service_connect_defaults {
    # Select the namespace to specify a group of services that make 
    # up your application. You can overwrite this 
    # value at the service level.
    namespace = aws_service_discovery_http_namespace.this.arn
  }

  tags = {
    env     = "dev"
    service = var.app_name
  }
}

# pod == ecs task, deployment == ecs service
resource "aws_ecs_task_definition" "this" {
  family                   = var.app_name
  requires_compatibilities = ["FARGATE"]
  # If using Fargate launch type, you must use awsvpc
  network_mode       = "awsvpc"
  cpu                = 1024 # MB
  memory             = 2048
  task_role_arn      = aws_iam_role.ecs_bedrock_invoker.arn
  execution_role_arn = aws_iam_role.ecs_task_execution_role_attachment.arn
  container_definitions = jsonencode(
    [
      {
        "name" : var.app_name,
        "image" : var.docker_image,
        "cpu" : 0,
        "portMappings" : [
          {
            "name" : "http",
            "containerPort" : 8080,
            "hostPort" : 8080,
            "protocol" : "tcp",
            "appProtocol" : "http"
          }
        ],
        "essential" : true,
        "environment" : [],
        "environmentFiles" : [],
        "mountPoints" : [],
        "volumesFrom" : [],
        "ulimits" : [],
        "logConfiguration" : {
          "logDriver" : "awslogs",
          "options" : {
            "awslogs-create-group" : "true",
            "awslogs-group" : "/ecs/${var.app_name}",
            "awslogs-region" : var.region,
            "awslogs-stream-prefix" : "ecs"
          },
          "secretOptions" : []
        },
        "healthCheck" : {
          "command" : [
            "CMD-SHELL", "curl -f http://127.0.0.1:8080/ || exit 1"
          ],
          "interval" : 30,
          "timeout" : 5,
          "retries" : 3
        }
      }
    ]
  )
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
}

# pod == ecs task, deployment == ecs service
resource "aws_ecs_service" "this" {
  name            = var.app_name
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  # If using Fargate or awsvpc network mode, do not specify this role.
  #   iam_role        = aws_iam_role.foo.arn
  #   depends_on      = [aws_iam_role_policy.foo]

  #   ordered_placement_strategy {
  #     type  = "binpack"
  #     field = "cpu"
  #   }

  network_configuration {
    subnets          = [aws_subnet.private1.id, aws_subnet.private2.id]
    security_groups  = [aws_security_group.ecs_service.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.fargate.arn
    container_name   = var.app_name # Change to your container name
    container_port   = 8080
  }
}
