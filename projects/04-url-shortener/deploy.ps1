<#
.SYNOPSIS
    Despliega el URL Shortener 100% Serverless en LocalStack:
    S3 (Hosting) + DynamoDB (2 tablas) + SQS + 4 Lambdas + EventSourceMapping.
#>

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " ⚡ Desplegando Proyecto 4: AWS Serverless URL Shortener   " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

function Run-AwsLocal {
    param ([string]$Command)
    docker exec localstack-hub bash -c "awslocal $Command"
}

# 1. Tablas DynamoDB
Write-Host "1️⃣ Creando tablas DynamoDB..." -ForegroundColor Yellow
Run-AwsLocal "dynamodb create-table \
    --table-name ShortUrls \
    --attribute-definitions AttributeName=short_code,AttributeType=S \
    --key-schema AttributeName=short_code,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST" 2>$null

Run-AwsLocal "dynamodb create-table \
    --table-name UrlClicksAudit \
    --attribute-definitions AttributeName=short_code,AttributeType=S AttributeName=clicked_at,AttributeType=S \
    --key-schema AttributeName=short_code,KeyType=HASH AttributeName=clicked_at,KeyType=RANGE \
    --billing-mode PAY_PER_REQUEST" 2>$null

# 2. Cola SQS
Write-Host "2️⃣ Creando cola SQS: url-clicks-queue..." -ForegroundColor Yellow
$queueUrl = Run-AwsLocal "sqs create-queue --queue-name url-clicks-queue --query 'QueueUrl' --output text"
$queueUrl = $queueUrl.Trim()

$queueArn = Run-AwsLocal "sqs get-queue-attributes --queue-url '$queueUrl' --attribute-names QueueArn --query 'Attributes.QueueArn' --output text"
$queueArn = $queueArn.Trim()
Write-Host "   Queue ARN: $queueArn" -ForegroundColor Gray

# 3. Empaquetar Lambdas
Write-Host "3️⃣ Empaquetando código de las Lambdas..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path "dist" | Out-Null

Compress-Archive -Path "src\shorten.py" -DestinationPath "dist\shorten.zip" -Force
Compress-Archive -Path "src\redirect.py" -DestinationPath "dist\redirect.zip" -Force
Compress-Archive -Path "src\analytics_worker.py" -DestinationPath "dist\analytics_worker.zip" -Force
Compress-Archive -Path "src\stats.py" -DestinationPath "dist\stats.zip" -Force

docker cp dist\shorten.zip localstack-hub:/tmp/shorten.zip
docker cp dist\redirect.zip localstack-hub:/tmp/redirect.zip
docker cp dist\analytics_worker.zip localstack-hub:/tmp/analytics_worker.zip
docker cp dist\stats.zip localstack-hub:/tmp/stats.zip

# 4. Crear Funciones Lambda
Write-Host "4️⃣ Creando funciones Lambda en LocalStack..." -ForegroundColor Yellow

# Lambda 1: Shorten
Run-AwsLocal "lambda delete-function --function-name ShortenUrlFunction" 2>$null
Run-AwsLocal "lambda create-function \
    --function-name ShortenUrlFunction \
    --runtime python3.10 \
    --role arn:aws:iam::000000000000:role/lambda-role \
    --handler shorten.handler \
    --timeout 15 \
    --zip-file fileb:///tmp/shorten.zip \
    --environment 'Variables={URLS_TABLE=ShortUrls}'"

# Lambda 2: Redirect
Run-AwsLocal "lambda delete-function --function-name RedirectUrlFunction" 2>$null
Run-AwsLocal "lambda create-function \
    --function-name RedirectUrlFunction \
    --runtime python3.10 \
    --role arn:aws:iam::000000000000:role/lambda-role \
    --handler redirect.handler \
    --timeout 15 \
    --zip-file fileb:///tmp/redirect.zip \
    --environment 'Variables={URLS_TABLE=ShortUrls,CLICKS_QUEUE=url-clicks-queue}'"

# Lambda 3: Analytics Worker (Trigger SQS)
Run-AwsLocal "lambda delete-function --function-name AnalyticsWorkerFunction" 2>$null
Run-AwsLocal "lambda create-function \
    --function-name AnalyticsWorkerFunction \
    --runtime python3.10 \
    --role arn:aws:iam::000000000000:role/lambda-role \
    --handler analytics_worker.handler \
    --timeout 15 \
    --zip-file fileb:///tmp/analytics_worker.zip \
    --environment 'Variables={URLS_TABLE=ShortUrls,AUDIT_TABLE=UrlClicksAudit}'"

# Lambda 4: Stats
Run-AwsLocal "lambda delete-function --function-name StatsUrlFunction" 2>$null
Run-AwsLocal "lambda create-function \
    --function-name StatsUrlFunction \
    --runtime python3.10 \
    --role arn:aws:iam::000000000000:role/lambda-role \
    --handler stats.handler \
    --timeout 15 \
    --zip-file fileb:///tmp/stats.zip \
    --environment 'Variables={URLS_TABLE=ShortUrls}'"

Write-Host "⏳ Esperando a que las Lambdas estén activas..." -ForegroundColor Yellow
Run-AwsLocal "lambda wait function-active-v2 --function-name ShortenUrlFunction"
Run-AwsLocal "lambda wait function-active-v2 --function-name RedirectUrlFunction"
Run-AwsLocal "lambda wait function-active-v2 --function-name AnalyticsWorkerFunction"
Run-AwsLocal "lambda wait function-active-v2 --function-name StatsUrlFunction"

# 5. Configurar Trigger SQS -> AnalyticsWorker Lambda
Write-Host "5️⃣ Vinculando EventSourceMapping SQS -> AnalyticsWorker..." -ForegroundColor Yellow
Run-AwsLocal "lambda create-event-source-mapping \
    --function-name AnalyticsWorkerFunction \
    --event-source-arn '$queueArn' \
    --batch-size 10" 2>$null

# 6. Desplegar Frontend Web en S3
Write-Host "6️⃣ Desplegando Frontend Web en Amazon S3..." -ForegroundColor Yellow
Run-AwsLocal "s3 mb s3://dev-shortener-web" 2>$null
docker cp web\index.html localstack-hub:/tmp/index.html
Run-AwsLocal "s3 cp /tmp/index.html s3://dev-shortener-web/index.html"
Run-AwsLocal "s3website s3://dev-shortener-web --index-document index.html" 2>$null

Write-Host "==========================================================" -ForegroundColor Green
Write-Host "🎉 Despliegue completado con éxito!" -ForegroundColor Green
Write-Host "🌐 Accede al Frontend Web en tu navegador:" -ForegroundColor Cyan
Write-Host "   http://localhost:4566/dev-shortener-web/index.html" -ForegroundColor White
Write-Host "🧪 O ejecuta las pruebas automáticas con: .\test-shortener.ps1" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Green
