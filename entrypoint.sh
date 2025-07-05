#!/bin/bash

# Create the log directory to prevent supervisor errors
mkdir -p /workspace/logs

# Start the main supervisor process with our custom config file.
echo "--- Starting all services... ---"
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/our-services.conf
