#!/bin/bash

# This is a self-contained, one-shot setup script for adding SearXNG.
# It finds the main supervisor process and adds SearXNG as a new service.

echo "--- Starting SearXNG Setup V2 ---"

# 1. Install Dependencies
echo "--- Installing dependencies... ---"
apt-get update && apt-get install -y --no-install-recommends git python3.11-venv

# 2. Install SearXNG
# We will install it into the persistent /workspace volume
if [ ! -d "/workspace/searxng" ]; then
    echo "--- Cloning and setting up SearXNG in /workspace/searxng... ---"
    cd /workspace
    git clone --depth 1 https://github.com/searxng/searxng.git searxng
    cd /workspace/searxng
    python3 -m venv searx-pyenv
    ./searx-pyenv/bin/pip install -r requirements.txt
    sed -i "s#ultrasecretkey#\$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32)#g" searx/settings.yml
    sed -i 's/port: 8080/port: 8888/g' searx/settings.yml
else
    echo "--- SearXNG already found in /workspace/searxng. Skipping installation. ---"
fi

# 3. Create a dedicated supervisor config for SearXNG
# This file will be loaded by the MAIN supervisor process.
echo "--- Creating supervisor config for SearXNG... ---"
# The base image's supervisor looks for configs in /etc/supervisor/conf.d/
mkdir -p /etc/supervisor/conf.d/
cat > /etc/supervisor/conf.d/searxng.conf << EOF
[program:searxng]
command=/workspace/searxng/searx-pyenv/bin/python searx/webapp.py
directory=/workspace/searxng
autostart=true
autorestart=true
startsecs=5
priority=30
stdout_logfile=/workspace/logs/searxng.log
stderr_logfile=/workspace/logs/searxng.err
environment=PYTHONPATH="/workspace/searxng"
EOF

# 4. Tell the main supervisor to reload its configuration
echo "--- Reloading main supervisor to start SearXNG... ---"
# The supervisorctl command tells the running supervisord to read new configs and start the new services.
supervisorctl reread
supervisorctl update

echo ""
echo "--- SearXNG setup complete. It should now be managed by the main supervisor. ---"
echo "You can check its status in a few moments with: supervisorctl status"
