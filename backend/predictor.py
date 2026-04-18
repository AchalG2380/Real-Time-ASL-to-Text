import tensorflow as tf
import numpy as np
import json
import os

class ASLPredictor:
    def __init__(self):
        base = os.path.dirname(os.path.abspath(__file__))
        model_path  = os.path.join(base, '..', 'asl_ml', 'models', 'asl_letter_model.tflite')
        labels_path = os.path.join(base, '..', 'asl_ml', 'models', 'letter_labels.json')

        self.interpreter = tf.lite.Interpreter(model_path=str(model_path))
        self.interpreter.allocate_tensors()
        self.inp = self.interpreter.get_input_details()
        self.out = self.interpreter.get_output_details()

        with open(labels_path) as f:
            self.labels = json.load(f)

        print("✓ ASLPredictor ready")

    def predict(self, keypoints: np.ndarray):
        """keypoints: np.array shape (126,) → returns (letter, confidence)"""
        x = keypoints.reshape(1, 126).astype(np.float32)
        self.interpreter.set_tensor(self.inp[0]['index'], x)
        self.interpreter.invoke()
        probs = self.interpreter.get_tensor(self.out[0]['index'])[0]
        idx = np.argmax(probs)
        return self.labels[idx], float(probs[idx])