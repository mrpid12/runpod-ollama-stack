#!/bin/bash

# Define the path to the supervisor configuration file
SUPERVISOR_CONF="/etc/supervisor/conf.d/all-services.conf"

# --- Error Handling ---
# Check if the supervisor configuration file exists before trying to run it.
if [ ! -f "$SUPERVISOR_CONF" ]; then
    echo "--- FATAL ERROR: Supervisor configuration file not found at $SUPERVISOR_CONF ---"
    exit 1
fi

# --- Start Services ---
echo "--- Starting all services via supervisor... ---"
# Use exec to make supervisord the main process in the container.
exec /usr/bin/supervisord -c "$SUPERVISOR_CONF"
