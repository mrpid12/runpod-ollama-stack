#!/bin/bash

# This is a self-contained, one-shot setup script for adding SearXNG.
# It should be run from the RunPod terminal after the pod has started.

echo "--- Starting SearXNG Setup ---"

# 1. Install Dependencies
# Check if supervisor is already installed. The base image might have it.
if ! command -v supervisorctl &> /dev/null
then
    echo "--- Installing dependencies (git, python-venv, supervisor)... ---"
    apt-get update && apt-get install -y --no-install-recommends git python3.11-venv supervisor
else
    echo "--- Supervisor found. Installing other dependencies... ---"
    apt-get update && apt-get install -y --no-install-recommends git python3.11-venv
fi


# 2. Install SearXNG
# We will install it into the persistent /workspace volume
if [ ! -d "/workspace/searxng" ]; then
    echo "--- Cloning and setting up SearXNG in /workspace/searxng... ---"
    cd /workspace
    git clone --depth 1 https://github.com/searxng/searxng.git searxng
    cd /workspace/searxng
    python3 -m venv searx-pyenv
    ./searx-pyenv/bin/pip install -r requirements.txt
    sed -i "s/ultrasecretkey/\$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32)/g" searx/settings.yml
    sed -i 's/port: 8080/port: 8888/g' searx/settings.yml
else
    echo "--- SearXNG already found in /workspace/searxng. Skipping installation. ---"
fi

# 3. Create a dedicated supervisor config for SearXNG
echo "--- Creating supervisor config for SearXNG... ---"
# Ensure the log directory exists
mkdir -p /workspace/logs
# Create the supervisor config file
cat > /workspace/searxng_supervisor.conf << EOF
[supervisord]
nodaemon=true
user=root

[program:searxng]
command=/workspace/searxng/searx-pyenv/bin/python searx/webapp.py
directory=/workspace/searxng
autostart=true
autorestart=true
startsecs=5
priority=1
stdout_logfile=/workspace/logs/searxng.log
stderr_logfile=/workspace/logs/searxng.err
environment=PYTHONPATH="/workspace/searxng"
EOF

# 4. Start the supervisor daemon to manage SearXNG
echo "--- Starting supervisor to run SearXNG... ---"
# We run this as a background process so the terminal is free
nohup /usr/bin/supervisord -c /workspace/searxng_supervisor.conf > /workspace/logs/supervisor_daemon.log 2>&1 &

echo ""
echo "--- SearXNG setup complete. It is now starting in the background. ---"
echo "You can check its status in a few moments with: tail -f /workspace/logs/searxng.log"
