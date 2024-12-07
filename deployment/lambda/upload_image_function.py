import json
import boto3
from base64 import b64decode
import os
import uuid



def lambda_handler(event, context):
    if 'body' not in event:
        return {
            "statusCode": 400,
            "body": json.dumps("Request is missing 'body'")
        }

    try:
        body = json.loads(event['body'])
    except json.JSONDecodeError:
        return {
            "statusCode": 400,
            "body": json.dumps("Invalid JSON format in 'body'")
        }

    image_url = body.get("image_url")
    username = body.get("username")

    # Upload the image to S3
    s3 = boto3.client('s3')
    bucket_name = os.environ.get("IMAGE_BUCKET_NAME")
    if not bucket_name:
        return {
            "statusCode": 500,
            "body": json.dumps("S3 bucket name is not configured in environment variables")
        }


    # Trigger Step Function
    step_functions_client = boto3.client('stepfunctions')
    
    # Get Step Function ARN from environment variable
    step_function_arn = os.environ.get("STEP_FUNCTION_ARN")
    if not step_function_arn:
        return {
            "statusCode": 500,
            "body": json.dumps("Step Function ARN is not configured in environment variables")
        }

    # Prepare the input for the Step Function, including username if present
    step_function_payload = {
        "image_url": image_url,
        "username": username if username else "",  # Add username even if empty
    }
        

    # Trigger Step Function execution
    try:
        step_response = step_functions_client.start_sync_execution(
            stateMachineArn=step_function_arn,
            input=json.dumps(step_function_payload)
        )
        return {
            "statusCode": 200,
            "headers": {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "POST, OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type, X-Amz-Date, Authorization, X-Api-Key, X-Amz-Security-Token",
            },
            "body": json.dumps({
                "message": "Step Function triggered.",
                "image_url": image_url,
                "result":step_response['output'],
                "step_function_execution_arn": step_response['executionArn']
            })
        }
    except Exception as e:
        return {
            "statusCode": 500,
            "headers": {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "POST, OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type, X-Amz-Date, Authorization, X-Api-Key, X-Amz-Security-Token",
            },
            "body": json.dumps(f"Error triggering Step Function: {str(e)}")
        }
