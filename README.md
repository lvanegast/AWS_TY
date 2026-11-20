# ☁️ AWS Local Hub (LocalStack Multi-Project)

Este repositorio es el **Hub Central de Infraestructura Local de AWS**, diseñado para que múltiples microservicios y proyectos en desarrollo puedan interactuar con servicios de AWS emulados (S3, SQS, SNS, DynamoDB, Lambda, Secrets Manager, etc.) de forma local, rápida y sin costos de nube.

---

## 🏗️ Arquitectura Multi-Proyecto

Todos los proyectos y microservicios se conectan a un único clúster LocalStack a través de la red Docker compartida **`aws-local-net`** o desde el host mediante el puerto unificado **`4566`**.

```text
                  +----------------------------------------------+
                  |         Docker Network: aws-local-net        |
                  |                                              |
                  |      +--------------------------------+      |
                  |      |      localstack-hub:4566       |      |
                  |      | (S3, DynamoDB, SQS, SNS, ...)  |      |
                  |      +---------------+----------------+      |
                  |                      ^                       |
                  |                      |                       |
       +----------+----------+     +-----+-----+     +-----------+----------+
       |   Proyecto 1        |     | Proyecto 2|     |   Proyecto 3         |
       | Serverless Pipeline |     | Docker API|     | Pub/Sub Fan-Out      |
       +---------------------+     +-----------+     +----------------------+
```

---

## 🚀 Inicio Rápido

### 1. Iniciar el Hub
Asegúrate de que Docker Desktop esté abierto y ejecuta en PowerShell:
```powershell
.\scripts\aws-hub.ps1 start
```

### 2. Verificar el Estado de los Servicios
```powershell
.\scripts\aws-hub.ps1 status
```

### 3. Abrir la Consola Gráfica Local (Web Dashboard)
Abre tu navegador en:
👉 **`http://localhost:3000`** (o ejecuta `.\scripts\aws-hub.ps1 dashboard`)

Desde esta consola visual puedes:
- Inspeccionar buckets y archivos de **S3**.
- Explorar y editar registros de **DynamoDB**.
- Monitorear colas de **SQS** y tópicos **SNS**.
- Probar e invocar funciones **Lambda**.
- Ver secretos de **Secrets Manager**.
- Acceder a los proyectos de ejemplo.

### 3. Ejecutar Comandos de AWS sin Instalar Nada
Puedes usar `awslocal` directamente a través del script de gestión:
```powershell
.\scripts\aws-hub.ps1 awslocal s3 ls
.\scripts\aws-hub.ps1 awslocal dynamodb list-tables
```

---

## 📂 Estructura del Repositorio

- **`docker-compose.yml`**: Configuración del clúster LocalStack con persistencia y red compartida.
- **`init/ready.d/`**: Scripts bash que se ejecutan automáticamente cada vez que LocalStack arranca para crear recursos base (buckets, tablas, colas, secretos).
- **`scripts/`**:
  - `aws-hub.ps1`: CLI de control (`start`, `stop`, `status`, `logs`, `reset`, `awslocal`).
  - `setup-cli.ps1`: Configura un entorno virtual de Python con `awscli-local` si deseas comandos nativos en PowerShell.
- **`projects/`**: Proyectos de ejemplo prácticos listos para probar:
  - **`01-serverless-pipeline`**: Pipeline serverless con S3, SQS, Lambda y DynamoDB.
  - **`02-container-api`**: Microservicio REST con Dockerfile propio que lee secretos de Secrets Manager y persiste en DynamoDB.
  - **`03-event-pubsub`**: Arquitectura orientada a eventos con tópico SNS y múltiples colas SQS suscritas.
  - **`04-url-shortener`**: Acortador de URLs 100% Serverless con Frontend en S3, 4 Lambdas, DynamoDB y buffer de analítica con SQS.
- **`templates/`**:
  - `.env.client.example`: Variables de entorno listas para copiar en tus nuevos proyectos.
  - `code-examples/`: Snippets de conexión en Node.js y Python.

---

## 🛠️ Cómo Conectar un Proyecto Nuevo

### Caso A: Tu proyecto corre dentro de un Contenedor Docker
1. En tu `docker-compose.yml`, conéctalo a la red externa `aws-local-net`:
   ```yaml
   services:
     mi-app:
       image: mi-app:latest
       environment:
         - AWS_ENDPOINT_URL=http://localstack:4566
         - AWS_DEFAULT_REGION=us-east-1
         - AWS_ACCESS_KEY_ID=test
         - AWS_SECRET_ACCESS_KEY=test
       networks:
         - aws-local-net

   networks:
     aws-local-net:
       external: true
   ```

### Caso B: Tu proyecto corre directamente en tu Host (Windows / Terminal)
Configura las variables de entorno en tu archivo `.env`:
```env
AWS_ENDPOINT_URL=http://localhost:4566
AWS_DEFAULT_REGION=us-east-1
AWS_ACCESS_KEY_ID=test
AWS_SECRET_ACCESS_KEY=test
```

---

## 🔄 Comandos de Mantenimiento

| Comando | Descripción |
| :--- | :--- |
| `.\scripts\aws-hub.ps1 start` | Inicia LocalStack y espera al healthcheck. |
| `.\scripts\aws-hub.ps1 stop` | Detiene el stack sin perder datos. |
| `.\scripts\aws-hub.ps1 status` | Muestra el estado de cada servicio AWS. |
| `.\scripts\aws-hub.ps1 logs` | Muestra la consola en vivo de LocalStack. |
| `.\scripts\aws-hub.ps1 reset` | Limpia los datos persistentes para un reinicio fresco. |
| `.\scripts\aws-hub.ps1 awslocal <cmd>` | Ejecuta comandos AWS dentro del contenedor. |
