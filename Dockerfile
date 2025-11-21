# Agent Memz Application Dockerfile
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY src/ ./src/
COPY tests/ ./tests/

# Create directory for secrets
RUN mkdir -p /run/secrets

# Set Python to run unbuffered
ENV PYTHONUNBUFFERED=1

# Default command (can be overridden)
CMD ["python", "-u", "src/memory_service.py"]
