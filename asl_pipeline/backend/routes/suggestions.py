from fastapi import APIRouter
from pydantic import BaseModel
from services.gemini_service import get_smart_suggestion, get_followup_suggestions

router = APIRouter()

# Define the exact structure we expect from Flutter
class SuggestionRequest(BaseModel):
    detected_sign: str
    conversation_history: list[str]
    screen: str
    store_type: str

@router.post("/smart")
async def generate_smart_predictions(request: SuggestionRequest):
    # Convert the incoming Pydantic model to a dictionary and pass it to OpenRouter
    predictions = await get_smart_suggestion(request.model_dump())
    return predictions