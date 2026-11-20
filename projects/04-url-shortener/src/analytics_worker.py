import json
import os
import boto3

localstack_host = os.environ.get("LOCALSTACK_HOSTNAME", "localstack")
ENDPOINT_URL = os.environ.get("AWS_ENDPOINT_URL") or f"http://{localstack_host}:4566"
REGION = os.environ.get("AWS_DEFAULT_REGION", "us-east-1")
URLS_TABLE = os.environ.get("URLS_TABLE", "ShortUrls")
AUDIT_TABLE = os.environ.get("AUDIT_TABLE", "UrlClicksAudit")

dynamodb = boto3.resource(
    "dynamodb",
    endpoint_url=ENDPOINT_URL,
    region_name=REGION,
    aws_access_key_id="test",
    aws_secret_access_key="test",
)

def handler(event, context):
    """
    Trigger automático de SQS (Event Source Mapping).
    Procesa lotes de clics acumulados, incrementa el contador en ShortUrls
    y guarda auditoría en UrlClicksAudit.
    """
    print(f"📥 AnalyticsWorker recibió evento SQS con {len(event.get('Records', []))} registros")

    urls_table = dynamodb.Table(URLS_TABLE)
    audit_table = dynamodb.Table(AUDIT_TABLE)

    processed_count = 0

    for record in event.get("Records", []):
        try:
            body = json.loads(record["body"])
            short_code = body["short_code"]
            clicked_at = body.get("clicked_at", "unknown")
            source = body.get("source", "unknown")

            # 1. Incrementar contador atómico en DynamoDB (ADD clicks :inc)
            urls_table.update_item(
                Key={"short_code": short_code},
                UpdateExpression="ADD clicks :inc",
                ExpressionAttributeValues={":inc": 1}
            )

            # 2. Guardar registro de auditoría individual
            try:
                audit_table.put_item(Item={
                    "short_code": short_code,
                    "clicked_at": clicked_at,
                    "source": source,
                    "sqs_message_id": record.get("messageId", "")
                })
            except Exception as e:
                print(f"⚠️ Error registrando auditoría: {e}")

            processed_count += 1
            print(f"📊 Clic procesado para {short_code} a las {clicked_at}")

        except Exception as e:
            print(f"❌ Error procesando registro SQS: {e}")

    return {
        "statusCode": 200,
        "body": json.dumps({"processed_clicks": processed_count})
    }
