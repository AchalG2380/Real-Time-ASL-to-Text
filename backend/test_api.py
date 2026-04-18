import cv2
import requests
import threading
import time
import os
import sys
from collections import Counter

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'asl_ml'))
from keypoint_extractor import KeypointExtractor

API_URL = "http://localhost:8000/predict"

local_extractor = KeypointExtractor(max_num_hands=1, min_detection_confidence=0.3)

latest_result = {"letter": "", "confidence": 0.0, "detected": False}
result_lock = threading.Lock()
latest_frame = None
frame_lock = threading.Lock()
running = True
prediction_buffer = []
BUFFER_SIZE = 7

def get_smoothed_prediction():
    if not prediction_buffer:
        return "", 0.0
    letters = [p[0] for p in prediction_buffer]
    most_common = Counter(letters).most_common(1)[0][0]
    confs = [p[1] for p in prediction_buffer if p[0] == most_common]
    return most_common, sum(confs) / len(confs)

def api_worker():
    time.sleep(2)
    while running:
        frame_copy = None
        with frame_lock:
            if latest_frame is not None:
                frame_copy = latest_frame.copy()

        if frame_copy is None:
            time.sleep(0.05)
            continue

        _, jpeg = cv2.imencode('.jpg', frame_copy, [cv2.IMWRITE_JPEG_QUALITY, 95])
        jpeg_bytes = jpeg.tobytes()

        try:
            response = requests.post(
                API_URL,
                files={"file": ("frame.jpg", jpeg_bytes, "image/jpeg")},
                timeout=10
            )
            result = response.json()
            with result_lock:
                latest_result.update(result)

            if result["detected"]:
                prediction_buffer.append((result["letter"], result["confidence"]))
                if len(prediction_buffer) > BUFFER_SIZE:
                    prediction_buffer.pop(0)
                smoothed, conf = get_smoothed_prediction()
                print(f"Raw: {result['letter']} ({result['confidence']:.0%})  Smoothed: {smoothed} ({conf:.0%})")
            else:
                prediction_buffer.clear()

        except Exception as e:
            print(f"API error: {e}")

        time.sleep(0.1)

print("Starting API thread...")
api_thread = threading.Thread(target=api_worker, daemon=True)
api_thread.start()

print("Opening webcam...")
cap = cv2.VideoCapture(0)
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
print("Webcam running. Show ASL letters. Press Q to quit.")

while cap.isOpened():
    ret, frame = cap.read()
    if not ret:
        break

    frame = cv2.flip(frame, 1)

    with frame_lock:
        latest_frame = frame.copy()

    frame = local_extractor.draw_landmarks(frame)

    with result_lock:
        detected = latest_result["detected"]

    smoothed_letter, smoothed_conf = get_smoothed_prediction()

    if detected and smoothed_letter:
        label = f"{smoothed_letter}  ({smoothed_conf:.0%})"
        color = (0, 255, 0) if smoothed_conf > 0.7 else (0, 165, 255)
    else:
        label = "No hand"
        color = (0, 0, 255)

    cv2.putText(frame, label, (10, 50),
                cv2.FONT_HERSHEY_SIMPLEX, 1.5, color, 3)
    cv2.imshow("ASL Predictor Test", frame)
    cv2.setWindowProperty("ASL Predictor Test", cv2.WND_PROP_TOPMOST, 1)

    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

running = False
cap.release()
cv2.destroyAllWindows()
local_extractor.close()