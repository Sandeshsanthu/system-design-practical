FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc libpq-dev curl && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py       .
COPY config.py     .
COPY database.py   .
COPY dispatcher.py .
COPY endpoints.py  .
COPY models.py     .
COPY schemas.py    .
COPY channels/     channels/
COPY templates/    templates/

EXPOSE 8007

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8007/health')" || exit 1

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8007", "--log-level", "info"]
