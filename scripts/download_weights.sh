#!/bin/bash
# Downloads model weights from Swan Inference API (NebulaBlock S3 backend).
# Skips download if weights already exist at MODEL_PATH.
#
# Required env vars:
#   SWAN_API_URL      - Swan Inference API base URL (e.g. https://inference.swanchain.io)
#   SWAN_MODEL_ID     - HuggingFace-style model ID (e.g. Sao10K/L3-8B-Stheno-v3.2)
#   MODEL_PATH        - Local directory to store weights
#
# Optional:
#   SWAN_WEIGHT_FORMAT - Weight format filter (fp16, awq, gptq, gguf)
set -e

SWAN_API_URL="${SWAN_API_URL:-https://inference.swanchain.io}"
SWAN_MODEL_ID="${SWAN_MODEL_ID:?SWAN_MODEL_ID is required}"
MODEL_PATH="${MODEL_PATH:?MODEL_PATH is required}"
SWAN_WEIGHT_FORMAT="${SWAN_WEIGHT_FORMAT:-}"

# Check if weights already exist (look for .safetensors, .bin, or .gguf files)
if [ -d "$MODEL_PATH" ] && [ "$(find "$MODEL_PATH" -maxdepth 2 \( -name '*.safetensors' -o -name '*.bin' -o -name '*.gguf' -o -name '*.ct2' \) 2>/dev/null | head -1)" ]; then
    echo "[swan] Weights already present at $MODEL_PATH, skipping download."
    exit 0
fi

echo "[swan] Downloading weights for ${SWAN_MODEL_ID} from ${SWAN_API_URL}..."

# URL-encode the model ID (slashes → %2F)
ENCODED_MODEL_ID=$(echo "$SWAN_MODEL_ID" | sed 's|/|%2F|g')

# Build API URL
API_ENDPOINT="${SWAN_API_URL}/api/v1/models/${ENCODED_MODEL_ID}/files"
if [ -n "$SWAN_WEIGHT_FORMAT" ]; then
    API_ENDPOINT="${API_ENDPOINT}?format=${SWAN_WEIGHT_FORMAT}"
fi

# Fetch file list from Swan Inference API
echo "[swan] Fetching file list from ${API_ENDPOINT}..."
RESPONSE=$(curl -sf "$API_ENDPOINT" 2>&1) || {
    echo "[swan] ERROR: Failed to fetch file list from API."
    echo "[swan] Response: $RESPONSE"
    echo "[swan] Make sure the model has been ingested via 'swan-inference ingest ${SWAN_MODEL_ID}'"
    exit 1
}

# Parse file count and total size
FILE_COUNT=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['file_count'])" 2>/dev/null || echo "0")
TOTAL_SIZE=$(echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin)['data']; print(f'{d[\"total_size_bytes\"]/1e9:.1f}GB')" 2>/dev/null || echo "unknown")

if [ "$FILE_COUNT" = "0" ]; then
    echo "[swan] ERROR: No files found for model ${SWAN_MODEL_ID}."
    echo "[swan] Run 'swan-inference ingest ${SWAN_MODEL_ID}' to upload weights to storage first."
    exit 1
fi

echo "[swan] Found ${FILE_COUNT} files (${TOTAL_SIZE} total). Downloading to ${MODEL_PATH}..."
mkdir -p "$MODEL_PATH"

# Download each file
echo "$RESPONSE" | python3 -c "
import sys, json, subprocess, os

data = json.load(sys.stdin)['data']
files = data['files']
model_path = os.environ['MODEL_PATH']

for i, f in enumerate(files, 1):
    url = f['url']
    filename = f['filename']
    size_mb = f['size_bytes'] / 1e6
    expected_hash = f.get('hash', '')

    dest = os.path.join(model_path, filename)
    os.makedirs(os.path.dirname(dest), exist_ok=True)

    # Skip if file exists and size matches
    if os.path.exists(dest) and os.path.getsize(dest) == f['size_bytes']:
        print(f'[swan] [{i}/{len(files)}] {filename} ({size_mb:.0f}MB) — already exists, skipping')
        continue

    print(f'[swan] [{i}/{len(files)}] {filename} ({size_mb:.0f}MB)')
    ret = subprocess.run(['curl', '-sfL', '--retry', '3', '-o', dest, url])
    if ret.returncode != 0:
        print(f'[swan] ERROR: Failed to download {filename}')
        sys.exit(1)

    # Verify hash if available
    if expected_hash and f.get('algorithm') == 'sha256':
        import hashlib
        sha = hashlib.sha256()
        with open(dest, 'rb') as fh:
            for chunk in iter(lambda: fh.read(8192*1024), b''):
                sha.update(chunk)
        actual = sha.hexdigest()
        if actual != expected_hash:
            print(f'[swan] ERROR: Hash mismatch for {filename}')
            print(f'[swan]   expected: {expected_hash}')
            print(f'[swan]   actual:   {actual}')
            os.remove(dest)
            sys.exit(1)

print(f'[swan] Download complete. {len(files)} files at {model_path}')
"

echo "[swan] Weights ready at ${MODEL_PATH}"
