### STAGE 1: Build the Open WebUI application ###
FROM ghcr.io/open-webui/open-webui:main as webui-builder

### STAGE 2: Build the final image ###
FROM nvidia/cuda:12.4.1-base-ubuntu22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV OLLAMA_HOST=0.0.0.0
ENV PATH="/usr/local/searxng/searx-pyenv/bin:$PATH"

# Install dependencies
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

# Create venv, install packages, copy and modify settings
RUN python -m venv searx-pyenv && \
    . ./searx-pyenv/bin/activate && \
    pip install -r requirements.txt && \
    cp searx/settings.yml.example searx/settings.yml && \
    sed -i "s/ultrasecretkey/$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32)/g" searx/settings.yml

# Create necessary directories
RUN mkdir -p /var/log/supervisor /root/.ollama /app/backend/data

# --- NEW: Copy the entrypoint script ---
# We no longer copy supervisord.conf or pull_model.sh here
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose the necessary ports
EXPOSE 8080
EXPOSE 11434
EXPOSE 8888

# --- NEW: Set the entrypoint to our script ---
ENTRYPOINT ["/entrypoint.sh"]
