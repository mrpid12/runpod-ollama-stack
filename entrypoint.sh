#!/bin/bash

# Define the repository URL and the local directory path
GIT_REPO_URL="https://github.com/your-github-username/runpod-ollama-stack.git"
CLONE_DIR="/workspace/runpod-ollama-stack"

# Check if the repository directory already exists
if [ ! -d "$CLONE_DIR" ]; then
    echo "--- Cloning repository for the first time... ---"
    git clone "$GIT_REPO_URL" "$CLONE_DIR"
else
    echo "--- Repository already exists. Skipping clone. ---"
fi

# Start the main supervisor process, using the config from the cloned repo
echo "--- Starting services... ---"
exec /usr/bin/supervisord -c "$CLONE_DIR/supervisord.conf"
