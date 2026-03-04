#!/bin/bash
# SGLang entrypoint that expands environment variables for model path
set -e

MODEL_PATH="${SGLANG_MODEL_PATH:-/models}"
HOST="${SGLANG_HOST:-0.0.0.0}"
PORT="${SGLANG_PORT:-8000}"
TP="${SGLANG_TP:-1}"
EXTRA_ARGS="${SGLANG_EXTRA_ARGS:-}"

exec python -m sglang.launch_server \
    --model-path "$MODEL_PATH" \
    --host "$HOST" \
    --port "$PORT" \
    --tp "$TP" \
    $EXTRA_ARGS
