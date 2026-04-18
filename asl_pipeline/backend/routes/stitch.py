class StitchRequest(BaseModel):
    tokens: list         # e.g. ["H","E","L","P"] or ["HELP"] or ["H","I"]
    store_type: str = "default"
    screen: str = "A"
    conversation_history: list = []

@router.post("/stitch")
async def stitch_signs(req: StitchRequest):
    """
    Receives a list of detected tokens (words or letters).
    Figures out if it's a fingerspelled word or a sign word.
    Returns a paraphrased sentence ready for chat.
    """
    # If single token and it's a full word (not a single letter) → treat as word sign
    if len(req.tokens) == 1 and len(req.tokens[0]) > 1:
        raw = req.tokens[0]  # e.g. "HELP"
    else:
        # Multiple single letters → join into word
        raw = "".join(req.tokens)  # ["H","E","L","P"] → "HELP"
    
    # Now paraphrase it
    paraphrase_req = ParaphraseRequest(
        raw_sign=raw,
        conversation_history=req.conversation_history,
        store_type=req.store_type,
        screen=req.screen
    )
    return await paraphrase_sign(paraphrase_req)