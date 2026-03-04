"""
OpenAI-compatible Whisper transcription server.
Serves POST /v1/audio/transcriptions with faster-whisper backend.
"""

import os
import io
import tempfile
import time

from flask import Flask, request, jsonify
from faster_whisper import WhisperModel

app = Flask(__name__)

MODEL_PATH = os.environ.get("WHISPER_MODEL_PATH", "/models/Systran/faster-whisper-large-v3")
DEVICE = os.environ.get("WHISPER_DEVICE", "cuda")
COMPUTE_TYPE = os.environ.get("WHISPER_COMPUTE_TYPE", "float16")
PORT = int(os.environ.get("WHISPER_PORT", "8000"))

model = None


def get_model():
    global model
    if model is None:
        model = WhisperModel(MODEL_PATH, device=DEVICE, compute_type=COMPUTE_TYPE)
    return model


@app.route("/v1/audio/transcriptions", methods=["POST"])
def transcribe():
    if "file" not in request.files:
        return jsonify({"error": {"message": "No audio file provided", "type": "invalid_request_error"}}), 400

    audio_file = request.files["file"]
    language = request.form.get("language", None)
    response_format = request.form.get("response_format", "json")

    # Save to temp file for faster-whisper
    with tempfile.NamedTemporaryFile(suffix=os.path.splitext(audio_file.filename)[1], delete=False) as tmp:
        audio_file.save(tmp.name)
        tmp_path = tmp.name

    try:
        m = get_model()
        segments, info = m.transcribe(tmp_path, language=language, beam_size=5)

        text_parts = []
        for segment in segments:
            text_parts.append(segment.text)

        full_text = "".join(text_parts).strip()

        if response_format == "text":
            return full_text, 200, {"Content-Type": "text/plain"}

        return jsonify({
            "text": full_text,
            "language": info.language,
            "duration": info.duration,
        })
    finally:
        os.unlink(tmp_path)


@app.route("/v1/models", methods=["GET"])
def list_models():
    return jsonify({
        "data": [
            {
                "id": os.environ.get("MODEL_ID", "Systran/faster-whisper-large-v3"),
                "object": "model",
                "owned_by": "swan-inference",
            }
        ]
    })


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok"})


if __name__ == "__main__":
    # Warm up the model
    print(f"Loading Whisper model from {MODEL_PATH}...")
    get_model()
    print("Model loaded. Starting server...")
    app.run(host="0.0.0.0", port=PORT)
