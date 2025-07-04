### STAGE 1: Build the Open WebUI application ###
FROM node:20 as webui-builder
WORKDIR /app
RUN git clone --depth 1 https://github.com/open-webui/open-webui.git .
RUN npm install && npm cache clean --force
RUN npm run build

### STAGE 2: Final Image using CUDA Developer Environment ###
FROM nvidia/cuda:12.4.1-devel-ubuntu22.04

# Set environment variables
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility
ENV DEBIAN_FRONTEND=noninteractive
ENV OLLAMA_HOST=0.0.0.0
ENV PATH="/usr/local/searxng/searx-pyenv/bin:$PATH"
ENV OLLAMA_MODELS=/workspace/ollama-models
ENV PIP_ROOT_USER_ACTION=ignore

# Install all system dependencies, including Go and Python, and clean up in the same layer
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    python3.11 \
    python3.11-dev \
    python3.11-venv \
    python3-pip \
    build-essential \
    libxslt-dev \
    zlib1g-dev \
    curl \
    supervisor \
    git \
    sed \
    && add-apt-repository -y ppa:longsleep/golang-backports \
    && apt-get update \
    && apt-get install -y --no-install-recommends golang-1.24 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Build Ollama from source and clean up in the same layer
WORKDIR /
RUN git clone --depth 1 https://github.com/ollama/ollama.git /ollama-src
WORKDIR /ollama-src
RUN CGO_ENABLED=1 /usr/lib/go-1.24/bin/go build -tags cuda -o /usr/bin/ollama . \
    && go clean -modcache \
    && rm -rf /ollama-src

# Set python3.11 as the default
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1
RUN python3 -m pip install --upgrade pip

# Copy the pre-built Open WebUI files
COPY --from=webui-builder /app/backend /app/backend
COPY --from=webui-builder /app/build /app/build
COPY --from=webui-builder /app/CHANGELOG.md /app/backend/open_webui/CHANGELOG.md

# Install WebUI's Python dependencies and clean up in the same layer
RUN python3 -m pip install --ignore-installed -r /app/backend/requirements.txt \
    && rm -rf /root/.cache/pip

# Initialize a git repository for WebUI
RUN git init /app/backend

# Clone and prepare SearxNG and clean up in the same layer
WORKDIR /usr/local
RUN git clone --depth 1 https://github.com/searxng/searxng.git searxng && \
    cd searxng && \
    python3 -m venv searx-pyenv && \
    ./searx-pyenv/bin/pip install -r requirements.txt && \
    sed -i "s/ultrasecretkey/$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32)/g" searx/settings.yml && \
    sed -i 's/port: 8080/port: 8888/g' searx/settings.yml && \
    rm -rf /root/.cache/pip

# Create necessary directories
RUN mkdir -p /var/log/supervisor /app/backend/data /workspace/logs

# Copy custom scripts and configs
COPY entrypoint.sh /entrypoint.sh
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY pull_model.sh /pull_model.sh
RUN chmod +x /entrypoint.sh /pull_model.sh

# Expose ports
EXPOSE 8080
EXPOSE 11434
EXPOSE 8888

# Set the entrypoint
WORKDIR /
ENTRYPOINT ["/entrypoint.sh"]
