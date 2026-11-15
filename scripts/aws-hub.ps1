<#
.SYNOPSIS
    CLI de control y gestión para el Hub LocalStack de AWS_TY.
.DESCRIPTION
    Permite iniciar, detener, monitorear y consultar el estado del stack de AWS Local.
.EXAMPLE
    .\scripts\aws-hub.ps1 start
    .\scripts\aws-hub.ps1 status
    .\scripts\aws-hub.ps1 awslocal s3 ls
#>

param (
    [Parameter(Position=0)]
    [ValidateSet("start", "stop", "restart", "status", "logs", "reset", "awslocal", "help")]
    [string]$Action = "help",

    [Parameter(Position=1, ValueFromRemainingArguments=$true)]
    [string[]]$ExtraArgs
)

$RootDir = Split-Path -Parent $PSScriptRoot
Set-Location $RootDir

function Show-Header {
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host " ☁️  AWS LOCAL HUB (LocalStack Orchestrator)              " -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
}

function Test-DockerRunning {
    $dockerCheck = docker ps 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Error: Docker no se está ejecutando." -ForegroundColor Red
        Write-Host "Por favor, inicia Docker Desktop en Windows y vuelve a intentarlo." -ForegroundColor Yellow
        exit 1
    }
}

switch ($Action.ToLower()) {
    "start" {
        Show-Header
        Test-DockerRunning
        Write-Host "🚀 Iniciando LocalStack Hub..." -ForegroundColor Green
        docker compose up -d

        Write-Host "⏳ Esperando a que los servicios estén listos..." -ForegroundColor Yellow
        $ready = $false
        for ($i = 0; $i -lt 30; $i++) {
            Start-Sleep -Seconds 2
            try {
                $response = Invoke-RestMethod -Uri "http://localhost:4566/_localstack/health" -Method Get -TimeoutSec 2 -ErrorAction Stop
                if ($response.services) {
                    $ready = $true
                    break
                }
            } catch {
                # Aún iniciando
            }
            Write-Host -NoNewline "."
        }
        Write-Host ""

        if ($ready) {
            Write-Host "✅ LocalStack está listo y escuchando en http://localhost:4566" -ForegroundColor Green
            & $PSCommandPath status
        } else {
            Write-Host "⚠️ LocalStack demoró más de lo esperado en iniciar. Revisa los logs con: .\scripts\aws-hub.ps1 logs" -ForegroundColor Yellow
        }
    }

    "stop" {
        Show-Header
        Write-Host "🛑 Deteniendo LocalStack Hub..." -ForegroundColor Yellow
        docker compose down
        Write-Host "✅ Contenedores detenidos." -ForegroundColor Green
    }

    "restart" {
        & $PSCommandPath stop
        & $PSCommandPath start
    }

    "status" {
        Show-Header
        Test-DockerRunning
        try {
            $health = Invoke-RestMethod -Uri "http://localhost:4566/_localstack/health" -Method Get -TimeoutSec 3 -ErrorAction Stop
            Write-Host "`n📡 Estado de los Servicios de AWS en LocalStack:" -ForegroundColor Cyan
            Write-Host "----------------------------------------------------------"
            $services = $health.services.PSObject.Properties | Select-Object Name, Value
            $services | Format-Table -AutoSize @{Label="Servicio"; Expression={$_.Name}}, @{Label="Estado"; Expression={
                if ($_.Value -in @("running", "available")) {
                    [char]0x2714 + " " + $_.Value
                } else {
                    $_.Value
                }
            }}
            Write-Host "🔗 Endpoint local: http://localhost:4566" -ForegroundColor Green
            Write-Host "🌐 Red Docker: aws-local-net (disponible para otros contenedores)" -ForegroundColor Green
        } catch {
            Write-Host "❌ No se pudo conectar a LocalStack (puerto 4566 no responde)." -ForegroundColor Red
            Write-Host "Verifica si el contenedor está iniciado con: docker ps" -ForegroundColor Yellow
        }
    }

    "logs" {
        docker compose logs -f localstack
    }

    "reset" {
        Show-Header
        Write-Host "⚠️ ATENCIÓN: Se eliminarán todos los datos persistentes y contenedores locales de AWS." -ForegroundColor Yellow
        $confirm = Read-Host "¿Deseas continuar? (s/N)"
        if ($confirm -eq "s" -or $confirm -eq "S") {
            docker compose down -v
            if (Test-Path "$RootDir\.localstack") {
                Remove-Item -Recurse -Force "$RootDir\.localstack"
            }
            Write-Host "✅ Estado local reseteado a cero." -ForegroundColor Green
        } else {
            Write-Host "Operación cancelada." -ForegroundColor Gray
        }
    }

    "awslocal" {
        Test-DockerRunning
        if (-not $ExtraArgs -or $ExtraArgs.Count -eq 0) {
            Write-Host "Uso: .\scripts\aws-hub.ps1 awslocal <comando AWS>" -ForegroundColor Yellow
            Write-Host "Ejemplo: .\scripts\aws-hub.ps1 awslocal s3 ls" -ForegroundColor Gray
            exit 0
        }
        $cmd = "awslocal " + ($ExtraArgs -join " ")
        docker exec -it localstack-hub bash -c $cmd
    }

    default {
        Show-Header
        Write-Host "Comandos disponibles:" -ForegroundColor Cyan
        Write-Host "  .\scripts\aws-hub.ps1 start      - Inicia LocalStack y espera a que esté listo"
        Write-Host "  .\scripts\aws-hub.ps1 stop       - Detiene LocalStack"
        Write-Host "  .\scripts\aws-hub.ps1 restart    - Reinicia el stack"
        Write-Host "  .\scripts\aws-hub.ps1 status     - Muestra salud de los servicios AWS"
        Write-Host "  .\scripts\aws-hub.ps1 logs       - Muestra los logs en tiempo real"
        Write-Host "  .\scripts\aws-hub.ps1 reset      - Elimina datos y vuelve al estado inicial"
        Write-Host "  .\scripts\aws-hub.ps1 awslocal   - Ejecuta comandos AWS dentro del contenedor"
        Write-Host ""
        Write-Host "Ejemplo rápido:" -ForegroundColor Yellow
        Write-Host "  .\scripts\aws-hub.ps1 start"
        Write-Host "  .\scripts\aws-hub.ps1 awslocal s3 ls"
    }
}
