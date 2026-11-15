<#
.SYNOPSIS
    Configura el entorno de herramientas CLI locales (awscli y awscli-local).
.DESCRIPTION
    Crea un virtualenv en .venv y descarga la librería awscli-local para poder
    ejecutar comandos 'awslocal' directamente desde PowerShell en Windows.
#>

$RootDir = Split-Path -Parent $PSScriptRoot
Set-Location $RootDir

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " 📦 Configuración de herramientas CLI para AWS Local       " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# Verificar Python
$pythonVersion = python --version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ No se encontró Python instalado en el sistema." -ForegroundColor Red
    exit 1
}
Write-Host "🐍 Usando $pythonVersion" -ForegroundColor Green

# Crear entorno virtual si no existe
if (-not (Test-Path "$RootDir\.venv")) {
    Write-Host "📁 Creando entorno virtual en .venv..." -ForegroundColor Yellow
    python -m venv .venv
}

Write-Host "⬇️ Instalando awscli y awscli-local..." -ForegroundColor Yellow
& "$RootDir\.venv\Scripts\python.exe" -m pip install --upgrade pip
& "$RootDir\.venv\Scripts\python.exe" -m pip install awscli awscli-local

# Crear script de wrapper 'awslocal.cmd' en el directorio para ejecución rápida
$wrapperContent = @"
@echo off
"$RootDir\.venv\Scripts\awslocal.exe" %*
"@
Set-Content -Path "$RootDir\awslocal.cmd" -Value $wrapperContent

Write-Host "==========================================================" -ForegroundColor Green
Write-Host "✅ Instalación completada." -ForegroundColor Green
Write-Host "Ahora puedes ejecutar comandos awslocal de dos formas:" -ForegroundColor Cyan
Write-Host "  1. Directamente con el wrapper: .\awslocal.cmd s3 ls" -ForegroundColor White
Write-Host "  2. O a través del hub: .\scripts\aws-hub.ps1 awslocal s3 ls" -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Green
