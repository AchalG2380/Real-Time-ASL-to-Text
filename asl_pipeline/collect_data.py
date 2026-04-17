import cv2
import numpy as np
import os
import time
from utils import extract_keypoints, draw_landmarks, SIGNS, FRAME_COUNT

DATA_DIR     = "data"
SAMPLES_GOAL = 50   # samples per sign — do at least 40


def count_existing(sign):
    path = os.path.join(DATA_DIR, sign)
    return len([f for f in os.listdir(path) if f.endswith(".npy")])


def collect_sign(cap, sign):
    existing = count_existing(sign)
    print(f"\n{'='*50}")
    print(f"  Collecting: {sign}  (have {existing}, need {SAMPLES_GOAL})")
    print(f"  Press SPACE to record one sample")
    print(f"  Press N to move to next sign")
    print(f"  Press Q to quit")
    print(f"{'='*50}")

    sample_num = existing

    while sample_num < SAMPLES_GOAL:
        ret, frame = cap.read()
        if not ret:
            continue

        frame = cv2.flip(frame, 1)   # mirror — more natural
        frame, detected = draw_landmarks(frame)

        # UI overlay
        cv2.rectangle(frame, (0,0), (640, 60), (50,50,50), -1)
        cv2.putText(frame, f"Sign: {sign}  [{sample_num}/{SAMPLES_GOAL}]",
                    (10, 20), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255,255,255), 2)
        cv2.putText(frame, "SPACE=record  N=next  Q=quit",
                    (10, 45), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (200,200,200), 1)

        if not detected:
            cv2.putText(frame, "NO HAND DETECTED",
                        (200, 300), cv2.FONT_HERSHEY_SIMPLEX, 1, (0,0,255), 3)

        cv2.imshow("Data Collection", frame)
        key = cv2.waitKey(1) & 0xFF

        if key == ord('q'):
            return False   # quit entirely

        if key == ord('n'):
            return True    # next sign

        if key == ord(' ') and detected:
            # ── RECORD ONE SAMPLE ──────────────────────────
            sequence = record_sequence(cap, sign, sample_num)
            if sequence is not None:
                save_path = os.path.join(DATA_DIR, sign, f"sample_{sample_num:03d}.npy")
                np.save(save_path, sequence)
                sample_num += 1
                print(f"  ✓ Saved sample {sample_num}/{SAMPLES_GOAL}")

    print(f"  ✓ Done collecting {sign}!")
    return True


def record_sequence(cap, sign, sample_num):
    """
    Countdown → record 25 frames of keypoints → return (25, 63) array.
    """
    # Countdown: 3, 2, 1
    for count in [3, 2, 1]:
        deadline = time.time() + 1.0
        while time.time() < deadline:
            ret, frame = cap.read()
            frame = cv2.flip(frame, 1)
            draw_landmarks(frame)
            cv2.rectangle(frame, (0,0), (640,480), (0,100,200), 4)
            cv2.putText(frame, str(count),
                        (290, 260), cv2.FONT_HERSHEY_SIMPLEX, 5, (0,100,200), 8)
            cv2.putText(frame, f"GET READY: {sign}",
                        (150, 60), cv2.FONT_HERSHEY_SIMPLEX, 1, (0,100,200), 2)
            cv2.imshow("Data Collection", frame)
            cv2.waitKey(1)

    # Recording phase
    sequence = []
    frames_recorded = 0

    while frames_recorded < FRAME_COUNT:
        ret, frame = cap.read()
        if not ret:
            continue

        frame = cv2.flip(frame, 1)
        draw_landmarks(frame)

        keypoints = extract_keypoints(frame)
        sequence.append(keypoints)
        frames_recorded += 1

        # Progress bar
        progress = int((frames_recorded / FRAME_COUNT) * 600)
        cv2.rectangle(frame, (0,0), (640,480), (0,255,0), 4)
        cv2.rectangle(frame, (20, 440), (20 + progress, 465), (0,255,0), -1)
        cv2.putText(frame, f"RECORDING... {frames_recorded}/{FRAME_COUNT}",
                    (150, 60), cv2.FONT_HERSHEY_SIMPLEX, 1, (0,255,0), 2)
        cv2.imshow("Data Collection", frame)
        cv2.waitKey(1)

    return np.array(sequence)   # shape: (25, 63)


def main():
    cap = cv2.VideoCapture(0)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)

    print("\nASL Data Collection Tool")
    print("Signs to collect:", SIGNS)
    print("\nTips:")
    print("  - Sign clearly and consistently")
    print("  - Vary your speed slightly across samples")
    print("  - Get teammates to record samples too")
    print("  - Good lighting matters\n")

    for sign in SIGNS:
        should_continue = collect_sign(cap, sign)
        if not should_continue:
            break

    cap.release()
    cv2.destroyAllWindows()

    # Summary
    print("\n── Collection Summary ──")
    total = 0
    for sign in SIGNS:
        count = count_existing(sign)
        total += count
        status = "✓" if count >= SAMPLES_GOAL else f"✗ need {SAMPLES_GOAL - count} more"
        print(f"  {sign:15s}: {count:3d} samples  {status}")
    print(f"\n  Total: {total} sequences saved")


if __name__ == "__main__":
    main()