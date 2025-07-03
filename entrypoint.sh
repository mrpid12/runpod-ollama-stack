#!/bin/bash

# Define the repository URL and the local directory path
# Using the '.git' suffix makes the clone command more explicit
GIT_REPO_URL="https://github.com/mrpid12/runpod-ollama-stack.git"
CLONE_DIR="/workspace/runpod-ollama-stack"

# Create the log directory to prevent supervisor errors
mkdir -p /workspace/logs

# If the directory doesn't exist, clone it.
if [ ! -d "$CLONE_DIR" ]; then
    echo "--- Cloning repository for the first time... ---"
    # The 'git clone' command now uses the full, explicit URL
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
