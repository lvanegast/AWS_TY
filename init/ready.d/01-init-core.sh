#!/usr/bin/env bash
set -eo pipefail

echo "=========================================================="
echo "🚀 [INIT HOOK] Inicializando recursos base en LocalStack..."
echo "=========================================================="

# 1. Bucket S3 base
echo "📦 Creando bucket S3: dev-bucket-general..."
awslocal s3 mb s3://dev-bucket-general || true

# 2. Cola SQS base
echo "📨 Creando cola SQS: system-events-queue..."
awslocal sqs create-queue --queue-name system-events-queue || true

# 3. Tópico SNS base
echo "📢 Creando tópico SNS: global-announcements..."
awslocal sns create-topic --name global-announcements || true

# 4. Tabla DynamoDB base
echo "🗄️ Creando tabla DynamoDB: SystemConfig..."
awslocal dynamodb create-table \
    --table-name SystemConfig \
    --attribute-definitions AttributeName=ConfigKey,AttributeType=S \
    --key-schema AttributeName=ConfigKey,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST || true

# 5. Secrets Manager
echo "🔐 Creando secreto en Secrets Manager: app/secrets..."
awslocal secretsmanager create-secret \
    --name "app/secrets" \
    --description "Credenciales de prueba para desarrollo local" \
    --secret-string '{"DB_HOST":"postgres","DB_USER":"admin","DB_PASS":"supersecret123"}' || true

# 6. SSM Parameter Store
echo "⚙️ Creando parámetro SSM: /app/environment..."
awslocal ssm put-parameter \
    --name "/app/environment" \
    --type "String" \
    --value "local-development" \
    --overwrite || true

# 7. Recursos para URL Shortener
echo "🔗 Inicializando recursos para URL Shortener (DynamoDB y SQS)..."
awslocal dynamodb create-table \
    --table-name ShortUrls \
    --attribute-definitions AttributeName=short_code,AttributeType=S \
    --key-schema AttributeName=short_code,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST || true

awslocal sqs create-queue --queue-name url-clicks-queue || true

echo "=========================================================="
echo "✅ [INIT HOOK] Recursos base creados exitosamente."
echo "=========================================================="
