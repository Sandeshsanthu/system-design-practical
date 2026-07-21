# filename: ledger_service/Dockerfile

FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y \
    gcc \
    libpq-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ✅ Copy into named subdirectory so ledger_service package is discoverable
COPY . /app/ledger_service/

RUN mkdir -p /app/logs

ENV PYTHONPATH=/app
ENV PORT=8007

EXPOSE 8007
CMD ["sh", "-c", "uvicorn ledger_service.app.main:app --host 0.0.0.0 --port ${PORT:-8007}"]
