import cv2
import numpy as np
import mediapipe as mp
from mediapipe.tasks import python
from mediapipe.tasks.python import vision
import os

_MODEL_PATH = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    '..', 'asl_ml', 'hand_landmarker.task'
)

_options = vision.HandLandmarkerOptions(
    base_options=python.BaseOptions(model_asset_path=str(_MODEL_PATH)),
    running_mode=vision.RunningMode.IMAGE,
    num_hands=1,
    min_hand_detection_confidence=0.5
)
_detector = vision.HandLandmarker.create_from_options(_options)

def extract_keypoints_from_bytes(image_bytes: bytes):
    arr = np.frombuffer(image_bytes, np.uint8)
    frame = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    if frame is None:
        return None

    img_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=img_rgb)
    results = _detector.detect(mp_image)

    if not results.hand_landmarks:
        return None

    landmarks = np.array(
        [[lm.x, lm.y, lm.z] for lm in results.hand_landmarks[0]],
        dtype=np.float32
    )
    wrist = landmarks[0].copy()
    landmarks -= wrist
    max_val = np.max(np.abs(landmarks)) + 1e-6
    landmarks /= max_val

    full = np.zeros((2, 21, 3), dtype=np.float32)
    full[0] = landmarks
    return full.flatten()