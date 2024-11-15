# Define the S3 Bucket to store uploaded files
resource "aws_s3_bucket" "file_upload_bucket" {
  bucket = "translation-files-${uuid()}"
  force_destroy = true
}

data "archive_file" "translate_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/translate_lambda.py"
  output_path = "${path.module}/lambda/translate_lambda.zip"
}

# IAM role for Lambda for S3, Textract, and Translate
resource "aws_iam_role" "lambda_execution_role" {
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

# Attach policy to Lambda
resource "aws_iam_role_policy" "lambda_policy" {
  name = "LambdaS3TextractTranslatePolicy"
  role = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "s3:GetObject",
          "s3:PutObject"
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
  function_name = "process_file_function"
  role          = aws_iam_role.lambda_execution_role.arn
  runtime       = "python3.11"

  # These are required for referencing a lambda which is stored locally
  handler         = "translate_lambda.handler"
  filename        = "lambda/translate_lambda.zip" # Must be a zip file
  source_code_hash = data.archive_file.translate_lambda_zip.output_base64sha256 # grab the hash from the zipped file

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.file_upload_bucket.bucket
    }
  }
}

# Add the necessary IAM permissions for API Gateway to invoke the Lambda function
resource "aws_lambda_permission" "allow_api_gateway" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.process_file_function.function_name
  principal     = "apigateway.amazonaws.com"
}

output "s3_bucket_name" {
  value = aws_s3_bucket.file_upload_bucket.bucket
}

output "lambda_function_name" {
  value = aws_lambda_function.process_file_function.function_name
}
