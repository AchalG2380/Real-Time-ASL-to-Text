"""
collect_data.py
---------------
Interactive data collection tool.
Records 30-frame keypoint sequences for each sign.

Controls:
  SPACE  — Record one sample (hold the sign, then press)
  N      — Move to next sign
  D      — Delete last sample
  Q      — Quit
"""

import cv2
import numpy as np
import os
import time
from keypoint_extractor import KeypointExtractor

# ── Configuration ──────────────────────────────────────────────────────────
SIGNS_TO_COLLECT = [
    "HELLO", "THANK_YOU", "HOW_MUCH", "HELP",
    "YES", "NO", "PLEASE", "SORRY", "WATER", "RECEIPT"
]
SAMPLES_PER_SIGN = 30   # Target: 30 per sign
FRAMES_PER_SAMPLE = 30  # Each sample = 30 frames
DATA_DIR = "data/raw"

# ── Main ───────────────────────────────────────────────────────────────────
def count_existing(sign_name):
    path = os.path.join(DATA_DIR, sign_name)
    if not os.path.exists(path):
        return 0
    return len([f for f in os.listdir(path) if f.endswith('.npy')])

def record_sample(extractor, cap, sign_name):
    """Record FRAMES_PER_SAMPLE frames for one sign."""
    frames = []
    collecting = False
    countdown = 0
    
    while True:
        ret, frame = cap.read()
        if not ret:
            break
        frame = cv2.flip(frame, 1)
        h, w = frame.shape[:2]
        
        keypoints = extractor.extract(frame)
        
        # Draw skeleton
        frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        results = extractor.hands.process(frame_rgb)
        frame = extractor.draw_landmarks(frame, results)
        
        if collecting:
            if keypoints is not None:
                frames.append(keypoints)
            else:
                frames.append(np.zeros(126, dtype=np.float32))
            
            progress = len(frames) / FRAMES_PER_SAMPLE
            cv2.rectangle(frame, (10, h-40), (int(10 + progress*(w-20)), h-20), (0,255,0), -1)
            cv2.putText(frame, f"Recording: {len(frames)}/{FRAMES_PER_SAMPLE}", 
                        (10, h-50), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0,255,0), 2)
            
            if len(frames) >= FRAMES_PER_SAMPLE:
                return np.array(frames, dtype=np.float32)
        else:
            cv2.putText(frame, f"Sign: {sign_name}", (10, 30),
                        cv2.FONT_HERSHEY_SIMPLEX, 1.0, (255,255,255), 2)
            cv2.putText(frame, "SPACE = record  |  N = next  |  D = delete  |  Q = quit",
                        (10, h-10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (200,200,200), 1)
            
            existing = count_existing(sign_name)
            cv2.putText(frame, f"Samples collected: {existing}/{SAMPLES_PER_SIGN}",
                        (10, 70), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0,200,255), 2)
        
        cv2.imshow("ASL Data Collector", frame)
        key = cv2.waitKey(10) & 0xFF
        
        if key == ord(' ') and not collecting:
            collecting = True
            frames = []
        elif key == ord('n'):
            return None  # Skip to next sign
        elif key == ord('q'):
            return "QUIT"
    
    return None

def main():
    extractor = KeypointExtractor()
    cap = cv2.VideoCapture(0)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1280)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)
    
    print("\n=== ASL Data Collector ===")
    print(f"Target: {SAMPLES_PER_SIGN} samples × {FRAMES_PER_SAMPLE} frames per sign")
    print("Controls: SPACE=record, N=next sign, D=delete last, Q=quit\n")
    
    for sign in SIGNS_TO_COLLECT:
        sign_dir = os.path.join(DATA_DIR, sign)
        os.makedirs(sign_dir, exist_ok=True)
        
        print(f"\n--- Collecting: {sign} ---")
        print(f"  Show the sign and press SPACE to record.")
        
        while count_existing(sign) < SAMPLES_PER_SIGN:
            result = record_sample(extractor, cap, sign)
            
            if result is None:
                continue
            if isinstance(result, str) and result == "QUIT":
                cap.release()
                cv2.destroyAllWindows()
                extractor.close()
                return
            
            # Save sample
            idx = count_existing(sign)
            save_path = os.path.join(sign_dir, f"sample_{idx:03d}.npy")
            np.save(save_path, result)
            print(f"  ✓ Saved {save_path}  ({idx+1}/{SAMPLES_PER_SIGN})")
        
        print(f"  ✓ {sign} complete!")
    
    print("\n✓ All signs collected! Ready to train.")
    cap.release()
    cv2.destroyAllWindows()
    extractor.close()

if __name__ == "__main__":
    main()