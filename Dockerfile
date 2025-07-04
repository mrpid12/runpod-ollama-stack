### STAGE 1: Build the Open WebUI application ###
FROM node:20 as webui-builder
WORKDIR /app
RUN git clone https://github.com/open-webui/open-webui.git .
RUN npm install && npm cache clean --force
RUN npm run build

### STAGE 2: Build Ollama from Source ###
FROM golang:1.24 as ollama-builder
RUN git clone https://github.com/ollama/ollama.git /go/src/github.com/ollama/ollama
WORKDIR /go/src/github.com/ollama/ollama
RUN go generate ./...
RUN CGO_ENABLED=1 go build . && go clean -modcache

### STAGE 3: Build the final image ###
FROM nvidia/cuda:12.4.1-base-ubuntu22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV OLLAMA_HOST=0.0.0.0
ENV PATH="/usr/local/searxng/searx-pyenv/bin:$PATH"
ENV OLLAMA_MODELS=/workspace/ollama-models
ENV PIP_ROOT_USER_ACTION=ignore

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    supervisor \
    git \
    sed \
    python3-dev \
    python3-venv \
    python3-pip \
    python-is-python3 \
    build-essential \
    libxslt-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy the pre-built Ollama binary
COPY --from=ollama-builder /go/src/github.com/ollama/ollama/ollama /usr/bin/ollama

# Copy the pre-built Open WebUI files
COPY --from=webui-builder /app/backend /app/backend
COPY --from=webui-builder /app/build /app/build

# --- THIS IS THE FIX ---
# Create a dummy .git directory inside the backend to satisfy the startup check
RUN mkdir -p /app/backend/.git

# Install WebUI's Python dependencies
# Note: The requirements file is in /app/backend, not /app
RUN pip3 install -r /app/backend/requirements.txt -U && rm -rf /root/.cache/pip

# Clone and prepare SearxNG
RUN git clone https://github.com/searxng/searxng.git /usr/local/searxng
WORKDIR /usr/local/searxng

# Create venv, install packages, and clean pip cache
RUN python -m venv searx-pyenv && \
    . ./searx-pyenv/bin/activate && \
    pip install -r requirements.txt && \
    rm -rf /root/.cache/pip && \
    sed -i "s/ultrasecretkey/$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32)/g" searx/settings.yml

# Create necessary directories
RUN mkdir -p /var/log/supervisor /app/backend/data /workspace/logs

# Copy our custom scripts and configs
COPY entrypoint.sh /entrypoint.sh
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
RUN chmod +x /entrypoint.sh

# Expose the necessary ports
EXPOSE 8080
EXPOSE 11434
EXPOSE 8888

# Set the entrypoint to our script
ENTRYPOINT ["/entrypoint.sh"]
