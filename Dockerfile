### STAGE 1: Build the Open WebUI application ###
# Use the official Open WebUI image as a builder base
FROM ghcr.io/open-webui/open-webui:main as webui-builder

### STAGE 2: Build the final image ###
# Start from your future-proof NVIDIA CUDA base image
FROM nvidia/cuda:12.4.1-base-ubuntu22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV OLLAMA_HOST=0.0.0.0
ENV PATH="/usr/local/searxng/searx-pyenv/bin:$PATH"

# Install ALL necessary build-time and run-time dependencies
RUN apt-get update && apt-get install -y \
    curl \
    supervisor \
    git \
    sed \
    python3-dev \
    python3-venv \
    python-is-python3 \
    build-essential \
    libxslt-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Ollama
RUN curl -L https://ollama.com/download/ollama-linux-amd64 -o /usr/bin/ollama && chmod +x /usr/bin/ollama

# Copy the working Open WebUI files from the builder stage
COPY --from=webui-builder /app/ /app/

# Clone and prepare SearxNG
RUN git clone https://github.com/searxng/searxng.git /usr/local/searxng
WORKDIR /usr/local/searxng

# THIS IS THE CORRECTED COMMAND BLOCK
# It creates the venv, copies the official template, then modifies it.
RUN python -m venv searx-pyenv && \
    . ./searx-pyenv/bin/activate && \
    pip install -r requirements.txt && \
    cp utils/templates/etc/searxng/settings.yml searx/settings.yml && \
    sed -i "s/ultrasecretkey/$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32)/g" searx/settings.yml

# Create necessary directories
RUN mkdir -p /var/log/supervisor /root/.ollama /app/backend/data

# Copy your supervisor and model pull configurations
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY pull_model.sh /usr/local/bin/pull_model.sh
RUN chmod +x /usr/local/bin/pull_model.sh

# Expose the necessary ports
EXPOSE 8080
EXPOSE 11434
EXPOSE 8888

# Set the command to run supervisor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
