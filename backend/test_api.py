import cv2
import numpy as np
import tensorflow as tf
import json
import os
import sys
import threading
import time
from collections import Counter

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'asl_ml'))
from keypoint_extractor import KeypointExtractor

# ── Load model directly ────────────────────────────────────────────────────
MODEL_PATH  = os.path.join('..', 'asl_ml', 'models', 'asl_letter_model.tflite')
LABELS_PATH = os.path.join('..', 'asl_ml', 'models', 'letter_labels.json')

interpreter = tf.lite.Interpreter(model_path=MODEL_PATH)
interpreter.allocate_tensors()
inp_details = interpreter.get_input_details()
out_details = interpreter.get_output_details()

with open(LABELS_PATH) as f:
    LETTERS = json.load(f)

def predict(keypoints):
    x = keypoints.reshape(1, 126).astype(np.float32)
    interpreter.set_tensor(inp_details[0]['index'], x)
    interpreter.invoke()
    probs = interpreter.get_tensor(out_details[0]['index'])[0]
    idx = np.argmax(probs)
    return LETTERS[idx], float(probs[idx])

# ── Extractor ──────────────────────────────────────────────────────────────
extractor = KeypointExtractor(max_num_hands=1, min_detection_confidence=0.3)

# ── Smoothing ──────────────────────────────────────────────────────────────
prediction_buffer = []
BUFFER_SIZE = 5

def get_smoothed_prediction():
    if not prediction_buffer:
        return "", 0.0
    letters = [p[0] for p in prediction_buffer]
    most_common = Counter(letters).most_common(1)[0][0]
    confs = [p[1] for p in prediction_buffer if p[0] == most_common]
    return most_common, sum(confs) / len(confs)

# ── Webcam loop ────────────────────────────────────────────────────────────
cap = cv2.VideoCapture(0)
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
print("Webcam running. Show ASL letters. Press Q to quit.")

while cap.isOpened():
    ret, frame = cap.read()
    if not ret:
        break

    frame = cv2.flip(frame, 1)

    # Extract keypoints
    keypoints = extractor.extract(frame)

    if keypoints is not None:
        letter, conf = predict(keypoints)
        prediction_buffer.append((letter, conf))
        if len(prediction_buffer) > BUFFER_SIZE:
            prediction_buffer.pop(0)
    else:
        prediction_buffer.clear()

    # Draw skeleton
    frame = extractor.draw_landmarks(frame)

    # Display
    smoothed_letter, smoothed_conf = get_smoothed_prediction()
    if smoothed_letter:
        label = f"{smoothed_letter}  ({smoothed_conf:.0%})"
        color = (0, 255, 0) if smoothed_conf > 0.7 else (0, 165, 255)
    else:
        label = "No hand"
        color = (0, 0, 255)

    cv2.putText(frame, label, (10, 50),
                cv2.FONT_HERSHEY_SIMPLEX, 1.5, color, 3)
    cv2.imshow("ASL Predictor", frame)
    cv2.setWindowProperty("ASL Predictor", cv2.WND_PROP_TOPMOST, 1)

    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()
extractor.close()