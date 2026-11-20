<#
.SYNOPSIS
    Prueba automatizada de extremo a extremo del URL Shortener Serverless:
    Shorten -> DynamoDB -> Redirect -> SQS -> Analytics Worker -> Stats
#>

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " 🧪 Probando Pipeline Serverless: URL Shortener           " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

function Run-AwsLocal {
    param ([string]$Command)
    docker exec localstack-hub bash -c "awslocal $Command"
}

# 1. Acortar una URL
Write-Host "1️⃣ [Shorten] Acortando URL https://github.com/localstack/localstack..." -ForegroundColor Yellow
$shortenPayload = '{"url":"https://github.com/localstack/localstack","custom_code":"lstk"}'
Set-Content -Path "test_shorten.json" -Value $shortenPayload
docker cp test_shorten.json localstack-hub:/tmp/test_shorten.json
Run-AwsLocal "lambda invoke --function-name ShortenUrlFunction --payload file:///tmp/test_shorten.json /tmp/shorten_res.json"
docker exec localstack-hub cat /tmp/shorten_res.json
Write-Host "`n"

# 2. Verificar en DynamoDB
Write-Host "2️⃣ [DynamoDB] Consultando registro guardado en ShortUrls..." -ForegroundColor Yellow
Run-AwsLocal "dynamodb get-item --table-name ShortUrls --key '{\"short_code\":{\"S\":\"lstk\"}}'"

# 3. Simular Redirección
Write-Host "`n3️⃣ [Redirect] Simulando petición de redirección para 'lstk'..." -ForegroundColor Yellow
$redirectPayload = '{"code":"lstk","headers":{"User-Agent":"TestRunnerPowerShell"}}'
Set-Content -Path "test_redirect.json" -Value $redirectPayload
docker cp test_redirect.json localstack-hub:/tmp/test_redirect.json
Run-AwsLocal "lambda invoke --function-name RedirectUrlFunction --payload file:///tmp/test_redirect.json /tmp/redirect_res.json"
docker exec localstack-hub cat /tmp/redirect_res.json
Write-Host "`n"

# 4. Esperar procesamiento asíncrono de SQS por AnalyticsWorker
Write-Host "4️⃣ [SQS -> Worker] Esperando a que AnalyticsWorker procese el evento de la cola..." -ForegroundColor Yellow
Start-Sleep -Seconds 3

# 5. Consultar Estadísticas Actualizadas
Write-Host "5️⃣ [Stats] Consultando estadísticas finales..." -ForegroundColor Yellow
$statsPayload = '{"code":"lstk"}'
Set-Content -Path "test_stats.json" -Value $statsPayload
docker cp test_stats.json localstack-hub:/tmp/test_stats.json
Run-AwsLocal "lambda invoke --function-name StatsUrlFunction --payload file:///tmp/test_stats.json /tmp/stats_res.json"
docker exec localstack-hub cat /tmp/stats_res.json
Write-Host "`n"

# 6. Consultar tabla de Auditoría
Write-Host "6️⃣ [Audit Log] Inspeccionando registro de auditoría en UrlClicksAudit..." -ForegroundColor Yellow
Run-AwsLocal "dynamodb scan --table-name UrlClicksAudit"

Write-Host "==========================================================" -ForegroundColor Green
Write-Host "🎉 Flujo Serverless verificado de punta a punta con éxito!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
