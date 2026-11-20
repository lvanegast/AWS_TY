import json
import os
from decimal import Decimal
import boto3

localstack_host = os.environ.get("LOCALSTACK_HOSTNAME", "localstack")
ENDPOINT_URL = os.environ.get("AWS_ENDPOINT_URL") or f"http://{localstack_host}:4566"
REGION = os.environ.get("AWS_DEFAULT_REGION", "us-east-1")
URLS_TABLE = os.environ.get("URLS_TABLE", "ShortUrls")

dynamodb = boto3.resource(
    "dynamodb",
    endpoint_url=ENDPOINT_URL,
    region_name=REGION,
    aws_access_key_id="test",
    aws_secret_access_key="test",
)

class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return int(obj) if obj % 1 == 0 else float(obj)
        return super(DecimalEncoder, self).default(obj)

def handler(event, context):
    """
    GET /stats/{short_code}
    Retorna las métricas y estadísticas del enlace.
    """
    path_params = event.get("pathParameters") or {}
    short_code = path_params.get("code") or event.get("code") or event.get("short_code")

    if not short_code:
        return {
            "statusCode": 400,
            "headers": {"Content-Type": "application/json", "Access-Control-Allow-Origin": "*"},
            "body": json.dumps({"error": "Parámetro 'code' faltante"})
        }

    table = dynamodb.Table(URLS_TABLE)
    resp = table.get_item(Key={"short_code": short_code})
    item = resp.get("Item")

    if not item:
        return {
            "statusCode": 404,
            "headers": {"Content-Type": "application/json", "Access-Control-Allow-Origin": "*"},
            "body": json.dumps({"error": f"Enlace corto '{short_code}' no encontrado"})
        }

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json", "Access-Control-Allow-Origin": "*"},
        "body": json.dumps({
            "short_code": item.get("short_code"),
            "original_url": item.get("original_url"),
            "created_at": item.get("created_at"),
            "total_clicks": item.get("clicks", 0)
        }, cls=DecimalEncoder)
    }
