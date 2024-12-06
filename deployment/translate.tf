# Define the S3 Bucket to store uploaded files
resource "aws_s3_bucket" "file_upload_bucket" {
  bucket = "translation-files-${uuid()}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "unblock_file_upload_bucket" {
  bucket = aws_s3_bucket.file_upload_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_cors_configuration" "file_upload_bucket_cors_policy" {
  bucket = aws_s3_bucket.file_upload_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST"]
    allowed_origins = ["*"]
    expose_headers  = ["Content-Type"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_policy" "file_upload_bucket_policy" {
  bucket = aws_s3_bucket.file_upload_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.file_upload_bucket.arn}/*"
        Principal = "*"
      }
    ]
  })
}

data "archive_file" "translate_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/translate_lambda.py"
  output_path = "${path.module}/lambda/translate_lambda.zip"
}

# IAM role for Lambda for S3, Textract, and Translate
resource "aws_iam_role" "translate_lambda_execution_role" {
  name = "LambdaExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Policy for lambda to access everything needed
resource "aws_iam_role_policy" "lambda_policy" {
  name = "LambdaS3TextractTranslatePolicy"
  role = aws_iam_role.translate_lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.file_upload_bucket.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = [
          "textract:StartDocumentTextDetection",
          "textract:GetDocumentTextDetection",
          "textract:DetectDocumentText", #For synchronous
          "textract:StartDocumentTextDetection" #For asynchronous
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = [
          "translate:TranslateText",
          "translate:TranslateDocument"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = [
          "comprehend:DetectDominantLanguage"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_function" "process_file_function" {
  function_name    = "process_file_function"
  role             = aws_iam_role.translate_lambda_execution_role.arn
  runtime          = "python3.11"

  handler          = "translate_lambda.handler"
  filename         = "lambda/translate_lambda.zip"
  source_code_hash = data.archive_file.translate_lambda_zip.output_base64sha256

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.file_upload_bucket.bucket
    }
  }
}

#Pre signed URLS -------------------------------------------------------------------------------------------------------

data "archive_file" "translate_lambda_presign_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/translate_presigned_url.py"
  output_path = "${path.module}/lambda/translate_presigned_url.zip"
}

resource "aws_lambda_function" "generate_translate_presigned_url" {
  function_name = "generateTranslatePresignedUrl" #Using pre-existing role
  role          = aws_iam_role.translate_lambda_execution_role.arn
  handler       = "translate_presigned_url.handler"
  runtime       = "python3.11"
  filename      = "lambda/translate_presigned_url.zip"

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.file_upload_bucket.bucket
    }
  }

  source_code_hash = data.archive_file.translate_lambda_presign_zip.output_base64sha256
}


output "translate_s3_bucket_name" {
  value = aws_s3_bucket.file_upload_bucket.bucket
}

