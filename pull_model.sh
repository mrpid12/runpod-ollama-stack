#!/bin/bash
sleep 15 # Wait for the Ollama server to be ready

MODEL_TO_PULL="nous-hermes-2-llama-3-70b"

if ! ollama list | grep -q "$MODEL_TO_PULL"; then
  echo "--- Pulling model $MODEL_TO_PULL ---"
  ollama pull "$MODEL_TO_PULL"
else
  echo "--- Model $MODEL_TO_PULL already exists ---"
fi
echo "--- Model check complete. ---"
