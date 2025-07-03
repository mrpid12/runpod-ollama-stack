### STAGE 1: Build Ollama from Source ###
FROM golang:1.24 as ollama-builder
RUN git clone https://github.com/ollama/ollama.git /go/src/github.com/ollama/ollama
WORKDIR /go/src/github.com/ollama/ollama
RUN go generate ./...
RUN CGO_ENABLED=1 go build .

### STAGE 2: The final image with GPU support ###
FROM nvidia/cuda:12.4.1-base-ubuntu22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV OLLAMA_HOST=0.0.0.0
ENV PATH="/usr/local/searxng/searx-pyenv/bin:$PATH"
ENV OLLAMA_MODELS=/workspace/ollama-models
# This prevents some Python warnings
ENV PIP_ROOT_USER_ACTION=ignore

# Install all system dependencies first
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    supervisor \
    git \
    sed \
    python3-dev \
    python3-venv \
    python3-pip \
    python-is-python3 \
    build-essential \
    libxslt-dev \
    zlib1g-dev \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

# Copy the pre-built Ollama binary from the builder stage
COPY --from=ollama-builder /go/src/github.com/ollama/ollama/ollama /usr/bin/ollama

# --- Correct Open WebUI Installation ---
# Clone the repository first
RUN git clone https://github.com/open-webui/open-webui.git /app
WORKDIR /app
# Install all of its backend and frontend dependencies
RUN npm install
RUN npm run build
RUN pip install -r backend/requirements.txt -U

# --- Correct SearxNG Installation ---
RUN git clone https://github.com/searxng/searxng.git /usr/local/searxng
WORKDIR /usr/local/searxng
# Create venv and install packages
RUN python -m venv searx-pyenv && \
    . ./searx-pyenv/bin/activate && \
    pip install -r requirements.txt && \
    sed -i "s/ultrasecretkey/$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32)/g" searx/settings.yml

# Create necessary directories
RUN mkdir -p /var/log/supervisor /app/backend/data /workspace/logs

# Copy our custom scripts and configs
COPY entrypoint.sh /entrypoint.sh
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
RUN chmod +x /entrypoint.sh

# Expose the necessary ports
EXPOSE 8080
EXPOSE 11434
EXPOSE 8888

# Set the entrypoint to our script
ENTRYPOINT ["/entrypoint.sh"]
