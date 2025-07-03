# Use an official NVIDIA CUDA image for GPU support
FROM nvidia/cuda:12.1.1-base-ubuntu22.04

# Set environment variables to avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV OLLAMA_HOST=0.0.0.0

# Install dependencies: curl, supervisor, git, wget, and pip
RUN apt-get update && apt-get install -y \
    curl \
    supervisor \
    git \
    wget \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Install Ollama
RUN curl -L https://ollama.com/download/ollama-linux-amd64 -o /usr/bin/ollama && chmod +x /usr/bin/ollama

# Install Open WebUI using 'uv' in a single layer
# This ensures the correct path is used for the install command
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    /root/.local/bin/uv pip install open-webui

# Create necessary directories for logs and data
RUN mkdir -p /var/log/supervisor /root/.ollama /app/backend/data

# Copy your supervisor and model pull configurations
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY pull_model.sh /usr/local/bin/pull_model.sh
RUN chmod +x /usr/local/bin/pull_model.sh

# Expose the necessary ports
EXPOSE 8080
EXPOSE 11434

# Set the command to run supervisor, which starts all our services
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
