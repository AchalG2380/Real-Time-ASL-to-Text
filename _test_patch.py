import os
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3'
os.environ['TF_ENABLE_ONEDNN_OPTS'] = '0'

import mediapipe as mp
import mediapipe.python.solutions as mps
mp.solutions = mps

from google.protobuf import symbol_database as _sdb, message_factory as _mf
_db = _sdb.Default()
if not hasattr(_db, 'GetPrototype'):
    _db.GetPrototype = _mf.GetMessageClass
    print('Patched GetPrototype')
else:
    print('GetPrototype already exists')

import cv2, numpy as np
mp_hands = mp.solutions.hands
hands = mp_hands.Hands(max_num_hands=2, min_detection_confidence=0.5)
dummy = np.zeros((480, 640, 3), dtype=np.uint8)
rgb = cv2.cvtColor(dummy, cv2.COLOR_BGR2RGB)
result = hands.process(rgb)
print('SUCCESS: hands.process() completed without crashing!')
hands.close()
