resource "aws_s3_bucket" "prod_media" {
  bucket = var.prod_media_bucket
}


resource "aws_s3_bucket_ownership_controls" "prod_s3_ownership" {
  bucket = var.prod_media_bucket
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "prod_s3_public_access_block" {
  bucket = var.prod_media_bucket

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}
resource "aws_s3_bucket_acl" "prod_acl" {
  depends_on = [
    aws_s3_bucket_ownership_controls.prod_s3_ownership,
    aws_s3_bucket_public_access_block.prod_s3_public_access_block,
  ]
  
  bucket = var.prod_media_bucket
  acl = "public-read"
}
resource "aws_s3_bucket_cors_configuration" "prod_media" {
  bucket = var.prod_media_bucket

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }  
}

resource "aws_iam_policy" "prod_media_iam_s3" {
  name        = "prod_iam_policy"
  path        = "/"
  description = "My s3 policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "PublicReadGetObject"
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.prod_media_bucket}/*",
          "arn:aws:s3:::${var.prod_media_bucket}"
        ]
      }
    ]
  })
}


resource "aws_iam_user" "prod_media_bucket" {
  name = "prod-media-bucket"
}

resource "aws_iam_user_policy" "prod_media_bucket" {
  user = aws_iam_user.prod_media_bucket.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:*",
        ]
        Effect = "Allow"
        Resource = [
          "arn:aws:s3:::${var.prod_media_bucket}",
          "arn:aws:s3:::${var.prod_media_bucket}/*"
        ]
      },
    ]
  })
}

resource "aws_iam_access_key" "prod_media_bucket" {
  user = aws_iam_user.prod_media_bucket.name
}