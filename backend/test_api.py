import cv2
import requests
import threading
import time

API_URL = "http://localhost:8000/predict"

# Shared state between threads
latest_result = {"letter": "", "confidence": 0.0, "detected": False}
result_lock = threading.Lock()
latest_frame = None
frame_lock = threading.Lock()
running = True

def api_worker():
    """Runs in background — sends frames to API every 500ms"""
    time.sleep(2)  # wait for webcam to open first
    while running:
        frame_copy = None
        with frame_lock:
            if latest_frame is not None:
                frame_copy = latest_frame.copy()

        if frame_copy is None:
            time.sleep(0.05)
            continue

        _, jpeg = cv2.imencode('.jpg', frame_copy, [cv2.IMWRITE_JPEG_QUALITY, 70])
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
        except Exception as e:
            print(f"API error: {e}")

        time.sleep(0.5)

# Start background thread
api_thread = threading.Thread(target=api_worker, daemon=True)
api_thread.start()

cap = cv2.VideoCapture(0)
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
print("Webcam running. Show ASL letters. Press Q to quit.")

while cap.isOpened():
    ret, frame = cap.read()
    if not ret:
        break

    frame = cv2.flip(frame, 1)

    # Update shared frame for API thread
    with frame_lock:
        latest_frame = frame.copy()

    # Read latest prediction (non-blocking)
    with result_lock:
        detected = latest_result["detected"]
        letter = latest_result["letter"]
        conf = latest_result["confidence"]

    # Display
    if detected:
        label = f"{letter}  ({conf:.0%})"
        color = (0, 255, 0) if conf > 0.7 else (0, 165, 255)
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