#!/bin/bash

# --- Configuration ---
IDLE_TIMEOUT=1800
CHECK_INTERVAL=60
APP_PORTS=("8080" "8888")

echo "--- Idle Shutdown Script Started ---"
echo "Monitoring ports ${APP_PORTS[*]} for inactivity."
echo "Pod will terminate after ${IDLE_TIMEOUT} seconds of inactivity."

if [ -z "$RUNPOD_API_KEY" ]; then
    echo "--- FATAL: RUNPOD_API_KEY environment variable not found. Create one in your RunPod account settings and add it as a secret."
    exit 0
fi

if [ -z "$RUNPOD_POD_ID" ]; then
    echo "--- FATAL: RUNPOD_POD_ID environment variable not found."
    exit 0
fi

LAST_ACTIVE=$(date +%s)
GREP_REGEX="ESTAB.*:($(IFS=\|; echo "${APP_PORTS[*]}"))"

while true; do
  if ss -tna | grep -qE "$GREP_REGEX"; then
    LAST_ACTIVE=$(date +%s)
  else
    CURRENT_TIME=$(date +%s)
    IDLE_TIME=$((CURRENT_TIME - LAST_ACTIVE))

    if [ ${IDLE_TIME} -ge ${IDLE_TIMEOUT} ]; then
      echo "Idle for ${IDLE_TIME} seconds. Terminating pod ${RUNPOD_POD_ID}..."
      
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
