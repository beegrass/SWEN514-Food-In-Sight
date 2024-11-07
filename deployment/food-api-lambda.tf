# Create Dependencies File
resource "null_resource" "install_layer_dependencies" {
  provisioner "local-exec" {
    command = "pip install -r ../src/lambda/requirements.txt -t layer/python/lib/python3.11/site-packages"
  }
  triggers = {
    trigger = timestamp()
  }
}

# Zip Dependencies
data "archive_file" "layer_zip" {
  type        = "zip"
  source_dir  = "layer"
  output_path = "zipped/layer.zip"
  depends_on = [
    null_resource.install_layer_dependencies
  ]
}

# Create lambda layer with dependencies
resource "aws_lambda_layer_version" "lambda_layer" {
  filename = "zipped/layer.zip"
  source_code_hash = data.archive_file.layer_zip.output_base64sha256
  layer_name = "food_api_layer_dependencies"

  compatible_runtimes = ["python3.11"]
  depends_on = [
    data.archive_file.layer_zip
  ]
}

# Archive Lambda code if not already zipped
data "archive_file" "food_lambda_zip" {
  type        = "zip"
  source_file = "../src/lambda/food-api-lambda.py"
  output_path = "zipped/food-api-lambda.zip"
}

# Create Lambda function
resource "aws_lambda_function" "food_api_lambda" {
  function_name = "food_api_lambda"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "food-api-lambda.lambda_handler" 
  runtime       = "python3.11" 
    layers = [
    aws_lambda_layer_version.lambda_layer.arn
  ]
  depends_on = [
    data.archive_file.food_lambda_zip,
    aws_lambda_layer_version.lambda_layer
  ]

  filename = data.archive_file.food_lambda_zip.output_path

  environment {
    variables = {
      FOOD_DATA_API_KEY = "1IBBdfpfJvI77K7gPalVETD69qtXOVRt0JHTg8Wa"
    }
  }
}