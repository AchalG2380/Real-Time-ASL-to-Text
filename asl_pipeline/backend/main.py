from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routes import suggestions, chat, speech, admin, stitch

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(suggestions.router, prefix="/suggestions")
app.include_router(chat.router, prefix="/chat")
app.include_router(speech.router, prefix="/speech")
app.include_router(admin.router, prefix="/admin")
app.include_router(stitch.router, prefix="/stitch")

@app.get("/")
def health_check():
    return {"status": "running"}