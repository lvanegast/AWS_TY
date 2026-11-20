import json
import os
import hashlib
import time
import boto3

localstack_host = os.environ.get("LOCALSTACK_HOSTNAME", "localstack")
ENDPOINT_URL = os.environ.get("AWS_ENDPOINT_URL") or f"http://{localstack_host}:4566"
REGION = os.environ.get("AWS_DEFAULT_REGION", "us-east-1")
TABLE_NAME = os.environ.get("URLS_TABLE", "ShortUrls")

dynamodb = boto3.resource(
    "dynamodb",
    endpoint_url=ENDPOINT_URL,
    region_name=REGION,
    aws_access_key_id="test",
    aws_secret_access_key="test",
)

BASE62_ALPHABET = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

def generate_short_code(url: str) -> str:
    # Genera un código hash corto de 6 caracteres usando SHA-256 + timestamp
    raw = f"{url}-{time.time()}"
    digest = hashlib.sha256(raw.encode()).hexdigest()
    num = int(digest[:10], 16)
    code = []
    while num > 0 and len(code) < 6:
        code.append(BASE62_ALPHABET[num % 62])
        num //= 62
    return "".join(code).ljust(6, "x")

def handler(event, context):
    """
    POST /shorten
    Recibe: { "url": "https://midominio.com/articulo-muy-largo" }
    Guarda en DynamoDB y retorna el código y metadata.
    """
    print(f"📥 Shorten event: {json.dumps(event)}")
    body = event
    if isinstance(event.get("body"), str):
        try:
            body = json.loads(event["body"])
        except Exception:
            body = {}

    original_url = body.get("url") or event.get("url")
    if not original_url:
        return {
            "statusCode": 400,
            "headers": {"Content-Type": "application/json", "Access-Control-Allow-Origin": "*"},
            "body": json.dumps({"error": "El campo 'url' es obligatorio"})
        }

    short_code = body.get("custom_code") or generate_short_code(original_url)
    created_at = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

    table = dynamodb.Table(TABLE_NAME)
    item = {
        "short_code": short_code,
        "original_url": original_url,
        "created_at": created_at,
        "clicks": 0
    }
    table.put_item(Item=item)
    print(f"✅ URL guardada: {short_code} -> {original_url}")

    return {
        "statusCode": 201,
        "headers": {"Content-Type": "application/json", "Access-Control-Allow-Origin": "*"},
        "body": json.dumps({
            "message": "URL acortada exitosamente",
            "short_code": short_code,
            "original_url": original_url,
            "created_at": created_at,
            "clicks": 0
        })
    }
