import cv2
import numpy as np
import mediapipe as mp
from mediapipe.tasks import python
from mediapipe.tasks.python import vision
import urllib.request
import os

# ── Download hand landmarker model if not present ──────────────────────────
_MODEL_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'hand_landmarker.task')

if not os.path.exists(_MODEL_PATH):
    print("Downloading hand landmarker model...")
    urllib.request.urlretrieve(
        'https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/1/hand_landmarker.task',
        _MODEL_PATH
    )
    print("✓ Downloaded")


class KeypointExtractor:
    def __init__(self, max_num_hands=2, min_detection_confidence=0.7):
        options = vision.HandLandmarkerOptions(
            base_options=python.BaseOptions(model_asset_path=_MODEL_PATH),
            running_mode=vision.RunningMode.IMAGE,
            num_hands=max_num_hands,
            min_hand_detection_confidence=min_detection_confidence
        )
        self._detector = vision.HandLandmarker.create_from_options(options)

    def extract(self, frame_bgr):
        """
        Extract normalized keypoints from a BGR frame.
        Returns np.array of shape (126,) or None if no hands detected.
        """
        img_rgb = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2RGB)
        mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=img_rgb)
        results = self._detector.detect(mp_image)

        if not results.hand_landmarks:
            return None

        keypoints = np.zeros((2, 21, 3), dtype=np.float32)

        for hand_idx, hand in enumerate(results.hand_landmarks):
            if hand_idx >= 2:
                break
            landmarks = np.array([[lm.x, lm.y, lm.z] for lm in hand], dtype=np.float32)
            wrist = landmarks[0].copy()
            landmarks -= wrist
            max_val = np.max(np.abs(landmarks)) + 1e-6
            landmarks /= max_val
            keypoints[hand_idx] = landmarks

        return keypoints.flatten()

    def extract_with_handedness(self, frame_bgr):
        """
        Returns (keypoints np.array (126,), handedness_labels list of 'Left'/'Right')
        """
        img_rgb = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2RGB)
        mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=img_rgb)
        results = self._detector.detect(mp_image)

        if not results.hand_landmarks:
            return None, []

        keypoints = np.zeros((2, 21, 3), dtype=np.float32)
        handedness_labels = []

        for hand_idx, (hand, handedness) in enumerate(
            zip(results.hand_landmarks, results.handedness)
        ):
            if hand_idx >= 2:
                break
            label = handedness[0].category_name  # 'Left' or 'Right'
            handedness_labels.append(label)
            landmarks = np.array([[lm.x, lm.y, lm.z] for lm in hand], dtype=np.float32)
            wrist = landmarks[0].copy()
            landmarks -= wrist
            max_val = np.max(np.abs(landmarks)) + 1e-6
            landmarks /= max_val
            keypoints[hand_idx] = landmarks

        return keypoints.flatten(), handedness_labels

    def draw_landmarks(self, frame_bgr):
        """Draw hand skeleton on frame. Returns annotated frame."""
        img_rgb = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2RGB)
        mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=img_rgb)
        results = self._detector.detect(mp_image)

        if not results.hand_landmarks:
            return frame_bgr

        # Manual drawing since mp.solutions.drawing_utils is unavailable
        h, w = frame_bgr.shape[:2]
        for hand in results.hand_landmarks:
            # Draw points
            for lm in hand:
                cx, cy = int(lm.x * w), int(lm.y * h)
                cv2.circle(frame_bgr, (cx, cy), 4, (0, 255, 0), -1)
            # Draw connections
            connections = [
                (0,1),(1,2),(2,3),(3,4),
                (0,5),(5,6),(6,7),(7,8),
                (0,9),(9,10),(10,11),(11,12),
                (0,13),(13,14),(14,15),(15,16),
                (0,17),(17,18),(18,19),(19,20),
                (5,9),(9,13),(13,17)
            ]
            for a, b in connections:
                ax, ay = int(hand[a].x * w), int(hand[a].y * h)
                bx, by = int(hand[b].x * w), int(hand[b].y * h)
                cv2.line(frame_bgr, (ax, ay), (bx, by), (0, 200, 255), 2)

        return frame_bgr

    def get_wrist_velocity(self, prev_keypoints, curr_keypoints):
        if prev_keypoints is None or curr_keypoints is None:
            return 0.0
        return float(np.linalg.norm(curr_keypoints[:3] - prev_keypoints[:3]))

    def close(self):
        self._detector.close()


# ── Quick Test ────────────────────────────────────────────────────────────
if __name__ == "__main__":
    extractor = KeypointExtractor()
    cap = cv2.VideoCapture(0)
    print("Webcam running. Press Q to quit.")

    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            break
        frame = cv2.flip(frame, 1)
        keypoints = extractor.extract(frame)

        if keypoints is not None:
            print(f"Keypoints: {keypoints.shape}, first 6: {keypoints[:6].round(3)}")
            cv2.putText(frame, "HANDS DETECTED", (10, 30),
                        cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)
        else:
            cv2.putText(frame, "No hands", (10, 30),
                        cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 0, 255), 2)

        frame = extractor.draw_landmarks(frame)
        cv2.imshow("Keypoint Extractor Test", frame)
        if cv2.waitKey(10) & 0xFF == ord('q'):
            break

    cap.release()
    cv2.destroyAllWindows()
    extractor.close()