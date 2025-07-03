# Use an official NVIDIA CUDA image for GPU support
FROM nvidia/cuda:12.1.1-base-ubuntu22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV OLLAMA_HOST=0.0.0.0

# Install dependencies: curl, supervisor, and other essentials
RUN apt-get update && apt-get install -y \
    curl \
    supervisor \
    git \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Install Ollama
RUN curl -fsSL https://ollama.com/install.sh | sh

# Install Open WebUI using the correct backend download method
RUN wget -qO- https://github.com/open-webui/open-webui/releases/latest/download/open-webui_linux_amd64.tar.gz | tar zx -C /
RUN mv /open-webui_linux_amd64 /usr/local/bin/open-webui

# Create necessary directories
RUN mkdir -p /var/log/supervisor /root/.ollama /app/backend/data

# Copy the supervisor config file
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Copy and make the model pull script executable
COPY pull_model.sh /usr/local/bin/pull_model.sh
RUN chmod +x /usr/local/bin/pull_model.sh

# Expose the necessary ports
EXPOSE 8080
EXPOSE 11434

# Set the command to run supervisor, which starts all our services
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
