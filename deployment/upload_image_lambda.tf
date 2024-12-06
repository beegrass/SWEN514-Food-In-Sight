# Lambda Function to handle image upload to S3
resource "aws_lambda_function" "upload_image_lambda" {
  function_name = "UploadImageLambdaFunction"
  handler       = "upload_image_function.lambda_handler"
  runtime       = "python3.12"
  filename      = data.archive_file.upload_image_lambda_zip.output_path
  role          = aws_iam_role.upload_image_lambda_exec_role.arn
  timeout       = 30
  layers = [aws_lambda_layer_version.upload_image_function_lambda_layer.arn]

  depends_on = [ data.archive_file.upload_image_lambda_zip,  aws_lambda_layer_version.upload_image_function_lambda_layer]

  environment {
    variables = {
      STEP_FUNCTION_ARN = aws_sfn_state_machine.identify_food_lambda_state_machine.arn,
      IMAGE_BUCKET_NAME = aws_s3_bucket.image_bucket.bucket
    }
  }
}



#Zipped Python Lambda / Dependencies

# Archive Lambda code if not already zipped
data "archive_file" "upload_image_lambda_zip" {
  type        = "zip"
  source_file = "lambda/upload_image_function.py"
  output_path = "zipped/upload_image_function.zip"
}

# Create Dependencies File
resource "null_resource" "install_upload_image_function_layer_dependencies" {
  provisioner "local-exec" {
    command = "pip install -r lambda/upload_image_function_requirements.txt -t layers/upload_image_function_layer/python/lib/python3.11/site-packages"
  }
  triggers = {
    trigger = timestamp()
  }
}

# Zip Dependencies
data "archive_file" "upload_image_function_layer_zip" {
  type        = "zip"
  source_dir  = "layers/upload_image_function_layer"
  output_path = "zipped/upload_image_function_layer.zip"
  depends_on = [
    null_resource.install_upload_image_function_layer_dependencies
  ]
}

# Create lambda layer with dependencies
resource "aws_lambda_layer_version" "upload_image_function_lambda_layer" {
  filename = data.archive_file.upload_image_function_layer_zip.output_path
  source_code_hash = data.archive_file.upload_image_function_layer_zip.output_base64sha256
  layer_name = "upload_image_function_layer_dependencies"

  compatible_runtimes = ["python3.12"]
  depends_on = [
    data.archive_file.upload_image_function_layer_zip
  ]
}




# Permissions

# IAM Role for Image Upload Lambda
resource "aws_iam_role" "upload_image_lambda_exec_role" {
  name = "upload_image_lambda_exec_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

# IAM Policy for Image Upload Lambda
resource "aws_iam_role_policy" "upload_image_lambda_policy" {
  name   = "upload_image_lambda_policy"
  role   = aws_iam_role.upload_image_lambda_exec_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = [
          "s3:PutObject",
          "s3:GetObject"
        ]
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.image_bucket.arn}/*"
      },
       {
        Action   = "states:StartSyncExecution"
        Effect   = "Allow"
        Resource = aws_sfn_state_machine.identify_food_lambda_state_machine.arn
      },
      {
        Action   = "logs:*"
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}



#presigned URL -------------------------------------------
data "archive_file" "upload_image_lambda_presign_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/upload_image_presigned_url.py"
  output_path = "${path.module}/lambda/upload_image_presigned_url.zip"
}

resource "aws_lambda_function" "get_image_upload_presigned_url" {
  function_name = "PresignedURLUploadImageLambdaFunction" #Using pre-existing role
  role          = aws_iam_role.upload_image_lambda_exec_role.arn
  handler       = "upload_image_presigned_url.handler"
  runtime       = "python3.11"
  filename      = "lambda/upload_image_presigned_url.zip"

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.image_bucket.bucket
    }
  }

  source_code_hash = data.archive_file.upload_image_lambda_presign_zip.output_base64sha256
}
#END presigned URL -------------------------------------------