AI-loganalyzer

**AI-Powered Log Analyzer using AWS Lambda, S3, DynamoDB, and Cohere/OpenAI**

This project is a serverless AI-powered log analysis pipeline. It automatically:
-  Ingests `.log` files uploaded to Amazon S3,
-  Extracts errors/exceptions,
-  Summarizes using Cohere (or OpenAI GPT-4o),
-  Stores results in DynamoDB,
-  Visualizes insights with a Streamlit frontend.

---

** Architecture**

S3 (log upload) ─▶ Lambda ─▶ AI Model (Cohere/OpenAI) ─▶ DynamoDB ─▶ Streamlit Viewer

Lambda Function
Create an S3 bucket and a DynamoDB table (ai-log-summary-table).

Set Lambda environment variables:

DDB_TABLE=ai-log-summary-table

COHERE_API_KEY=<your-key> or OPENAI_API_KEY=<your-key>

Attach a role with:

s3:GetObject

dynamodb:PutItem

Access to Cohere/OpenAI

Deploy lambda_function.py and test by uploading .log files to S3.
![Screenshot 2025-07-04 090646](https://github.com/user-attachments/assets/02679d4a-feb7-42d9-abc4-e6751f66f334)

