# Install dependencies for the Lambda layer
resource "null_resource" "install_layer_dependencies" {
  provisioner "local-exec" {
    command = "pip install -r ../src/requirements.txt -t layer/python/lib/python3.11/site-packages"
  }
  triggers = {
    trigger = timestamp()
  }
}

# Package the Lambda layer dependencies into a zip file
data "archive_file" "layer_zip" {
  type        = "zip"
  source_dir  = "layer"
  output_path = "zipped/layer.zip"
  depends_on = [null_resource.install_layer_dependencies]
}

# Create Lambda layer with dependencies
resource "aws_lambda_layer_version" "rek_layer" {
  filename           = "zipped/layer.zip"
  source_code_hash   = data.archive_file.layer_zip.output_base64sha256
  layer_name         = "reckon_layer_dependencies"
  compatible_runtimes = ["python3.11"]
}

# Package the Lambda function code
data "archive_file" "identfy_function_zip" {
  type        = "zip"
  source_file = "../src/lambda/identfy_function.py"
  output_path = "zipped/identfy_function.zip"
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
    Version = "2012-10-17",
    Statement = [
      {
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
          "s3:PutObject",
          "s3:ListBucket"  # Added ListBucket permission for both buckets
        ],
        Effect   = "Allow",
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.image_bucket.bucket}",
          "arn:aws:s3:::${aws_s3_bucket.image_bucket.bucket}/*",
          "arn:aws:s3:::${aws_s3_bucket.results_bucket.bucket}",
          "arn:aws:s3:::${aws_s3_bucket.results_bucket.bucket}/*"
        ]
      },
      {
        Action = [
          "rekognition:DetectLabels"
        ],
        Effect   = "Allow",
        Resource = "*"
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
  function_name = "detect_food_lambda"
  filename      = data.archive_file.identfy_function_zip.output_path  # Specify the zipped function code
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "identfy_function.lambda_handler"
  runtime       = "python3.11"  # Ensure runtime matches the layer
  memory_size   = 128
  timeout       = 60
  layers        = [aws_lambda_layer_version.rek_layer.arn]
  depends_on    = [aws_lambda_layer_version.rek_layer]
}

# S3 Trigger for Lambda
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.image_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.detect_food_lambda.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_function.detect_food_lambda, aws_lambda_permission.allow_s3_invoke]
}

# Lambda Permission for S3 Invocation
resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.detect_food_lambda.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.image_bucket.arn
}
