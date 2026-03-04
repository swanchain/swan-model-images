#!/bin/bash
# SGLang entrypoint: download weights from NebulaBlock S3 (if needed), then launch server.
set -e

MODEL_PATH="${SGLANG_MODEL_PATH:-/models/${SWAN_MODEL_ID}}"
HOST="${SGLANG_HOST:-0.0.0.0}"
PORT="${SGLANG_PORT:-8000}"
TP="${SGLANG_TP:-1}"
EXTRA_ARGS="${SGLANG_EXTRA_ARGS:-}"

# Download weights from Swan Inference API / NebulaBlock S3
if [ -n "$SWAN_MODEL_ID" ]; then
    export MODEL_PATH
    /app/download_weights.sh
fi

exec python -m sglang.launch_server \
    --model-path "$MODEL_PATH" \
    --host "$HOST" \
    --port "$PORT" \
    --tp "$TP" \
    $EXTRA_ARGS
