### STAGE 1: Build the Open WebUI application ###
FROM ghcr.io/open-webui/open-webui:main as webui-builder

### STAGE 2: Build Ollama from Source ###
FROM golang:1.24 as ollama-builder
RUN git clone https://github.com/ollama/ollama.git /go/src/github.com/ollama/ollama
WORKDIR /go/src/github.com/ollama/ollama
RUN go generate ./...
RUN CGO_ENABLED=1 go build .

### STAGE 3: Build the final image ###
FROM nvidia/cuda:12.4.1-base-ubuntu22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV OLLAMA_HOST=0.0.0.0
ENV PATH="/usr/local/searxng/searx-pyenv/bin:$PATH"
ENV OLLAMA_MODELS=/workspace/ollama-models

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    supervisor \
    git \
    sed \
    python3-dev \
    python3-venv \
    python-is-python3 \
    build-essential \
    libxslt-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy the pre-built Ollama binary
COPY --from=ollama-builder /go/src/github.com/ollama/ollama/ollama /usr/bin/ollama

# Copy the working Open WebUI files from the builder stage
COPY --from=webui-builder /app/ /app/

# --- DEFINITIVE FIX: Bootstrap pip directly ---
RUN curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
RUN python get-pip.py
RUN python -m pip install -r /app/requirements.txt

# Clone and prepare SearxNG
RUN git clone https://github.com/searxng/searxng.git /usr/local/searxng
WORKDIR /usr/local/searxng

# Create venv and install packages
RUN python -m venv searx-pyenv && \
    . ./searx-pyenv/bin/activate && \
    pip install -r requirements.txt && \
    sed -i "s/ultrasecretkey/$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32)/g" searx/settings.yml

# Create necessary directories
RUN mkdir -p /var/log/supervisor /app/backend/data

# Copy the entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose the necessary ports
EXPOSE 8080
EXPOSE 11434
EXPOSE 8888

# Set the entrypoint to our script
ENTRYPOINT ["/entrypoint.sh"]
