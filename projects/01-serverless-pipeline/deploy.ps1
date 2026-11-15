<#
.SYNOPSIS
    Despliega el Proyecto 1 (Serverless Pipeline) en LocalStack.
#>

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " 🚀 Desplegando Proyecto 1: Serverless Pipeline (S3/Lambda/DynamoDB) " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

function Run-AwsLocal {
    param ([string]$Command)
    docker exec localstack-hub bash -c "awslocal $Command"
}

# 1. Crear Bucket S3
Write-Host "1️⃣ Creando bucket S3: raw-documents-bucket..." -ForegroundColor Yellow
Run-AwsLocal "s3 mb s3://raw-documents-bucket"

# 2. Crear Tabla DynamoDB
Write-Host "2️⃣ Creando tabla DynamoDB: ProcessedFiles..." -ForegroundColor Yellow
Run-AwsLocal "dynamodb create-table \
    --table-name ProcessedFiles \
    --attribute-definitions AttributeName=FileId,AttributeType=S \
    --key-schema AttributeName=FileId,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST"

# 3. Empaquetar la función Lambda
Write-Host "3️⃣ Empaquetando lambda_function.py en function.zip..." -ForegroundColor Yellow
if (Test-Path "function.zip") { Remove-Item "function.zip" }
Compress-Archive -Path "lambda_function.py" -DestinationPath "function.zip"

# Copiar el zip dentro del contenedor para crearlo rápidamente
docker cp function.zip localstack-hub:/tmp/function.zip

# 4. Crear la función Lambda en LocalStack
Write-Host "4️⃣ Creando función Lambda: FileProcessorLambda..." -ForegroundColor Yellow
Run-AwsLocal "lambda delete-function --function-name FileProcessorLambda" 2>$null
Run-AwsLocal "lambda create-function \
    --function-name FileProcessorLambda \
    --runtime python3.10 \
    --role arn:aws:iam::000000000000:role/lambda-role \
    --handler lambda_function.handler \
    --timeout 15 \
    --zip-file fileb:///tmp/function.zip \
    --environment 'Variables={TABLE_NAME=ProcessedFiles}'"
Run-AwsLocal "lambda wait function-active-v2 --function-name FileProcessorLambda"

Write-Host "==========================================================" -ForegroundColor Green
Write-Host "✅ Despliegue de Proyecto 1 completado con éxito." -ForegroundColor Green
Write-Host "Para probarlo ejecuta: .\test-pipeline.ps1" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Green
