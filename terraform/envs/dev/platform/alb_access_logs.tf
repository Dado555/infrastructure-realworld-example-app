# resolves the region's elb log-delivery account id - avoids hardcoding a magic number per region
data "aws_elb_service_account" "main" {}

# s3 bucket for alb access logs (step 7.5) - alb log delivery requires sse-s3, kms is not supported
resource "aws_s3_bucket" "alb_access_logs" {
  bucket = "realworld-aws-${var.environment}-alb-logs-262786914511"
}

resource "aws_s3_bucket_public_access_block" "alb_access_logs" {
  bucket = aws_s3_bucket.alb_access_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "alb_access_logs" {
  bucket = aws_s3_bucket.alb_access_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# expires logs after 30 days - dev environment, not worth longer retention
resource "aws_s3_bucket_lifecycle_configuration" "alb_access_logs" {
  bucket = aws_s3_bucket.alb_access_logs.id

  rule {
    id     = "expire-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = 30
    }
  }
}

# grants the elb log-delivery account write access, per aws's documented alb access-logging requirement
resource "aws_s3_bucket_policy" "alb_access_logs" {
  bucket = aws_s3_bucket.alb_access_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSLogDeliveryWrite"
        Effect = "Allow"
        Principal = {
          AWS = data.aws_elb_service_account.main.arn
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_access_logs.arn}/alb/AWSLogs/262786914511/*"
      }
    ]
  })
}

output "alb_access_logs_bucket" {
  description = "S3 bucket name for ALB access logs, referenced by the Ingress annotation."
  value       = aws_s3_bucket.alb_access_logs.bucket
}
