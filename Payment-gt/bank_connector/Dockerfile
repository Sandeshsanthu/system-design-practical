# filename: bank_connector/Dockerfile

FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y \
    gcc \
    libpq-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ✅ Copy into a named subdirectory so the package resolves correctly
COPY . /app/bank_connector/

RUN mkdir -p /app/logs

ENV PYTHONPATH=/app
ENV PORT=8005

EXPOSE 8005

# ✅ Update entrypoint to match the new package path
CMD ["uvicorn", "bank_connector.app.main:app", "--host", "0.0.0.0", "--port", "8005"]
