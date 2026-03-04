#!/bin/bash
# Whisper entrypoint: download weights from NebulaBlock S3 (if needed), then launch server.
set -e

export MODEL_PATH="${MODEL_PATH:-/models/${SWAN_MODEL_ID}}"
export WHISPER_MODEL_PATH="$MODEL_PATH"

# Download weights from Swan Inference API / NebulaBlock S3
if [ -n "$SWAN_MODEL_ID" ]; then
    /app/download_weights.sh
fi

exec python3 /app/whisper_server.py
