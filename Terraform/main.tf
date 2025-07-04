provider "aws" {
  region = "ap-south-1"
}



# S3 Bucket for logs
resource "aws_s3_bucket" "log_bucket" {
  bucket = "ai-log-input-bucket" 
}

# DynamoDB Table for storing summaries
resource "aws_dynamodb_table" "log_summary_table" {
  name         = "ai-log-summary-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "log_id"

  attribute {
    name = "log_id"
    type = "S"
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "cohere-log-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Inline Policy: Allow logs + S3 read + DynamoDB write
resource "aws_iam_role_policy" "lambda_inline_policy" {
  name = "inline-policy-cohere-lambda"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = [
          "s3:GetObject"
        ],
        Resource = [
          "${aws_s3_bucket.log_bucket.arn}",
          "${aws_s3_bucket.log_bucket.arn}/*"
        ]
      },
      {
        Effect   = "Allow",
        Action   = [
          "dynamodb:PutItem"
        ],
        Resource = aws_dynamodb_table.log_summary_table.arn
      }
    ]
  })
}

# Lambda Function
resource "aws_lambda_function" "cohere_log_lambda" {
  function_name = "cohere-log-summarizer"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"
  filename      = "function.zip"  # Pre-zipped with requests lib and code
  timeout       = 10
  memory_size   = 256

  environment {
    variables = {
      COHERE_API_KEY = var.cohere_api_key
      DDB_TABLE      = aws_dynamodb_table.log_summary_table.name
    }
  }

  depends_on = [aws_iam_role_policy.lambda_inline_policy]
}

# Allow S3 to invoke Lambda
resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cohere_log_lambda.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.log_bucket.arn
}

# S3 Trigger
resource "aws_s3_bucket_notification" "lambda_trigger" {
  bucket = aws_s3_bucket.log_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.cohere_log_lambda.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3_invoke]
}

resource "aws_s3_bucket_policy" "allow_lambda_read" {
  bucket = aws_s3_bucket.log_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowLambdaReadAccess",
        Effect = "Allow",
        Principal = {
          AWS = aws_iam_role.lambda_role.arn
        },
        Action = "s3:GetObject",
        Resource = "${aws_s3_bucket.log_bucket.arn}/*"
      }
    ]
  })
}

