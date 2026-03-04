"""
OpenAI-compatible image generation server.
Serves POST /v1/images/generations with diffusers backend.
"""

import os
import io
import base64
import time
import uuid

import torch
from flask import Flask, request, jsonify
from diffusers import AutoPipelineForText2Image
from PIL import Image

app = Flask(__name__)

MODEL_PATH = os.environ.get("DIFFUSION_MODEL_PATH", "/models/black-forest-labs/FLUX.1-schnell")
PORT = int(os.environ.get("DIFFUSION_PORT", "8000"))
DEVICE = os.environ.get("DIFFUSION_DEVICE", "cuda")

pipeline = None


def get_pipeline():
    global pipeline
    if pipeline is None:
        pipeline = AutoPipelineForText2Image.from_pretrained(
            MODEL_PATH,
            torch_dtype=torch.float16,
            variant="fp16",
        ).to(DEVICE)
    return pipeline


@app.route("/v1/images/generations", methods=["POST"])
def generate_image():
    data = request.get_json()
    if not data or "prompt" not in data:
        return jsonify({"error": {"message": "Missing 'prompt'", "type": "invalid_request_error"}}), 400

    prompt = data["prompt"]
    n = data.get("n", 1)
    size = data.get("size", "1024x1024")
    response_format = data.get("response_format", "b64_json")

    width, height = 1024, 1024
    if "x" in size:
        parts = size.split("x")
        width, height = int(parts[0]), int(parts[1])

    pipe = get_pipeline()

    results = []
    for _ in range(n):
        image = pipe(
            prompt=prompt,
            width=width,
            height=height,
            num_inference_steps=4,  # FLUX.1-schnell is optimized for few steps
            guidance_scale=0.0,
        ).images[0]

        if response_format == "b64_json":
            buf = io.BytesIO()
            image.save(buf, format="PNG")
            b64 = base64.b64encode(buf.getvalue()).decode("utf-8")
            results.append({"b64_json": b64})
        else:
            # URL format not supported in local mode
            results.append({"b64_json": ""})

    return jsonify({
        "created": int(time.time()),
        "data": results,
    })


@app.route("/v1/models", methods=["GET"])
def list_models():
    return jsonify({
        "data": [
            {
                "id": os.environ.get("MODEL_ID", "black-forest-labs/FLUX.1-schnell"),
                "object": "model",
                "owned_by": "swan-inference",
            }
        ]
    })


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok"})


if __name__ == "__main__":
    print(f"Loading diffusion model from {MODEL_PATH}...")
    get_pipeline()
    print("Model loaded. Starting server...")
    app.run(host="0.0.0.0", port=PORT)
