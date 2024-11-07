data "archive_file" "rekognition_lambda_zip" {
  type        = "zip"
  source_file = "../src/lambda/rekognition-lambda.py"
  output_path = "zipped/rekognition-lambda.zip"
}

resource "aws_lambda_function" "rekognition_lambda" {
  function_name = "rekognition_lambda"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "rekognition-lambda.lambda_handler" 
  runtime       = "python3.11" 
  depends_on = [data.archive_file.rekognition_lambda_zip]

  filename = data.archive_file.rekognition_lambda_zip.output_path
}