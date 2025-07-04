#!/bin/bash

# --- RUNTIME DIAGNOSTIC ---
# List the contents of /app/backend to verify the .git directory exists at runtime.
echo "--- Verifying /app/backend contents at runtime... ---"
ls -la /app/backend
echo "-----------------------------------------------------"

# --- GPU DIAGNOSTIC ---
# Check the dynamic libraries linked to the Ollama binary.
# This will show if any required .so files are missing.
echo "--- Checking Ollama dynamic library dependencies... ---"
ldd /usr/bin/ollama
echo "-------------------------------------------------------"


# Create the log directory to prevent supervisor errors
mkdir -p /workspace/logs

# Start the main supervisor process.
echo "--- Starting services... ---"
exec /usr/bin/supervisord
