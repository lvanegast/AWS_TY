# Proyecto 3: Patrón Pub/Sub Fan-Out (SNS ➡️ Múltiples SQS)

Este proyecto demuestra el desacoplamiento asíncrono de microservicios:
1. **SNS (Simple Notification Service)**: Expone un tópico central (`orders-fanout-topic`).
2. **SQS (Simple Queue Service)**: Dos colas independientes (`orders-billing-queue` y `orders-shipping-queue`) suscritas al mismo tópico.
3. Al publicar un evento de compra, LocalStack distribuye automáticamente una copia del mensaje a cada cola.

## Cómo ejecutarlo:
1. Configurar la topología:
   ```powershell
   .\setup-pubsub.ps1
   ```
2. Publicar una orden de compra:
   ```powershell
   .\publish-order.ps1
   ```
3. Verificar la recepción simultánea en ambas colas:
   ```powershell
   .\verify-queues.ps1
   ```
