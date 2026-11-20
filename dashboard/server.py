import os
import json
import time
from decimal import Decimal
from http.server import HTTPServer, BaseHTTPRequestHandler
import urllib.parse
import urllib.request
import boto3

PORT = int(os.environ.get("DASHBOARD_PORT", "3000"))
localstack_host = os.environ.get("LOCALSTACK_HOSTNAME", "localstack")
ENDPOINT_URL = os.environ.get("AWS_ENDPOINT_URL") or f"http://{localstack_host}:4566"
REGION = os.environ.get("AWS_DEFAULT_REGION", "us-east-1")

def get_boto_client(service_name):
    return boto3.client(
        service_name,
        endpoint_url=ENDPOINT_URL,
        region_name=REGION,
        aws_access_key_id="test",
        aws_secret_access_key="test",
    )

def get_boto_resource(service_name):
    return boto3.resource(
        service_name,
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

class DashboardHandler(BaseHTTPRequestHandler):
    def _send_json(self, status_code, data):
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()
        self.wfile.write(json.dumps(data, indent=2, cls=DecimalEncoder).encode("utf-8"))

    def _send_file(self, file_path, content_type="text/html; charset=utf-8"):
        try:
            with open(file_path, "rb") as f:
                content = f.read()
            self.send_response(200)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(content)))
            self.end_headers()
            self.wfile.write(content)
        except Exception as e:
            self.send_response(404)
            self.end_headers()
            self.wfile.write(f"Archivo no encontrado: {e}".encode("utf-8"))

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        query = urllib.parse.parse_qs(parsed.query)

        # 1. Servir Frontend estático
        if path == "/" or path == "/index.html":
            static_dir = os.path.join(os.path.dirname(__file__), "static")
            return self._send_file(os.path.join(static_dir, "index.html"))

        # 2. API: Resumen general y salud
        elif path == "/api/overview":
            try:
                health_url = f"{ENDPOINT_URL}/_localstack/health"
                req = urllib.request.Request(health_url)
                with urllib.request.urlopen(req, timeout=3) as resp:
                    health_data = json.loads(resp.read().decode())
                
                # Obtener conteos básicos
                s3 = get_boto_client("s3")
                buckets = s3.list_buckets().get("Buckets", [])
                
                dynamodb = get_boto_client("dynamodb")
                tables = dynamodb.list_tables().get("TableNames", [])

                sqs = get_boto_client("sqs")
                queues = sqs.list_queues().get("QueueUrls", [])

                lambda_client = get_boto_client("lambda")
                lambdas = lambda_client.list_functions().get("Functions", [])

                self._send_json(200, {
                    "services": health_data.get("services", {}),
                    "counts": {
                        "s3_buckets": len(buckets),
                        "dynamodb_tables": len(tables),
                        "sqs_queues": len(queues),
                        "lambda_functions": len(lambdas)
                    },
                    "endpoint": ENDPOINT_URL
                })
            except Exception as e:
                self._send_json(500, {"error": str(e)})

        # 3. API: S3 Buckets y Objetos
        elif path == "/api/s3":
            try:
                s3 = get_boto_client("s3")
                buckets = s3.list_buckets().get("Buckets", [])
                bucket_list = []
                for b in buckets:
                    b_name = b["Name"]
                    objects = s3.list_objects_v2(Bucket=b_name).get("Contents", [])
                    bucket_list.append({
                        "name": b_name,
                        "created_at": b["CreationDate"].isoformat(),
                        "object_count": len(objects),
                        "objects": [{
                            "key": o["Key"],
                            "size": o["Size"],
                            "last_modified": o["LastModified"].isoformat()
                        } for o in objects]
                    })
                self._send_json(200, {"buckets": bucket_list})
            except Exception as e:
                self._send_json(500, {"error": str(e)})

        # 4. API: DynamoDB Tablas y Datos
        elif path == "/api/dynamodb":
            try:
                dynamodb = get_boto_client("dynamodb")
                table_names = dynamodb.list_tables().get("TableNames", [])
                
                selected_table = query.get("table", [None])[0]
                table_items = []
                if selected_table and selected_table in table_names:
                    res_db = get_boto_resource("dynamodb")
                    tbl = res_db.Table(selected_table)
                    table_items = tbl.scan(Limit=50).get("Items", [])

                self._send_json(200, {
                    "tables": table_names,
                    "selected_table": selected_table,
                    "items": table_items
                })
            except Exception as e:
                self._send_json(500, {"error": str(e)})

        # 5. API: SQS Colas
        elif path == "/api/sqs":
            try:
                sqs = get_boto_client("sqs")
                queue_urls = sqs.list_queues().get("QueueUrls", [])
                queues_data = []
                for q_url in queue_urls:
                    name = q_url.split("/")[-1]
                    attrs = sqs.get_queue_attributes(
                        QueueUrl=q_url,
                        AttributeNames=["ApproximateNumberOfMessages", "QueueArn"]
                    ).get("Attributes", {})
                    queues_data.append({
                        "name": name,
                        "url": q_url,
                        "arn": attrs.get("QueueArn", ""),
                        "messages": int(attrs.get("ApproximateNumberOfMessages", 0))
                    })
                self._send_json(200, {"queues": queues_data})
            except Exception as e:
                self._send_json(500, {"error": str(e)})

        # 6. API: Lambdas
        elif path == "/api/lambdas":
            try:
                lam = get_boto_client("lambda")
                funcs = lam.list_functions().get("Functions", [])
                result = [{
                    "name": f["FunctionName"],
                    "runtime": f.get("Runtime", "custom"),
                    "handler": f.get("Handler", "-"),
                    "timeout": f.get("Timeout", 0),
                    "memory": f.get("MemorySize", 0),
                    "state": f.get("State", "Active"),
                    "last_modified": f.get("LastModified", "")
                } for f in funcs]
                self._send_json(200, {"functions": result})
            except Exception as e:
                self._send_json(500, {"error": str(e)})

        # 7. API: Secrets Manager
        elif path == "/api/secrets":
            try:
                sm = get_boto_client("secretsmanager")
                secrets_list = sm.list_secrets().get("SecretList", [])
                detailed = []
                for s in secrets_list:
                    name = s["Name"]
                    val = sm.get_secret_value(SecretId=name).get("SecretString", "")
                    detailed.append({
                        "name": name,
                        "description": s.get("Description", ""),
                        "value": val
                    })
                self._send_json(200, {"secrets": detailed})
            except Exception as e:
                self._send_json(500, {"error": str(e)})

        # 8. API: SNS Topics
        elif path == "/api/sns":
            try:
                sns = get_boto_client("sns")
                topics = sns.list_topics().get("Topics", [])
                subs = sns.list_subscriptions().get("Subscriptions", [])
                self._send_json(200, {"topics": topics, "subscriptions": subs})
            except Exception as e:
                self._send_json(500, {"error": str(e)})

        else:
            self._send_json(404, {"error": "Ruta no encontrada"})

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        content_length = int(self.headers.get("Content-Length", 0))
        body_bytes = self.rfile.read(content_length)
        payload = {}
        if body_bytes:
            try:
                payload = json.loads(body_bytes.decode())
            except Exception:
                pass

        # Inserción en DynamoDB
        if path == "/api/dynamodb/item":
            try:
                table_name = payload.get("table")
                item = payload.get("item")
                if not table_name or not item:
                    return self._send_json(400, {"error": "Faltan 'table' o 'item'"})
                res_db = get_boto_resource("dynamodb")
                tbl = res_db.Table(table_name)
                tbl.put_item(Item=item)
                self._send_json(201, {"message": "Registro creado en DynamoDB", "item": item})
            except Exception as e:
                self._send_json(500, {"error": str(e)})

        # Enviar mensaje a SQS
        elif path == "/api/sqs/send":
            try:
                queue_url = payload.get("queue_url")
                message = payload.get("message")
                sqs = get_boto_client("sqs")
                msg_body = json.dumps(message) if isinstance(message, (dict, list)) else str(message)
                res = sqs.send_message(QueueUrl=queue_url, MessageBody=msg_body)
                self._send_json(200, {"message": "Mensaje enviado a SQS", "message_id": res.get("MessageId")})
            except Exception as e:
                self._send_json(500, {"error": str(e)})

        # Invocar Lambda
        elif path == "/api/lambdas/invoke":
            try:
                func_name = payload.get("function_name")
                input_payload = payload.get("payload", {})
                lam = get_boto_client("lambda")
                res = lam.invoke(
                    FunctionName=func_name,
                    Payload=json.dumps(input_payload).encode()
                )
                output_str = res["Payload"].read().decode()
                try:
                    output_json = json.loads(output_str)
                except Exception:
                    output_json = output_str
                self._send_json(200, {
                    "statusCode": res.get("StatusCode"),
                    "response": output_json
                })
            except Exception as e:
                self._send_json(500, {"error": str(e)})

        # Publicar en SNS
        elif path == "/api/sns/publish":
            try:
                topic_arn = payload.get("topic_arn")
                message = payload.get("message")
                sns = get_boto_client("sns")
                msg_body = json.dumps(message) if isinstance(message, (dict, list)) else str(message)
                res = sns.publish(TopicArn=topic_arn, Message=msg_body)
                self._send_json(200, {"message": "Publicado en SNS", "message_id": res.get("MessageId")})
            except Exception as e:
                self._send_json(500, {"error": str(e)})

        else:
            self._send_json(404, {"error": "Ruta no encontrada"})

if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", PORT), DashboardHandler)
    print(f"==========================================================")
    print(f"🚀 AWS Local Hub Dashboard listo en http://localhost:{PORT}")
    print(f"📡 Conectado a LocalStack en {ENDPOINT_URL}")
    print(f"==========================================================")
    server.serve_forever()
