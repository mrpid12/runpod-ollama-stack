### STAGE 1: Build the Open WebUI application ###
FROM node:20 as webui-builder
WORKDIR /app
# Use a shallow clone for a faster, smaller build stage
RUN git clone --depth 1 https://github.com/open-webui/open-webui.git .
RUN npm install && npm cache clean --force
RUN npm run build

### STAGE 2: Build Ollama from Source ###
FROM golang:1.24 as ollama-builder
WORKDIR /go/src/github.com/ollama/ollama
# Use a shallow clone for a faster, smaller build stage
RUN git clone --depth 1 https://github.com/ollama/ollama.git .
RUN go generate ./...
# Build with CUDA support
RUN CGO_ENABLED=1 go build -tags cuda . \
    && go clean -modcache

### STAGE 3: Build the final image ###
FROM nvidia/cuda:12.4.1-base-ubuntu22.04

# --- START OF FIX ---

# Set environment variables to enable NVIDIA GPU access and other settings
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility
ENV DEBIAN_FRONTEND=noninteractive
ENV OLLAMA_HOST=0.0.0.0
ENV PATH="/usr/local/searxng/searx-pyenv/bin:$PATH"
ENV OLLAMA_MODELS=/workspace/ollama-models
ENV PIP_ROOT_USER_ACTION=ignore

# Install curl and gnupg first, then add the NVIDIA repository and GPG key
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    gnupg \
    && curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
    && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

# --- END OF FIX ---

# Install the NVIDIA toolkit and other required system packages
# The PPA is for installing Python 3.11
RUN apt-get update && apt-get install -y --no-install-recommends \
    nvidia-container-toolkit \
    software-properties-common \
    && add-apt-repository -y ppa:deadsnakes/ppa \
    && apt-get update && apt-get install -y --no-install-recommends \
    supervisor \
    git \
    sed \
    python3.11 \
    python3.11-dev \
    python3.11-venv \
    python3-pip \
    build-essential \
    libxslt-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Set python3.11 as the default python3
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1

# Upgrade pip for the new Python version
RUN python3 -m pip install --upgrade pip

# Copy the pre-built Ollama binary
COPY --from=ollama-builder /go/src/github.com/ollama/ollama/ollama /usr/bin/ollama

# Copy the pre-built Open WebUI files
COPY --from=webui-builder /app/backend /app/backend
COPY --from=webui-builder /app/build /app/build

# Copy the changelog file required by the backend on startup
COPY --from=webui-builder /app/CHANGELOG.md /app/backend/open_webui/CHANGELOG.md

# Install WebUI's Python dependencies, ignoring packages already installed by the OS
RUN python3 -m pip install --ignore-installed -r /app/backend/requirements.txt && rm -rf /root/.cache/pip

# Initialize a valid, empty git repository in the backend directory
RUN git init /app/backend

# Clone and prepare SearxNG
RUN git clone --depth 1 https://github.com/searxng/searxng.git /usr/local/searxng && \
    rm -rf /usr/local/searxng/.git
WORKDIR /usr/local/searxng

# Create venv and install packages using the new Python 3.11
RUN python3 -m venv searx-pyenv && \
    ./searx-pyenv/bin/pip install -r requirements.txt && \
    rm -rf /root/.cache/pip && \
    sed -i "s/ultrasecretkey/$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32)/g" searx/settings.yml && \
    sed -i 's/port: 8080/port: 8888/g' searx/settings.yml

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
