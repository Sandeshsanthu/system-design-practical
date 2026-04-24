FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
# libpq-dev: for postgres
# libjpeg-dev, zlib1g-dev: for xhtml2pdf (image processing)
# gcc: for compiling C extensions
RUN apt-get update && apt-get install -y \
    libpq-dev \
    gcc \
    pkg-config \
    python3-dev \
    libcairo2-dev \
    libpango1.0-dev \
    libjpeg-dev \
    zlib1g-dev \
    libgif-dev \
    && rm -rf /var/lib/apt/lists/*
RUN pip install --no-cache-dir --upgrade pip setuptools wheel
# Upgrade pip to avoid metadata errors
RUN pip install --upgrade pip

COPY requirment.txt .

# Install dependencies
RUN pip install --no-cache-dir -r requirment.txt

COPY . .

EXPOSE 8080

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
