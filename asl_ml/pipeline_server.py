import base64
import cv2
import numpy as np
import json
import os
from flask import Flask, request, jsonify
from flask_cors import CORS

# Use mock if model not trained yet
USE_MOCK = not os.path.exists('models/asl_dynamic_model.tflite')

if USE_MOCK:
    from inference_pipeline import MockASLPipeline
    pipeline = MockASLPipeline()
    print("⚠️  Running with MOCK pipeline (no model found)")
else:
    from inference_pipeline import ASLInferencePipeline
    pipeline = ASLInferencePipeline(
        dynamic_model_path='models/asl_dynamic_model.tflite',
        letter_model_path='models/asl_letter_model.tflite',
        dynamic_labels_path='models/dynamic_labels.json',
        letter_labels_path='models/letter_labels.json',
    )
    print("✓ Running with trained model")

app = Flask(__name__)
CORS(app)  # Allow Flutter to call from any origin


@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "ok", "mock": USE_MOCK})


@app.route('/process_frame', methods=['POST'])
def process_frame():
    """
    Accepts a base64 JPEG frame, returns inference result.
    
    Flutter sends:
        { "frame_base64": "..." }
    """
    try:
        data = request.get_json()
        frame_b64 = data.get('frame_base64', '')

        # Decode base64 → numpy array
        img_bytes = base64.b64decode(frame_b64)
        img_arr = np.frombuffer(img_bytes, dtype=np.uint8)
        frame = cv2.imdecode(img_arr, cv2.IMREAD_COLOR)

        if frame is None:
            return jsonify({"error": "Invalid frame"}), 400

        result = pipeline.process_frame(frame)
        return jsonify(result)

    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route('/complete_sentence', methods=['POST'])
def complete_sentence():
    completed = pipeline.complete_sentence()
    return jsonify({"completed": completed})


@app.route('/clear_conversation', methods=['POST'])
def clear_conversation():
    pipeline.clear_conversation()
    return jsonify({"status": "cleared"})


@app.route('/set_language', methods=['POST'])
def set_language():
    data = request.get_json()
    lang = data.get('lang', 'en')
    pipeline.set_language(lang)
    return jsonify({"language": lang})


@app.route('/set_letter_mode', methods=['POST'])
def set_letter_mode():
    data = request.get_json()
    enabled = data.get('enabled', False)
    pipeline.set_letter_mode(enabled)
    return jsonify({"letter_mode": enabled})


@app.route('/suggestions', methods=['GET'])
def get_offline_suggestions():
    """Return offline suggestions (no camera needed)."""
    from sentence_formatter import (
        OFFLINE_SUGGESTIONS_CUSTOMER_EN,
        OFFLINE_SUGGESTIONS_CUSTOMER_HI,
        OFFLINE_SUGGESTIONS_RETAILER_EN,
        OFFLINE_SUGGESTIONS_RETAILER_HI
    )
    return jsonify({
        "customer": {
            "en": OFFLINE_SUGGESTIONS_CUSTOMER_EN,
            "hi": OFFLINE_SUGGESTIONS_CUSTOMER_HI
        },
        "retailer": {
            "en": OFFLINE_SUGGESTIONS_RETAILER_EN,
            "hi": OFFLINE_SUGGESTIONS_RETAILER_HI
        }
    })


if __name__ == '__main__':
    print("\n=== ASL Pipeline Server ===")
    print("Flutter endpoint: http://localhost:5000")
    print("Health check: http://localhost:5000/health\n")
    app.run(host='0.0.0.0', port=5000, debug=False, threaded=True)
