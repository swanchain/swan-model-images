# Swan Model Images

Lightweight Docker images for [Swan Inference](https://github.com/swanchain/swan-inference) providers. Images contain only the inference engine (~2-5GB) — model weights are downloaded from NebulaBlock S3 at startup and cached in a Docker volume.

## Quick Start

```bash
# Pull the SGLang engine image (once)
docker pull ghcr.io/swanchain/swan-model-images/sglang:latest

# Run any LLM model — weights download on first run, cached after
docker run --gpus all -p 8000:8000 \
  -e SWAN_MODEL_ID=Sao10K/L3-8B-Stheno-v3.2 \
  -v swan-weights:/models \
  ghcr.io/swanchain/swan-model-images/sglang:latest
```

The `-v swan-weights:/models` volume persists weights across container restarts — first run downloads, subsequent runs start instantly.

For multi-GPU models (70B), set tensor parallelism:

```bash
docker run --gpus all -p 8000:8000 \
  -e SWAN_MODEL_ID=Sao10K/L3.3-70B-Euryale-v2.3 \
  -e SGLANG_TP=2 \
  -v swan-weights:/models \
  ghcr.io/swanchain/swan-model-images/sglang:latest
```

## Engine Images

Only 3 images to pull — the model is selected at runtime via `SWAN_MODEL_ID`:

| Image | Engine | Models | Size |
|-------|--------|--------|------|
| `sglang` | SGLang | LLM, embedding, reranking | ~3GB |
| `whisper` | faster-whisper | Audio transcription | ~2GB |
| `diffusion` | diffusers | Image generation | ~5GB |

## Available Models

### Tier S — Premium (70B, 40GB+ VRAM, multi-GPU)

| Model ID | Description | TP |
|----------|-------------|-----|
| `Sao10K/L3.3-70B-Euryale-v2.3` | Roleplay-focused 70B | 2+ |
| `BruhzWater/Sapphira-L3.3-70b-0.1` | Storytelling & dialogue | 2+ |
| `meta-llama/Llama-3.3-70B-Instruct` | Multilingual general-purpose | 2+ |

### Tier A — Agent & Advanced (24B, 48GB VRAM)

| Model ID | Description | TP |
|----------|-------------|-----|
| `mistralai/Mistral-Small-3.2-24B-Instruct-2506` | Long context, fewer errors | 1 |
| `TheDrummer/Cydonia-24B-v4.1` | Creative writing | 1 |

### Tier B — Growth (8-12B, 16-24GB VRAM)

| Model ID | Description | TP |
|----------|-------------|-----|
| `FallenMerick/MN-Violet-Lotus-12B` | Emotional intelligence | 1 |
| `Sao10K/L3-8B-Stheno-v3.2` | Roleplay & assistant | 1 |
| `NeverSleep/Llama-3-Lumimaid-8B-v0.1` | Creative roleplay | 1 |
| `meta-llama/Llama-3.1-8B-Instruct` | General-purpose 8B | 1 |
| `Qwen/Qwen2.5-7B-Instruct` | General-purpose 7B | 1 |

### Tier C — Utility Models

| Model ID | Engine | Description |
|----------|--------|-------------|
| `Qwen/Qwen3-Embedding-8B` | sglang | Text embeddings |
| `BAAI/bge-reranker-v2-m3` | sglang | Multilingual reranking |
| `Systran/faster-whisper-large-v3` | whisper | Audio transcription |
| `black-forest-labs/FLUX.1-schnell` | diffusion | Fast image generation |
| `Lykon/dreamshaper-8` | diffusion | Stable Diffusion image gen |

## How Weight Downloads Work

1. On first `docker run`, the entrypoint calls the Swan Inference API:
   `GET /api/v1/models/{model_id}/files`
2. The API returns file URLs pointing to NebulaBlock S3 storage
3. Each file is downloaded with SHA256 verification
4. Weights are stored in `/models` (mount a volume to persist)
5. Subsequent runs detect existing weights and skip download

Models must first be ingested into NebulaBlock S3:
```bash
# On the Swan Inference server
swan-inference ingest Sao10K/L3-8B-Stheno-v3.2
```

## Environment Variables

### All Images

| Variable | Default | Description |
|----------|---------|-------------|
| `SWAN_API_URL` | `https://inference.swanchain.io` | Swan Inference API for file list |
| `SWAN_MODEL_ID` | (required) | HuggingFace-style model ID |
| `SWAN_WEIGHT_FORMAT` | | Filter by weight format (fp16, awq, gptq) |

### SGLang (`sglang` image)

| Variable | Default | Description |
|----------|---------|-------------|
| `SGLANG_PORT` | `8000` | Server port |
| `SGLANG_HOST` | `0.0.0.0` | Bind address |
| `SGLANG_TP` | `1` | Tensor parallelism (GPU count for 70B) |
| `SGLANG_EXTRA_ARGS` | | Additional args (e.g., `--is-embedding`) |

### Whisper (`whisper` image)

| Variable | Default | Description |
|----------|---------|-------------|
| `WHISPER_PORT` | `8000` | Server port |
| `WHISPER_DEVICE` | `cuda` | Device (`cuda` or `cpu`) |
| `WHISPER_COMPUTE_TYPE` | `float16` | Compute type |

### Diffusion (`diffusion` image)

| Variable | Default | Description |
|----------|---------|-------------|
| `DIFFUSION_PORT` | `8000` | Server port |

## Building Locally

```bash
make sglang         # Build SGLang engine image
make whisper        # Build Whisper engine image
make diffusion      # Build Diffusion engine image
make build-all      # Build all 3 images
make push-all       # Push all to GHCR

# Run a model
make run-model MODEL=Sao10K/L3-8B-Stheno-v3.2
make run-model MODEL=Sao10K/L3.3-70B-Euryale-v2.3 TP=2
make run-whisper
make run-diffusion MODEL=black-forest-labs/FLUX.1-schnell
```

## For Swan Inference Providers

1. Pull the engine image for your model type
2. Run with `SWAN_MODEL_ID` and a persistent volume
3. Connect your `computing-provider` agent to Swan Inference
4. The agent routes inference requests to your running model

See the [Provider Guide](https://docs.swanchain.io/core-concepts/swan-2.0-inference-cloud) for full setup.
