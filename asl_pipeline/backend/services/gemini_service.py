import os
import json
import httpx
from dotenv import load_dotenv

# Load your OpenRouter API key from the .env file
load_dotenv()
OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY")

async def get_smart_suggestion(payload: dict) -> list:
    """Calls OpenRouter to predict what the user is trying to sign."""
    
    # 1. Pull the specific details out of the data sent by Flutter
    sign = payload.get("detected_sign", "")
    history = payload.get("conversation_history", [])
    screen = payload.get("screen", "general")
    store_type = payload.get("store_type", "default")
    
    # 2. Create the instructions for the AI
    system_prompt = (
        "You are a predictive text engine for an ASL translation app. "
        "Based on the user's current sign, previous conversation history, and app screen context, "
        "predict the 3 most likely complete sentences or phrases they want to say. "
        "Return ONLY a valid JSON list of 3 strings. Do not add markdown formatting. "
        "Example: [\"Where is the restroom?\", \"How much does this cost?\", \"I need help.\"]"
    )
    
    user_prompt = f"Current Sign: {sign}\nHistory: {history}\nScreen Context: {screen}\nStore Type: {store_type}"

    # 3. Set up the web request to OpenRouter
    headers = {
        "Authorization": f"Bearer {OPENROUTER_API_KEY}",
        "HTTP-Referer": "http://localhost:8000", # OpenRouter requires a referer URL
        "Content-Type": "application/json"
    }
    
    data = {
        "model": "google/gemini-2.5-flash-lite", # A highly capable, free model on OpenRouter
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt}
        ],
        "temperature": 0.5 # Keeps the predictions logical and grounded
    }
    
    try:
        # 4. Send the request asynchronously so the server doesn't freeze up
        async with httpx.AsyncClient() as client:
            response = await client.post(
                "https://openrouter.ai/api/v1/chat/completions",
                headers=headers,
                json=data,
                timeout=10.0
            )
            response.raise_for_status() # Check for errors like a bad API key
            
            # 5. Extract the AI's text response
            result = response.json()
            content = result["choices"][0]["message"]["content"]
            
            # 6. Clean up the response and convert it from a string back into a Python list
            cleaned_content = content.replace("```json", "").replace("```", "").strip()
            suggestions_list = json.loads(cleaned_content)
            
            return suggestions_list
            
    except Exception as e:
        print(f"OpenRouter API Error: {e}")
        # If the internet drops or the API fails, return safe fallback options so the app doesn't crash
        return ["Can you repeat that?", "I need help.", "Thank you."]


async def get_followup_suggestions(text: str) -> list:
    """Placeholder for the other route so your app doesn't throw import errors."""
    return ["Follow-up 1", "Follow-up 2"]