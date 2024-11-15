import json
import boto3

def lambda_handler(event, context):
    rekognition = boto3.client('rekognition')
        
    # Get the image URL and username from the Step Function Payload
    step_function_payload = event.get('Payload', {})
    image_url = step_function_payload.get('image_url', "")
    username = step_function_payload.get('username', "")
    
    # Check if URL has enough segments
    url_segments = image_url.split("/")
    if len(url_segments) < 4:
        return {
            'statusCode': 400,
            'body': json.dumps({
                'message': 'Invalid S3 URL format.',
                'provided_url': image_url
            })
        }
    
    # Parse bucket name and key based on URL format
    if image_url.startswith("s3://"):
        # Handle s3://bucket-name/path/to/image.jpg
        bucket_name = url_segments[2]
        key = "/".join(url_segments[3:])
    elif "s3.amazonaws.com" in image_url:
        # Handle https://bucket-name.s3.amazonaws.com/path/to/image.jpg
        bucket_name = url_segments[2].split(".")[0]
        key = "/".join(url_segments[3:])
    else:
        return {
            'statusCode': 400,
            'body': json.dumps({
                'message': 'Unsupported S3 URL format.',
                'provided_url': image_url
            })
        }
    
    # Call Rekognition to detect labels
    try:
        response = rekognition.detect_labels(
            Image={
                'S3Object': {
                    'Bucket': bucket_name,
                    'Name': key
                }
            },
            MaxLabels=10,
            MinConfidence=70
        )
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': 'Error calling Rekognition API',
                'error': str(e)
            })
        }
    
    # Return response
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Image processed successfully and Step Function triggered.',
            'rekognition_labels': response['Labels'],
            'step_function_payload': step_function_payload
        })
    }
