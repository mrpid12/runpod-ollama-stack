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
RUN curl -L https://ollama.com/download/ollama-linux-amd64 -o /usr/bin/ollama && chmod +x /usr/bin/ollama

# Install Open WebUI using the current official installer script
RUN curl -sSL https://raw.githubusercontent.com/open-webui/open-webui/main/install.sh | sh

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
