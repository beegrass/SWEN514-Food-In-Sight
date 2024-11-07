locals {
  indentify_food_step_function_definition = <<JSON
  {
    "Comment": "Step function declaration to identify food",
    "StartAt": "RekognitionLambda",
    "States": {
      "RekognitionLambda": {
        "Type": "Task",
        "Resource": "${aws_lambda_function.rekognition_lambda.arn}",
        "Next": "FoodAPILambda"
      },
      "FoodAPILambda": {
        "Type": "Task",
        "Resource": "${aws_lambda_function.food_api_lambda.arn}",
        "Next": "DynamoLambda"
      },
      "DynamoLambda": {
        "Type": "Task",
        "Resource": "${aws_lambda_function.dynamo_lambda.arn}",
        "End": true
      }
    }
  }
  JSON
}

resource "aws_iam_role" "step_function_exec" {
  name = "StepFunctionExecutionRole"
  assume_role_policy = <<EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "states.us-east-1.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  }
  EOF
}

resource "aws_iam_role_policy" "step_function_policy" {
  name = "StepFunctionPolicy"
  role = aws_iam_role.step_function_exec.id
  policy = <<EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": "lambda:InvokeFunction",
        "Resource": [
          "${aws_lambda_function.rekognition_lambda.arn}",
          "${aws_lambda_function.food_api_lambda.arn}",
          "${aws_lambda_function.dynamo_lambda.arn}"
        ]
      }
    ]
  }
  EOF
}

resource "aws_sfn_state_machine" "identify_food_step_function" {
  name     = "IdentifyFoodStepFunction"
  role_arn = aws_iam_role.step_function_exec.arn
  definition = local.indentify_food_step_function_definition
}
