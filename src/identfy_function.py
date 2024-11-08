import boto3
from decimal import Decimal
import json
import urllib.parse
import io
from PIL import Image, ImageDraw, ImageFont

rekognition = boto3.client('rekognition')
s3_client = boto3.client('s3')
#model = "arn:aws:rekognition:us-east-1:559050203586:project/Food-In-sight/version/Food-In-sight.2024-10-26T02.09.05/1729922945143"

def detect_food(bucket, photo):
    try:
        response = rekognition.detect_labels(
            Image={'S3Object': {'Bucket': bucket, 'Name': photo}},
            MaxLabels=5,
            MinConfidence=80
        )
        ''' For custom model
        #response = rekognition.detect_custom_labels(
            Image={'S3Object': {'Bucket': bucket, 'Name': photo}},
            MaxLabels=5,
            MinConfidence=90,
            ProjectVersionArn=model
        )
        '''
        return response
    except Exception as e:
        print(f"Error in detect_food: {str(e)}")
        return None

def display_image(bucket, photo, response):
    try:
        # Load image from S3 bucket
        s3_connection = boto3.resource('s3')
        s3_object = s3_connection.Object(bucket, photo)
        s3_response = s3_object.get()

        stream = io.BytesIO(s3_response['Body'].read())
        image = Image.open(stream)

        # Ready image to draw bounding boxes on it.
        imgWidth, imgHeight = image.size
        draw = ImageDraw.Draw(image)

        # Load a default font if Arial is unavailable (e.g., on Lambda)
        try:
            fnt = ImageFont.truetype('/Library/Fonts/Arial.ttf', 50)
        except IOError:
            fnt = ImageFont.load_default()

        # Calculate and display bounding boxes for each detected custom label
        for customLabel in response.get('CustomLabels', []):
            if 'Geometry' in customLabel:
                box = customLabel['Geometry']['BoundingBox']
                left = imgWidth * box['Left']
                top = imgHeight * box['Top']
                width = imgWidth * box['Width']
                height = imgHeight * box['Height']

                draw.text((left, top), customLabel['Name'], fill='#00d400', font=fnt)
                points = [
                    (left, top),
                    (left + width, top),
                    (left + width, top + height),
                    (left, top + height),
                    (left, top)
                ]
                draw.line(points, fill='#00d400', width=5)

        return image
    except Exception as e:
        print(f"Error in display_image: {str(e)}")
        return None
def upload_results_to_s3(bucket, key, labeled_image, labels):
    try:
        # Save the labeled image to a BytesIO object
        image_buffer = io.BytesIO()
        labeled_image.save(image_buffer, format='JPEG')
        image_buffer.seek(0)

        # Upload the labeled image back to S3
        output_image_key = f'labeled/{key.split("/")[-1]}'  # Store labeled images in a 'labeled' folder
        s3_client.put_object(
            Bucket=bucket,
            Key=output_image_key,
            Body=image_buffer,
            ContentType='image/jpeg'
        )

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

        return output_image_key, labels_key
    except Exception as e:
        print(f"Error uploading results to S3: {str(e)}")
        return None, None
      
def lambda_handler(event, context):
    try:
        # Get bucket and image key from the S3 event
        bucket = event['Records'][0]['s3']['bucket']['name']
        key = urllib.parse.unquote_plus(event['Records'][0]['s3']['object']['key'], encoding='utf-8')
        
        # Detect food in the image
        response = detect_food(bucket, key)
        ''''''
        if response:
            # Annotate the image with labels
            labeled_image = display_image(bucket, key, response)
            if labeled_image:
                # Specify the results bucket (the one created with Terraform)
                results_bucket = "new-foods-tub-results"
                
                # Upload labeled image and labels to S3
                output_image_key, labels_key = upload_results_to_s3(results_bucket, key, labeled_image, 
                                                                     [label['Name'] for label in response.get('Labels', [])])
                p
                print(f"Labeled image uploaded to: {output_image_key}")
                print(f"Labels uploaded to: {labels_key}")
            else:
                print("Failed to create labeled image.")
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