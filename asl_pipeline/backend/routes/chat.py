from fastapi import APIRouter
from pydantic import BaseModel
from services.translate_service import translate_text
import uuid

router = APIRouter()

# In-memory session store — disappears when server restarts
# Structure: { session_id: [ {sender, text, timestamp}, ... ] }
SESSIONS: dict = {}


class StartSessionRequest(BaseModel):
    pass  # No body needed

class MessageRequest(BaseModel):
    session_id: str
    sender: str   # "A" or "B"
    text: str

class TranslateRequest(BaseModel):
    text: str
    target_language: str  # e.g. "hi" for Hindi, "en" for English

class ClearSessionRequest(BaseModel):
    session_id: str


@router.post("/session/start")
def start_session():
    """Creates a new session and returns the ID."""
    session_id = str(uuid.uuid4())
    SESSIONS[session_id] = []
    return {
        "session_id": session_id,
        "greeting": "Hi! Please sign or type what you'd like to say."
    }


@router.post("/session/message")
def add_message(req: MessageRequest):
    """Adds a message to the session history."""
    if req.session_id not in SESSIONS:
        return {"error": "Session not found"}, 404
    
    from datetime import datetime
    message = {
        "sender": req.sender,
        "text": req.text,
        "timestamp": datetime.now().isoformat()
    }
    SESSIONS[req.session_id].append(message)
    return {"status": "ok", "message": message}


@router.get("/session/{session_id}/history")
def get_history(session_id: str):
    """Returns full conversation history for this session."""
    if session_id not in SESSIONS:
        return {"error": "Session not found"}
    return {"history": SESSIONS[session_id]}


@router.post("/session/clear")
def clear_session(req: ClearSessionRequest):
    """Ends the session and deletes all conversation data."""
    if req.session_id in SESSIONS:
        del SESSIONS[req.session_id]
    return {"status": "cleared"}


@router.post("/translate")
async def translate(req: TranslateRequest):
    """Translates a piece of text to the target language."""
    translated = await translate_text(req.text, req.target_language)
    return {"original": req.text, "translated": translated, "language": req.target_language}