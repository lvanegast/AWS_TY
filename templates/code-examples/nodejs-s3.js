/**
 * Ejemplo de conexión a S3 en LocalStack usando AWS SDK v3 para Node.js
 * Dependencias: npm install @aws-sdk/client-s3
 */
const { S3Client, ListBucketsCommand } = require("@aws-sdk/client-s3");

const endpoint = process.env.AWS_ENDPOINT_URL || "http://localhost:4566";
const region = process.env.AWS_DEFAULT_REGION || "us-east-1";

const s3 = new S3Client({
  endpoint: endpoint,
  region: region,
  credentials: {
    accessKeyId: process.env.AWS_ACCESS_KEY_ID || "test",
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY || "test",
  },
  forcePathStyle: true, // Requerido para S3 en LocalStack
});

async function main() {
  console.log(`🔌 Conectando a LocalStack S3 en: ${endpoint}`);
  const command = new ListBucketsCommand({});
  const response = await s3.send(command);
  console.log("📦 Buckets disponibles:", response.Buckets.map(b => b.Name));
}

main().catch(console.error);
