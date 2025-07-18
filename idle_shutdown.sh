#!/bin/bash

# --- Configuration ---
IDLE_TIMEOUT=${IDLE_TIMEOUT_SECONDS:-1800}
CHECK_INTERVAL=60
GPU_UTILIZATION_THRESHOLD=10

echo "--- GPU Idle Shutdown Script Started ---"
echo "Timeout is set to ${IDLE_TIMEOUT} seconds."
echo "Monitoring GPU utilization. Threshold for activity: ${GPU_UTILIZATION_THRESHOLD}%"
echo "--- Starting main loop with debugging ---"

# --- Sanity Checks ---
if [ -z "$RUNPOD_API_KEY" ]; then
    echo "--- FATAL: RUNPOD_API_KEY environment variable not found."
    exit 0
fi
if [ -z "$RUNPOD_POD_ID" ]; then
    echo "--- FATAL: RUNPOD_POD_ID environment variable not found."
    exit 0
fi
if ! command -v nvidia-smi &> /dev/null; then
    echo "--- FATAL: nvidia-smi command not found. Cannot monitor GPU."
    exit 0
fi

# --- Main Loop ---
LAST_ACTIVE=$(date +%s)

while true; do
  # Get the maximum GPU utilization across all GPUs.
  CURRENT_UTILIZATION=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | sort -nr | head -n1)
  
  # --- THIS IS THE NEW DEBUGGING LINE ---
  echo "DEBUG: Current GPU utilization read as: '${CURRENT_
