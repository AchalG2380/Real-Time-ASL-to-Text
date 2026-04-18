import tensorflow as tf
import numpy as np
import json

# Load model
interpreter = tf.lite.Interpreter(model_path='models/asl_letter_model.tflite')
interpreter.allocate_tensors()

inp = interpreter.get_input_details()
out = interpreter.get_output_details()

# Load labels
with open('models/letter_labels.json') as f:
    LETTERS = json.load(f)

print(f"✓ Model loaded")
print(f"  Input shape:  {inp[0]['shape']}")   # should be [1, 126]
print(f"  Output shape: {out[0]['shape']}")   # should be [1, 26]
print(f"  Labels: {LETTERS}")

# Test with dummy input
dummy = np.zeros((1, 126), dtype=np.float32)
interpreter.set_tensor(inp[0]['index'], dummy)
interpreter.invoke()
probs = interpreter.get_tensor(out[0]['index'])[0]
print(f"\n✓ Inference works — dummy output shape: {probs.shape}")