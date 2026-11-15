<#
.SYNOPSIS
    Publica una orden de compra de prueba en el tópico SNS.
#>

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " 🛒 Publicando orden en tópico SNS                         " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

function Run-AwsLocal {
    param ([string]$Command)
    docker exec localstack-hub bash -c "awslocal $Command"
}

$orderPayload = '{\"orderId\":\"ORD-9988\",\"customer\":\"Juan Perez\",\"amount\":129.50,\"status\":\"CONFIRMED\"}'

Write-Host "📦 Enviando orden: $orderPayload" -ForegroundColor Yellow

$topicArn = Run-AwsLocal "sns list-topics --query 'Topics[?contains(TopicArn, ``orders-fanout-topic``)].TopicArn' --output text"
$topicArn = $topicArn.Trim()

if (-not $topicArn) {
    Write-Host "❌ No se encontró el tópico. Ejecuta primero: .\setup-pubsub.ps1" -ForegroundColor Red
    exit 1
}

$messageId = Run-AwsLocal "sns publish --topic-arn '$topicArn' --message '$orderPayload' --query 'MessageId' --output text"

Write-Host "✅ Mensaje publicado con MessageId: $messageId" -ForegroundColor Green
Write-Host "Ahora ejecuta: .\verify-queues.ps1 para ver cómo ambas colas lo recibieron." -ForegroundColor Cyan
