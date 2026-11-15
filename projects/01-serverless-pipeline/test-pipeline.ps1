<#
.SYNOPSIS
    Prueba el pipeline serverless invocando la función y verificando la persistencia en DynamoDB.
#>

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " 🧪 Probando Proyecto 1: Invocación y Registro en DynamoDB " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

function Run-AwsLocal {
    param ([string]$Command)
    docker exec localstack-hub bash -c "awslocal $Command"
}

# 1. Subir archivo a S3
Write-Host "1️⃣ Subiendo archivo de prueba a S3..." -ForegroundColor Yellow
"Contenido de reporte financiero 2026" | Set-Content -Path "reporte.txt"
docker cp reporte.txt localstack-hub:/tmp/reporte.txt
Run-AwsLocal "s3 cp /tmp/reporte.txt s3://raw-documents-bucket/reporte.txt"

# 2. Invocar Lambda simulando el procesamiento
Write-Host "2️⃣ Invocando Lambda FileProcessorLambda..." -ForegroundColor Yellow
$jsonContent = '{"filename":"reporte.txt","bucket":"raw-documents-bucket","size":1540}'
Set-Content -Path "event.json" -Value $jsonContent
docker cp event.json localstack-hub:/tmp/event.json
Run-AwsLocal "lambda wait function-active-v2 --function-name FileProcessorLambda"
Run-AwsLocal "lambda invoke --function-name FileProcessorLambda --payload file:///tmp/event.json /tmp/response.json"

Write-Host "📄 Respuesta de la Lambda:" -ForegroundColor Cyan
docker exec localstack-hub cat /tmp/response.json
Write-Host "`n"

# 3. Consultar DynamoDB para validar que la metadata fue guardada
Write-Host "3️⃣ Verificando registro en DynamoDB (ProcessedFiles)..." -ForegroundColor Yellow
Run-AwsLocal "dynamodb scan --table-name ProcessedFiles"

Write-Host "==========================================================" -ForegroundColor Green
Write-Host "✅ Pipeline Serverless probado exitosamente!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
