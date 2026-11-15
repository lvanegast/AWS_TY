# Proyecto 2: Microservicio API en Contenedor Docker

Este proyecto demuestra cómo un servicio containerizado independiente se conecta a la red compartida `aws-local-net` e interactúa con los servicios de AWS emulados por LocalStack.

## Características:
- **Secrets Manager**: Lee credenciales de configuración de `/app/secrets` al iniciar.
- **DynamoDB**: Crea y gestiona la tabla `Products` realizando operaciones de lectura y escritura.
- **Red Docker Bridge**: Conexión directa mediante `http://localstack:4566`.

## Cómo ejecutarlo:
1. Asegúrate de que el Hub LocalStack esté encendido.
2. Levanta el microservicio:
   ```bash
   docker compose up -d --build
   ```
3. Probar endpoints:
   - Estado: `curl http://localhost:8080/health`
   - Secretos: `curl http://localhost:8080/config`
   - Crear producto:
     ```bash
     curl -X POST http://localhost:8080/products -H "Content-Type: application/json" -d '{"name": "Teclado Mecanico", "price": 89.99}'
     ```
   - Listar productos: `curl http://localhost:8080/products`
