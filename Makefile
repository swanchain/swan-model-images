REGISTRY ?= ghcr.io/swanchain/swan-model-images
TAG ?= latest

# ── SGLang LLM Models ──────────────────────────────────────────────

# Tier S (70B)
.PHONY: euryale-70b
euryale-70b:
	docker build --build-arg HF_REPO=Sao10K/L3.3-70B-Euryale-v2.3 \
		-f Dockerfile.sglang -t $(REGISTRY)/euryale-70b:$(TAG) .

.PHONY: sapphira-70b
sapphira-70b:
	docker build --build-arg HF_REPO=BruhzWater/Sapphira-L3.3-70b-0.1 \
		-f Dockerfile.sglang -t $(REGISTRY)/sapphira-70b:$(TAG) .

.PHONY: llama-3.3-70b
llama-3.3-70b:
	docker build --build-arg HF_REPO=meta-llama/Llama-3.3-70B-Instruct \
		-f Dockerfile.sglang -t $(REGISTRY)/llama-3.3-70b:$(TAG) .

# Tier A (24B)
.PHONY: mistral-small-24b
mistral-small-24b:
	docker build --build-arg HF_REPO=mistralai/Mistral-Small-3.2-24B-Instruct-2506 \
		-f Dockerfile.sglang -t $(REGISTRY)/mistral-small-24b:$(TAG) .

.PHONY: cydonia-24b
cydonia-24b:
	docker build --build-arg HF_REPO=TheDrummer/Cydonia-24B-v4.1 \
		-f Dockerfile.sglang -t $(REGISTRY)/cydonia-24b:$(TAG) .

# Tier B (8-12B)
.PHONY: violet-lotus-12b
violet-lotus-12b:
	docker build --build-arg HF_REPO=FallenMerick/MN-Violet-Lotus-12B \
		-f Dockerfile.sglang -t $(REGISTRY)/violet-lotus-12b:$(TAG) .

.PHONY: stheno-8b
stheno-8b:
	docker build --build-arg HF_REPO=Sao10K/L3-8B-Stheno-v3.2 \
		-f Dockerfile.sglang -t $(REGISTRY)/stheno-8b:$(TAG) .

.PHONY: lumimaid-8b
lumimaid-8b:
	docker build --build-arg HF_REPO=NeverSleep/Llama-3-Lumimaid-8B-v0.1 \
		-f Dockerfile.sglang -t $(REGISTRY)/lumimaid-8b:$(TAG) .

.PHONY: llama-3.1-8b
llama-3.1-8b:
	docker build --build-arg HF_REPO=meta-llama/Llama-3.1-8B-Instruct \
		-f Dockerfile.sglang -t $(REGISTRY)/llama-3.1-8b:$(TAG) .

.PHONY: qwen-2.5-7b
qwen-2.5-7b:
	docker build --build-arg HF_REPO=Qwen/Qwen2.5-7B-Instruct \
		-f Dockerfile.sglang -t $(REGISTRY)/qwen-2.5-7b:$(TAG) .

# Tier C (Embedding / Reranking)
.PHONY: qwen3-embedding-8b
qwen3-embedding-8b:
	docker build --build-arg HF_REPO=Qwen/Qwen3-Embedding-8B \
		-f Dockerfile.sglang -t $(REGISTRY)/qwen3-embedding-8b:$(TAG) .

.PHONY: bge-reranker-v2-m3
bge-reranker-v2-m3:
	docker build --build-arg HF_REPO=BAAI/bge-reranker-v2-m3 \
		-f Dockerfile.sglang -t $(REGISTRY)/bge-reranker-v2-m3:$(TAG) .

# ── Non-SGLang Models ──────────────────────────────────────────────

.PHONY: whisper-large-v3
whisper-large-v3:
	docker build --build-arg HF_REPO=Systran/faster-whisper-large-v3 \
		-f Dockerfile.whisper -t $(REGISTRY)/whisper-large-v3:$(TAG) .

.PHONY: flux-schnell
flux-schnell:
	docker build --build-arg HF_REPO=black-forest-labs/FLUX.1-schnell \
		-f Dockerfile.diffusion -t $(REGISTRY)/flux-schnell:$(TAG) .

.PHONY: dreamshaper-8
dreamshaper-8:
	docker build --build-arg HF_REPO=Lykon/dreamshaper-8 \
		-f Dockerfile.diffusion -t $(REGISTRY)/dreamshaper-8:$(TAG) .

# ── Batch Targets ──────────────────────────────────────────────────

SGLANG_MODELS = euryale-70b sapphira-70b llama-3.3-70b \
	mistral-small-24b cydonia-24b \
	violet-lotus-12b stheno-8b lumimaid-8b llama-3.1-8b qwen-2.5-7b \
	qwen3-embedding-8b bge-reranker-v2-m3

OTHER_MODELS = whisper-large-v3 flux-schnell dreamshaper-8

ALL_MODELS = $(SGLANG_MODELS) $(OTHER_MODELS)

.PHONY: build-all
build-all: $(ALL_MODELS)

.PHONY: push-all
push-all:
	@for model in $(ALL_MODELS); do \
		echo "Pushing $(REGISTRY)/$$model:$(TAG)..."; \
		docker push $(REGISTRY)/$$model:$(TAG); \
	done

.PHONY: build-tier-s
build-tier-s: euryale-70b sapphira-70b llama-3.3-70b

.PHONY: build-tier-a
build-tier-a: mistral-small-24b cydonia-24b

.PHONY: build-tier-b
build-tier-b: violet-lotus-12b stheno-8b lumimaid-8b llama-3.1-8b qwen-2.5-7b

.PHONY: build-tier-c
build-tier-c: qwen3-embedding-8b bge-reranker-v2-m3 whisper-large-v3 flux-schnell dreamshaper-8

.PHONY: list
list:
	@echo "Available models:"
	@for model in $(ALL_MODELS); do \
		echo "  $$model"; \
	done
