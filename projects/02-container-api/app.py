import os
import json
from decimal import Decimal
from http.server import HTTPServer, BaseHTTPRequestHandler
import boto3

class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        return super(DecimalEncoder, self).default(obj)

# Configuración desde variables de entorno
ENDPOINT_URL = os.environ.get("AWS_ENDPOINT_URL", "http://localstack:4566")
REGION = os.environ.get("AWS_DEFAULT_REGION", "us-east-1")
PORT = int(os.environ.get("PORT", "8080"))

# Clientes de AWS apuntando a LocalStack
dynamodb = boto3.resource(
    "dynamodb",
    endpoint_url=ENDPOINT_URL,
    region_name=REGION,
    aws_access_key_id="test",
    aws_secret_access_key="test",
)
secrets_client = boto3.client(
    "secretsmanager",
    endpoint_url=ENDPOINT_URL,
    region_name=REGION,
    aws_access_key_id="test",
    aws_secret_access_key="test",
)

TABLE_NAME = "Products"

def ensure_table():
    try:
        dynamodb.create_table(
            TableName=TABLE_NAME,
            KeySchema=[{"AttributeName": "id", "KeyType": "HASH"}],
            AttributeDefinitions=[{"AttributeName": "id", "AttributeType": "S"}],
            BillingMode="PAY_PER_REQUEST"
        )
    except Exception:
        pass  # La tabla ya existe

class SimpleAPIHandler(BaseHTTPRequestHandler):
    def _send_json(self, status_code, data):
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(data, indent=2, cls=DecimalEncoder).encode("utf-8"))

    def do_GET(self):
        if self.path == "/health":
            self._send_json(200, {"status": "HEALTHY", "service": "catalog-api", "aws_endpoint": ENDPOINT_URL})

        elif self.path == "/config":
            try:
                secret_resp = secrets_client.get_secret_value(SecretId="app/secrets")
                secret_data = json.loads(secret_resp.get("SecretString", "{}"))
                self._send_json(200, {
                    "message": "Configuración leída con éxito desde AWS Secrets Manager",
                    "secrets": secret_data
                })
            except Exception as e:
                self._send_json(500, {"error": str(e)})

        elif self.path == "/products":
            try:
                ensure_table()
                table = dynamodb.Table(TABLE_NAME)
                response = table.scan()
                items = response.get("Items", [])
                self._send_json(200, {"products": items, "count": len(items)})
            except Exception as e:
                self._send_json(500, {"error": str(e)})
        else:
            self._send_json(404, {"error": "Not Found"})

    def do_POST(self):
        if self.path == "/products":
            try:
                ensure_table()
                content_length = int(self.headers.get("Content-Length", 0))
                body = self.rfile.read(content_length)
                payload = json.loads(body.decode("utf-8"), parse_float=Decimal)

                product_id = payload.get("id", f"prod-{int(os.urandom(2).hex(), 16)}")
                name = payload.get("name", "Producto Sin Nombre")
                price = payload.get("price", 0)

                item = {"id": product_id, "name": name, "price": price}
                table = dynamodb.Table(TABLE_NAME)
                table.put_item(Item=item)

                self._send_json(201, {"message": "Producto guardado en DynamoDB", "product": item})
            except Exception as e:
                self._send_json(500, {"error": str(e)})
        else:
            self._send_json(404, {"error": "Not Found"})

if __name__ == "__main__":
    ensure_table()
    server = HTTPServer(("0.0.0.0", PORT), SimpleAPIHandler)
    print(f"🚀 Microservicio API corriendo en puerto {PORT}...")
    print(f"📡 Conectado a AWS Local en {ENDPOINT_URL}")
    server.serve_forever()
