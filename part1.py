#!/usr/bin/env python3
import os
import requests
import boto3
from botocore.errorfactory import ClientError
from bs4 import BeautifulSoup

LINK = "https://download.bls.gov/pub/time.series/pr/"
"""The link that holds the dataset"""

def get_links_from_source():
  response = requests.get(LINK)
  soup = BeautifulSoup(response.content)
  # The HTML has multiple links. One links to the parent directory. Here, we 
  # ignore that "[To Parent Directory]" link.
  return {
    link.text: LINK + link.text for link in soup.find_all('a') 
    if link.text != '[To Parent Directory]'
  }

def update_s3(source_links):
  s3 = boto3.client('s3')
  for file_name, link_to_download in source_links.items():
    try:
      s3.head_object(
        Bucket=os.environ['BucketName'], 
        Key=file_name
      )
    except ClientError:
      # File not in S3
      response = requests.get(link_to_download)
      s3.put_object(
        Body=response.content, 
        Bucket=os.environ['BucketName'],
        Key=file_name
      )
      pass

def lambda_handler(event, context):
  source_links = get_links_from_source()
  update_s3(source_links)


