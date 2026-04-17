import cv2
import numpy as np
import tensorflow as tf
import time
import os
from collections import deque
from utils import (extract_keypoints, draw_landmarks,
                   SIGN_TO_SENTENCE, FRAME_COUNT, NUM_FEATURES)

MODEL_DIR = "models"

# ── Tuning knobs ─────────────────────────────────────────────────
CONFIDENCE_THRESHOLD = 0.75   # below this → ignore prediction
VELOCITY_THRESHOLD   = 0.02   # below this → hand is "still" → trigger classification
SIGN_COOLDOWN        = 1.5    # seconds before same sign can repeat
SENTENCE_GAP         = 3.0    # seconds of stillness → finalize sentence


class ASLInference:
    def __init__(self):
        # Load TFLite model
        model_path  = os.path.join(MODEL_DIR, "asl_model.tflite")
        classes_path = os.path.join(MODEL_DIR, "classes.npy")

        self.interpreter = tf.lite.Interpreter(model_path=model_path)
        self.interpreter.allocate_tensors()
        self.input_details  = self.interpreter.get_input_details()
        self.output_details = self.interpreter.get_output_details()

        self.classes = np.load(classes_path, allow_pickle=True)

        # Frame buffer — rolling window
        self.frame_buffer  = deque(maxlen=FRAME_COUNT)
        self.prev_keypoints = np.zeros(NUM_FEATURES)

        # Sentence building
        self.current_sentence  = []
        self.last_sign_time    = 0
        self.last_sign         = None
        self.finalized_sentences = []

        print(f"Model loaded. Classes: {list(self.classes)}")

    def predict(self, keypoints):
        """Run TFLite inference on a (25, 63) sequence."""
        seq   = np.array(list(self.frame_buffer), dtype=np.float32)
        seq   = seq[np.newaxis, ...]   # (1, 25, 63)

        self.interpreter.set_tensor(self.input_details[0]['index'], seq)
        self.interpreter.invoke()
        probs = self.interpreter.get_tensor(self.output_details[0]['index'])[0]

        idx        = np.argmax(probs)
        confidence = probs[idx]
        sign       = self.classes[idx]
        return sign, float(confidence)

    def compute_velocity(self, keypoints):
        """Mean absolute change in keypoints vs previous frame."""
        vel = np.mean(np.abs(keypoints - self.prev_keypoints))
        self.prev_keypoints = keypoints.copy()
        return vel

    def process_frame(self, keypoints, hand_detected):
        """
        Main per-frame logic.
        Returns dict with current state for UI.
        """
        now      = time.time()
        velocity = self.compute_velocity(keypoints) if hand_detected else 0.0
        sign_just_confirmed = None

        if hand_detected:
            self.frame_buffer.append(keypoints)

        # Classify when buffer is full AND hand just became still
        if (len(self.frame_buffer) == FRAME_COUNT
                and hand_detected
                and velocity < VELOCITY_THRESHOLD):

            sign, confidence = self.predict(keypoints)

            # Cooldown check — don't repeat same sign instantly
            time_since_last = now - self.last_sign_time
            if (confidence >= CONFIDENCE_THRESHOLD
                    and not (sign == self.last_sign and time_since_last < SIGN_COOLDOWN)):

                sentence_text = SIGN_TO_SENTENCE.get(sign, sign)
                self.current_sentence.append(sentence_text)
                self.last_sign      = sign
                self.last_sign_time = now
                sign_just_confirmed = sign
                self.frame_buffer.clear()   # reset buffer after confirmation

        # Finalize sentence after long pause
        if (self.current_sentence
                and not hand_detected
                and (now - self.last_sign_time) > SENTENCE_GAP):
            final = " ".join(self.current_sentence)
            self.finalized_sentences.append(final)
            self.current_sentence = []

        return {
            "hand_detected":  hand_detected,
            "velocity":       round(velocity, 4),
            "buffer_fill":    len(self.frame_buffer),
            "sign_confirmed": sign_just_confirmed,
            "current_phrase": " ".join(self.current_sentence),
            "finalized":      self.finalized_sentences[-1] if self.finalized_sentences else "",
            "sentence_history": list(self.finalized_sentences),
            "status": "signing" if hand_detected else "waiting"
        }


def run_live_demo():
    """Standalone live demo with OpenCV window."""
    engine = ASLInference()
    cap    = cv2.VideoCapture(0)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)

    print("Live inference running. Press Q to quit.")

    while True:
        ret, frame = cap.read()
        if not ret:
            continue

        frame         = cv2.flip(frame, 1)
        frame, detected = draw_landmarks(frame)
        keypoints     = extract_keypoints(frame)
        state         = engine.process_frame(keypoints, detected)

        # ── HUD overlay ──────────────────────────────────────────
        overlay = frame.copy()
        cv2.rectangle(overlay, (0,0), (640, 80), (20,20,20), -1)
        cv2.addWeighted(overlay, 0.7, frame, 0.3, 0, frame)

        # Status
        color = (0,255,0) if detected else (0,0,255)
        cv2.putText(frame, f"Status: {state['status'].upper()}",
                    (10,25), cv2.FONT_HERSHEY_SIMPLEX, 0.7, color, 2)

        # Buffer fill bar
        fill_pct = state['buffer_fill'] / FRAME_COUNT
        cv2.rectangle(frame, (10,40), (200,55), (60,60,60), -1)
        cv2.rectangle(frame, (10,40), (10 + int(190*fill_pct), 55), (0,200,255), -1)
        cv2.putText(frame, f"Buffer: {state['buffer_fill']}/{FRAME_COUNT}",
                    (10,70), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (200,200,200), 1)

        # Confirmed sign flash
        if state['sign_confirmed']:
            cv2.putText(frame, f"✓ {state['sign_confirmed']}",
                        (240, 50), cv2.FONT_HERSHEY_SIMPLEX, 1.5, (0,255,100), 3)

        # Current phrase
        phrase = state['current_phrase']
        if phrase:
            cv2.rectangle(frame, (0, 380), (640, 420), (0,80,0), -1)
            cv2.putText(frame, phrase,
                        (10, 408), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255,255,255), 2)

        # Last finalized sentence
        final = state['finalized']
        if final:
            cv2.rectangle(frame, (0, 430), (640, 480), (0,40,80), -1)
            cv2.putText(frame, f">> {final}",
                        (10, 460), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (100,255,255), 2)

        cv2.imshow("ASL Live Demo", frame)
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    cap.release()
    cv2.destroyAllWindows()


if __name__ == "__main__":
    run_live_demo()