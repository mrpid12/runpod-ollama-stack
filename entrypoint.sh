#!/bin/bash

# Define the repository URL and the local directory path
GIT_REPO_URL="https://github.com/your-github-username/runpod-ollama-stack.git"
CLONE_DIR="/workspace/runpod-ollama-stack"

# Create the log directory to prevent supervisor errors
mkdir -p /workspace/logs

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

# --- NEW: Run the model pull script in the background ---
echo "--- Starting model download in the background... ---"
bash "$CLONE_DIR/pull_model.sh" &

# Start the main supervisor process to manage long-running services
echo "--- Starting services... ---"
exec /usr/bin/supervisord -c "$CLONE_DIR/supervisord.conf"
