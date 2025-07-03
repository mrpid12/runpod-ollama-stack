### STAGE 1: Build the Open WebUI application ###
FROM ghcr.io/open-webui/open-webui:main as webui-builder

### STAGE 2: Build the final image ###
FROM nvidia/cuda:12.4.1-base-ubuntu22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV OLLAMA_HOST=0.0.0.0

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    supervisor \
    git \
    sed \
    && rm -rf /var/lib/apt/lists/*

# Clone SearxNG
RUN git clone https://github.com/searxng/searxng.git /usr/local/searxng
WORKDIR /usr/local/searxng

# --- DIAGNOSTIC COMMAND ---
# List all files and directories recursively to find the correct path
RUN ls -laR

# The rest of the Dockerfile is commented out for this diagnostic run
#
# # Install Ollama
# RUN curl -L https://ollama.com/download/ollama-linux-amd64 -o /usr/bin/ollama && chmod +x /usr/bin/ollama
#
# # Copy the working Open WebUI files from the builder stage
# COPY --from=webui-builder /app/ /app/
#
# # THIS IS THE COMMAND BLOCK THAT FAILED
# # RUN cp searxng/settings.yml.example searxng/settings.yml && \
# #     sed -i "s/ultrasecretkey/$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32)/g" searxng/settings.yml && \
# #     ./utils/searxng.sh update_packages
#
# # Create necessary directories
# RUN mkdir -p /var/log/supervisor /root/.ollama /app/backend/data
#
# # Copy your supervisor and model pull configurations
# COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
# COPY pull_model.sh /usr/local/bin/pull_model.sh
# RUN chmod +x /usr/local/bin/pull_model.sh
#
# # Expose the necessary ports (add 8888 for SearxNG)
# EXPOSE 8080
# EXPOSE 11434
# EXPOSE 8888
#
# # Set the command to run supervisor
# CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
