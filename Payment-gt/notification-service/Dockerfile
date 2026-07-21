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

ENV PORT=8008
EXPOSE 8008
CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port ${PORT:-8008} --log-level info"]