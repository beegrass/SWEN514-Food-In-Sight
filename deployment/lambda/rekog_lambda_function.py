import json
import boto3

# Initialize Rekognition client
rekognition = boto3.client('rekognition')

def lambda_handler(event, context):
    # Get the image URL and username from the Step Function Payload
    step_function_payload = event.get('Payload', {})
    image_url = step_function_payload.get('image_url', "")
    username = step_function_payload.get('username', "")
    
    print(f"Processing image for user: {username}")
    
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

    # Try to detect custom labels
    try:
        response = rekognition.detect_custom_labels(
            Image={
                'S3Object': {
                    'Bucket': bucket_name,
                    'Name': key
                }
            },
            MaxResults=10,
            MinConfidence=70,
            ProjectVersionArn="arn:aws:rekognition:us-east-1:559050203586:project/FoodInSight/version/FoodInSight.2024-11-11T12.31.51/1731346311117"
        )
        
        print(f"Custom labels response: {response}")
        
        # If no custom labels are found, fall back to regular Rekognition labels
        if not response.get('CustomLabels', []):
            print("No custom labels found, using regular Rekognition labels")
            raise ValueError("No custom labels found.")  # Force fallback to regular labels
        
        custom_labels = response['CustomLabels']

    except (ValueError, rekognition.exceptions.ClientError) as e:
        print(f"Error with custom labels or fallback triggered: {e}")
        
        # If there's an error with custom labels or no labels found, fall back to regular Rekognition labels
        try:
            response = rekognition.detect_labels(
                Image={
                    'S3Object': {
                        'Bucket': bucket_name,
                        'Name': key
                    }
                },
                MaxLabels=10,
                MinConfidence=70,
            )
            custom_labels = response['Labels']
            print(f"Regular labels: {custom_labels}")
        except rekognition.exceptions.ClientError as e:
            print(f"Error calling Rekognition API for regular labels: {e}")
            return {
                'statusCode': 500,
                'body': json.dumps({
                    'message': 'Error calling Rekognition API for regular labels.',
                    'error': str(e)
                })
            }
    
    except Exception as e:
        print(f"Unexpected error: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': 'Unexpected error occurred during processing.',
                'error': str(e)
            })
        }

    # Return response
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Image processed successfully and Step Function triggered.',
            'rekognition_labels': custom_labels,
            'step_function_payload': step_function_payload
        })
    }
