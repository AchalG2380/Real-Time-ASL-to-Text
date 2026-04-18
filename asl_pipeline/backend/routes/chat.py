from fastapi import APIRouter, HTTPException
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


class EditMessageRequest(BaseModel):
    session_id: str
    message_index: int   # which bubble to edit (its position in history)
    new_text: str
    sender: str          # "A" or "B"

@router.post("/session/message/edit")
def edit_message(req: EditMessageRequest):
    if req.session_id not in SESSIONS:
        raise HTTPException(status_code=404, detail="Session not found")
    
    history = SESSIONS[req.session_id]
    
    # Check the message exists
    if req.message_index >= len(history):
        raise HTTPException(status_code=404, detail="Message not found")
    
    # Check it belongs to the right sender
    if history[req.message_index]["sender"] != req.sender:
        raise HTTPException(status_code=403, detail="Cannot edit other person's message")
    
    # Check no newer message from same sender exists after this one
    for msg in history[req.message_index + 1:]:
        if msg["sender"] == req.sender:
            raise HTTPException(
                status_code=403, 
                detail="Cannot edit — a newer message from same sender exists"
            )
    
    # All good — edit it
    history[req.message_index]["text"] = req.new_text
    history[req.message_index]["edited"] = True
    return {"status": "edited", "message": history[req.message_index]}