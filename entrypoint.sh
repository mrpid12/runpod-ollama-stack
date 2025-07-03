#!/bin/bash

GIT_REPO_URL="https://github.com/mrpid12/runpod-ollama-stack.git"
CLONE_DIR="/workspace/runpod-ollama-stack"

# If the directory doesn't exist, clone it.
if [ ! -d "$CLONE_DIR" ]; then
    echo "--- Cloning repository for the first time... ---"
    git clone "$GIT_REPO_URL" "$CLONE_DIR"
# If it does exist, pull the latest changes.
else
    echo "--- Repository exists. Pulling latest changes... ---"
    cd "$CLONE_DIR"
    git pull
fi

# Start the main supervisor process
echo "--- Starting services... ---"
exec /usr/bin/supervisord -c "$CLONE_DIR/supervisord.conf"
