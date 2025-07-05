#!/bin/bash

# This script is designed to run when the RunPod container starts.
# It installs SearXNG if it's not already present, then starts all services.

# --- SearXNG Installation ---
# Check if SearXNG is already installed to prevent re-installation on pod restart
if [ ! -d "/usr/local/searxng" ]; then
    echo "--- SearXNG not found. Installing now... ---"
    # We need root permissions to install packages
    if [ "$(id -u)" -ne 0 ]; then
        echo "Error: This script must be run as root to install packages." >&2
        exit 1
    fi
    
    # Install dependencies for SearXNG
    apt-get update && apt-get install -y --no-install-recommends git python3.11-venv build-essential
    
    # Clone and prepare SearxNG
    cd /usr/local
    git clone --depth 1 https://github.com/searxng/searxng.git searxng
    cd searxng
    python3 -m venv searx-pyenv
    ./searx-pyenv/bin/pip install -r requirements.txt
    sed -i "s/ultrasecretkey/$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32)/g" searx/settings.yml
    sed -i 's/port: 8080/port: 8888/g' searx/settings.yml
    echo "--- SearXNG installation complete. ---"
else
    echo "--- SearXNG already installed. Skipping installation. ---"
fi

# --- Start Services ---
# Create the log directory to prevent supervisor errors
mkdir -p /workspace/logs

# Start the main supervisor process with our custom config file.
# This assumes your repository is mounted at /workspace
echo "--- Starting all services using custom supervisor config... ---"
exec /usr/bin/supervisord -c /workspace/supervisord.conf
