# Use an official lightweight Python runtime
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Copy files
COPY . .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Expose the port Cloud Run expects
EXPOSE 8080

# Set environment variables
ENV PORT=8080
ENV PYTHONUNBUFFERED=1

# Start Gunicorn server with Flask app
CMD exec gunicorn --bind :$PORT --workers 1 --threads 8 main:app
