# Start from the pre-built, working image that already contains Ollama and Open WebUI
FROM madiator2011/better-ollama-webui:cuda12.4

# Switch to the root user to install packages
USER root

# Install system dependencies needed for SearXNG and supervisor
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.11 \
    python3.11-venv \
    build-essential \
    git \
    supervisor \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Clone and prepare SearxNG
WORKDIR /usr/local
RUN git clone --depth 1 https://github.com/searxng/searxng.git searxng && \
    cd searxng && \
    python3 -m venv searx-pyenv && \
    ./searx-pyenv/bin/pip install -r requirements.txt && \
    sed -i "s/ultrasecretkey/$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32)/g" searx/settings.yml && \
    sed -i 's/port: 8080/port: 8888/g' searx/settings.yml

# Create necessary directories for logs
RUN mkdir -p /var/log/supervisor /workspace/logs

# Copy your custom scripts and the new supervisor config
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY pull_model.sh /pull_model.sh
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh /pull_model.sh

# Expose the SearXNG port
EXPOSE 8888

# Set the entrypoint to our new script
ENTRYPOINT ["/entrypoint.sh"]
