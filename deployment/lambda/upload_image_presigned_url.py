#maxs code
import json
import os
import boto3
from botocore.exceptions import ClientError

def handler(event, context):
    body = json.loads(event['body'])
#     bucket_name = body['bucketName']
    bucket_name = os.getenv('BUCKET_NAME') # This is passed in from the environment defined during the creation of the lambda

    file_name = body['fileName']
    contentType = body['contentType']
    expiration = body.get('expiration', 60)  # Default expiration is 60 seconds

    image_url = "s3://"+str(bucket_name) + '/'+ str(file_name)

    s3_client = boto3.client('s3')

    # Generate the pre-signed URL
    try:
        url = s3_client.generate_presigned_url('put_object',
                                               Params={'Bucket': bucket_name,
                                                       'Key': file_name,
                                                       'ContentType': contentType},
                                               ExpiresIn=expiration,
                                               HttpMethod='PUT')
        return {
            'statusCode': 200,
             'headers': {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "POST, PUT",
            },
            'body': json.dumps({'url': url, 'image_url': image_url})
        }
    except ClientError as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
