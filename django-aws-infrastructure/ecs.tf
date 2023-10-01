# Production cluster
resource "aws_ecs_cluster" "prod" {
  name = "prod"
}

locals {
  container_vars = {
    region = var.region

    image     = aws_ecr_repository.backend.repository_url
    log_group = aws_cloudwatch_log_group.prod_backend.name

    rds_db_name  = var.prod_rds_db_name
    rds_username = var.prod_rds_username
    rds_password = var.prod_rds_password
    rds_hostname = aws_db_instance.prod.address
  
    
    sqs_access_key = aws_iam_access_key.prod_sqs.id
    sqs_secret_key = aws_iam_access_key.prod_sqs.secret
    sqs_name = aws_sqs_queue.prod.name
    
    s3_media_bucket         = var.prod_media_bucket
    s3_access_key           = aws_iam_access_key.prod_media_bucket.id
    s3_secret_key           = aws_iam_access_key.prod_media_bucket.secret

  }
}

# Backend web task definition and service
resource "aws_ecs_task_definition" "prod_backend_web" {
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512

  family = "backend-web"
  container_definitions = templatefile(
    "templates/backend_container.json.tpl",
    merge(
      local.container_vars,
      {
        name       = "prod-backend-web"
        command    = ["gunicorn", "-w", "3", "-b", ":8000", "django_aws.wsgi:application"]
        log_stream = aws_cloudwatch_log_stream.prod_backend_web.name
    
      },
   )
  )
  execution_role_arn = aws_iam_role.ecs_task_execution.arn
  task_role_arn      = aws_iam_role.prod_backend_task.arn
}

resource "aws_ecs_service" "prod_backend_web" {
  name                               = "prod-backend-web"
  cluster                            = aws_ecs_cluster.prod.id
  task_definition                    = aws_ecs_task_definition.prod_backend_web.arn
  enable_execute_command             = true
  desired_count                      = 1
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
  launch_type                        = "FARGATE"
  scheduling_strategy                = "REPLICA"

  load_balancer {
    target_group_arn = aws_lb_target_group.prod_backend.arn
    container_name   = "prod-backend-web"
    container_port   = 8000
  }

  network_configuration {
    security_groups  = [aws_security_group.prod_ecs_backend.id]
    subnets          = [aws_subnet.prod_private_1.id, aws_subnet.prod_private_2.id]
    assign_public_ip = false
  }
}

# Security Group
resource "aws_security_group" "prod_ecs_backend" {
  name        = "prod-ecs-backend"
  vpc_id      = aws_vpc.prod.id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.prod_lb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# IAM roles and policies
resource "aws_iam_role" "prod_backend_task" {
  name = "prod-backend-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
        Effect = "Allow",
        Sid    = ""
      }
    ]
  })
  
  inline_policy {
    name = "prod-backend-task-ssmmessages"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action   = [
            "ssmmessages:CreateControlChannel",
            "ssmmessages:CreateDataChannel",
            "ssmmessages:OpenControlChannel",
            "ssmmessages:OpenDataChannel",
          ]
          Effect   = "Allow"
          Resource = "*"
        },
      ]
    })
  }
}

resource "aws_iam_role" "ecs_task_execution" {
  name = "ecs-task-execution"

  assume_role_policy = jsonencode(
    {
      Version = "2012-10-17",
      Statement = [
        {
          Action = "sts:AssumeRole",
          Principal = {
            Service = "ecs-tasks.amazonaws.com"
          },
          Effect = "Allow",
          Sid    = ""
        }
      ]
    }
  )
}

resource "aws_iam_role_policy_attachment" "ecs-task-execution-role-policy-attachment" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Cloudwatch Logs
resource "aws_cloudwatch_log_group" "prod_backend" {
  name              = "prod-backend"
  retention_in_days = var.ecs_prod_backend_retention_days
}

resource "aws_cloudwatch_log_stream" "prod_backend_web" {
  name           = "prod-backend-web"
  log_group_name = aws_cloudwatch_log_group.prod_backend.name
}

resource "aws_cloudwatch_log_stream" "prod_backend_migrations" {
  name           = "prod-backend-migrations"
  log_group_name = aws_cloudwatch_log_group.prod_backend.name
}


resource "aws_cloudwatch_log_stream" "prod_backend_worker" {
  name           = "prod-backend-worker"
  log_group_name = aws_cloudwatch_log_group.prod_backend.name
}

resource "aws_cloudwatch_log_stream" "prod_backend_beat" {
  name           = "prod-backend-beat"
  log_group_name = aws_cloudwatch_log_group.prod_backend.name
}

# Migrations

resource "aws_ecs_task_definition" "prod_backend_migration" {
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512

  family = "backend-migration"
  container_definitions = templatefile(
    "templates/backend_container.json.tpl",
    merge(
      local.container_vars,
      {
        name       = "prod-backend-migration"
        command    = ["python", "manage.py", "migrate"]
        log_stream = aws_cloudwatch_log_stream.prod_backend_migrations.name
      },
    )
  )
  depends_on         = [aws_db_instance.prod]
  execution_role_arn = aws_iam_role.ecs_task_execution.arn
  task_role_arn      = aws_iam_role.prod_backend_task.arn
}


# Worker

resource "aws_ecs_task_definition" "prod_backend_worker" {
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512

  family = "backend-worker"
  container_definitions = templatefile(
    "templates/backend_container.json.tpl",
    merge(
      local.container_vars,
      {
        name       = "prod-backend-worker"
        command    = ["celery", "-A", "django_aws", "worker", "--loglevel", "info"]
        log_stream = aws_cloudwatch_log_stream.prod_backend_worker.name
      },
    )
  )
  depends_on = [aws_sqs_queue.prod, aws_db_instance.prod]
  execution_role_arn = aws_iam_role.ecs_task_execution.arn
  task_role_arn      = aws_iam_role.prod_backend_task.arn
}

resource "aws_ecs_service" "prod_backend_worker" {
  name                               = "prod-backend-worker"
  cluster                            = aws_ecs_cluster.prod.id
  task_definition                    = aws_ecs_task_definition.prod_backend_worker.arn
  desired_count                      = 2
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
  launch_type                        = "FARGATE"
  scheduling_strategy                = "REPLICA"
  enable_execute_command             = true

  network_configuration {
    security_groups  = [aws_security_group.prod_ecs_backend.id]
    subnets          = [aws_subnet.prod_private_1.id, aws_subnet.prod_private_2.id]
    assign_public_ip = false
  }
}

# Beat

resource "aws_ecs_task_definition" "prod_backend_beat" {
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512

  family = "backend-beat"
  container_definitions = templatefile(
    "templates/backend_container.json.tpl",
    merge(
      local.container_vars,
      {
        name       = "prod-backend-beat"
        command    = ["celery", "-A", "django_aws", "beat", "--loglevel", "info"]
        log_stream = aws_cloudwatch_log_stream.prod_backend_beat.name
      },
    )
  )
  depends_on = [aws_sqs_queue.prod, aws_db_instance.prod]
  execution_role_arn = aws_iam_role.ecs_task_execution.arn
  task_role_arn      = aws_iam_role.prod_backend_task.arn
}

resource "aws_ecs_service" "prod_backend_beat" {
  name                               = "prod-backend-beat"
  cluster                            = aws_ecs_cluster.prod.id
  task_definition                    = aws_ecs_task_definition.prod_backend_beat.arn
  desired_count                      = 1
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
  launch_type                        = "FARGATE"
  scheduling_strategy                = "REPLICA"
  enable_execute_command             = true

  network_configuration {
    security_groups  = [aws_security_group.prod_ecs_backend.id]
    subnets          = [aws_subnet.prod_private_1.id, aws_subnet.prod_private_2.id]
    assign_public_ip = false
  }
}