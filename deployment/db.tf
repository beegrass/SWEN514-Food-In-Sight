locals {
    # Users table data
    users_json = jsondecode(file("${path.module}/db/users_db.json"))
    users_transformed = {
        for idx, user in local.users_json.users : idx => {
            UserName = { S = user.UserName }
            Password = { S = user.Password }
            Diets    = { L = [for diet in user.Diets : { S = diet }] }
        }
    }

    # Diets table data
    diets_json = jsondecode(file("${path.module}/db/diets_db.json"))
    diets_transformed = {
        for idx, diet in local.diets_json.diets : idx => {
            Restriction = { S = diet.Restriction }
            Ingredients = { L = [for ingredient in diet.Ingredients : { S = ingredient }] }
        }
    }
}

# ---------- DYNAMODB DEV ----------
resource "aws_dynamodb_table" "user_table" {
    name            = "Users"
    billing_mode    = "PROVISIONED"
    read_capacity   = "1"
    write_capacity  = "1"
    hash_key        = "UserName"

    attribute {
        name = "UserName"
        type = "S"
    }
}

resource "aws_dynamodb_table" "diet_table" {
    name            = "Diets"
    billing_mode    = "PROVISIONED"
    read_capacity   = "1"
    write_capacity  = "1"
    hash_key        = "Restriction"

    attribute {
        name = "Restriction"
        type = "S"
    }
}

# DynamoDB items for Users table
resource "aws_dynamodb_table_item" "user_items" {
    for_each = local.users_transformed
    
    table_name = aws_dynamodb_table.user_table.name
    hash_key   = "UserName"
    
    item = jsonencode(each.value)
}

# DynamoDB items for Diets table
resource "aws_dynamodb_table_item" "diet_items" {
    for_each = local.diets_transformed
    
    table_name = aws_dynamodb_table.diet_table.name
    hash_key   = "Restriction"
    
    item = jsonencode(each.value)
}

# ---------- LAMBDA DEV ----------
resource "aws_lambda_function" "user_lambda" {
    function_name = "UserProcessingFunction"
    runtime       = "python3.11"
    handler       = "users_lambda.lambda_handler"
    role          = aws_iam_role.lambda_exec.arn
    filename      = data.archive_file.user_zip_python.output_path

    environment {
        variables = {
            DYNAMODB_TABLE = aws_dynamodb_table.user_table.name
        }
    }
}

resource "aws_lambda_function" "diet_lambda" {
    function_name = "DietProcessingFunction"
    runtime       = "python3.11"
    handler       = "diets_lambda.lambda_handler"
    role          = aws_iam_role.lambda_exec.arn
    filename      = data.archive_file.diet_zip_python.output_path

    environment {
        variables = {
            DYNAMODB_TABLE = aws_dynamodb_table.diet_table.name
        }
    }
}

# Lambda Functions
resource "aws_lambda_function" "post_user_creation" {
    function_name = "PostUserCreation"
    runtime       = "python3.11"
    handler       = "new_user_lambda.lambda_handler"
    role          = aws_iam_role.lambda_exec.arn
    filename      = data.archive_file.post_user_creation_zip_python.output_path

    environment {
        variables = {
        DYNAMODB_TABLE = aws_dynamodb_table.user_table.name
        }
    }
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_exec" {
    name = "user_lambda_exec_role"

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

# Attach policies to the Lambda execution role
resource "aws_iam_role_policy_attachment" "lambda_policy" {
    role       = aws_iam_role.lambda_exec.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb_policy" {
    role       = aws_iam_role.lambda_exec.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

# ---------- API GATEWAY DEV ----------
# API Gateway REST API using Swagger
resource "aws_api_gateway_rest_api" "food_api" {
    name        = "UserAPI"
    description = "API Gateway for User Processing"

    body = data.template_file.swagger_with_lambda_arn.rendered
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "api_deployment" {
    depends_on  = [aws_api_gateway_rest_api.food_api]
    rest_api_id = aws_api_gateway_rest_api.food_api.id
    stage_name  = "prod"
}

# Lambda Permission for API Gateway to invoke User Lambda function
resource "aws_lambda_permission" "api_gateway_user_invoke" {
    statement_id  = "AllowAPIGatewayInvokeUser"
    action        = "lambda:InvokeFunction"
    function_name = aws_lambda_function.user_lambda.arn
    principal     = "apigateway.amazonaws.com"
    source_arn    = "${aws_api_gateway_rest_api.food_api.execution_arn}/*/*"
}

# Lambda Permission for API Gateway to invoke Diet Lambda function
resource "aws_lambda_permission" "api_gateway_diet_invoke" {
    statement_id  = "AllowAPIGatewayInvokeDiet"
    action        = "lambda:InvokeFunction"
    function_name = aws_lambda_function.diet_lambda.arn
    principal     = "apigateway.amazonaws.com"
    source_arn    = "${aws_api_gateway_rest_api.food_api.execution_arn}/*/*"
}

# ---------- FILES ----------
data "local_file" "api_swagger_spec" {
    filename = "${path.module}/db/usersApiDoc.yaml"  # Ensure this matches your actual Swagger file path
}

# Update the template file data source to include both Lambda ARNs
data "template_file" "swagger_with_lambda_arn" {
    template = data.local_file.api_swagger_spec.content
    vars = {
        user_lambda_arn = aws_lambda_function.user_lambda.arn
        diet_lambda_arn = aws_lambda_function.diet_lambda.arn
    }
}

data "archive_file" "user_zip_python" {
    type        = "zip"
    source_file = "${path.module}/lambda/users_lambda.py"  # Ensure this matches the path to your Python file
    output_path = "${path.module}/zipped/users_lambda.zip"
}

data "archive_file" "diet_zip_python" {
    type        = "zip"
    source_file = "${path.module}/lambda/diets_lambda.py"
    output_path = "${path.module}/zipped/diets_lambda.zip"
}

data "archive_file" "post_user_creation_zip_python" {
    type        = "zip"
    source_file = "${path.module}/lambda/new_user_lambda.py"
    output_path = "${path.module}/zipped/new_user_lambda.zip"
}