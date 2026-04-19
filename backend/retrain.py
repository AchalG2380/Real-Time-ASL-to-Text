import numpy as np
import os
import json
import sys
import tensorflow as tf
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mlflow_utils import ASLRun
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import Dense, Dropout, BatchNormalization
from tensorflow.keras.utils import to_categorical
from sklearn.model_selection import train_test_split

DATA_DIR = os.path.join('..', 'data', 'processed')
MODEL_OUT = os.path.join('..', 'asl_ml', 'models', 'asl_letter_model.tflite')
LABELS_OUT = os.path.join('..', 'asl_ml', 'models', 'letter_labels.json')

# ── Load data ──────────────────────────────────────────────────────────────
collected_letters = []
X_all, y_all = [], []

for i, letter_file in enumerate(sorted(os.listdir(DATA_DIR))):
    if not letter_file.endswith('.npy'):
        continue
    name = letter_file.replace('.npy', '')
    data = np.load(os.path.join(DATA_DIR, letter_file))
    collected_letters.append(name)
    for sample in data:
        X_all.append(sample)
        y_all.append(i)
    print(f"  Loaded {name}: {len(data)} samples")

X_all = np.array(X_all, dtype=np.float32)
y_all = np.array(y_all, dtype=np.int32)
LETTERS = collected_letters
NUM_CLASSES = len(LETTERS)
print(f"\n✓ Total: {len(X_all)} samples, {NUM_CLASSES} classes")

# ── Augment ────────────────────────────────────────────────────────────────
def augment(X, y, factor=4):
    X_aug, y_aug = [X], [y]
    for _ in range(factor):
        noise = np.random.normal(0, 0.01, X.shape).astype(np.float32)
        X_aug.append(X + noise)
        y_aug.append(y)
    return np.concatenate(X_aug), np.concatenate(y_aug)

print("Augmenting data...")
X_all, y_all = augment(X_all, y_all, factor=4)
print(f"✓ Augmented total: {len(X_all)} samples")

# ── Split ──────────────────────────────────────────────────────────────────
X_train, X_test, y_train, y_test = train_test_split(
    X_all, y_all, test_size=0.2, random_state=42, stratify=y_all
)

y_train_cat = to_categorical(y_train, NUM_CLASSES)
y_test_cat  = to_categorical(y_test,  NUM_CLASSES)

# ── Model ──────────────────────────────────────────────────────────────────
model = Sequential([
    Dense(512, activation='relu', input_shape=(126,)),
    BatchNormalization(),
    Dropout(0.4),
    Dense(256, activation='relu'),
    BatchNormalization(),
    Dropout(0.4),
    Dense(128, activation='relu'),
    BatchNormalization(),
    Dropout(0.3),
    Dense(64, activation='relu'),
    Dropout(0.2),
    Dense(NUM_CLASSES, activation='softmax')
], name='asl_letter_model')

model.compile(
    optimizer=tf.keras.optimizers.Adam(learning_rate=0.001),
    loss='categorical_crossentropy',
    metrics=['accuracy']
)

model.summary()

# ── Train ──────────────────────────────────────────────────────────────────
callbacks = [
    tf.keras.callbacks.EarlyStopping(
        monitor='val_accuracy', patience=15,
        restore_best_weights=True, verbose=1
    ),
    tf.keras.callbacks.ReduceLROnPlateau(
        monitor='val_loss', factor=0.5,
        patience=7, min_lr=1e-6, verbose=1
    )
]

# ── MLflow run ────────────────────────────────────────────────────────────
MLFLOW_PARAMS = {
    "architecture": "Dense-MLP",
    "n_classes":    NUM_CLASSES,
    "n_samples":    len(X_train),
    "n_val":        len(X_test),
    "epochs":       150,
    "batch_size":   64,
    "learning_rate": 0.001,
    "optimizer":    "Adam",
    "augment_factor": 4,
    "early_stop_patience": 15,
    "reduce_lr_patience":  7,
}
MLFLOW_TAGS = {
    "model_type": "letters",
    "framework":  "keras-tflite",
    "dataset":    "processed-keypoints",
}

with ASLRun(
    experiment_name="ASL-Letters",
    run_name=f"MLP_{NUM_CLASSES}classes",
    params=MLFLOW_PARAMS,
    tags=MLFLOW_TAGS,
) as mlrun:

    print("\nTraining...")
    history = model.fit(
        X_train, y_train_cat,
        epochs=150,
        batch_size=64,
        validation_data=(X_test, y_test_cat),
        callbacks=callbacks,
        verbose=1
    )

    loss, acc = model.evaluate(X_test, y_test_cat, verbose=0)
    print(f"\n✓ Test accuracy: {acc:.1%}")

    # ── Log to MLflow ──────────────────────────────────────────────────────
    mlrun.log_keras_history(history)
    mlrun.log_eval(test_loss=loss, test_accuracy=acc)
    # ── Export TFLite (inside run so artifact is logged before close) ───────
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()

    with open(MODEL_OUT, 'wb') as f:
        f.write(tflite_model)
    print(f"\u2713 Model saved: {MODEL_OUT}")

    # ── Save labels ────────────────────────────────────────────────────────────
    with open(LABELS_OUT, 'w') as f:
        json.dump(LETTERS, f)
    print(f"\u2713 Labels saved: {LABELS_OUT} \u2192 {LETTERS}")
    print(f"  Classes: {LETTERS}")

    # ── Log exported artifacts ──────────────────────────────────────────────
    mlrun.log_artifact_file(MODEL_OUT)
    mlrun.log_artifact_file(LABELS_OUT)
    print("[MLflow] All artifacts logged. Run complete.")