#!/bin/bash

# Ensure the log directory exists on the volume before supervisord starts.
mkdir -p /workspace/logs


# --- NEW FIX: Make Open WebUI settings persistent ---
WEBUI_DATA_DIR="/app/backend/data"
PERSISTENT_DATA_DIR="/workspace/webui-data"

echo "--- Ensuring Open WebUI data is persistent..."
# Create the persistent data directory on the volume if it doesn't exist
mkdir -p "$PERSISTENT_DATA_DIR"

# If the data directory in the app exists and is not a symlink,
# move its contents to the persistent volume and create the link.
if [ -d "$WEBUI_DATA_DIR" ] && [ ! -L "$WEBUI_DATA_DIR" ]; then
  # Move any initial data from the image to the persistent volume, ignore errors if empty
  mv "$WEBUI_DATA_DIR"/* "$PERSISTENT_DATA_DIR/" 2>/dev/null || true
  rm -rf "$WEBUI_DATA_DIR"
fi

# Create the symlink if it doesn't already exist
if [ ! -L "$WEBUI_DATA_DIR" ]; then
  echo "Linking $PERSISTENT_DATA_DIR to $WEBUI_DATA_DIR..."
  ln -s "$PERSISTENT_DATA_DIR" "$WEBUI_DATA_DIR"
fi
echo "--- WebUI data persistence configured."
# --- END OF FIX ---


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
