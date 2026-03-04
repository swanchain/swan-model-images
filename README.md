# Swan Model Images

Pre-built Docker images with baked-in model weights for [Swan Inference](https://github.com/swanchain/swan-inference) providers. Pull an image, run it, and start serving inference — no weight downloads at runtime.

## Quick Start

```bash
# Pull a model image
docker pull ghcr.io/swanchain/swan-model-images/stheno-8b:latest

# Run it (SGLang serves on port 8000)
docker run --gpus all -p 8000:8000 \
  ghcr.io/swanchain/swan-model-images/stheno-8b:latest
```

For multi-GPU models (70B), set tensor parallelism:

```bash
docker run --gpus all -p 8000:8000 \
  -e SGLANG_TP=2 \
  ghcr.io/swanchain/swan-model-images/euryale-70b:latest
```

## Available Models

### Tier S — Premium (70B, 40GB+ VRAM, multi-GPU)

| Image | HuggingFace Repo | Size |
|-------|-------------------|------|
| `euryale-70b` | `Sao10K/L3.3-70B-Euryale-v2.3` | ~140GB |
| `sapphira-70b` | `BruhzWater/Sapphira-L3.3-70b-0.1` | ~140GB |
| `llama-3.3-70b` | `meta-llama/Llama-3.3-70B-Instruct` | ~140GB |

### Tier A — Agent & Advanced (24B, 48GB VRAM)

| Image | HuggingFace Repo | Size |
|-------|-------------------|------|
| `mistral-small-24b` | `mistralai/Mistral-Small-3.2-24B-Instruct-2506` | ~50GB |
| `cydonia-24b` | `TheDrummer/Cydonia-24B-v4.1` | ~50GB |

### Tier B — Growth (8-12B, 16-24GB VRAM)

| Image | HuggingFace Repo | Size |
|-------|-------------------|------|
| `violet-lotus-12b` | `FallenMerick/MN-Violet-Lotus-12B` | ~25GB |
| `stheno-8b` | `Sao10K/L3-8B-Stheno-v3.2` | ~16GB |
| `lumimaid-8b` | `NeverSleep/Llama-3-Lumimaid-8B-v0.1` | ~16GB |
| `llama-3.1-8b` | `meta-llama/Llama-3.1-8B-Instruct` | ~16GB |
| `qwen-2.5-7b` | `Qwen/Qwen2.5-7B-Instruct` | ~15GB |

### Tier C — Utility Models

| Image | HuggingFace Repo | Engine | Size |
|-------|-------------------|--------|------|
| `qwen3-embedding-8b` | `Qwen/Qwen3-Embedding-8B` | SGLang | ~16GB |
| `bge-reranker-v2-m3` | `BAAI/bge-reranker-v2-m3` | SGLang | ~2GB |
| `whisper-large-v3` | `Systran/faster-whisper-large-v3` | faster-whisper | ~3GB |
| `flux-schnell` | `black-forest-labs/FLUX.1-schnell` | diffusers | ~24GB |
| `dreamshaper-8` | `Lykon/dreamshaper-8` | diffusers | ~4GB |

## Environment Variables

### SGLang Models (LLM / Embedding)

| Variable | Default | Description |
|----------|---------|-------------|
| `SGLANG_PORT` | `8000` | Server port |
| `SGLANG_HOST` | `0.0.0.0` | Bind address |
| `SGLANG_TP` | `1` | Tensor parallelism (set to GPU count for 70B models) |
| `SGLANG_EXTRA_ARGS` | | Additional SGLang args (e.g., `--is-embedding`) |

### Whisper Models

| Variable | Default | Description |
|----------|---------|-------------|
| `WHISPER_PORT` | `8000` | Server port |
| `WHISPER_DEVICE` | `cuda` | Device (`cuda` or `cpu`) |
| `WHISPER_COMPUTE_TYPE` | `float16` | Compute type |

### Diffusion Models

| Variable | Default | Description |
|----------|---------|-------------|
| `DIFFUSION_PORT` | `8000` | Server port |

## Building Locally

```bash
# Build a single model
make stheno-8b

# Build by tier
make build-tier-b

# Build all models
make build-all

# List available models
make list

# Push all to GHCR
make push-all
```

For gated models (e.g., Llama), set your HuggingFace token:

```bash
docker build \
  --build-arg HF_REPO=meta-llama/Llama-3.3-70B-Instruct \
  --secret id=hf_token,src=<(echo $HF_TOKEN) \
  -f Dockerfile.sglang \
  -t llama-3.3-70b .
```

## For Swan Inference Providers

These images are designed for Swan Inference computing providers. After pulling an image:

1. Run the container with `--gpus all`
2. The model server starts on port 8000
3. Connect your computing-provider agent to Swan Inference
4. The agent will route inference requests to your running model

See the [Swan Inference Provider Guide](https://docs.swanchain.io/core-concepts/swan-2.0-inference-cloud) for full setup instructions.
