import os
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3'

import cv2
import mediapipe as mp
import numpy as np
import tensorflow as tf
import json
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import (
    LSTM, Dense, Dropout, Conv1D, MaxPooling1D,
    BatchNormalization, GlobalAveragePooling1D,
    Bidirectional, InputLayer
)

MAX_FRAMES       = 40
FEAT_SIZE        = 84
CONF_THRESH      = 0.50        # lowered slightly — 55% was blocking some valid signs
CONSEC_NEEDED    = 4           # 4 consecutive frames (was 5 — too slow for some signs)
COOLDOWN_FRAMES  = 15          # shorter cooldown so next sign can start sooner
EMA_ALPHA        = 0.6         # faster response (was 0.4 — too sluggish, 'when' took 50+ frames)
MARGIN           = 0.10        # top must beat 2nd by 10% (was 15% — killed 'yes' at 53% vs 38%)

META = {}
if os.path.exists('model_meta.json'):
    with open('model_meta.json') as f:
        META = json.load(f)
    MAX_FRAMES = META.get('max_frames', MAX_FRAMES)
    FEAT_SIZE  = META.get('feat_size',  FEAT_SIZE)
    print(f"model_meta.json: winner={META.get('winner','?')}  val_acc={META.get('val_acc',0)*100:.1f}%")
else:
    print("No model_meta.json — using defaults")

classes = np.load('Final_ASL_Classes.npy', allow_pickle=True)
classes = [str(c) for c in classes]
N = len(classes)
print(f"Classes ({N}): {classes}")

def build_conv1d(fr, ft, nc):
    return Sequential([
        InputLayer(input_shape=(fr, ft)),
        BatchNormalization(),
        Conv1D(64, 3, activation='relu', padding='same'),
        MaxPooling1D(2), Dropout(0.25),
        Conv1D(128, 3, activation='relu', padding='same'),
        MaxPooling1D(2), Dropout(0.25),
        GlobalAveragePooling1D(),
        Dense(128, activation='relu'), Dropout(0.4),
        Dense(nc, activation='softmax')
    ], name='Conv1D')

def build_bilstm(fr, ft, nc):
    return Sequential([
        InputLayer(input_shape=(fr, ft)),
        BatchNormalization(),
        Bidirectional(LSTM(64, return_sequences=True, dropout=0.2)), Dropout(0.3),
        Bidirectional(LSTM(64, return_sequences=False, dropout=0.2)), Dropout(0.3),
        Dense(64, activation='relu'), Dropout(0.4),
        Dense(nc, activation='softmax')
    ], name='BiLSTM')

def build_old_lstm(fr, ft, nc):
    return Sequential([
        InputLayer(input_shape=(fr, ft)),
        LSTM(64, return_sequences=True, activation='tanh'), Dropout(0.2),
        LSTM(128, activation='tanh'), Dropout(0.2),
        Dense(64, activation='relu'),
        Dense(nc, activation='softmax')
    ], name='OldLSTM')

def try_load_full(path):
    try:
        m = tf.keras.models.load_model(path, compile=False)
        m.compile(optimizer='adam', loss='categorical_crossentropy', metrics=['accuracy'])
        print(f"  Full model loaded from {path}")
        return m
    except Exception as e:
        print(f"  Full load failed: {e}")
        return None

def try_weights(builder_fn, path, label):
    try:
        m = builder_fn(MAX_FRAMES, FEAT_SIZE, N)
        m.compile(optimizer='adam', loss='categorical_crossentropy', metrics=['accuracy'])
        m.load_weights(path)
        print(f"  Weights OK: {label}")
        return m
    except Exception as e:
        print(f"  Weights failed ({label}): {e}")
        return None

WEIGHT_FILES = [
    'Final_ASL_Model_fixed.weights.h5',
    'Final_ASL_Model_fixed.h5',
    'Final_ASL_Model.h5',
]

winner = META.get('winner', 'Conv1D')
if winner == 'BiLSTM':
    arch_order = [('BiLSTM', build_bilstm), ('Conv1D', build_conv1d), ('OldLSTM', build_old_lstm)]
else:
    arch_order = [('Conv1D', build_conv1d), ('BiLSTM', build_bilstm), ('OldLSTM', build_old_lstm)]

model = None
for path in WEIGHT_FILES:
    if not os.path.exists(path):
        continue
    print(f"\nTrying: {path}")
    model = try_load_full(path)
    if model:
        break
    for arch_name, builder in arch_order:
        print(f"  Rebuilding {arch_name}...")
        model = try_weights(builder, path, arch_name)
        if model:
            break
    if model:
        break

if model is None:
    print("\nERROR: Could not load model.")
    print("Present:", [f for f in WEIGHT_FILES if os.path.exists(f)])
    print("Run retrain_quick.py first.")
    exit()

print(f"\nModel ready!")

mp_hands = mp.solutions.hands
mp_draw  = mp.solutions.drawing_utils
hands    = mp_hands.Hands(max_num_hands=2, min_detection_confidence=0.5, min_tracking_confidence=0.5)

def open_camera():
    for backend in [cv2.CAP_DSHOW, None]:
        for idx in range(5):
            args = (idx, backend) if backend is not None else (idx,)
            cap  = cv2.VideoCapture(*args)
            if cap.isOpened():
                ret, frame = cap.read()
                if ret and frame is not None:
                    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
                    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
                    print(f"Camera index={idx}")
                    return cap
            cap.release()
    return None

print("Opening camera...")
cap = open_camera()
if cap is None:
    print("ERROR: No camera found.")
    exit()

W = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
H = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
print(f"Camera {W}x{H} | Q=quit C=clear\n" + "-"*50)

sequence       = []
confirmed_word = ""
confirmed_conf = 0.0
cooldown       = 0
sentence       = []
last_probs     = np.zeros(N)

# Consecutive-frame tracking (replaces noisy vote buffer)
consec_word    = ""
consec_count   = 0
smoothed_probs = np.zeros(N)   # EMA-smoothed probabilities

def extract_keypoints(results):
    """Extract 84 features — MUST match record_dataset.py exactly.
    Uses detection order (enumerate) and raw absolute (x, y) coordinates.
    """
    keypoints = np.zeros(84)
    if results.multi_hand_landmarks:
        for i, hand_landmarks in enumerate(results.multi_hand_landmarks):
            if i > 1: break
            offset = i * 42
            for j, lm in enumerate(hand_landmarks.landmark):
                keypoints[offset + j * 2]     = lm.x
                keypoints[offset + j * 2 + 1] = lm.y
    return keypoints

while cap.isOpened():
    ret, frame = cap.read()
    if not ret: break

    # No flip — matches record_dataset.py which had no flip
    rgb     = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    results = hands.process(rgb)

    if results.multi_hand_landmarks:
        for h in results.multi_hand_landmarks:
            mp_draw.draw_landmarks(frame, h, mp_hands.HAND_CONNECTIONS)

    kp = extract_keypoints(results)
    sequence.append(kp)
    sequence = sequence[-MAX_FRAMES:]
    if cooldown > 0: cooldown -= 1
    hand_active = np.any(kp != 0)

    if len(sequence) == MAX_FRAMES and hand_active and cooldown == 0:
        inp   = np.expand_dims(np.array(sequence, dtype='float32'), axis=0)
        raw_probs = model(inp, training=False)[0].numpy()

        # EMA smoothing — dampens single-frame spikes
        if np.all(smoothed_probs == 0):
            smoothed_probs = raw_probs.copy()
        else:
            smoothed_probs = EMA_ALPHA * raw_probs + (1 - EMA_ALPHA) * smoothed_probs

        probs = smoothed_probs
        last_probs = probs
        top_idx  = np.argmax(probs)
        top_conf = float(probs[top_idx])
        top_word = classes[top_idx]
        sec_idx  = np.argsort(probs)[-2]
        sec_conf = float(probs[sec_idx])

        print(f"  {top_word:12s} {top_conf*100:5.1f}%  |  "
              f"{classes[sec_idx]:12s} {sec_conf*100:4.1f}%  |  "
              f"consec {consec_count}/{CONSEC_NEEDED}")

        # ── Consecutive-frame confirmation ─────────────────────────
        # Top class must be above threshold AND have a clear margin
        # over second place to prevent ambiguous near-ties
        margin_ok = (top_conf - sec_conf) >= MARGIN
        if top_conf >= CONF_THRESH and margin_ok:
            if top_word == consec_word:
                consec_count += 1
            else:
                consec_word  = top_word
                consec_count = 1
        else:
            # Confidence too low or no clear winner — reset streak
            consec_count = 0
            consec_word  = ""

        if consec_count >= CONSEC_NEEDED:
            confirmed_word = consec_word
            confirmed_conf = top_conf
            cooldown       = COOLDOWN_FRAMES
            # Clear sequence so next sign starts fresh (no stale frames)
            sequence.clear()
            smoothed_probs = np.zeros(N)
            consec_word  = ""
            consec_count = 0
            if not sentence or sentence[-1] != confirmed_word:
                sentence.append(confirmed_word)
                if len(sentence) > 6: sentence.pop(0)
            print(f">>> CONFIRMED: {confirmed_word} ({confirmed_conf*100:.0f}%)")
    elif not hand_active:
        consec_word  = ""
        consec_count = 0
        smoothed_probs = np.zeros(N)

    # UI
    cv2.rectangle(frame, (0, 0), (W, 95), (15, 15, 15), -1)
    wcol = (0, 255, 100) if confirmed_word else (130, 130, 130)
    dtxt = (confirmed_word + f"  {int(confirmed_conf*100)}%") if confirmed_word else "Show hand..."
    cv2.putText(frame, dtxt, (12, 55), cv2.FONT_HERSHEY_SIMPLEX, 1.3, wcol, 2, cv2.LINE_AA)

    bx = W - 235
    for rank, idx in enumerate(np.argsort(last_probs)[-3:][::-1]):
        by  = 14 + rank * 24
        bw  = int(200 * last_probs[idx])
        cv2.rectangle(frame, (bx, by), (bx+200, by+17), (40,40,40), -1)
        if bw > 0:
            cv2.rectangle(frame, (bx, by), (bx+bw, by+17), (0,200,80) if rank==0 else (0,110,200), -1)
        cv2.putText(frame, f"{classes[idx][:11]}  {last_probs[idx]*100:.0f}%",
                    (bx+4, by+13), cv2.FONT_HERSHEY_SIMPLEX, 0.4, (220,220,220), 1)

    vpct = min(consec_count / CONSEC_NEEDED, 1.0)
    cv2.rectangle(frame, (0,88), (W,95), (25,25,25), -1)
    cv2.rectangle(frame, (0,88), (int(W*vpct),95), (0,170,255), -1)
    if cooldown > 0:
        cv2.rectangle(frame, (0,88), (int(W*(1-cooldown/COOLDOWN_FRAMES)),95), (0,210,255), -1)

    dot_col = (0,255,0) if hand_active else (0,0,210)
    cv2.circle(frame, (20,115), 8, dot_col, -1)
    cv2.putText(frame, "Hand" if hand_active else "No hand", (34,120), cv2.FONT_HERSHEY_SIMPLEX, 0.45, dot_col, 1)

    cv2.rectangle(frame, (0,H-38), (W,H), (15,15,15), -1)
    stxt = "  ›  ".join(sentence) if sentence else "Sentence appears here"
    scol = (200,200,255) if sentence else (70,70,70)
    cv2.putText(frame, stxt, (10,H-12), cv2.FONT_HERSHEY_SIMPLEX, 0.6, scol, 1, cv2.LINE_AA)
    cv2.putText(frame, "Q=quit  C=clear", (W-130,H-12), cv2.FONT_HERSHEY_SIMPLEX, 0.4, (70,70,70), 1)

    cv2.imshow("SignBridge  ASL Live", frame)
    key = cv2.waitKey(1) & 0xFF
    if key == ord('q'): break
    if key == ord('c'):
        sentence.clear(); confirmed_word=""; confirmed_conf=0.0
        sequence.clear(); last_probs=np.zeros(N)
        consec_word=""; consec_count=0; smoothed_probs=np.zeros(N)
        print("--- Cleared ---")

cap.release()
cv2.destroyAllWindows()
hands.close()
print("Done.")