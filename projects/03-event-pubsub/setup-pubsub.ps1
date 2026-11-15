<#
.SYNOPSIS
    Configura el patrón Pub/Sub Fan-Out con SNS y dos colas SQS en LocalStack.
#>

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " 📢 Configurando Pub/Sub Fan-Out (SNS -> SQS x2)          " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

function Run-AwsLocal {
    param ([string]$Command)
    docker exec localstack-hub bash -c "awslocal $Command"
}

# 1. Crear Tópico SNS
Write-Host "1️⃣ Creando tópico SNS: orders-fanout-topic..." -ForegroundColor Yellow
$topicArn = Run-AwsLocal "sns create-topic --name orders-fanout-topic --query 'TopicArn' --output text"
$topicArn = $topicArn.Trim()
Write-Host "   ARN del Tópico: $topicArn" -ForegroundColor Gray

# 2. Crear Colas SQS
Write-Host "2️⃣ Creando colas SQS..." -ForegroundColor Yellow
$billingUrl = Run-AwsLocal "sqs create-queue --queue-name orders-billing-queue --query 'QueueUrl' --output text"
$shippingUrl = Run-AwsLocal "sqs create-queue --queue-name orders-shipping-queue --query 'QueueUrl' --output text"

$billingArn = Run-AwsLocal "sqs get-queue-attributes --queue-url '$($billingUrl.Trim())' --attribute-names QueueArn --query 'Attributes.QueueArn' --output text"
$shippingArn = Run-AwsLocal "sqs get-queue-attributes --queue-url '$($shippingUrl.Trim())' --attribute-names QueueArn --query 'Attributes.QueueArn' --output text"

# 3. Suscribir Colas al Tópico
Write-Host "3️⃣ Suscribiendo colas al tópico SNS..." -ForegroundColor Yellow
Run-AwsLocal "sns subscribe --topic-arn '$topicArn' --protocol sqs --notification-endpoint '$($billingArn.Trim())'"
Run-AwsLocal "sns subscribe --topic-arn '$topicArn' --protocol sqs --notification-endpoint '$($shippingArn.Trim())'"

Write-Host "==========================================================" -ForegroundColor Green
Write-Host "✅ Topología Fan-Out creada con éxito!" -ForegroundColor Green
Write-Host "Para enviar una orden ejecuta: .\publish-order.ps1" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Green
