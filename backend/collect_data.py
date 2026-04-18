import cv2
import numpy as np
import os
import sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'asl_ml'))
from keypoint_extractor import KeypointExtractor

SAVE_DIR = os.path.join('..', 'data', 'processed')
LETTERS = list("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
SAMPLES_PER_LETTER = 200

os.makedirs(SAVE_DIR, exist_ok=True)
extractor = KeypointExtractor(max_num_hands=1, min_detection_confidence=0.3)
cap = cv2.VideoCapture(0)

print("ASL Data Collector")
print("==================")
print(f"Will collect {SAMPLES_PER_LETTER} samples per letter")
print("Press SPACE to start collecting, Q to quit\n")

for letter in LETTERS:
    print(f"\nGet ready for letter: {letter}")
    print("Position your hand and press SPACE to start...")

    while True:
        ret, frame = cap.read()
        frame = cv2.flip(frame, 1)
        cv2.putText(frame, f"Letter: {letter} — Press SPACE to start",
                    (10, 50), cv2.FONT_HERSHEY_SIMPLEX, 0.9, (0, 255, 255), 2)
        cv2.putText(frame, "Press Q to quit early",
                    (10, 90), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 200, 255), 2)
        cv2.imshow("Data Collector", frame)
        cv2.setWindowProperty("Data Collector", cv2.WND_PROP_TOPMOST, 1)
        key = cv2.waitKey(1) & 0xFF
        if key == ord(' '):
            break
        if key == ord('q'):
            cap.release()
            cv2.destroyAllWindows()
            extractor.close()
            print("\nStopped early. Collected letters saved.")
            sys.exit(0)

    samples = []
    while len(samples) < SAMPLES_PER_LETTER:
        ret, frame = cap.read()
        frame = cv2.flip(frame, 1)
        kp = extractor.extract(frame)

        if kp is not None:
            samples.append(kp)
            progress = len(samples) / SAMPLES_PER_LETTER
            bar = int(progress * 20)
            cv2.putText(frame, f"{letter}: {len(samples)}/{SAMPLES_PER_LETTER}",
                        (10, 50), cv2.FONT_HERSHEY_SIMPLEX, 1.2, (0, 255, 0), 2)
            cv2.rectangle(frame, (10, 70), (10 + bar * 15, 95), (0, 255, 0), -1)
            cv2.rectangle(frame, (10, 70), (310, 95), (255, 255, 255), 2)
        else:
            cv2.putText(frame, "No hand detected — move closer",
                        (10, 50), cv2.FONT_HERSHEY_SIMPLEX, 0.9, (0, 0, 255), 2)

        cv2.imshow("Data Collector", frame)
        cv2.setWindowProperty("Data Collector", cv2.WND_PROP_TOPMOST, 1)
        if cv2.waitKey(1) & 0xFF == ord('q'):
            cap.release()
            cv2.destroyAllWindows()
            extractor.close()
            print("\nStopped early. Collected letters saved.")
            sys.exit(0)

    arr = np.array(samples, dtype=np.float32)
    np.save(os.path.join(SAVE_DIR, f'{letter}.npy'), arr)
    print(f"  ✓ Saved {len(samples)} samples for {letter}")

cap.release()
cv2.destroyAllWindows()
extractor.close()
print("\n✓ All letters collected!")
print(f"  Saved to {os.path.abspath(SAVE_DIR)}")