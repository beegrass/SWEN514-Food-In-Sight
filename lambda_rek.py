import boto3
from decimal import Decimal
import json
import urllib.request
import urllib.parse
import urllib.error

rekognition = boto3.client('rekongition')
project_arn='arn:aws:rekognition:us-east-1:559050203586:project/Food-In-sight/1729534598384'
model_arn='arn:aws:rekognition:us-east-1:559050203586:project/Food-In-sight/version/Food-In-sight.2024-10-26T02.09.05/1729922945143'

def detect_food(bucket,key):
    response = rek