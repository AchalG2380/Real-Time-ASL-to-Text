# quick_test.py — run this to verify
from utils import extract_keypoints, draw_landmarks
import cv2

cap = cv2.VideoCapture(0)
while True:
    ret, frame = cap.read()
    frame, detected = draw_landmarks(frame)
    kp = extract_keypoints(frame)
    cv2.putText(frame, f"Hand: {detected} | KP sum: {kp.sum():.2f}",
                (10,30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0,255,0), 2)
    cv2.imshow("Test", frame)
    if cv2.waitKey(1) & 0xFF == ord('q'):
        break
cap.release()
cv2.destroyAllWindows()