"""
word_predictor.py
-----------------
Loads the Conv1D/BiLSTM word model from Words/ and exposes a predict()
method that takes a (40, 84) keypoint sequence and returns (word, confidence).

This module is lazy-loaded on first use so that the FastAPI server starts
quickly even if the model is large.
"""

import os
import json
import numpy as np
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import (
    LSTM, Dense, Dropout, Conv1D, MaxPooling1D,
    BatchNormalization, GlobalAveragePooling1D, Bidirectional
)

_BASE = os.path.dirname(os.path.abspath(__file__))
_WORDS_DIR = os.path.join(_BASE, '..', 'Words')

_META_FILE    = os.path.join(_WORDS_DIR, 'model_meta.json')
_CLASSES_FILE = os.path.join(_WORDS_DIR, 'Final_ASL_Classes.npy')
_WEIGHT_FILES = [
    os.path.join(_WORDS_DIR, 'Final_ASL_Model_fixed.weights.h5'),
    os.path.join(_WORDS_DIR, 'Final_ASL_Model_fixed.h5'),
    os.path.join(_WORDS_DIR, 'Final_ASL_Model.h5'),
]


def _build_conv1d(frames, feat, n_classes):
    return Sequential([
        keras.Input(shape=(frames, feat)), BatchNormalization(),
        Conv1D(64, 3, activation='relu', padding='same'), MaxPooling1D(2), Dropout(0.25),
        Conv1D(128, 3, activation='relu', padding='same'), MaxPooling1D(2), Dropout(0.25),
        GlobalAveragePooling1D(), Dense(128, activation='relu'), Dropout(0.4),
        Dense(n_classes, activation='softmax'),
    ], name='Conv1D')


def _build_bilstm(frames, feat, n_classes):
    return Sequential([
        keras.Input(shape=(frames, feat)), BatchNormalization(),
        Bidirectional(LSTM(64, return_sequences=True, dropout=0.2)), Dropout(0.3),
        Bidirectional(LSTM(64, return_sequences=False, dropout=0.2)), Dropout(0.3),
        Dense(64, activation='relu'), Dropout(0.4),
        Dense(n_classes, activation='softmax'),
    ], name='BiLSTM')


def _build_old_lstm(frames, feat, n_classes):
    return Sequential([
        keras.Input(shape=(frames, feat)),
        LSTM(64, return_sequences=True, activation='tanh'), Dropout(0.2),
        LSTM(128, activation='tanh'), Dropout(0.2),
        Dense(64, activation='relu'),
        Dense(n_classes, activation='softmax'),
    ], name='OldLSTM')


class WordPredictor:
    """Singleton-style word model loader. Call WordPredictor.instance()."""

    _instance = None

    def __init__(self):
        # ── Load metadata ──────────────────────────────────────────
        meta = {}
        if os.path.exists(_META_FILE):
            with open(_META_FILE) as f:
                meta = json.load(f)

        self.max_frames  = int(meta.get('max_frames', 40))
        self.feat_size   = int(meta.get('feat_size',  84))
        self.conf_thresh = 0.50
        self.margin      = 0.10

        # ── Load classes ───────────────────────────────────────────
        self.classes = [str(c) for c in np.load(_CLASSES_FILE, allow_pickle=True)]
        n_classes = len(self.classes)
        print(f"[WordPredictor] {n_classes} classes: {self.classes}")

        winner = meta.get('winner', 'Conv1D')
        arch_order = (
            [('BiLSTM', _build_bilstm), ('Conv1D', _build_conv1d), ('OldLSTM', _build_old_lstm)]
            if winner == 'BiLSTM'
            else [('Conv1D', _build_conv1d), ('BiLSTM', _build_bilstm), ('OldLSTM', _build_old_lstm)]
        )

        # ── Load model ─────────────────────────────────────────────
        self.model = None
        for path in _WEIGHT_FILES:
            if not os.path.exists(path):
                continue
            print(f"[WordPredictor] Trying {os.path.basename(path)}")
            try:
                self.model = tf.keras.models.load_model(path, compile=False)
                print(f"[WordPredictor] Full load OK  output={self.model.output_shape}")
                break
            except Exception as e:
                print(f"  Full failed: {str(e)[:80]}")

            for arch_name, builder in arch_order:
                try:
                    m = builder(self.max_frames, self.feat_size, n_classes)
                    m.compile(optimizer='adam', loss='categorical_crossentropy', metrics=['accuracy'])
                    m.load_weights(path)
                    self.model = m
                    print(f"[WordPredictor] Weights OK ({arch_name})")
                    break
                except Exception as e:
                    print(f"  Weights failed ({arch_name}): {str(e)[:60]}")

            if self.model:
                break

        if self.model is None:
            print("[WordPredictor] WARNING: word model could not be loaded — word detection disabled")

    @classmethod
    def instance(cls):
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance

    def predict(self, sequence: list) -> tuple:
        """
        sequence: list of 40 lists/arrays each with self.feat_size (84) floats
                  (2 hands × 21 landmarks × 2 coords = 84)
        Returns: (word: str, confidence: float, detected: bool)
        """
        if self.model is None:
            return '', 0.0, False

        arr = np.array(sequence, dtype='float32')  # (40, 84)
        if arr.shape != (self.max_frames, self.feat_size):
            return '', 0.0, False

        inp   = np.expand_dims(arr, 0)              # (1, 40, 84)
        probs = self.model(inp, training=False)[0].numpy()

        top_idx  = int(np.argmax(probs))
        top_conf = float(probs[top_idx])
        sec_conf = float(np.sort(probs)[-2])
        margin   = top_conf - sec_conf

        if top_conf >= self.conf_thresh and margin >= self.margin:
            return self.classes[top_idx], top_conf, True

        return '', top_conf, False
