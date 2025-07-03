# Use an official NVIDIA CUDA image for GPU support
FROM nvidia/cuda:12.1.1-base-ubuntu22.04

# Avoid interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies: curl, supervisor, and python
RUN apt-get update && apt-get install -y \
    curl \
    supervisor \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Install Ollama
RUN curl -fsSL https://ollama.com/install.sh | sh

# Install Open WebUI
RUN pip3 install open-webui

# Create necessary directories
RUN mkdir -p /var/log/supervisor /root/.ollama

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
