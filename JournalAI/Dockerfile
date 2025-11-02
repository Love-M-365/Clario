# Use official Python runtime
FROM python:3.11-slim

# Working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code
COPY . .

# Expose port
ENV PORT=8080
CMD ["gunicorn", "-b", "0.0.0.0:8080", "main:app"]
