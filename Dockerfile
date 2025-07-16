# --- STAGE 1: Build Open WebUI Frontend ---
FROM node:20 as webui-builder
WORKDIR /app
RUN git clone --depth 1 https://github.com/open-webui/open-webui.git .
RUN npm install && npm cache clean --force
RUN NODE_OPTIONS="--max-old-space-size=6144" npm run build

# --- STAGE 2: Final Production Image ---
FROM nvidia/cuda:12.4.1-devel-ubuntu22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility
ENV OLLAMA_MODELS=/workspace/models
ENV PIP_ROOT_USER_ACTION=ignore

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    supervisor \
    python3.11 \
    python3.11-venv \
    python3-venv \
    libgomp1 \
    build-essential \
    python3.11-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Ollama
RUN curl -fsSL https://ollama.com/install.sh | sh

# Copy Open WebUI from the build stage
COPY --from=webui-builder /app/backend /app/backend
COPY --from=webui-builder /app/build /app/build
COPY --from=webui-builder /app/CHANGELOG.md /app/CHANGELOG.md

# Install Open WebUI Python dependencies
RUN curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py && \
    python3 get-pip.py && \
    python3 -m pip install -r /app/backend/requirements.txt -U && \
    rm -rf /root/.cache/pip

# --- FIX: Pin SearXNG to a specific, known-good commit hash ---
RUN git clone https://github.com/searxng/searxng.git /usr/local/searxng && \
    cd /usr/local/searxng && \
    git checkout 2d0831033320332375892523277989393a525f9b && \
    python3 -m venv searx-pyenv && \
    ./searx-pyenv/bin/pip install -r requirements.txt uwsgi && \
    mkdir -p /etc/searxng

# Copy config files and custom scripts
COPY custom_settings.yml /usr/local/searxng/searx/settings.yml
COPY uwsgi.ini /etc/searxng/uwsgi.ini
COPY supervisord.conf /etc/supervisor/conf.d/all-services.conf
COPY entrypoint.sh /entrypoint.sh
COPY pull_model.sh /pull_model.sh
RUN chmod +x /entrypoint.sh /pull_model.sh

# Expose the ports for clarity
EXPOSE 8888 8080

# Set the entrypoint to start all services
ENTRYPOINT ["/entrypoint.sh"]
