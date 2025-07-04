#!/bin/bash
sleep 15 # Wait for the Ollama server to be ready

# Changed to a smaller, more responsive model suitable for most hardware.
MODEL_TO_PULL="llama3:8b-instruct"

if ! ollama list | grep -q "$MODEL_TO_PULL"; then
  echo "--- Pulling default model: $MODEL_TO_PULL ---"
  ollama pull "$MODEL_TO_PULL"
else
  echo "--- Default model $MODEL_TO_PULL already exists ---"
fi
echo "--- Model check complete. ---"
