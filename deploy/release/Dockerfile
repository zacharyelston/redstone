# Redstone Release.com Tools Container
# Following the "Built for Clarity" design philosophy
# Portable environment for Release.com API client and management scripts

FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Create requirements file for Python dependencies
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy Release.com API client and configuration
COPY api/ ./api/
COPY environments/ ./environments/

# Create scripts directory (scripts will be mounted at runtime)
RUN mkdir -p ./scripts

# Create non-root user for security
RUN useradd -m -u 1000 releaseuser && \
    chown -R releaseuser:releaseuser /app
USER releaseuser

# Set environment variables
ENV PYTHONPATH=/app
ENV PATH="/app/scripts:${PATH}"

# Default command
CMD ["python", "api/client.py", "--help"]
