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
  source_dir  = "../src/lambda"  # Assuming you want to zip the entire directory
  output_path = "zipped/identfy_function.zip"
}

# Lambda function to start the model
data "archive_file" "start_model_zip" {
  type        = "zip"
  source_file = "../src/lambda/start_model.py"  # Path to the start model script
  output_path = "zipped/start_model.zip"
}

# Lambda function to stop the model
data "archive_file" "stop_model_zip" {
  type        = "zip"
  source_file = "../src/lambda/stop_model.py"  # Path to the stop model script
  output_path = "zipped/stop_model.zip"
}

# S3 Bucket for Images
resource "aws_s3_bucket" "image_bucket" {
  bucket        = "new-foods-tub"
  force_destroy = true
}

# S3 Bucket for Results
resource "aws_s3_bucket" "results_bucket" {
  bucket        = "new-foods-tub-results"
  force_destroy = true
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

# IAM Policy for Lambda with access to Rekognition and S3
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
          "s3:ListBucket"
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
          "rekognition:DetectCustomLabels",
          "rekognition:CreateProjectVersion",
          "rekognition:StartProjectVersion",
          "rekognition:StopProjectVersion"
        ],
        Effect   = "Allow",
        Resource = "arn:aws:rekognition:us-east-1:559050203586:project/FoodInSight/version/FoodInSight.2024-11-11T12.31.51/1731346311117"
      }
    ]
  })
}

# Attach IAM Policy to Role
resource "aws_iam_role_policy_attachment" "lambda_exec_role_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_exec_policy.arn
}

# Lambda Function Resource to detect food
resource "aws_lambda_function" "detect_food_lambda" {
  function_name = "detect_food_lambda"
  filename      = data.archive_file.identfy_function_zip.output_path
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "identfy_function.lambda_handler"
  runtime       = "python3.11"
  memory_size   = 512
  timeout       = 300
  layers        = [aws_lambda_layer_version.rek_layer.arn]
  depends_on    = [aws_lambda_layer_version.rek_layer]
}

# Lambda Function to start the model
resource "aws_lambda_function" "start_model" {
  function_name = "start_model_function"
  filename      = data.archive_file.start_model_zip.output_path
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "start_model.lambda_handler"
  runtime       = "python3.11"
  memory_size   = 128
  timeout       = 60
}

# Lambda Function to stop the model
resource "aws_lambda_function" "stop_model" {
  function_name = "stop_model_function"
  filename      = data.archive_file.stop_model_zip.output_path
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "stop_model.lambda_handler"
  runtime       = "python3.11"
  memory_size   = 128
  timeout       = 60
}

# Trigger Lambda function to start model after the lambda function is created
resource "null_resource" "start_model_trigger" {
  provisioner "local-exec" {
    command = "aws lambda invoke --function-name ${aws_lambda_function.start_model.function_name} output.txt"
  }

  depends_on = [aws_lambda_function.detect_food_lambda, aws_lambda_function.start_model]
}

# Trigger Lambda function to stop model when resources are destroyed
resource "null_resource" "stop_model_trigger" {
  provisioner "local-exec" {
    command = "aws lambda invoke --function-name ${aws_lambda_function.stop_model.function_name} output.txt"
  }

  lifecycle {
    prevent_destroy = false
  }

  depends_on = [aws_lambda_function.stop_model]
}

# S3 Trigger for Lambda function when new object is created
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
