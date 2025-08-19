# Orryx Helm Chart Container
# Release.com requires a Dockerfile in the Helm directory for service detection

FROM alpine/helm:3.12.0

# Set working directory
WORKDIR /app

# Copy Helm chart files
COPY . /app/

# Install dependencies
RUN helm dependency update

# Default command
CMD ["helm", "template", "orryx", "."]
