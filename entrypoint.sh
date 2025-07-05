#!/bin/bash

# Create the log directory to prevent supervisor errors
mkdir -p /workspace/logs

# Start the main supervisor process.
echo "--- Starting services... ---"
exec /usr/bin/supervisord
