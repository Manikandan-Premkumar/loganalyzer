import json
import requests
import os
import logging
from datetime import datetime
import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Clients
s3 = boto3.client("s3", region_name="ap-south-1")
ddb = boto3.resource("dynamodb", region_name="ap-south-1")
table = ddb.Table(os.environ["DDB_TABLE"])

COHERE_API_KEY = os.environ["COHERE_API_KEY"]

def lambda_handler(event, context):
    try:
        # 1. Get S3 object
        record = event["Records"][0]
        bucket = record["s3"]["bucket"]["name"]
        key = record["s3"]["object"]["key"]

        logger.info(f"Reading: s3://{bucket}/{key}")
        obj = s3.get_object(Bucket=bucket, Key=key)
        content = obj["Body"].read().decode("utf-8")

        # 2. Prepare prompt from logs
        lines = content.splitlines()
        errors = [line for line in lines if "ERROR" in line or "Exception" in line]
        prompt = "\n".join(errors if errors else lines[-20:])
        prompt = prompt[:12000]  # Safety trim

        # 3. Call Cohere Chat
        headers = {
            "Authorization": f"Bearer {COHERE_API_KEY}",
            "Content-Type": "application/json"
        }

        body = {
            "chat_history": [],
            "message": f"Summarize the following logs:\n{prompt}",
            "model": "command-r-plus",  # Or "command-r" if not available
            "temperature": 0.5
        }

        response = requests.post("https://api.cohere.ai/v1/chat", headers=headers, json=body)
        response.raise_for_status()

        result = response.json()
        summary = result.get("text", "No summary generated")

        # 4. Store in DynamoDB
        table.put_item(Item={
            "log_id": key,
            "timestamp": datetime.utcnow().isoformat(),
            "summary": summary
        })

        return {
            "statusCode": 200,
            "body": json.dumps("Summary stored successfully")
        }

    except Exception as e:
        logger.error(f"Error: {str(e)}")
        return {
            "statusCode": 500,
            "body": json.dumps(f"Error: {str(e)}")
        }
