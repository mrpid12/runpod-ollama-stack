### STAGE 1: Build the Open WebUI application ###
# Use the official Open WebUI image as a builder base
FROM ghcr.io/open-webui/open-webui:main as webui-builder
# We don't need to do anything here; this stage just holds the working files.

### STAGE 2: Build the final image ###
# Start from a newer NVIDIA CUDA base image for future GPU support
FROM nvidia/cuda:12.4.1-base-ubuntu22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV OLLAMA_HOST=0.0.0.0

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# Install Ollama
RUN curl -L https://ollama.com/download/ollama-linux-amd64 -o /usr/bin/ollama && chmod +x /usr/bin/ollama

# Copy the working Open WebUI files from the builder stage
COPY --from=webui-builder /app/ /app/

# Create necessary directories
RUN mkdir -p /var/log/supervisor /root/.ollama /app/backend/data

# Copy your supervisor and model pull configurations
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY pull_model.sh /usr/local/bin/pull_model.sh
RUN chmod +x /usr/local/bin/pull_model.sh

# Expose the necessary ports
EXPOSE 8080
EXPOSE 11434

# Set the command to run supervisor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
