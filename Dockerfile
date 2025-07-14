# --- STAGE 1: Build Open WebUI Frontend ---
# Use an official Node.js image as a temporary builder stage.
FROM node:20 as webui-builder
WORKDIR /app
# Clone the repository and install dependencies
RUN git clone --depth 1 https://github.com/open-webui/open-webui.git .
RUN npm install && npm cache clean --force
# Increase the memory available to the Node.js build process.
RUN NODE_OPTIONS="--max-old-space-size=6144" npm run build


# --- STAGE 2: Final Production Image ---
# Start from the official NVIDIA CUDA base image for GPU support.
FROM nvidia/cuda:12.4.1-devel-ubuntu22.04

# Set environment variables to avoid interactive prompts and configure applications.
ENV DEBIAN_FRONTEND=noninteractive
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility
# --- NEW FIX ---
# Point Ollama to a dedicated, unambiguous path inside the container.
# This avoids potential issues where Ollama tries to guess subdirectories.
ENV OLLAMA_MODELS=/ollama_home
ENV PIP_ROOT_USER_ACTION=ignore

# Install all system dependencies, including the generic python3-venv package,
# and then explicitly set python3.11 as the default.
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

# Download and install Ollama using the official installation script for reliability.
RUN curl -fsSL https://ollama.com/install.sh | sh

# Copy the pre-built Open WebUI backend and frontend from the builder stage.
COPY --from=webui-builder /app/backend /app/backend
COPY --from=webui-builder /app/build /app/build
# Copy the CHANGELOG.md file required by the backend to start.
COPY --from=webui-builder /app/CHANGELOG.md /app/CHANGELOG.md

# Ensure pip is available and then install Open WebUI's Python dependencies.
RUN curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py && \
    python3 get-pip.py && \
    python3 -m pip install -r /app/backend/requirements.txt -U && \
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

# --- NEW FIX ---
# Create the dedicated home for Ollama and create symbolic links
# from it to your actual model data on the network volume (/workspace).
# This ensures Ollama finds the manifests and models directories exactly where it expects them.
RUN mkdir -p /ollama_home && \
    ln -s /workspace/manifests /ollama_home/manifests && \
    ln -s /workspace/models /ollama_home/models

# Copy your custom scripts and supervisor config.
COPY supervisord.conf /etc/supervisor/conf.d/all-services.conf
COPY entrypoint.sh /entrypoint.sh
COPY pull_model.sh /pull_model.sh
RUN chmod +x /entrypoint.sh /pull_model.sh

# Expose all necessary ports for the services.
EXPOSE 8080 8888 11434

# Set the entrypoint to start all services.
ENTRYPOINT ["/entrypoint.sh"]
