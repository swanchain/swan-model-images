#!/bin/bash
# Downloads model weights from Swan Inference API (NebulaBlock S3 backend).
# Falls back to HuggingFace direct download if S3 files aren't available.
# Skips download if weights already exist at MODEL_PATH.
#
# Required env vars:
#   SWAN_MODEL_ID     - HuggingFace-style model ID (e.g. Sao10K/L3-8B-Stheno-v3.2)
#   MODEL_PATH        - Local directory to store weights
#
# Optional:
#   SWAN_API_URL      - Swan Inference API base URL (default: https://inference.swanchain.io)
#   SWAN_WEIGHT_FORMAT - Weight format filter (fp16, awq, gptq, gguf)
#   HF_TOKEN          - HuggingFace token for gated models (fallback only)
set -e

SWAN_API_URL="${SWAN_API_URL:-https://inference.swanchain.io}"
SWAN_MODEL_ID="${SWAN_MODEL_ID:?SWAN_MODEL_ID is required}"
MODEL_PATH="${MODEL_PATH:?MODEL_PATH is required}"
SWAN_WEIGHT_FORMAT="${SWAN_WEIGHT_FORMAT:-}"

# Check if weights already exist (look for model weight files)
if [ -d "$MODEL_PATH" ] && [ "$(find "$MODEL_PATH" -maxdepth 2 \( -name '*.safetensors' -o -name '*.bin' -o -name '*.gguf' -o -name '*.ct2' -o -name 'config.json' \) 2>/dev/null | head -1)" ]; then
    echo "[swan] Weights already present at $MODEL_PATH, skipping download."
    exit 0
fi

mkdir -p "$MODEL_PATH"

# ── Try Swan Inference API (NebulaBlock S3) first ──────────────────

# URL-encode the model ID (slashes → %2F)
ENCODED_MODEL_ID=$(echo "$SWAN_MODEL_ID" | sed 's|/|%2F|g')

API_ENDPOINT="${SWAN_API_URL}/api/v1/models/${ENCODED_MODEL_ID}/files"
if [ -n "$SWAN_WEIGHT_FORMAT" ]; then
    API_ENDPOINT="${API_ENDPOINT}?format=${SWAN_WEIGHT_FORMAT}"
fi

echo "[swan] Fetching file list from ${API_ENDPOINT}..."
RESPONSE=$(curl -sf --connect-timeout 10 "$API_ENDPOINT" 2>/dev/null) || RESPONSE=""

# Check if API returned valid files
S3_AVAILABLE=false
if [ -n "$RESPONSE" ]; then
    FILE_COUNT=$(echo "$RESPONSE" | python3 -c "
import sys, json
try:
    r = json.load(sys.stdin)
    print(r.get('data', {}).get('file_count', 0))
except:
    print(0)
" 2>/dev/null || echo "0")

    if [ "$FILE_COUNT" != "0" ] && [ "$FILE_COUNT" != "" ]; then
        S3_AVAILABLE=true
    fi
fi

if [ "$S3_AVAILABLE" = "true" ]; then
    TOTAL_SIZE=$(echo "$RESPONSE" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)['data']
    print(f'{d[\"total_size_bytes\"]/1e9:.1f}GB')
except:
    print('unknown')
" 2>/dev/null || echo "unknown")

    echo "[swan] Found ${FILE_COUNT} files (${TOTAL_SIZE}) on NebulaBlock S3. Downloading..."

    echo "$RESPONSE" | python3 -c "
import sys, json, subprocess, os

data = json.load(sys.stdin)['data']
files = data['files']
model_path = os.environ['MODEL_PATH']

for i, f in enumerate(files, 1):
    url = f['url']
    filename = f['filename']
    size_bytes = f.get('size_bytes', 0)
    size_mb = size_bytes / 1e6
    expected_hash = f.get('hash', '')

    dest = os.path.join(model_path, filename)
    os.makedirs(os.path.dirname(dest), exist_ok=True)

    # Skip if file exists and size matches
    if os.path.exists(dest) and size_bytes > 0 and os.path.getsize(dest) == size_bytes:
        print(f'[swan] [{i}/{len(files)}] {filename} ({size_mb:.0f}MB) — exists, skipping')
        continue

    print(f'[swan] [{i}/{len(files)}] {filename} ({size_mb:.0f}MB)')
    ret = subprocess.run(['curl', '-sfL', '--retry', '3', '--retry-delay', '5', '-o', dest, url])
    if ret.returncode != 0:
        print(f'[swan] ERROR: Failed to download {filename}')
        sys.exit(1)

    # Verify SHA256 hash if available
    if expected_hash and f.get('algorithm') == 'sha256':
        import hashlib
        sha = hashlib.sha256()
        with open(dest, 'rb') as fh:
            for chunk in iter(lambda: fh.read(8192 * 1024), b''):
                sha.update(chunk)
        actual = sha.hexdigest()
        if actual != expected_hash:
            print(f'[swan] ERROR: Hash mismatch for {filename}')
            print(f'[swan]   expected: {expected_hash}')
            print(f'[swan]   actual:   {actual}')
            os.remove(dest)
            sys.exit(1)
        print(f'[swan]   SHA256 verified: {actual[:16]}...')

print(f'[swan] S3 download complete. {len(files)} files at {model_path}')
"
    echo "[swan] Weights ready at ${MODEL_PATH}"
    exit 0
fi

# ── Fallback: download from HuggingFace directly ──────────────────

echo "[swan] S3 files not available (model may not be ingested yet)."
echo "[swan] Falling back to HuggingFace direct download..."

if ! command -v huggingface-cli &>/dev/null; then
    echo "[swan] ERROR: huggingface-cli not found. Install with: pip install huggingface_hub[cli]"
    exit 1
fi

HF_ARGS="--local-dir ${MODEL_PATH} --local-dir-use-symlinks False"
if [ -n "$HF_TOKEN" ]; then
    HF_ARGS="$HF_ARGS --token $HF_TOKEN"
fi

echo "[swan] Running: huggingface-cli download ${SWAN_MODEL_ID} ${HF_ARGS}"
huggingface-cli download ${SWAN_MODEL_ID} ${HF_ARGS}

echo "[swan] HuggingFace download complete. Weights at ${MODEL_PATH}"
