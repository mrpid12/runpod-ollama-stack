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
    && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Ollama
RUN curl -fsSL https://ollama.com/install.sh | sh

# Copy Open WebUI
COPY --from=webui-builder /app/backend /app/backend
COPY --from=webui-builder /app/build /app/build
COPY --from=webui-builder /app/CHANGELOG.md /app/CHANGELOG.md

# Install Open WebUI Python dependencies
RUN curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py && \
    python3 get-pip.py && \
    python3 -m pip install -r /app/backend/requirements.txt -U && \
    rm -rf /root/.cache/pip

# --- FIX: Install uvicorn alongside gunicorn for the async worker ---
# Install and set up SearXNG with gunicorn and uvicorn worker
RUN git clone --depth 1 https://github.com/searxng/searxng.git /usr/local/searxng && \
    cd /usr/local/searxng && \
    python3 -m venv searx-pyenv && \
    ./searx-pyenv/bin/pip install -r requirements.txt gunicorn uvicorn && \
    sed -i "s#ultrasecretkey#$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32)#g" searx/settings.yml && \
    sed -i 's/port: 8080/port: 8888/g' searx/settings.yml && \
    sed -i "/port: 8888/a \ \ use_proxy: true" searx/settings.yml && \
    rm -rf /root/.cache/pip

# Copy custom scripts and supervisord config
COPY supervisord.conf /etc/supervisor/conf.d/all-services.conf
COPY entrypoint.sh /entrypoint.sh
COPY pull_model.sh /pull_model.sh
RUN chmod +x /entrypoint.sh /pull_model.sh

# Set the entrypoint to start all services
ENTRYPOINT ["/entrypoint.sh"]
