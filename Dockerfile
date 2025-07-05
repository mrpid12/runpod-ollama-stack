### STAGE 1: Build the Open WebUI application ###
FROM node:20 as webui-builder
WORKDIR /app
[span_0](start_span)RUN git clone --depth 1 https://github.com/open-webui/open-webui.git .[span_0](end_span)
[span_1](start_span)RUN npm install && npm cache clean --force[span_1](end_span)
[span_2](start_span)RUN npm run build[span_2](end_span)

### STAGE 2: Final Image using CUDA Developer Environment ###
[span_3](start_span)FROM nvidia/cuda:12.4.1-devel-ubuntu22.04[span_3](end_span)

# Set environment variables
[span_4](start_span)ENV NVIDIA_VISIBLE_DEVICES=all[span_4](end_span)
[span_5](start_span)ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility[span_5](end_span)
[span_6](start_span)ENV DEBIAN_FRONTEND=noninteractive[span_6](end_span)
[span_7](start_span)ENV OLLAMA_HOST=0.0.0.0[span_7](end_span)
[span_8](start_span)ENV PATH="/usr/local/searxng/searx-pyenv/bin:$PATH"[span_8](end_span)
[span_9](start_span)ENV OLLAMA_MODELS=/workspace/ollama-models[span_9](end_span)
[span_10](start_span)ENV PIP_ROOT_USER_ACTION=ignore[span_10](end_span)

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
    [span_11](start_span)&& rm -rf /var/lib/apt/lists/*[span_11](end_span)

# Build Ollama from source and clean up in the same layer
WORKDIR /
[span_12](start_span)RUN git clone --depth 1 https://github.com/ollama/ollama.git /ollama-src[span_12](end_span)
WORKDIR /ollama-src
RUN CGO_ENABLED=1 /usr/lib/go-1.24/bin/go build -tags cuda -o /usr/bin/ollama . \
    && /usr/lib/go-1.24/bin/go clean -modcache \
    [span_13](start_span)&& rm -rf /ollama-src[span_13](end_span)

# Set python3.11 as the default
[span_14](start_span)RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1[span_14](end_span)
[span_15](start_span)RUN python3 -m pip install --upgrade pip[span_15](end_span)

# Copy the pre-built Open WebUI files
[span_16](start_span)COPY --from=webui-builder /app/backend /app/backend[span_16](end_span)
[span_17](start_span)COPY --from=webui-builder /app/build /app/build[span_17](end_span)
[span_18](start_span)COPY --from=webui-builder /app/CHANGELOG.md /app/backend/open_webui/CHANGELOG.md[span_18](end_span)

# --- TEMPORARILY COMMENTED OUT FOR PARTIAL BUILD ---
# Install WebUI's Python dependencies without using the cache to save space
# RUN python3 -m pip install --no-cache-dir --ignore-installed -r /app/backend/requirements.txt

# Initialize a git repository for WebUI
[span_19](start_span)RUN git init /app/backend[span_19](end_span)

# Clone and prepare SearxNG and clean up in the same layer
WORKDIR /usr/local
RUN git clone --depth 1 https://github.com/searxng/searxng.git searxng && \
    cd searxng && \
    python3 -m venv searx-pyenv && \
    ./searx-pyenv/bin/pip install -r requirements.txt && \
    sed -i "s/ultrasecretkey/$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32)/g" searx/settings.yml && \
    sed -i 's/port: 8080/port: 8888/g' searx/settings.yml && \
    [span_20](start_span)rm -rf /root/.cache/pip[span_20](end_span)

# Create necessary directories
[span_21](start_span)RUN mkdir -p /var/log/supervisor /app/backend/data /workspace/logs[span_21](end_span)

# Copy custom scripts and configs
[span_22](start_span)COPY entrypoint.sh /entrypoint.sh[span_22](end_span)
[span_23](start_span)COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf[span_23](end_span)
[span_24](start_span)COPY pull_model.sh /pull_model.sh[span_24](end_span)
[span_25](start_span)RUN chmod +x /entrypoint.sh /pull_model.sh[span_25](end_span)

# Expose ports
[span_26](start_span)EXPOSE 8080[span_26](end_span)
[span_27](start_span)EXPOSE 11434[span_27](end_span)
[span_28](start_span)EXPOSE 8888[span_28](end_span)

# Set the entrypoint
WORKDIR /
[span_29](start_span)ENTRYPOINT ["/entrypoint.sh"][span_29](end_span)
