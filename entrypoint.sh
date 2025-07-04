#!/bin/bash

# Create the log directory to prevent supervisor errors
mkdir -p /workspace/logs

# Start the main supervisor process.
# It will automatically pick up the .conf file from /etc/supervisor/conf.d/
echo "--- Starting services... ---"
exec /usr/bin/supervisord
