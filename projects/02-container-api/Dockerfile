FROM python:3.10-slim

WORKDIR /app

# Instalar boto3
RUN pip install --no-cache-dir boto3

COPY app.py .

EXPOSE 8080

CMD ["python", "app.py"]
