import streamlit as st
import boto3

# DynamoDB setup
REGION = "ap-south-1"
TABLE_NAME = "ai-log-summary-table"  # Replace with your table name

dynamodb = boto3.resource("dynamodb", region_name=REGION)
table = dynamodb.Table(TABLE_NAME)

st.title("🧠 AI Log Summaries")

# Fetch data
with st.spinner("Loading summaries..."):
    response = table.scan()
    logs = response.get("Items", [])

# Sort by latest
logs.sort(key=lambda x: x.get("timestamp", ""), reverse=True)

# Display summaries
for log in logs:
    st.subheader(f"📝 {log['log_id']}")
    st.text(f"⏱️ {log.get('timestamp', 'No timestamp')}")
    st.markdown(log.get("summary", "No summary available"))
    st.markdown("---")
