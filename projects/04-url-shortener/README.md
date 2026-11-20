# Proyecto 4: AWS Serverless URL Shortener & Analytics

Este proyecto implementa un acortador de URLs completo siguiendo una arquitectura **100% Serverless en AWS** sobre LocalStack, combinando almacenamiento de alta velocidad, cómputo por eventos y colas asíncronas.

---

## 🏗️ Arquitectura y Servicios

```text
  [ Navegador Web ]
          |
          v
   +---------------+          +------------------------+
   |   Amazon S3   | -------> |  Frontend Web Hosting  |
   +---------------+          |  (index.html)          |
                              +------------------------+
                                          |
                        +-----------------+-----------------+
                        |                                   |
                        v                                   v
             +----------------------+            +----------------------+
             |  ShortenUrlFunction  |            |  RedirectUrlFunction |
             |   (AWS Lambda)       |            |   (AWS Lambda)       |
             +----------+-----------+            +----------+-----------+
                        |                                   |
                        v                                   | (Envía evento de clic)
             +----------------------+                       v
             |   Amazon DynamoDB    |            +----------------------+
             |   Tabla: ShortUrls   | <--------- |      Amazon SQS      |
             +----------------------+  (Actualiza|  (url-clicks-queue)  |
                        ^               contador)+----------+-----------+
                        |                                   |
                        |                        (Dispara   | EventSource)
                        |                                   v
             +----------+-----------+            +----------------------+
             |   StatsUrlFunction   |            |AnalyticsWorkerFunction
             |     (AWS Lambda)     |            |     (AWS Lambda)     |
             +----------------------+            +----------+-----------+
                                                            |
                                                            v
                                                 +----------------------+
                                                 |   Amazon DynamoDB    |
                                                 | Tabla: UrlClicksAudit|
                                                 +----------------------+
```

---

## 🚀 Despliegue Rápido

1. Asegúrate de que LocalStack esté encendido:
   ```powershell
   .\scripts\aws-hub.ps1 start
   ```

2. Desplegar toda la infraestructura serverless y el frontend web:
   ```powershell
   cd .\projects\04-url-shortener
   .\deploy.ps1
   ```

3. Abrir la interfaz gráfica en tu navegador:
   👉 **`http://localhost:4566/dev-shortener-web/index.html`**

---

## 🧪 Pruebas Automáticas

Para validar todo el flujo de punta a punta (acortar ➡️ guardar en DynamoDB ➡️ redirigir 302 ➡️ encolar en SQS ➡️ procesar con worker ➡️ verificar analítica):
```powershell
.\test-shortener.ps1
```
