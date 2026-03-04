REGISTRY ?= ghcr.io/swanchain/swan-model-images
TAG ?= latest

# ── Engine Images (lightweight, no weights baked in) ───────────────

.PHONY: sglang
sglang:
	docker build -f Dockerfile.sglang -t $(REGISTRY)/sglang:$(TAG) .

.PHONY: whisper
whisper:
	docker build -f Dockerfile.whisper -t $(REGISTRY)/whisper:$(TAG) .

.PHONY: diffusion
diffusion:
	docker build -f Dockerfile.diffusion -t $(REGISTRY)/diffusion:$(TAG) .

# ── Batch Targets ──────────────────────────────────────────────────

ALL_IMAGES = sglang whisper diffusion

.PHONY: build-all
build-all: $(ALL_IMAGES)

.PHONY: push-all
push-all:
	@for img in $(ALL_IMAGES); do \
		echo "Pushing $(REGISTRY)/$$img:$(TAG)..."; \
		docker push $(REGISTRY)/$$img:$(TAG); \
	done

# ── Convenience: run a model locally ──────────────────────────────

# Usage: make run-model MODEL=Sao10K/L3-8B-Stheno-v3.2 TP=1
.PHONY: run-model
run-model:
	docker run --gpus all -p 8000:8000 \
		-e SWAN_MODEL_ID=$(MODEL) \
		-e SGLANG_TP=$(or $(TP),1) \
		-v swan-weights:/models \
		$(REGISTRY)/sglang:$(TAG)

# Usage: make run-whisper
.PHONY: run-whisper
run-whisper:
	docker run --gpus all -p 8000:8000 \
		-e SWAN_MODEL_ID=Systran/faster-whisper-large-v3 \
		-v swan-weights:/models \
		$(REGISTRY)/whisper:$(TAG)

# Usage: make run-diffusion MODEL=black-forest-labs/FLUX.1-schnell
.PHONY: run-diffusion
run-diffusion:
	docker run --gpus all -p 8000:8000 \
		-e SWAN_MODEL_ID=$(MODEL) \
		-v swan-weights:/models \
		$(REGISTRY)/diffusion:$(TAG)

.PHONY: list
list:
	@echo "Engine images:"
	@echo "  sglang     — LLM, embedding, reranking models (SGLang)"
	@echo "  whisper    — Audio transcription (faster-whisper)"
	@echo "  diffusion  — Image generation (diffusers)"
	@echo ""
	@echo "Run a model:"
	@echo "  make run-model MODEL=Sao10K/L3-8B-Stheno-v3.2"
	@echo "  make run-model MODEL=Sao10K/L3.3-70B-Euryale-v2.3 TP=2"
	@echo "  make run-whisper"
	@echo "  make run-diffusion MODEL=black-forest-labs/FLUX.1-schnell"
