#!/bin/bash

# --- RUNTIME DIAGNOSTIC ---
# List the contents of /app/backend to verify the .git directory exists at runtime.
# This output will appear in your main pod log.
echo "--- Verifying /app/backend contents at runtime... ---"
ls -la /app/backend
echo "-----------------------------------------------------"

# Create the log directory to prevent supervisor errors
mkdir -p /workspace/logs

# Start the main supervisor process.
echo "--- Starting services... ---"
exec /usr/bin/supervisord
