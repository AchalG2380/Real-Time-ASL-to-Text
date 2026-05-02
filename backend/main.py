from fastapi import FastAPI, File, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List
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


# ── Models ────────────────────────────────────────────────────────────────────

class PredictResponse(BaseModel):
    letter: str
    confidence: float
    detected: bool


class PredictFrameResponse(BaseModel):
    """Extended response that also returns the 84-feature keypoints so the
    Flutter web app can accumulate them for word-sequence prediction."""
    letter: str
    confidence: float
    detected: bool
    keypoints: List[float]   # 84 floats (2 hands × 21 landmarks × x,y)


class WordSequenceRequest(BaseModel):
    """40 frames × 84 features each — sent by Flutter web for word detection."""
    sequence: List[List[float]]   # shape (40, 84)


class WordSequenceResponse(BaseModel):
    word: str
    confidence: float
    detected: bool


class TranslateRequest(BaseModel):
    text: str
    target_language: str = "hi"


class TranslateResponse(BaseModel):
    translated: str
    original: str


# ── Health ────────────────────────────────────────────────────────────────────

@app.get("/health")
def health():
    return {"status": "ok", "translator": _translator_available}


# ── Letter prediction (single frame) — original endpoint ─────────────────────

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


# ── Extended single-frame endpoint — also returns keypoints for word buffer ───

@app.post("/predict/frame", response_model=PredictFrameResponse)
async def predict_frame(file: UploadFile = File(...)):
    """
    Flutter Web calls this every ~400 ms.
    Returns letter prediction AND the 84-feature keypoints so the
    client can accumulate a 40-frame sequence for word prediction.

    Keypoints format (84 floats):
      [hand0_lm0_x, hand0_lm0_y,  hand0_lm1_x, hand0_lm1_y, ... (42 floats)
       hand1_lm0_x, hand1_lm0_y,  ... (42 floats)]
    """
    image_bytes = await file.read()
    kp126 = extract_keypoints_from_bytes(image_bytes)   # shape (126,) or None

    if kp126 is None:
        return PredictFrameResponse(
            letter="", confidence=0.0, detected=False, keypoints=[]
        )

    # Letter prediction uses all 126 features (x,y,z)
    letter, confidence = predictor.predict(kp126)

    # Word model uses 84 features (x,y only, both hands in detection order)
    # kp126 layout: [hand0: 21×3, hand1: 21×3]
    #  → word kp: [hand0: 21×2, hand1: 21×2]  = 84 floats
    import numpy as np
    kp126_arr = kp126.reshape(2, 21, 3)          # (2 hands, 21 lm, 3 coords)
    kp84_arr  = kp126_arr[:, :, :2]              # keep x,y only → (2, 21, 2)
    kp84      = kp84_arr.flatten().tolist()      # 84 floats

    return PredictFrameResponse(
        letter=letter,
        confidence=confidence,
        detected=True,
        keypoints=kp84,
    )


# ── Word prediction (sequence of 40 frames) ───────────────────────────────────

@app.post("/predict/word", response_model=WordSequenceResponse)
async def predict_word(req: WordSequenceRequest):
    """
    Flutter Web sends a rolling buffer of 40 keypoint frames (each 84 floats).
    Returns the detected ASL word + confidence.

    The word model is lazy-loaded on the first call.
    """
    from word_predictor import WordPredictor

    seq = req.sequence
    if len(seq) < 40:
        return WordSequenceResponse(word="", confidence=0.0, detected=False)

    # Use the last 40 frames
    seq40 = seq[-40:]
    word, confidence, detected = WordPredictor.instance().predict(seq40)

    return WordSequenceResponse(word=word, confidence=confidence, detected=detected)


# ── Translation ───────────────────────────────────────────────────────────────

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