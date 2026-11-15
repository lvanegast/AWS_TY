<#
.SYNOPSIS
    Prueba los endpoints del Microservicio API en Contenedor (Proyecto 2).
#>

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " 🌐 Probando Proyecto 2: API en Contenedor (Docker + AWS) " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Healthcheck
Write-Host "1️⃣ GET /health..." -ForegroundColor Yellow
$health = Invoke-RestMethod -Uri "http://localhost:8080/health" -Method Get
$health | Format-List

# 2. Lectura de Secretos desde Secrets Manager
Write-Host "2️⃣ GET /config (Leyendo secreto 'app/secrets' desde LocalStack)..." -ForegroundColor Yellow
$config = Invoke-RestMethod -Uri "http://localhost:8080/config" -Method Get
$config | Format-List

# 3. Creación de un Producto en DynamoDB a través del API
Write-Host "3️⃣ POST /products (Guardando producto en DynamoDB)..." -ForegroundColor Yellow
$body = @{
    name = "Monitor Gaming 27 pulgadas"
    price = 299.99
} | ConvertTo-Json

$created = Invoke-RestMethod -Uri "http://localhost:8080/products" -Method Post -Body $body -ContentType "application/json"
$created | Format-List

# 4. Listado de Productos desde DynamoDB
Write-Host "4️⃣ GET /products (Listando productos)..." -ForegroundColor Yellow
$list = Invoke-RestMethod -Uri "http://localhost:8080/products" -Method Get
$list.products | Format-Table -AutoSize

Write-Host "==========================================================" -ForegroundColor Green
Write-Host "✅ Microservicio API probado exitosamente!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
