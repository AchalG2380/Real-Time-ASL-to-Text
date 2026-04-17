import mediapipe as mp
import numpy as np
import cv2

mp_hands = mp.solutions.hands
mp_draw  = mp.solutions.drawing_utils

hands_detector = mp_hands.Hands(
    static_image_mode=False,
    max_num_hands=2,
    min_detection_confidence=0.7,
    min_tracking_confidence=0.6
)

SIGN_TO_SENTENCE = {
    "HELP":      "I need help",
    "THANK_YOU": "Thank you!",
    "HOW_MUCH":  "How much does this cost?",
    "BATHROOM":  "Where is the bathroom?",
    "BAG":       "Can I get a bag?",
    "WANT":      "I want this item",
    "REPEAT":    "Could you say that again?",
    "HELLO":     "Hello!",
}

SIGNS        = list(SIGN_TO_SENTENCE.keys())
NUM_SIGNS    = len(SIGNS)
FRAME_COUNT  = 25
NUM_FEATURES = 63


def extract_keypoints(frame):
    rgb    = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    result = hands_detector.process(rgb)

    if result.multi_hand_landmarks:
        hand   = result.multi_hand_landmarks[0]
        lm     = hand.landmark
        coords = np.array([[l.x, l.y, l.z] for l in lm])  # (21, 3)

        # Wrist-relative — removes hand position on screen
        wrist  = coords[0]
        coords = coords - wrist

        # Scale normalisation — removes hand size differences
        max_val = np.max(np.abs(coords)) + 1e-6
        coords  = coords / max_val

        return coords.flatten()  # (63,)

    return np.zeros(NUM_FEATURES)


def draw_landmarks(frame, draw_box=True):
    rgb      = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    result   = hands_detector.process(rgb)
    detected = False

    if result.multi_hand_landmarks:
        detected = True
        for hand_lm in result.multi_hand_landmarks:
            mp_draw.draw_landmarks(
                frame, hand_lm, mp_hands.HAND_CONNECTIONS,
                mp_draw.DrawingSpec(color=(0, 255, 0), thickness=2, circle_radius=3),
                mp_draw.DrawingSpec(color=(255, 255, 255), thickness=2)
            )

        if draw_box:
            h, w, _ = frame.shape
            for hand_lm in result.multi_hand_landmarks:
                xs = [l.x * w for l in hand_lm.landmark]
                ys = [l.y * h for l in hand_lm.landmark]
                cv2.rectangle(
                    frame,
                    (int(min(xs)) - 20, int(min(ys)) - 20),
                    (int(max(xs)) + 20, int(max(ys)) + 20),
                    (0, 255, 0), 2
                )

    return frame, detected