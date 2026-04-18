import cv2
import numpy as np
import mediapipe as mp

_mp_hands = mp.solutions.hands
_detector = _mp_hands.Hands(
    static_image_mode=True,
    max_num_hands=1,
    min_detection_confidence=0.3
)

def extract_keypoints_from_bytes(image_bytes: bytes):
    arr = np.frombuffer(image_bytes, np.uint8)
    frame = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    if frame is None:
        return None

    frame = cv2.resize(frame, (960, 720))
    img_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    results = _detector.process(img_rgb)

    if not results.multi_hand_landmarks:
        return None

    landmarks = np.array(
        [[lm.x, lm.y, lm.z] for lm in results.multi_hand_landmarks[0].landmark],
        dtype=np.float32
    )
    wrist = landmarks[0].copy()
    landmarks -= wrist
    max_val = np.max(np.abs(landmarks)) + 1e-6
    landmarks /= max_val

    full = np.zeros((2, 21, 3), dtype=np.float32)
    full[0] = landmarks
    return full.flatten()