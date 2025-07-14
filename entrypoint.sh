#!/bin/bash

# --- FINAL FIX ---
# The RunPod environment forces OLLAMA_MODELS to /workspace/models,
# but the user's models are in /workspace.
# This startup script creates symbolic links to bridge the gap before starting services.

# The target directory where Ollama is forced to look
TARGET_DIR="/workspace/models"

# The source directories where the files actually are
SOURCE_MANIFESTS="/workspace/manifests"
SOURCE_BLOBS="/workspace/blobs"

echo "--- Bridging Ollama model paths..."
# Ensure the target directory exists
mkdir -p "$TARGET_DIR"

# Create symlink for manifests if it doesn't exist.
# If a real directory is in the way, move it.
if [ ! -L "${TARGET_DIR}/manifests" ]; then
    if [ -d "${TARGET_DIR}/manifests" ]; then
        mv "${TARGET_DIR}/manifests" "${TARGET_DIR}/manifests_old"
    fi
    echo "Linking ${SOURCE_MANIFESTS} to ${TARGET_DIR}/manifests."
    ln -s "${SOURCE_MANIFESTS}" "${TARGET_DIR}/manifests"
fi

# Create symlink for blobs if it doesn't exist.
# If a real directory is in the way, move it.
if [ ! -L "${TARGET_DIR}/blobs" ]; then
    if [ -d "${TARGET_DIR}/blobs" ]; then
        mv "${TARGET_DIR}/blobs" "${TARGET_DIR}/blobs_old"
    fi
    echo "Linking ${SOURCE_BLOBS} to ${TARGET_DIR}/blobs."
    ln -s "${SOURCE_BLOBS}" "${TARGET_DIR}/blobs"
fi
echo "--- Path bridging complete."


# --- Original Content ---
# Define the path to the supervisor configuration file
SUPERVISOR_CONF="/etc/supervisor/conf.d/all-services.conf"

# Check if the supervisor configuration file exists before trying to run it.
if [ ! -f "$SUPERVISOR_CONF" ]; then
    echo "--- FATAL ERROR: Supervisor configuration file not found at $SUPERVISOR_CONF ---"
    exit 1
fi

# Start all services
echo "--- Starting all services via supervisor... ---"
exec /usr/bin/supervisord -c "$SUPERVISOR_CONF"
