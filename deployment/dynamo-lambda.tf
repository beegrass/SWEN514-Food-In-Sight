data "archive_file" "dynamo_lambda_zip" {
  type        = "zip"
  source_file = "../src/lambda/dynamo-lambda.py"  
  output_path = "zipped/dynamo-lambda.zip"        
}

resource "aws_lambda_function" "dynamo_lambda" {  
  function_name = "dynamo_lambda"                 
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "dynamo-lambda.lambda_handler"  
  runtime       = "python3.11"
  depends_on    = [data.archive_file.dynamo_lambda_zip]

  filename = data.archive_file.dynamo_lambda_zip.output_path  
}
