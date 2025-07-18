#!/bin/bash

# --- Configuration ---
# Timeout in seconds (30 minutes = 1800 seconds)
IDLE_TIMEOUT=1800
# How often to check for activity (in seconds)
CHECK_INTERVAL=60
# Ports to monitor inside the container
APP_PORTS=("8080" "8888")

echo "--- Idle Shutdown Script Started ---"
echo "Monitoring ports ${APP_PORTS[*]} for inactivity."
echo "Pod will terminate after ${IDLE_TIMEOUT} seconds of inactivity."

# Check for necessary RunPod environment variables
if [ -z "$RUNPOD_POD_ID" ] || [ -z "$RUNPOD_API_KEY" ]; then
    echo "--- FATAL: RUNPOD_POD_ID or RUNPOD_API_KEY env vars not set. ---"
    echo "--- Disabling idle shutdown monitor. It will not run. ---"
    # Exit gracefully so supervisord doesn't keep restarting it in a tight loop.
    exit 0
fi

LAST_ACTIVE=$(date +%s)

# Build the regex for grep to check all specified ports
# This will create a pattern like: "ESTAB.*:(8080|8888)"
GREP_REGEX="ESTAB.*:($(IFS=\|; echo "${APP_PORTS[*]}"))"

while true; do
  # Check for any established TCP connections on the application ports
  if ss -tna | grep -qE "$GREP_REGEX"; then
    LAST_ACTIVE=$(date +%s)
  else
    CURRENT_TIME=$(date +%s)
    IDLE_TIME=$((CURRENT_TIME - LAST_ACTIVE))

    if [ ${IDLE_TIME} -ge ${IDLE_TIMEOUT} ]; then
      echo "Idle for ${IDLE_TIME} seconds. Terminating pod ${RUNPOD_POD_ID}..."
      
      # Use the RunPod API to terminate this pod
      curl -s -X POST "https://api.runpod.io/v2/${RUNPOD_POD_ID}/terminate" \
           -H "Authorization: Bearer ${RUNPOD_API_KEY}"
      
      echo "Termination signal sent to RunPod API. Script will now exit."
      exit 0
    fi
  fi
  sleep ${CHECK_INTERVAL}
done
