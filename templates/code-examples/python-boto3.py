"""
Ejemplo de conexión a DynamoDB en LocalStack usando boto3 para Python.
Dependencias: pip install boto3
"""
import os
import boto3

endpoint = os.environ.get("AWS_ENDPOINT_URL", "http://localhost:4566")
region = os.environ.get("AWS_DEFAULT_REGION", "us-east-1")

dynamodb = boto3.client(
    "dynamodb",
    endpoint_url=endpoint,
    region_name=region,
    aws_access_key_id=os.environ.get("AWS_ACCESS_KEY_ID", "test"),
    aws_secret_access_key=os.environ.get("AWS_SECRET_ACCESS_KEY", "test"),
)

def main():
    print(f"🔌 Conectando a LocalStack DynamoDB en: {endpoint}")
    response = dynamodb.list_tables()
    print("🗄️ Tablas encontradas:", response.get("TableNames", []))

if __name__ == "__main__":
    main()
