import numpy as np
import os
import tensorflow as tf
from tensorflow.keras import layers, models
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
import json
from utils import SIGNS, FRAME_COUNT, NUM_FEATURES

DATA_DIR  = "data"
MODEL_DIR = "models"


def load_dataset():
    X, y = [], []

    for sign in SIGNS:
        sign_dir = os.path.join(DATA_DIR, sign)
        files    = [f for f in os.listdir(sign_dir) if f.endswith(".npy")]

        if not files:
            print(f"  ⚠ No data for {sign} — skipping")
            continue

        for fname in files:
            seq = np.load(os.path.join(sign_dir, fname))  # (25, 63)

            # Pad or trim to exactly FRAME_COUNT frames
            if len(seq) < FRAME_COUNT:
                pad = np.zeros((FRAME_COUNT - len(seq), NUM_FEATURES))
                seq = np.vstack([seq, pad])
            else:
                seq = seq[:FRAME_COUNT]

            X.append(seq)
            y.append(sign)

        print(f"  Loaded {len(files):3d} samples for {sign}")

    return np.array(X), np.array(y)


def build_model(num_classes):
    model = models.Sequential([
        layers.Input(shape=(FRAME_COUNT, NUM_FEATURES)),

        layers.Conv1D(64, kernel_size=3, activation='relu', padding='same'),
        layers.BatchNormalization(),
        layers.Dropout(0.2),

        layers.Conv1D(128, kernel_size=3, activation='relu', padding='same'),
        layers.BatchNormalization(),
        layers.Dropout(0.2),

        layers.Conv1D(64, kernel_size=3, activation='relu', padding='same'),
        layers.GlobalAveragePooling1D(),

        layers.Dense(128, activation='relu'),
        layers.Dropout(0.3),
        layers.Dense(64, activation='relu'),
        layers.Dense(num_classes, activation='softmax')
    ])

    model.compile(
        optimizer='adam',
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy']
    )
    return model


def main():
    print("── Loading dataset ──")
    X, y_raw = load_dataset()
    print(f"\n  Total samples: {len(X)}")
    print(f"  Shape: {X.shape}")

    # Encode labels
    le = LabelEncoder()
    le.fit(SIGNS)   # fit on all signs to preserve consistent indices
    y  = le.transform(y_raw)

    # Save label encoder classes so inference can decode
    os.makedirs(MODEL_DIR, exist_ok=True)
    np.save(os.path.join(MODEL_DIR, "classes.npy"), le.classes_)
    print(f"\n  Classes: {list(le.classes_)}")

    # Train/test split
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )
    print(f"  Train: {len(X_train)}  Test: {len(X_test)}")

    # Build & train
    print("\n── Training ──")
    model = build_model(len(le.classes_))
    model.summary()

    callbacks = [
        tf.keras.callbacks.EarlyStopping(
            monitor='val_accuracy', patience=10, restore_best_weights=True
        ),
        tf.keras.callbacks.ReduceLROnPlateau(
            monitor='val_loss', factor=0.5, patience=5
        )
    ]

    history = model.fit(
        X_train, y_train,
        epochs=60,
        batch_size=16,
        validation_data=(X_test, y_test),
        callbacks=callbacks,
        verbose=1
    )

    # Evaluate
    loss, acc = model.evaluate(X_test, y_test, verbose=0)
    print(f"\n── Results ──")
    print(f"  Test Accuracy: {acc*100:.1f}%")
    print(f"  Test Loss:     {loss:.4f}")

    # Save Keras model
    keras_path = os.path.join(MODEL_DIR, "asl_model.h5")
    model.save(keras_path)
    print(f"\n  Saved Keras model → {keras_path}")

    # Export to TFLite
    print("\n── Exporting to TFLite ──")
    converter    = tf.lite.TFLiteConverter.from_keras_model(model)
    tflite_model = converter.convert()
    tflite_path  = os.path.join(MODEL_DIR, "asl_model.tflite")

    with open(tflite_path, "wb") as f:
        f.write(tflite_model)
    print(f"  Saved TFLite model → {tflite_path}")
    print(f"  TFLite size: {len(tflite_model)/1024:.1f} KB")

    # Per-class accuracy report
    print("\n── Per-sign accuracy ──")
    y_pred = np.argmax(model.predict(X_test, verbose=0), axis=1)
    for i, sign in enumerate(le.classes_):
        mask    = y_test == i
        if mask.sum() == 0:
            continue
        sign_acc = (y_pred[mask] == i).mean() * 100
        bar = "█" * int(sign_acc / 5)
        print(f"  {sign:15s}: {sign_acc:5.1f}%  {bar}")

    if acc < 0.85:
        print("\n  ⚠ Accuracy below 85%. Collect more data for weak signs and retrain.")
    else:
        print("\n  ✓ Model ready for inference!")


if __name__ == "__main__":
    main()