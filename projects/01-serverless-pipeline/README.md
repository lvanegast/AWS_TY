# Proyecto 1: Pipeline Serverless (S3 + Lambda + DynamoDB)

Este proyecto demuestra el cómputo serverless con LocalStack:
1. **S3**: Almacén de archivos de entrada (`raw-documents-bucket`).
2. **Lambda**: Función en Python 3.10 ejecutada en contenedor Docker administrado por LocalStack.
3. **DynamoDB**: Base de datos NoSQL donde se guardan metadatos y estado de los archivos.

## Cómo ejecutarlo:
1. Desplegar los recursos:
   ```powershell
   .\deploy.ps1
   ```
2. Ejecutar la prueba de procesamiento y verificación:
   ```powershell
   .\test-pipeline.ps1
   ```
