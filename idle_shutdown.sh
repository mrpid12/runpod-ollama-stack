#!/bin/bash

# --- Configuration ---
# Read the timeout from an environment variable, with a default of 1800 seconds (30 minutes).
# You can set IDLE_TIMEOUT_SECONDS in your RunPod template to override this.
IDLE_TIMEOUT=${IDLE_TIMEOUT_SECONDS:-1800}

# How often (in seconds) to check for activity.
CHECK_INTERVAL=60

# The GPU utilization percentage that is considered "active".
# If usage is above this, the idle timer resets.
GPU_UTILIZATION_THRESHOLD=10

echo "--- GPU Idle Shutdown Script Started ---"
echo "Timeout is set to ${IDLE_TIMEOUT} seconds."
echo "Monitoring GPU utilization. Threshold for activity: ${GPU_UTILIZATION_THRESHOLD}%"

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

  # Check if the GPU is currently active
  if [ "$CURRENT_UTILIZATION" -gt "$GPU_UTILIZATION_THRESHOLD" ]; then
    # If usage is above the threshold, reset the timer.
    LAST_ACTIVE=$(date +%s)
  else
    # If usage is below the threshold, check if the timeout has been reached.
    CURRENT_TIME=$(date +%s)
    IDLE_TIME=$((CURRENT_TIME - LAST_ACTIVE))

    if [ ${IDLE_TIME} -ge ${IDLE_TIMEOUT} ]; then
      echo "GPU has been idle for ${IDLE_TIME} seconds. Terminating pod ${RUNPOD_POD_ID}..."
      
      HTTP_RESPONSE=$(curl -s -w "%{http_code}" -X POST "https://api.runpod.io/v2/${RUNPOD_POD_ID}/terminate" \
           -H "Authorization: Bearer ${RUNPOD_API_KEY}")
      
      HTTP_STATUS=$(tail -n1 <<< "$HTTP_RESPONSE")
      HTTP_BODY=$(sed '$ d' <<< "$HTTP_RESPONSE")

      echo "Termination signal sent to RunPod API. Response Status: ${HTTP_STATUS}, Body: ${HTTP_BODY}"
      exit 0
    fi
  fi
  
  sleep ${CHECK_INTERVAL}
done
