# --- STAGE 1: Build Open WebUI Frontend ---
# Use an official Node.js image as a temporary builder stage.
FROM node:20 as webui-builder
WORKDIR /app
# Clone the repository and install dependencies
RUN git clone --depth 1 https://github.com/open-webui/open-webui.git .
RUN npm install && npm cache clean --force
# Build the production-ready frontend
RUN npm run build


# --- STAGE 2: Final Production Image ---
# Start from the official NVIDIA CUDA base image for GPU support.
FROM nvidia/cuda:12.4.1-devel-ubuntu22.04

# Set environment variables to avoid interactive prompts and configure applications.
ENV DEBIAN_FRONTEND=noninteractive
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility
ENV OLLAMA_HOST=0.0.0.0
ENV OLLAMA_MODELS=/workspace/ollama-models
ENV PIP_ROOT_USER_ACTION=ignore

# Install all system dependencies in a single layer to save space and clean up caches.
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    supervisor \
    python3.11 \
    python3.11-venv \
    libgomp1 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Download and install the official pre-compiled Ollama binary for reliability.
RUN curl -L https://ollama.com/download/ollama-linux-amd64 -o /usr/bin/ollama && \
    chmod +x /usr/bin/ollama

# Copy the pre-built Open WebUI backend and frontend from the builder stage.
COPY --from=webui-builder /app/backend /app/backend
COPY --from=webui-builder /app/build /app/build

# Install Open WebUI's Python dependencies.
RUN pip install -r /app/backend/requirements.txt -U && \
    rm -rf /root/.cache/pip

# Clone and set up SearXNG.
RUN git clone --depth 1 https://github.com/searxng/searxng.git /usr/local/searxng && \
    cd /usr/local/searxng && \
    python3 -m venv searx-pyenv && \
    ./searx-pyenv/bin/pip install -r requirements.txt && \
    sed -i "s#ultrasecretkey#$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32)#g" searx/settings.yml && \
    sed -i 's/port: 8080/port: 8888/g' searx/settings.yml && \
    rm -rf /root/.cache/pip

# Create necessary directories for logs and data.
RUN mkdir -p /workspace/logs /app/backend/data

# Copy your custom scripts and supervisor config.
COPY supervisord.conf /etc/supervisor/conf.d/all-services.conf
COPY entrypoint.sh /entrypoint.sh
COPY pull_model.sh /pull_model.sh
RUN chmod +x /entrypoint.sh /pull_model.sh

# Expose all necessary ports for the services.
EXPOSE 8080 8888 11434

# Set the entrypoint to start all services.
ENTRYPOINT ["/entrypoint.sh"]
