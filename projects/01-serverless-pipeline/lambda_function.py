import json
import os
import boto3
from datetime import datetime

# En LocalStack, dentro del contenedor de Lambda se usa LOCALSTACK_HOSTNAME o localstack:4566
localstack_host = os.environ.get("LOCALSTACK_HOSTNAME", "localstack")
ENDPOINT_URL = os.environ.get("AWS_ENDPOINT_URL") or f"http://{localstack_host}:4566"
DYNAMODB_TABLE = os.environ.get("TABLE_NAME", "ProcessedFiles")

dynamodb = boto3.resource(
    "dynamodb",
    endpoint_url=ENDPOINT_URL,
    region_name=os.environ.get("AWS_DEFAULT_REGION", "us-east-1"),
    aws_access_key_id="test",
    aws_secret_access_key="test",
)

def handler(event, context):
    """
    Función Lambda que procesa eventos de S3 o invocaciones directas,
    extrayendo información y persistiendo el registro de auditoría en DynamoDB.
    """
    print(f"📥 Evento recibido: {json.dumps(event, indent=2)}")

    table = dynamodb.Table(DYNAMODB_TABLE)
    processed_items = []

    # Caso 1: Evento disparado por S3
    if "Records" in event and event["Records"][0].get("eventSource") == "aws:s3":
        for record in event["Records"]:
            bucket = record["s3"]["bucket"]["name"]
            key = record["s3"]["object"]["key"]
            size = record["s3"]["object"].get("size", 0)

            item = {
                "FileId": f"{bucket}/{key}",
                "Bucket": bucket,
                "FileName": key,
                "SizeBytes": size,
                "ProcessedAt": datetime.utcnow().isoformat(),
                "Status": "COMPLETED",
                "Source": "S3_TRIGGER"
            }
            table.put_item(Item=item)
            processed_items.append(item)
            print(f"✅ Archivo procesado y registrado en DynamoDB: {item['FileId']}")

    # Caso 2: Invocación directa (manual o API)
    else:
        file_name = event.get("filename", "unknown.txt")
        bucket = event.get("bucket", "manual-uploads")
        item = {
            "FileId": f"{bucket}/{file_name}",
            "Bucket": bucket,
            "FileName": file_name,
            "SizeBytes": event.get("size", 1024),
            "ProcessedAt": datetime.utcnow().isoformat(),
            "Status": "COMPLETED",
            "Source": "DIRECT_INVOCATION"
        }
        table.put_item(Item=item)
        processed_items.append(item)
        print(f"✅ Invocación directa registrada en DynamoDB: {item['FileId']}")

    return {
        "statusCode": 200,
        "body": json.dumps({
            "message": "Archivos procesados correctamente",
            "items": processed_items
        })
    }
