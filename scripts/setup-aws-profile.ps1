<#
.SYNOPSIS
    Configura el perfil local 'localstack' en ~/.aws/credentials y ~/.aws/config
.DESCRIPTION
    Permite que herramientas oficiales como AWS Toolkit para VS Code,
    NoSQL Workbench de AWS o el comando 'aws --profile localstack' se conecten
    directamente al endpoint local http://localhost:4566 sin requerir credenciales reales.
#>

$awsDir = Join-Path $HOME ".aws"
if (-not (Test-Path $awsDir)) {
    New-Item -ItemType Directory -Path $awsDir -Force | Out-Null
}

$credentialsFile = Join-Path $awsDir "credentials"
$configFile = Join-Path $awsDir "config"

# Configurar Credenciales
$credBlock = @"

[localstack]
aws_access_key_id = test
aws_secret_access_key = test
"@

if (Test-Path $credentialsFile) {
    $existingCreds = Get-Content $credentialsFile -Raw
    if ($existingCreds -notmatch "\[localstack\]") {
        Add-Content -Path $credentialsFile -Value $credBlock
    }
} else {
    Set-Content -Path $credentialsFile -Value $credBlock.TrimStart()
}

# Configurar Config
$configBlock = @"

[profile localstack]
region = us-east-1
output = json
endpoint_url = http://localhost:4566
"@

if (Test-Path $configFile) {
    $existingConfig = Get-Content $configFile -Raw
    if ($existingConfig -notmatch "\[profile localstack\]") {
        Add-Content -Path $configFile -Value $configBlock
    }
} else {
    Set-Content -Path $configFile -Value $configBlock.TrimStart()
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " ☁️  Perfil 'localstack' configurado en ~/.aws/           " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "✅ Archivo credentials: $credentialsFile" -ForegroundColor Green
Write-Host "✅ Archivo config:      $configFile" -ForegroundColor Green
Write-Host ""
Write-Host "Ahora puedes usar herramientas de AWS de escritorio:" -ForegroundColor Yellow
Write-Host "  1. En VS Code con la extension 'AWS Toolkit' seleccionando el perfil 'localstack'." -ForegroundColor White
Write-Host "  2. En NoSQL Workbench conectando a http://localhost:4566." -ForegroundColor White
Write-Host "  3. En tu terminal: aws --profile localstack s3 ls" -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Cyan
