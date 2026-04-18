import cv2

cap = cv2.VideoCapture(0)
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
print("Opening webcam...")

ret, frame = cap.read()
print(f"Frame read: {ret}")

if ret:
    cv2.imshow("Test", frame)
    cv2.waitKey(3000)  # show for 3 seconds

cap.release()
cv2.destroyAllWindows()
print("Done")