import json
import boto3
from botocore.exceptions import ClientError

def handler(event, context):
    body = json.loads(event['body'])
#     bucket_name = body['bucketName']
    bucket_name = os.getenv('BUCKET_NAME') # This is passed in from the environment defined during the creation of the lambda

    file_name = body['fileName']
    expiration = body.get('expiration', 60)  # Default expiration is 60 seconds

    s3_client = boto3.client('s3')

    # Generate the pre-signed URL
    try:
        url = s3_client.generate_presigned_url('put_object',
                                               Params={'Bucket': bucket_name,
                                                       'Key': file_name},
                                               ExpiresIn=expiration,
                                               HttpMethod='PUT')
        return {
            'statusCode': 200,
            'body': json.dumps({'url': url})
        }
    except ClientError as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
