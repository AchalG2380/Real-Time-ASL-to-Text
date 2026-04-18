from fastapi import FastAPI, File, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from predictor import ASLPredictor
from keypoint_extractor import extract_keypoints_from_bytes

app = FastAPI()
predictor = ASLPredictor()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

class PredictResponse(BaseModel):
    letter: str
    confidence: float
    detected: bool

@app.get("/health")
def health():
    return {"status": "ok"}

@app.post("/predict", response_model=PredictResponse)
async def predict(file: UploadFile = File(...)):
    """
    Flutter sends a camera frame as JPEG bytes.
    Returns predicted ASL letter + confidence.
    """
    image_bytes = await file.read()
    keypoints = extract_keypoints_from_bytes(image_bytes)

    if keypoints is None:
        return PredictResponse(letter="", confidence=0.0, detected=False)

    letter, confidence = predictor.predict(keypoints)
    return PredictResponse(letter=letter, confidence=confidence, detected=True)