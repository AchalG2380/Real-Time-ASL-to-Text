# Flutter Integration Guide — Backend API

Base URL: https://asl-retail-backend.onrender.com

---

## STEP 1 — On App Launch (runs once)

GET /admin/settings/public

No body needed. Store the response in your top-level app state:
- is_online (bool) → controls whether to call AI endpoints
- store_type (string) → pass this in every suggestion call
- window_mode (string) → controls which window is on which side

---

## STEP 2 — When a New Conversation Starts

POST /chat/session/start
Body: {}

Store session_id at TOP LEVEL of app — not inside any widget.
This ID must survive screen changes and rebuilds.
Every single chat request after this needs this ID.

Response:
{
  "session_id": "abc-123",
  "greeting": "Hi! Please sign or type what you'd like to say."
}

Show the greeting text at the top of the chat window.

---

## STEP 3 — When a Sign is Detected (Person 4 sends you a sentence)

Person 4's bridge gives you a paraphrased sentence like "I need help."
Do these TWO things at the same time:

--- LEFT: Save to chat automatically ---
POST /chat/session/message
Body:
{
  "session_id": "your-stored-id",
  "sender": "A",
  "text": "I need help"
}
Display as Person A's chat bubble. No user action needed.

--- RIGHT: Get suggestions for side panel ---

If is_online is TRUE:
  First try:
  POST /suggestions/template
  Body: { "detected_sign": "HELP", "screen": "A" }
  
  If response has "matched": true → show those suggestions as chips
  If response has "matched": false → then call:
  POST /suggestions/smart
  Body:
  {
    "detected_sign": "HELP",
    "conversation_history": [last 4 messages as list],
    "screen": "A",
    "store_type": "your-stored-store-type"
  }
  Show the 3 returned strings as tappable suggestion chips.

If is_online is FALSE:
  POST /suggestions/predefined
  Body: { "store_type": "your-stored-store-type", "screen": "A" }
  Show returned list as suggestion chips.

---

## STEP 4 — When a Suggestion Chip is Tapped

POST /chat/session/message
Body:
{
  "session_id": "your-stored-id",
  "sender": "A",
  "text": "the tapped suggestion text"
}

Then immediately call:
POST /suggestions/followup
Body:
{
  "chosen_suggestion": "I need help",
  "conversation_history": [last 4 messages],
  "store_type": "your-stored-store-type"
}
Show 2-3 returned strings as smaller autocomplete chips below chat.

---

## STEP 5 — When Person B Types a Reply

POST /chat/session/message
Body:
{
  "session_id": "your-stored-id",
  "sender": "B",
  "text": "Of course! How can I help?"
}

Show as Person B's bubble in both windows.

---

## STEP 6 — When Person B Speaks a Reply

Flutter records audio → send as multipart form:
POST /speech/transcribe
Body: form-data
  key: "audio"
  value: the recorded audio file (.webm or .mp3)

Returns: { "text": "transcribed words here" }
Show this text to Person B for confirmation before sending.
After confirmation → call /chat/session/message with sender "B".

---

## STEP 7 — When Speaker Button on a Bubble is Tapped

POST /speech/speak
Body: { "text": "the bubble text here" }

Returns audio bytes → play directly in Flutter.

---

## STEP 8 — When Language Toggle is Switched

For EACH bubble in the current chat:
POST /chat/translate
Body:
{
  "text": "original English text",
  "target_language": "hi"
}

Replace display text with translation.
IMPORTANT: Keep the original English stored separately.
Only change what is displayed, not what is stored.

---

## STEP 9 — When a Bubble is Long-Pressed to Edit

POST /chat/session/message/edit
Body:
{
  "session_id": "your-stored-id",
  "message_index": 0,
  "new_text": "corrected sentence here",
  "sender": "A"
}

This only works if no newer message from the same sender exists after it.
Handle the 403 error by showing "Cannot edit — newer message exists."

---

## STEP 10 — When Conversation is Reset

POST /chat/session/clear
Body: { "session_id": "your-stored-id" }

Then immediately call /chat/session/start again.
Store the new session_id, replacing the old one.

---

## Admin Dashboard Calls

Login:
POST /admin/login
Body: { "password": "admin password" }
Returns: { "token": "admin_authenticated" }
Store this token for subsequent admin calls.

Get all settings:
GET /admin/settings?token=admin_authenticated

Update settings:
POST /admin/settings/update
Body:
{
  "password": "admin password",
  "store_type": "coffee_shop",
  "is_online": true,
  "window_mode": "customer_A_input",
  "custom_suggestions_A": ["I need help", "How much is this?"],
  "custom_suggestions_B": ["Hello!", "Let me check that"]
}

---

## conversation_history Format (IMPORTANT)

Every time you send conversation_history, it must be a list like this:
[
  {"sender": "B", "text": "Hello, how can I help?"},
  {"sender": "A", "text": "I need help"},
  {"sender": "B", "text": "Of course!"}
]

Keep this list in your top-level app state.
Add every new message to it as they come in.
Only send the last 4 entries to keep requests fast.

---

## Which Windows Call Which Endpoints

Person A Input Window:
- /suggestions/paraphrase (auto after sign)
- /suggestions/template (side panel)
- /suggestions/smart (side panel if no template match)
- /suggestions/predefined (offline mode)
- /chat/session/message (auto after paraphrase, and when chip tapped)
- /chat/translate (on language toggle)
- /chat/session/message/edit (on long press)
- /speech/speak (on speaker button tap)

Person B Output Window:
- /suggestions/followup (after A sends a message)
- /speech/transcribe (when B speaks reply)
- /chat/session/message (when B sends reply)
- /speech/speak (on speaker button tap)
- /chat/translate (on language toggle)

Person A Output Window:
- Read-only. Just displays chat history. No API calls needed.

Person B Input Window:
- Same as Person A Input Window but send screen: "B" in all suggestion calls.

Admin Dashboard:
- /admin/login
- /admin/settings (GET)
- /admin/settings/update (POST)
- /admin/settings/public (GET, on launch)