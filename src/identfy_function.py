import boto3
from decimal import Decimal
import json
import urllib.parse
import io

rekognition = boto3.client('rekognition')
s3_client = boto3.client('s3')

def detect_food(bucket, photo):
    try:
        response = rekognition.detect_labels(
            Image={'S3Object': {'Bucket': bucket, 'Name': photo}},
            MaxLabels=5,
            MinConfidence=90
        )
        return response
    except Exception as e:
        print(f"Error in detect_food: {str(e)}")
        return None

def upload_results_to_s3(bucket, key, labels):
    try:
        # Create a text file with the labels
        labels_content = "\n".join(labels)
        labels_buffer = io.BytesIO(labels_content.encode('utf-8'))

        # Upload the labels text file to S3
        labels_key = f'labeled/labels_{key.split("/")[-1].replace(".jpg", ".txt")}'  # Create a .txt file with the same base name
        s3_client.put_object(
            Bucket=bucket,
            Key=labels_key,
            Body=labels_buffer,
            ContentType='text/plain'
        )

        return labels_key
    except Exception as e:
        print(f"Error uploading results to S3: {str(e)}")
        return None

def lambda_handler(event, context):
    try:
        # Get bucket and image key from the S3 event
        bucket = event['Records'][0]['s3']['bucket']['name']
        key = urllib.parse.unquote_plus(event['Records'][0]['s3']['object']['key'], encoding='utf-8')
        
        # Detect food in the image
        response = detect_food(bucket, key)
        
        if response:
            # Upload labels to S3
            results_bucket = "new-foods-tub-results"
            labels_key = upload_results_to_s3(results_bucket, key, 
                                                [label['Name'] for label in response.get('Labels', [])])
                
            print(f"Labels uploaded to: {labels_key}")
        else:
            print("No response received from detect_food.")
        
        return {
            'statusCode': 200,
            'body': json.dumps('Success')
        }
    except Exception as e:
        print(f"Error in lambda_handler: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps('Error processing request')
        }
