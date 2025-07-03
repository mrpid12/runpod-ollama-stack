### STAGE 1: Build the Open WebUI application ###
# Use the official Open WebUI image as a builder base
FROM ghcr.io/open-webui/open-webui:main as webui-builder

### STAGE 2: Build the final image ###
# Start from your future-proof NVIDIA CUDA base image
FROM nvidia/cuda:12.4.1-base-ubuntu22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV OLLAMA_HOST=0.0.0.0

# Install ALL dependencies for Ollama, Supervisor, AND SearxNG (from official docs)
RUN apt-get update && apt-get install -y \
    curl \
    supervisor \
    git \
    sed \
    python3-dev \
    python3-venv \
    python3-babel \
    python-is-python3 \
    build-essential \
    libxslt-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Ollama
RUN curl -L https://ollama.com/download/ollama-linux-amd64 -o /usr/bin/ollama && chmod +x /usr/bin/ollama

# Copy the working Open WebUI files from the builder stage
COPY --from=webui-builder /app/ /app/

# Clone and prepare SearxNG using the official commands
RUN git clone https://github.com/searxng/searxng.git /usr/local/searxng
WORKDIR /usr/local/searxng

# THIS IS THE CORRECTED COMMAND BLOCK BASED ON THE OFFICIAL DOCS
RUN sed -i "s/ultrasecretkey/$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32)/g" searx/settings.yml && \
    ./utils/searxng.sh install packages

# Create necessary directories
RUN mkdir -p /var/log/supervisor /root/.ollama /app/backend/data

# Copy your supervisor and model pull configurations
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY pull_model.sh /usr/local/bin/pull_model.sh
RUN chmod +x /usr/local/bin/pull_model.sh

# Expose the necessary ports (add 8888 for SearxNG)
EXPOSE 8080
EXPOSE 11434
EXPOSE 8888

# Set the command to run supervisor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
