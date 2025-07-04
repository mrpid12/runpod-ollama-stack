### STAGE 1: Build the Open WebUI application ###
FROM node:20 as webui-builder
WORKDIR /app
RUN git clone --depth 1 https://github.com/open-webui/open-webui.git .
RUN npm install && npm cache clean --force
RUN npm run build

### STAGE 2: Build Python Dependencies ###
FROM python:3.11-slim as python-builder
ENV PIP_ROOT_USER_ACTION=ignore
# Install build tools needed for Python packages
RUN apt-get update && apt-get install -y --no-install-recommends git build-essential libxslt-dev zlib1g-dev && rm -rf /var/lib/apt/lists/*
# Copy WebUI requirements and install them
COPY --from=webui-builder /app/backend/requirements.txt /tmp/webui_requirements.txt
RUN pip install --no-cache-dir --ignore-installed -r /tmp/webui_requirements.txt
# Clone SearxNG and build its virtual environment
RUN git clone --depth 1 https://github.com/searxng/searxng.git /usr/local/searxng
WORKDIR /usr/local/searxng
RUN python3 -m venv searx-pyenv && \
    ./searx-pyenv/bin/pip install --no-cache-dir -r requirements.txt && \
    rm -rf /usr/local/searxng/.git

### STAGE 3: The Final, Lean Image ###
FROM nvidia/cuda:12.4.1-base-ubuntu22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV OLLAMA_HOST=0.0.0.0
ENV PATH="/usr/local/searxng/searx-pyenv/bin:$PATH"
ENV OLLAMA_MODELS=/workspace/ollama-models

# Install only the RUNTIME dependencies.
RUN apt-get update && apt-get install -y --no-install-recommends software-properties-common && \
    add-apt-repository -y ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        curl supervisor git sed python3.11 python3.11-venv nano wget && \
    rm -rf /var/lib/apt/lists/*
# Set python3.11 as the default python3
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1

# Copy the pre-built, GPU-enabled Ollama binary from the official image
# This provides GPU support and solves the "No space left" build error.
COPY --from=ollama/ollama:latest /bin/ollama /usr/bin/ollama

# Copy other pre-built assets
COPY --from=webui-builder /app/backend /app/backend
COPY --from=webui-builder /app/build /app/build
COPY --from=webui-builder /app/CHANGELOG.md /app/backend/open_webui/CHANGELOG.md

# Copy pre-compiled Python dependencies from the builder stage
COPY --from=python-builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=python-builder /usr/local/searxng /usr/local/searxng

# Initialize a valid, empty git repository in the backend directory.
RUN git init /app/backend

# Configure SearxNG's settings file now that it's copied over
WORKDIR /usr/local/searxng
RUN sed -i "s/ultrasecretkey/$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32)/g" searx/settings.yml && \
    # Fix the port conflict
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
