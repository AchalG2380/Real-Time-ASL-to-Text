import os
import json
import httpx
from dotenv import load_dotenv

load_dotenv()
OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY")

# These were missing — add them
MODEL = "google/gemini-2.0-flash-001"
FALLBACK_MODEL = "mistralai/mistral-7b-instruct"
OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
HEADERS = {
    "Authorization": f"Bearer {OPENROUTER_API_KEY}",
    "Content-Type": "application/json",
    "HTTP-Referer": "https://asl-retail-translator.com",
    "X-Title": "ASL Retail Translator"
}

RULE_BASED_FALLBACK = {
    "HELP": ["I need help, please", "Can someone assist me?", "Could you help me?"],
    "PRICE": ["How much does this cost?", "What is the price?", "Can you tell me the price?"],
    "THANK": ["Thank you!", "Thanks very much!", "I really appreciate it"],
    "BATHROOM": ["Where is the bathroom?", "Could you direct me to the restroom?"],
    "BAG": ["Can I get a bag please?", "I need a carry bag"],
    "HELLO": ["Hello!", "Hi there!", "Good day!"],
    "REPEAT": ["Could you please repeat that?", "Sorry, could you say that again?"],
    "DEFAULT": ["Could you help me?", "I have a question", "Excuse me"]
}


async def get_smart_suggestion(detected_sign: str, history: list, screen: str, store_type: str):
    try:
        result = await _call_openrouter(detected_sign, history, screen, store_type, MODEL)
        if result:
            return result
    except Exception as e:
        print(f"Primary model failed: {e}")

    try:
        result = await _call_openrouter(detected_sign, history, screen, store_type, FALLBACK_MODEL)
        if result:
            return result
    except Exception as e:
        print(f"Fallback model failed: {e}")

    print("Using rule-based fallback")
    return RULE_BASED_FALLBACK.get(detected_sign.upper(), RULE_BASED_FALLBACK["DEFAULT"])


# This was completely missing — add it
async def get_followup_suggestions(chosen: str, history: list, store_type: str):
    context = "\n".join([f"{m['sender']}: {m['text']}" for m in history[-4:]])

    prompt = f"""You are a suggestion engine for a retail store ASL tablet.
The user just said: "{chosen}"
Store type: {store_type}
Recent conversation:
{context}

Give exactly 2-3 short follow-up sentences the user might say next, like autocomplete.
Return ONLY a JSON array. No explanation. No markdown."""

    payload = {
        "model": MODEL,
        "messages": [{"role": "user", "content": prompt}],
        "max_tokens": 120,
        "temperature": 0.5
    }

    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.post(OPENROUTER_URL, json=payload, headers=HEADERS)
            data = response.json()
            text = data["choices"][0]["message"]["content"].strip()
            text = text.replace("```json", "").replace("```", "").strip()
            return json.loads(text)[:3]
    except Exception as e:
        print(f"Followup error: {e}")
        return []


async def get_paraphrase(raw_sign: str, history: list, screen: str, store_type: str):
    context = "\n".join([f"{m['sender']}: {m['text']}" for m in history[-4:]])
    who = "deaf customer" if screen == "A" else "deaf store employee"

    prompt = f"""You are a translator for a retail store ASL tablet.
A {who} just signed the word: "{raw_sign}"
Store context: {store_type}
Recent conversation:
{context}

Convert this single signed word into ONE natural, complete, polite sentence.
Return ONLY the sentence. No explanation. No quotes."""

    payload = {
        "model": MODEL,
        "messages": [{"role": "user", "content": prompt}],
        "max_tokens": 60,
        "temperature": 0.3
    }

    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.post(OPENROUTER_URL, json=payload, headers=HEADERS)
            data = response.json()
            sentence = data["choices"][0]["message"]["content"].strip()
            return sentence
    except Exception as e:
        print(f"Paraphrase error: {e}")
        return f"I need {raw_sign.lower()}"


async def _call_openrouter(detected_sign, history, screen, store_type, model_name):
    context = "\n".join([f"{m['sender']}: {m['text']}" for m in history[-4:]])
    who = "deaf customer" if screen == "A" else "deaf store employee"

    prompt = f"""You are a smart suggestion engine for a retail store ASL tablet.
Person signing is a {who} in a {store_type}.
Sign detected: "{detected_sign}"
Recent conversation: {context}
Give exactly 3 short natural sentences. Return ONLY a JSON array of 3 strings."""

    payload = {
        "model": model_name,
        "messages": [{"role": "user", "content": prompt}],
        "max_tokens": 150,
        "temperature": 0.4
    }

    async with httpx.AsyncClient(timeout=5.0) as client:
        response = await client.post(OPENROUTER_URL, json=payload, headers=HEADERS)
        data = response.json()
        text = data["choices"][0]["message"]["content"].strip()
        text = text.replace("```json", "").replace("```", "").strip()
        return json.loads(text)[:3]