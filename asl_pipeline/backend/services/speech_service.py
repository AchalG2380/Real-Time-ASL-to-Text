import os
import io
import tempfile
import whisper
from gtts import gTTS

# Load the Whisper model globally so it only loads once when the server starts.
# "base" is highly optimized for CPUs without a GPU.
print("Loading local Whisper model...")
model = whisper.load_model("base")
print("Model loaded successfully!")


async def transcribe_audio(audio_bytes: bytes, filename: str) -> str:
    """Uses local OpenAI Whisper to convert audio to text."""
    try:
        # Local Whisper needs a file path, so we create a temporary file
        with tempfile.NamedTemporaryFile(delete=False, suffix=".webm") as temp_audio:
            temp_audio.write(audio_bytes)
            temp_file_path = temp_audio.name
        
        # Transcribe the temporary file
        result = model.transcribe(temp_file_path)
        
        # Delete the temporary file to save space
        os.remove(temp_file_path)
        
        return result["text"]
        
    except Exception as e:
        print(f"Local Whisper STT error: {e}")
        return ""


async def synthesize_speech(text: str) -> bytes:
    """Uses gTTS (Google Text-to-Speech) to convert text to audio bytes."""
    try:
        # Create the gTTS object
        tts = gTTS(text=text, lang='en', slow=False)
        
        # Save the audio to an in-memory bytes buffer
        audio_fp = io.BytesIO()
        tts.write_to_fp(audio_fp)
        
        # Return the bytes exactly as the original OpenAI code did
        return audio_fp.getvalue()
        
    except Exception as e:
        print(f"gTTS error: {e}")
        return b""
    
    #edited by gemini 