provider "aws" {
  region = "us-east-1"
}

locals {
  aws_key = "AWS_KEY"
}

# S3 Bucket for Images
resource "aws_s3_bucket" "image_bucket" {
  bucket = "new-foods-tub"
}

# S3 Bucket for Results
resource "aws_s3_bucket" "results_bucket" {
  bucket = "new-foods-tub-results"
}

# IAM Role for Lambda Function
resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for Lambda
resource "aws_iam_policy" "lambda_exec_policy" {
  name        = "lambda_exec_policy"
  description = "Policy for Lambda execution with S3 and Rekognition access"
  policy      = jsonencode({
    Statement = [
      {

        Version = "2012-10-17",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect   = "Allow",
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ],
        Effect   = "Allow",
        Resource = "arn:aws:s3:::${aws_s3_bucket.image_bucket.bucket}/*"
      },
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ],
        Effect   = "Allow",
        Resource = "arn:aws:s3:::${aws_s3_bucket.results_bucket.bucket}/*"
      },
      {
        Action = [
          "rekognition:DetectLabels"
        ],
        Effect   = "Allow",
        Resource = "*"
      },
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ],
        Effect   = "Allow",
        Resource = "arn:aws:s3:::my-lambda-code6/*"
      }
    ]
  })
}

# Attach IAM Policy to Role
resource "aws_iam_role_policy_attachment" "lambda_exec_role_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_exec_policy.arn
}

# Lambda Function Resource with S3 Code Reference
resource "aws_lambda_function" "detect_food_lambda" {
  function_name    = "detect_food_lambda"
  s3_bucket        = "my-lambda-code6"
  s3_key           = "identfy_function.zip"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "identfy_function.lambda_handler"
  runtime          = "python3.9"

  memory_size = 128
  timeout     = 30
}

# S3 Trigger for Lambda
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.image_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.detect_food_lambda.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_function.detect_food_lambda]  # Ensures the Lambda function is created before setting notification
}

# Lambda Permission for S3 Invocation
resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.detect_food_lambda.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.image_bucket.arn
}
