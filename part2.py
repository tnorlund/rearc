#!/usr/bin/env python3
import os
import boto3
import requests

LINK = "https://datausa.io/api/data?drilldowns=Nation&measures=Population"
"""The endpoint of the API"""

def lambda_handler(event, context):
  s3 = boto3.client('s3')
  response = requests.get(LINK)
  s3.put_object(
    Body=response.content, 
    Bucket=os.environ['BucketName'],
    Key="api.json"
  )
