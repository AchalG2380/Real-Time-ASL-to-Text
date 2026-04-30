from fastapi import FastAPI, File, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from predictor import ASLPredictor
from keypoint_extractor import extract_keypoints_from_bytes

# Translation support (deep-translator — free, no API key required)
try:
    from deep_translator import GoogleTranslator
    _translator_available = True
except ImportError:
    _translator_available = False

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


class TranslateRequest(BaseModel):
    text: str
    target_language: str = "hi"


class TranslateResponse(BaseModel):
    translated: str
    original: str


@app.get("/health")
def health():
    return {"status": "ok", "translator": _translator_available}


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


@app.post("/chat/translate", response_model=TranslateResponse)
async def translate_text(req: TranslateRequest):
    """
    Translate text to the target language.
    Falls back gracefully if deep-translator is not installed.
    Supported lang codes: 'hi' (Hindi), 'en' (English), etc.
    """
    if not _translator_available:
        return TranslateResponse(translated=req.text, original=req.text)

    if req.target_language == "en":
        return TranslateResponse(translated=req.text, original=req.text)

    try:
        translator = GoogleTranslator(source="auto", target=req.target_language)
        translated = translator.translate(req.text)
        return TranslateResponse(
            translated=translated or req.text,
            original=req.text,
        )
    except Exception as e:
        print(f"[translate] error: {e}")
        return TranslateResponse(translated=req.text, original=req.text)