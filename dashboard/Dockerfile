FROM python:3.10-slim

WORKDIR /app

RUN pip install --no-cache-dir boto3

COPY server.py .
COPY static/ static/

EXPOSE 3000

CMD ["python", "server.py"]
