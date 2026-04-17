import cv2
import numpy as np
import mediapipe as mp


class KeypointExtractor:
    def __init__(self, max_num_hands=2, min_detection_confidence=0.7, min_tracking_confidence=0.5):
        self.mp_hands = mp.solutions.hands
        self.mp_drawing = mp.solutions.drawing_utils
        self.mp_drawing_styles = mp.solutions.drawing_styles

        self.hands = self.mp_hands.Hands(
            static_image_mode=False,
            max_num_hands=max_num_hands,
            min_detection_confidence=min_detection_confidence,
            min_tracking_confidence=min_tracking_confidence
        )

    def extract(self, frame_bgr):
        """
        Extract normalized keypoints from a BGR frame.

        Returns:
            np.array of shape (126,) — 21 landmarks × 3 (x,y,z) × 2 hands
            Returns None if no hands detected.
        """
        # Convert BGR to RGB for MediaPipe
        frame_rgb = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2RGB)
        frame_rgb.flags.writeable = False
        results = self.hands.process(frame_rgb)
        frame_rgb.flags.writeable = True

        if not results.multi_hand_landmarks:
            return None

        # Build feature vector for up to 2 hands
        keypoints = np.zeros((2, 21, 3), dtype=np.float32)  # (hands, landmarks, xyz)

        for hand_idx, hand_landmarks in enumerate(results.multi_hand_landmarks):
            if hand_idx >= 2:
                break

            landmarks = np.array(
                [[lm.x, lm.y, lm.z] for lm in hand_landmarks.landmark],
                dtype=np.float32
            )

            # Normalize relative to wrist (landmark 0)
            # This makes the model translation-invariant
            wrist = landmarks[0].copy()
            landmarks -= wrist

            # Scale normalization: divide by max absolute value
            max_val = np.max(np.abs(landmarks)) + 1e-6
            landmarks /= max_val

            keypoints[hand_idx] = landmarks

        # Flatten: (2, 21, 3) -> (126,)
        return keypoints.flatten()

    def extract_with_handedness(self, frame_bgr):
        """
        Extract keypoints with handedness info.
        Returns tuple: (keypoints, handedness_labels)
        handedness_labels: list of 'Left' or 'Right'
        """
        frame_rgb = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2RGB)
        frame_rgb.flags.writeable = False
        results = self.hands.process(frame_rgb)
        frame_rgb.flags.writeable = True

        if not results.multi_hand_landmarks:
            return None, []

        keypoints = np.zeros((2, 21, 3), dtype=np.float32)
        handedness_labels = []

        for hand_idx, (hand_landmarks, handedness) in enumerate(
            zip(results.multi_hand_landmarks, results.multi_handedness)
        ):
            if hand_idx >= 2:
                break

            label = handedness.classification[0].label
            handedness_labels.append(label)

            landmarks = np.array(
                [[lm.x, lm.y, lm.z] for lm in hand_landmarks.landmark],
                dtype=np.float32
            )

            wrist = landmarks[0].copy()
            landmarks -= wrist
            max_val = np.max(np.abs(landmarks)) + 1e-6
            landmarks /= max_val

            keypoints[hand_idx] = landmarks

        return keypoints.flatten(), handedness_labels

    def draw_landmarks(self, frame_bgr, results=None):
        """Draw landmarks on frame for visualization."""
        if results is None:
            frame_rgb = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2RGB)
            results = self.hands.process(frame_rgb)

        if results.multi_hand_landmarks:
            for hand_landmarks in results.multi_hand_landmarks:
                self.mp_drawing.draw_landmarks(
                    frame_bgr,
                    hand_landmarks,
                    self.mp_hands.HAND_CONNECTIONS,
                    self.mp_drawing_styles.get_default_hand_landmarks_style(),
                    self.mp_drawing_styles.get_default_hand_connections_style()
                )
        return frame_bgr

    def get_wrist_velocity(self, prev_keypoints, curr_keypoints):
        """
        Calculate wrist movement velocity between frames.
        Used for sign boundary detection.
        Returns scalar velocity value.
        """
        if prev_keypoints is None or curr_keypoints is None:
            return 0.0

        # Wrist is index 0 in the keypoint vector (first 3 values)
        prev_wrist = prev_keypoints[:3]
        curr_wrist = curr_keypoints[:3]
        return float(np.linalg.norm(curr_wrist - prev_wrist))

    def close(self):
        self.hands.close()


# ─── Quick Test ──────────────────────────────────────────────────────────────
if __name__ == "__main__":
    extractor = KeypointExtractor()
    cap = cv2.VideoCapture(0)

    print("Webcam running. Press Q to quit.")
    print("Show your hands — keypoints will be printed.")

    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            break

        # Flip for mirror view
        frame = cv2.flip(frame, 1)

        keypoints = extractor.extract(frame)

        if keypoints is not None:
            print(f"Keypoints shape: {keypoints.shape}, first 6 values: {keypoints[:6].round(3)}")
            cv2.putText(frame, "HANDS DETECTED", (10, 30),
                        cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)
        else:
            cv2.putText(frame, "No hands", (10, 30),
                        cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 0, 255), 2)

        # Draw skeleton
        frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        results = extractor.hands.process(frame_rgb)
        frame = extractor.draw_landmarks(frame, results)

        cv2.imshow("Keypoint Extractor Test", frame)
        if cv2.waitKey(10) & 0xFF == ord('q'):
            break

    cap.release()
    cv2.destroyAllWindows()
    extractor.close()
