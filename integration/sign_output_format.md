# Sign Output Format — Agreement for Person 2 and Person 4

## Person 2 (Alphabet Model) Output
When your model detects a letter, emit this JSON:
{
  "sign": "H",
  "confidence": 0.91,
  "source": "alphabet_model"
}

## Person 4 (Word Model) Output  
When your model detects a word, emit this JSON:
{
  "sign": "HELP",
  "confidence": 0.88,
  "source": "word_model"
}

## Rules
- confidence below 0.6 → do not emit, ignore the detection
- sign must be UPPERCASE always
- source must be exactly "alphabet_model" or "word_model"

## What Happens Next (Person 4's Bridge Job)
Person 4 collects these emissions and calls the backend.

For a word sign (source = word_model):
POST https://asl-retail-backend.onrender.com/stitch/
Body:
{
  "tokens": ["HELP"],
  "store_type": "default",
  "screen": "A",
  "conversation_history": []
}

For fingerspelled letters (source = alphabet_model):
Collect letters until 1.5 seconds of no new letter arrives.
Then send all collected letters together:
POST https://asl-retail-backend.onrender.com/stitch/
Body:
{
  "tokens": ["H", "E", "L", "P"],
  "store_type": "default",
  "screen": "A",
  "conversation_history": []
}

The backend returns:
{
  "paraphrased": "I need help, please.",
  "raw": "HELP"
}

Pass this paraphrased sentence to Flutter.