resource "aws_sqs_queue" "prod" {
  name                      = "prod-queue"
  receive_wait_time_seconds = 10
  tags = {
    Environment = "production"
  }
}

resource "aws_iam_user" "prod_sqs" {
  name = "prod-sqs-user"
}

resource "aws_iam_user_policy" "prod_sqs" {
  user = aws_iam_user.prod_sqs.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sqs:*",
        ]
        Effect   = "Allow"
        Resource = "arn:aws:sqs:*:*:*"
      },
    ]
  })
}

resource "aws_iam_access_key" "prod_sqs" {
  user = aws_iam_user.prod_sqs.name
}