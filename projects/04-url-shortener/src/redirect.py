import json
import os
import time
import boto3

localstack_host = os.environ.get("LOCALSTACK_HOSTNAME", "localstack")
ENDPOINT_URL = os.environ.get("AWS_ENDPOINT_URL") or f"http://{localstack_host}:4566"
REGION = os.environ.get("AWS_DEFAULT_REGION", "us-east-1")
TABLE_NAME = os.environ.get("URLS_TABLE", "ShortUrls")
QUEUE_NAME = os.environ.get("CLICKS_QUEUE", "url-clicks-queue")

dynamodb = boto3.resource(
    "dynamodb",
    endpoint_url=ENDPOINT_URL,
    region_name=REGION,
    aws_access_key_id="test",
    aws_secret_access_key="test",
)
sqs = boto3.client(
    "sqs",
    endpoint_url=ENDPOINT_URL,
    region_name=REGION,
    aws_access_key_id="test",
    aws_secret_access_key="test",
)

def get_queue_url():
    try:
        res = sqs.get_queue_url(QueueName=QUEUE_NAME)
        return res["QueueUrl"]
    except Exception as e:
        print(f"⚠️ Error obteniendo QueueUrl: {e}")
        return None

def handler(event, context):
    """
    GET /r/{short_code}
    Busca la URL original en DynamoDB, envía evento asíncrono a SQS y redirige (302).
    """
    print(f"📥 Redirect event: {json.dumps(event)}")
    path_params = event.get("pathParameters") or {}
    short_code = path_params.get("code") or event.get("code") or event.get("short_code")

    if not short_code:
        return {
            "statusCode": 400,
            "headers": {"Content-Type": "application/json", "Access-Control-Allow-Origin": "*"},
            "body": json.dumps({"error": "Parámetro 'code' faltante"})
        }

    table = dynamodb.Table(TABLE_NAME)
    resp = table.get_item(Key={"short_code": short_code})
    item = resp.get("Item")

    if not item:
        return {
            "statusCode": 404,
            "headers": {"Content-Type": "application/json", "Access-Control-Allow-Origin": "*"},
            "body": json.dumps({"error": f"Enlace corto '{short_code}' no encontrado"})
        }

    original_url = item["original_url"]

    # Enviar evento asíncrono a SQS para conteo y analítica desacoplada
    queue_url = get_queue_url()
    if queue_url:
        click_event = {
            "short_code": short_code,
            "clicked_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "source": event.get("headers", {}).get("User-Agent", "DirectInvocation")
        }
        try:
            sqs.send_message(
                QueueUrl=queue_url,
                MessageBody=json.dumps(click_event)
            )
            print(f"📨 Evento de clic enviado a SQS para {short_code}")
        except Exception as e:
            print(f"⚠️ Error enviando a SQS: {e}")

    # Retornar redirección 302 con header Location
    return {
        "statusCode": 302,
        "headers": {
            "Location": original_url,
            "Access-Control-Allow-Origin": "*",
            "Content-Type": "application/json"
        },
        "body": json.dumps({
            "message": "Redirigiendo...",
            "short_code": short_code,
            "redirect_to": original_url
        })
    }
