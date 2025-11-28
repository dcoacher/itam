# Python 3.11 Slim Image usage
FROM python:3.11-slim

# Set working directory for the application
WORKDIR /app

# Install dependencies directly
RUN pip install --no-cache-dir flask==3.0.0 pytest==8.2.1 gunicorn==21.2.0

# Copy application files
COPY app/ .

# Use port 31415 for the application
EXPOSE 31415

# Run the Flask application with Gunicorn (production WSGI server)
CMD ["gunicorn", "--bind", "0.0.0.0:31415", "--workers", "4", "--threads", "2", "--timeout", "120", "--keep-alive", "5", "app:app"]



