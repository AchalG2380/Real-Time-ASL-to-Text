import asyncio
import cv2
import json
import numpy as np
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
from utils import extract_keypoints, draw_landmarks
from inference import ASLInference

app = FastAPI(title="ASL Pipeline API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

engine = None   # initialized on startup


@app.on_event("startup")
async def startup():
    global engine
    engine = ASLInference()
    print("ASL engine ready.")


@app.get("/status")
async def status():
    return {"status": "online", "engine_ready": engine is not None}


@app.get("/signs")
async def get_signs():
    from utils import SIGN_TO_SENTENCE
    return {"signs": SIGN_TO_SENTENCE}


@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    print("Flutter client connected")

    cap = cv2.VideoCapture(0)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)

    try:
        while True:
            ret, frame = cap.read()
            if not ret:
                continue

            frame         = cv2.flip(frame, 1)
            _, detected   = draw_landmarks(frame)
            keypoints     = extract_keypoints(frame)
            state         = engine.process_frame(keypoints, detected)

            # Send state to Flutter
            await websocket.send_text(json.dumps(state))
            await asyncio.sleep(0.033)   # ~30fps

    except WebSocketDisconnect:
        print("Flutter client disconnected")
    finally:
        cap.release()


if __name__ == "__main__":
    uvicorn.run("api:app", host="0.0.0.0", port=8000, reload=False)