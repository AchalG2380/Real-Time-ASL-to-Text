"""
train_words.py  —  ASL Words Model Training with MLflow Tracking
=================================================================
Trains three architectures (Conv1D, BiLSTM, OldLSTM) on the ASL word
keypoint dataset, picks the winner by validation accuracy, saves weights
+ model_meta.json, and logs every experiment to MLflow.

Expected data layout
--------------------
../data/words/<word_label>/  — subdirs each containing .npy sequence files
  OR
../data/words_sequences.npz  — pre-stacked {X: (N,40,84), y: (N,)}

Usage
-----
  cd Words
  python train_words.py                    # uses default data dir
  python train_words.py --data ../mydata   # custom data path
  python train_words.py --epochs 100 --batch 32
"""

import os, sys, json, argparse
import numpy as np
import tensorflow as tf
import keras
from keras.models import Sequential
from keras.layers import (
    LSTM, Dense, Dropout, Conv1D, MaxPooling1D,
    BatchNormalization, GlobalAveragePooling1D, Bidirectional,
)
from keras.utils import to_categorical
from sklearn.model_selection import train_test_split

# ── Path setup so mlflow_utils can be found from either venv ──────────────
WORDS_DIR  = os.path.dirname(os.path.abspath(__file__))
BACKEND_DIR = os.path.join(WORDS_DIR, '..', 'backend')
sys.path.insert(0, BACKEND_DIR)
from mlflow_utils import ASLRun  # shared MLflow helper


# ─────────────────────────────────────────────────────────────────────────────
# CLI args
# ─────────────────────────────────────────────────────────────────────────────
parser = argparse.ArgumentParser(description="Train ASL Words model")
parser.add_argument("--data",    default=os.path.join(WORDS_DIR, '..', 'data', 'words'),
                    help="Path to word-sequence data directory or .npz file")
parser.add_argument("--epochs",  type=int, default=120, help="Max epochs (default 120)")
parser.add_argument("--batch",   type=int, default=32,  help="Batch size (default 32)")
parser.add_argument("--frames",  type=int, default=40,  help="Sequence length (default 40)")
parser.add_argument("--feats",   type=int, default=84,  help="Feature size (default 84)")
parser.add_argument("--augment", type=int, default=3,   help="Augmentation factor (default 3)")
args = parser.parse_args()

MAX_FRAMES   = args.frames
FEAT_SIZE    = args.feats
MAX_EPOCHS   = args.epochs
BATCH_SIZE   = args.batch
AUG_FACTOR   = args.augment
DATA_PATH    = args.data

CLASSES_FILE = os.path.join(WORDS_DIR, 'Final_ASL_Classes.npy')
META_FILE    = os.path.join(WORDS_DIR, 'model_meta.json')
WEIGHTS_OUT  = os.path.join(WORDS_DIR, 'Final_ASL_Model_fixed.weights.h5')


# ─────────────────────────────────────────────────────────────────────────────
# Data loading
# ─────────────────────────────────────────────────────────────────────────────
def load_data(data_path: str):
    """
    Supports two layouts:
    1. data_path/*.npz  — single file {X, y, classes}
    2. data_path/<word>/<idx>.npy  — directory of per-class, per-sample .npy files
    3. data_path/<word>.npy  — one .npy per class, shape (N, MAX_FRAMES, FEAT_SIZE)
    """
    X_all, y_all, classes = [], [], []

    # ── Layout 1: pre-stacked .npz ────────────────────────────────────────
    if data_path.endswith('.npz') and os.path.isfile(data_path):
        archive = np.load(data_path, allow_pickle=True)
        X_all   = archive['X']
        y_all   = archive['y']
        classes = list(archive['classes'])
        print(f"[Data] Loaded from .npz  →  {X_all.shape}  classes: {classes}")
        return np.array(X_all, dtype=np.float32), np.array(y_all, dtype=np.int32), classes

    if not os.path.isdir(data_path):
        raise FileNotFoundError(
            f"Data path not found: {data_path}\n"
            "Run your data-collection / recording script first, or pass --data <path>."
        )

    items = sorted(os.listdir(data_path))

    # ── Layout 2: <word>/<sample>.npy flat directories ────────────────────
    npy_dirs = [d for d in items if os.path.isdir(os.path.join(data_path, d))]
    npy_files = [f for f in items if f.endswith('.npy')]

    if npy_dirs:
        for i, word in enumerate(npy_dirs):
            word_dir = os.path.join(data_path, word)
            for fname in sorted(os.listdir(word_dir)):
                if not fname.endswith('.npy'):
                    continue
                seq = np.load(os.path.join(word_dir, fname))
                if seq.shape != (MAX_FRAMES, FEAT_SIZE):
                    seq = seq[:MAX_FRAMES] if len(seq) >= MAX_FRAMES else np.pad(
                        seq, ((0, MAX_FRAMES - len(seq)), (0, 0))
                    )
                X_all.append(seq.astype(np.float32))
                y_all.append(i)
            classes.append(word)
            print(f"  [Data] {word}: collected so far {y_all.count(i)} sequences")

    # ── Layout 3: one .npy per class, shape (N, frames, feats) ───────────
    elif npy_files:
        for i, fname in enumerate(npy_files):
            word = fname.replace('.npy', '')
            arr  = np.load(os.path.join(data_path, fname), allow_pickle=True)
            for seq in arr:
                if seq.shape != (MAX_FRAMES, FEAT_SIZE):
                    seq = seq[:MAX_FRAMES] if len(seq) >= MAX_FRAMES else np.pad(
                        seq, ((0, MAX_FRAMES - len(seq)), (0, 0))
                    )
                X_all.append(seq.astype(np.float32))
                y_all.append(i)
            classes.append(word)
            print(f"  [Data] {word}: {len(arr)} sequences")
    else:
        raise ValueError(f"No recognizable data format found in: {data_path}")

    return np.array(X_all, dtype=np.float32), np.array(y_all, dtype=np.int32), classes


# ─────────────────────────────────────────────────────────────────────────────
# Data augmentation  (small Gaussian noise — preserves temporal pattern)
# ─────────────────────────────────────────────────────────────────────────────
def augment(X, y, factor):
    X_aug, y_aug = [X], [y]
    for _ in range(factor):
        noise = np.random.normal(0, 0.005, X.shape).astype(np.float32)
        X_aug.append(X + noise)
        y_aug.append(y)
    return np.concatenate(X_aug), np.concatenate(y_aug)


# ─────────────────────────────────────────────────────────────────────────────
# Model architectures
# ─────────────────────────────────────────────────────────────────────────────
def build_conv1d(fr, ft, nc):
    return Sequential([
        keras.Input(shape=(fr, ft)),
        BatchNormalization(),
        Conv1D(64, 3, activation='relu', padding='same'), MaxPooling1D(2), Dropout(0.25),
        Conv1D(128, 3, activation='relu', padding='same'), MaxPooling1D(2), Dropout(0.25),
        GlobalAveragePooling1D(),
        Dense(128, activation='relu'), Dropout(0.4),
        Dense(nc, activation='softmax'),
    ], name='Conv1D')


def build_bilstm(fr, ft, nc):
    return Sequential([
        keras.Input(shape=(fr, ft)),
        BatchNormalization(),
        Bidirectional(LSTM(64, return_sequences=True, dropout=0.2)), Dropout(0.3),
        Bidirectional(LSTM(64, return_sequences=False, dropout=0.2)), Dropout(0.3),
        Dense(64, activation='relu'), Dropout(0.4),
        Dense(nc, activation='softmax'),
    ], name='BiLSTM')


def build_old_lstm(fr, ft, nc):
    return Sequential([
        keras.Input(shape=(fr, ft)),
        LSTM(64, return_sequences=True, activation='tanh'), Dropout(0.2),
        LSTM(128, activation='tanh'), Dropout(0.2),
        Dense(64, activation='relu'),
        Dense(nc, activation='softmax'),
    ], name='OldLSTM')


ARCHITECTURES = [
    ('Conv1D',  build_conv1d),
    ('BiLSTM',  build_bilstm),
    ('OldLSTM', build_old_lstm),
]


# ─────────────────────────────────────────────────────────────────────────────
# Training helper  (one MLflow child run per architecture)
# ─────────────────────────────────────────────────────────────────────────────
def train_arch(arch_name, builder_fn, X_tr, y_tr, X_val, y_val,
               n_classes, parent_run_id):

    model = builder_fn(MAX_FRAMES, FEAT_SIZE, n_classes)
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=0.001),
        loss='categorical_crossentropy',
        metrics=['accuracy'],
    )

    callbacks = [
        tf.keras.callbacks.EarlyStopping(
            monitor='val_accuracy', patience=15,
            restore_best_weights=True, verbose=1,
        ),
        tf.keras.callbacks.ReduceLROnPlateau(
            monitor='val_loss', factor=0.5,
            patience=7, min_lr=1e-6, verbose=1,
        ),
    ]

    params = {
        "architecture":        arch_name,
        "n_classes":           n_classes,
        "n_train":             len(X_tr),
        "n_val":               len(X_val),
        "max_frames":          MAX_FRAMES,
        "feat_size":           FEAT_SIZE,
        "epochs":              MAX_EPOCHS,
        "batch_size":          BATCH_SIZE,
        "learning_rate":       0.001,
        "optimizer":           "Adam",
        "augment_factor":      AUG_FACTOR,
        "early_stop_patience": 15,
        "reduce_lr_patience":  7,
    }
    tags = {
        "model_type":   "words",
        "framework":    "keras-h5",
        "dataset":      DATA_PATH,
        "parent_run_id": parent_run_id,
    }

    with ASLRun(
        experiment_name="ASL-Words",
        run_name=f"{arch_name}_{n_classes}classes",
        params=params,
        tags=tags,
    ) as mlrun:

        print(f"\n{'='*60}")
        print(f"  Training: {arch_name}")
        print(f"{'='*60}")

        y_tr_cat  = to_categorical(y_tr,  n_classes)
        y_val_cat = to_categorical(y_val, n_classes)

        history = model.fit(
            X_tr, y_tr_cat,
            epochs=MAX_EPOCHS,
            batch_size=BATCH_SIZE,
            validation_data=(X_val, y_val_cat),
            callbacks=callbacks,
            verbose=1,
        )

        val_loss, val_acc = model.evaluate(X_val, y_val_cat, verbose=0)
        print(f"\n  ✓ {arch_name}  val_acc={val_acc:.4f}  val_loss={val_loss:.4f}")

        mlrun.log_keras_history(history)
        mlrun.log_eval(test_loss=val_loss, test_accuracy=val_acc)

        run_id = mlrun.run_id

    return model, val_acc, val_loss, run_id


# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────
def main():
    print("\n" + "="*60)
    print("  ASL WORDS — Training Pipeline (MLflow enabled)")
    print("="*60)
    print(f"  Data path : {os.path.abspath(DATA_PATH)}")
    print(f"  Max epochs: {MAX_EPOCHS}  Batch: {BATCH_SIZE}")
    print(f"  Frames    : {MAX_FRAMES}  Features: {FEAT_SIZE}")
    print()

    # ── Load & split ──────────────────────────────────────────────────────
    X, y, classes = load_data(DATA_PATH)
    N_CLASSES = len(classes)
    print(f"\n[Data] Total: {len(X)} sequences  |  {N_CLASSES} classes: {classes}")

    # Save classes file immediately
    np.save(CLASSES_FILE, np.array(classes))
    print(f"[Data] Classes saved → {CLASSES_FILE}")

    print("\n[Data] Augmenting...")
    X, y = augment(X, y, AUG_FACTOR)
    print(f"[Data] After augmentation: {len(X)} sequences")

    X_train, X_val, y_train, y_val = train_test_split(
        X, y, test_size=0.15, random_state=42, stratify=y
    )
    print(f"[Data] Train: {len(X_train)}  |  Val: {len(X_val)}")

    # ── Parent MLflow run (groups all arch sub-runs) ──────────────────────
    import mlflow
    from mlflow_utils import TRACKING_URI
    mlflow.set_tracking_uri(TRACKING_URI)
    mlflow.set_experiment("ASL-Words")

    with mlflow.start_run(run_name=f"WordsComparison_{N_CLASSES}classes") as parent:
        parent_run_id = parent.info.run_id
        mlflow.set_tag("role", "comparison_parent")
        mlflow.log_param("n_architectures", len(ARCHITECTURES))
        mlflow.log_param("n_classes", N_CLASSES)
        mlflow.log_param("classes", str(classes))

        # ── Train all architectures ───────────────────────────────────────
        results = []
        for arch_name, builder_fn in ARCHITECTURES:
            model, val_acc, val_loss, run_id = train_arch(
                arch_name, builder_fn,
                X_train, y_train, X_val, y_val,
                N_CLASSES, parent_run_id,
            )
            results.append({
                "arch":     arch_name,
                "model":    model,
                "val_acc":  val_acc,
                "val_loss": val_loss,
                "run_id":   run_id,
            })

        # ── Pick winner ───────────────────────────────────────────────────
        winner_entry = max(results, key=lambda r: r["val_acc"])
        winner_name  = winner_entry["arch"]
        winner_model = winner_entry["model"]
        winner_acc   = winner_entry["val_acc"]
        winner_loss  = winner_entry["val_loss"]

        print(f"\n{'='*60}")
        print(f"  🏆  WINNER: {winner_name}  "
              f"val_acc={winner_acc:.4f}  val_loss={winner_loss:.4f}")
        print(f"{'='*60}\n")

        # Log comparison summary on parent run
        mlflow.log_metric("best_val_acc",  winner_acc)
        mlflow.log_metric("best_val_loss", winner_loss)
        mlflow.set_tag("winner_architecture", winner_name)
        for r in results:
            mlflow.log_metric(f"{r['arch']}_val_acc",  r["val_acc"])
            mlflow.log_metric(f"{r['arch']}_val_loss", r["val_loss"])

        # ── Save weights ──────────────────────────────────────────────────
        winner_model.save_weights(WEIGHTS_OUT)
        print(f"✓ Weights saved → {WEIGHTS_OUT}")

        # ── Write model_meta.json ─────────────────────────────────────────
        meta = {
            "winner":     winner_name,
            "val_acc":    float(winner_acc),
            "val_loss":   float(winner_loss),
            "max_frames": MAX_FRAMES,
            "feat_size":  FEAT_SIZE,
            "n_classes":  N_CLASSES,
            "classes":    classes,
            "run_id":     winner_entry["run_id"],          # ← links to MLflow
            "parent_run_id": parent_run_id,
        }
        with open(META_FILE, 'w') as f:
            json.dump(meta, f, indent=2)
        print(f"✓ model_meta.json saved → {META_FILE}")

        # ── Log files as artifacts on parent run ──────────────────────────
        mlflow.log_artifact(WEIGHTS_OUT,  artifact_path="weights")
        mlflow.log_artifact(CLASSES_FILE, artifact_path="weights")
        mlflow.log_artifact(META_FILE,    artifact_path="weights")
        print("[MLflow] Artifacts logged to parent run.")

    print("\n✅  Training complete!")
    print(f"   View results: mlflow ui  (then open http://localhost:5000)")
    print(f"   Experiment  : ASL-Words")
    print(f"   Winner      : {winner_name}  ({winner_acc:.2%} val_acc)")


if __name__ == "__main__":
    main()
