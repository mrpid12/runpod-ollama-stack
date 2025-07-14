#!/bin/bash

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
