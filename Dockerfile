# Use a single stage to avoid disk space issues on GitHub Actions runners
FROM nvidia/cuda:12.4.1-base-ubuntu22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV OLLAMA_HOST=0.0.0.0
ENV PATH="/usr/local/searxng/searx-pyenv/bin:$PATH"
ENV OLLAMA_MODELS=/workspace/ollama-models
ENV PIP_ROOT_USER_ACTION=ignore

# Install all system dependencies, including Python 3.11 and extra tools
RUN apt-get update && apt-get install -y --no-install-recommends software-properties-common && \
    add-apt-repository -y ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        # Basic tools
        curl \
        supervisor \
        git \
        sed \
        # User-requested tools
        nano \
        wget \
        # Python build dependencies
        build-essential \
        python3.11 \
        python3.11-dev \
        python3.11-venv \
        python3-pip \
        libxslt-dev \
        zlib1g-dev \
        # Node and Go for building from source
        nodejs \
        npm \
        golang \
    && rm -rf /var/lib/apt/lists/*

# Set python3.11 as the default
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 && \
    python3 -m pip install --upgrade pip

# --- Build and Install All Services ---

# 1. OpenWebUI
WORKDIR /app
RUN git clone --depth 1 https://github.com/open-webui/open-webui.git . && \
    npm install && npm cache clean --force && \
    npm run build && \
    # Install Python dependencies, ignoring system conflicts
    python3 -m pip install --ignore-installed -r /app/backend/requirements.txt && \
    # Fix: Create dummy git repo and copy changelog
    git init /app/backend && \
    cp /app/CHANGELOG.md /app/backend/open_webui/CHANGELOG.md

# 2. Ollama
WORKDIR /tmp
RUN git clone --depth 1 https://github.com/ollama/ollama.git . && \
    # Fix: Build with GPU support
    go generate ./... && \
    CGO_ENABLED=1 go build -tags cuda -o /usr/bin/ollama . && \
    go clean -modcache && \
    rm -rf /tmp/*

# 3. SearxNG
WORKDIR /
RUN git clone --depth 1 https://github.com/searxng/searxng.git /usr/local/searxng && \
    cd /usr/local/searxng && \
    python3 -m venv searx-pyenv && \
    ./searx-pyenv/bin/pip install -r requirements.txt && \
    # Fix: Port conflict
    sed -i "s/ultrasecretkey/$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32)/g" searx/settings.yml && \
    sed -i 's/port: 8080/port: 8888/g' searx/settings.yml

# --- Final Configuration ---

# Create necessary directories
RUN mkdir -p /var/log/supervisor /app/backend/data /workspace/logs

# Copy our custom scripts and configs
COPY entrypoint.sh /entrypoint.sh
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY pull_model.sh /pull_model.sh
RUN chmod +x /entrypoint.sh /pull_model.sh

# Expose the necessary ports
EXPOSE 8080
EXPOSE 11434
EXPOSE 8888

# Set the entrypoint to our script
ENTRYPOINT ["/entrypoint.sh"]
