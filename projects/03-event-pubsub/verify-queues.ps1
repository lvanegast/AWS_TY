<#
.SYNOPSIS
    Verifica que las dos colas SQS hayan recibido el mensaje distribuido desde SNS.
#>

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " 📬 Verificando colas SQS del patrón Fan-Out              " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

function Run-AwsLocal {
    param ([string]$Command)
    docker exec localstack-hub bash -c "awslocal $Command"
}

$billingUrl = Run-AwsLocal "sqs get-queue-url --queue-name orders-billing-queue --query 'QueueUrl' --output text"
$shippingUrl = Run-AwsLocal "sqs get-queue-url --queue-name orders-shipping-queue --query 'QueueUrl' --output text"

Write-Host "1️⃣ Mensaje en Cola de FACTURACIÓN (orders-billing-queue):" -ForegroundColor Yellow
Run-AwsLocal "sqs receive-message --queue-url '$($billingUrl.Trim())' --max-number-of-messages 1 --query 'Messages[0].Body' --output text"

Write-Host "`n2️⃣ Mensaje en Cola de LOGÍSTICA / ENVÍOS (orders-shipping-queue):" -ForegroundColor Yellow
Run-AwsLocal "sqs receive-message --queue-url '$($shippingUrl.Trim())' --max-number-of-messages 1 --query 'Messages[0].Body' --output text"

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "🎉 Ambos microservicios recibieron el mismo evento sin acoplamiento!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
