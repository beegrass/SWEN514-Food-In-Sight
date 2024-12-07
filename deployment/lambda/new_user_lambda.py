import boto3
import os
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# DynamoDB client
dynamodb = boto3.resource('dynamodb')
user_table_name = os.environ['DYNAMODB_TABLE']
user_table = dynamodb.Table(user_table_name)

def lambda_handler(event, context):
    """
    Post Confirmation Lambda Trigger.
    Adds a new user's UserName to the DynamoDB table upon confirmation.
    """
    try:
        logger.info(f"Post Confirmation Event: {event}")

        # Extract UserName from the event
        user_name = event['userName']

        # Add the user to DynamoDB
        user_table.put_item(
            Item={
                'UserName': user_name
            }
        )

        logger.info(f"Successfully added user {user_name} to table {user_table_name}")
        return event  # Must return the event for Cognito to continue processing

    except Exception as e:
        logger.error(f"Error adding user to DynamoDB: {e}")
        raise
