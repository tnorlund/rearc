terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.22.0"
    }
  }
  required_version = "1.3.1"

  cloud {
    organization = "tnorlund"

    workspaces {
      name = "rearc"
    }
  }
}

variable "aws_region" {
  type        = string
  description = "The AWS region"
  default     = "us-east-1"
}

variable "developer" {
  type        = string
  description = "The name of the person adding the infra"
  default     = "Tyler"
}

/**
 * The AWS provider should be handled by ENV vars. 
 */
provider "aws" {
  region = var.aws_region
}

# Create an S3 Bucket to store the data
resource "aws_s3_bucket" "bucket" {
  bucket = "questdata"
  tags = {
    Project   = "quest"
    Developer = var.developer
  }
}

/**
 * Creates a layer using the '.zip' found in S3.
 * See the setup.sh script for implementation
 */
resource "aws_lambda_layer_version" "layer" {
  layer_name          = "rearc"
  s3_bucket           = "tf-cloud"
  s3_key              = "rearc/python.zip"
  description         = "Dependencies for the rearc lambda functions"
  compatible_runtimes = ["python3.9"]
}

resource "aws_iam_role" "iam_for_lambda_part1" {
  name = "iam_for_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}
# Use a Lambda Function to process the DynamoDB stream
data "aws_iam_policy_document" "lambda_policy_doc" {
  # The Lambda function needs accesss to the DynamoDB table and the stream.
  statement {
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:GetObject"
    ]
    resources = [
      aws_s3_bucket.bucket.arn,
      "${aws_s3_bucket.bucket.arn}/*"
    ]
    sid = "codecommitid"
  }
}
resource "aws_iam_role_policy" "lambda_policy" {
  policy = data.aws_iam_policy_document.lambda_policy_doc.json
  role   = aws_iam_role.iam_for_lambda_part1.id
}
data "aws_s3_object" "part1" {
  bucket = "tf-cloud"
  key    = "rearc/part1.zip"

}
resource "aws_lambda_function" "lambda_function_part1" {
  filename      = "part1.zip"
  function_name = "part1"
  role          = aws_iam_role.iam_for_lambda_part1.arn
  handler       = "part1.lambda_handler"

  source_code_hash = data.aws_s3_object.part1.body
  runtime          = "python3.9"
  layers           = [aws_lambda_layer_version.layer.arn]
  memory_size      = 256
  timeout          = 60

  environment {
    variables = {
      BucketName = aws_s3_bucket.bucket.id
    }
  }
}
data "aws_s3_object" "part2" {
  bucket = "tf-cloud"
  key    = "rearc/part2.zip"

}
resource "aws_lambda_function" "lambda_function_part2" {
  filename      = "part2.zip"
  function_name = "part2"
  role          = aws_iam_role.iam_for_lambda_part1.arn
  handler       = "part2.lambda_handler"

  source_code_hash = data.aws_s3_object.part2.body
  runtime          = "python3.9"
  layers           = [aws_lambda_layer_version.layer.arn]
  memory_size      = 256
  timeout          = 60

  environment {
    variables = {
      BucketName = aws_s3_bucket.bucket.id
    }
  }
}
data "aws_s3_object" "part3" {
  bucket = "tf-cloud"
  key    = "rearc/part3.zip"

}
resource "aws_lambda_function" "lambda_function_part3" {
  filename      = "part3.zip"
  function_name = "part3"
  role          = aws_iam_role.iam_for_lambda_part1.arn
  handler       = "part3.lambda_handler"

  source_code_hash = data.aws_s3_object.part3.body
  runtime          = "python3.9"
  layers           = [
    aws_lambda_layer_version.layer.arn,
    "arn:aws:lambda:us-east-1:336392948345:layer:AWSSDKPandas-Python39:1"
  ]
  memory_size      = 256
  timeout          = 60

  environment {
    variables = {
      BucketName = aws_s3_bucket.bucket.id
    }
  }
}

# Run part 1 and part 2 every day
resource "aws_cloudwatch_event_rule" "part_1_every_day" {
  name                = "part-1-every-day"
  description         = "Fires every day"
  schedule_expression = "rate(1 day)"
}
resource "aws_cloudwatch_event_target" "trigger_part_1_on_schedule" {
  rule      = aws_cloudwatch_event_rule.part_1_every_day.name
  target_id = "lambda"
  arn       = aws_lambda_function.lambda_function_part1.arn
}
resource "aws_lambda_permission" "cloud_watch_part_1" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function_part1.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.part_1_every_day.arn
}
resource "aws_cloudwatch_event_rule" "part_2_every_day" {
  name                = "part-2-every-day"
  description         = "Fires every day"
  schedule_expression = "rate(1 day)"
}
resource "aws_cloudwatch_event_target" "trigger_part_2_on_schedule" {
  rule      = aws_cloudwatch_event_rule.part_2_every_day.name
  target_id = "lambda"
  arn       = aws_lambda_function.lambda_function_part2.arn
}
resource "aws_lambda_permission" "cloud_watch_part_2" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function_part2.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.part_2_every_day.arn
}

# Trigger Part 3 when the ".json" is placed in S3 from part 2
resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function_part3.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.bucket.arn
}
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.lambda_function_part3.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = "api.json"
  }

  depends_on = [aws_lambda_permission.allow_bucket]
}