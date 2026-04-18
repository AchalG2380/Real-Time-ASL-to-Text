# API Contract — Quick Reference

Base URL: https://asl-retail-backend.onrender.com

ENDPOINT                          METHOD   WHO CALLS IT
/admin/settings/public            GET      Flutter on launch
/chat/session/start               POST     Flutter on new conversation
/chat/session/message             POST     Flutter when any message sent
/chat/session/{id}/history        GET      Flutter to reload chat
/chat/session/clear               POST     Flutter on reset
/chat/session/message/edit        POST     Flutter on long press edit
/chat/translate                   POST     Flutter on language toggle
/suggestions/paraphrase           POST     Flutter after sign detected
/suggestions/template             POST     Flutter after sign detected
/suggestions/smart                POST     Flutter if no template match
/suggestions/predefined           POST     Flutter in offline mode
/suggestions/followup             POST     Flutter when chip tapped
/stitch/                          POST     Person 4's bridge
/speech/transcribe                POST     Flutter when B speaks
/speech/speak                     POST     Flutter when speaker tapped
/admin/login                      POST     Admin dashboard
/admin/settings                   GET      Admin dashboard
/admin/settings/update            POST     Admin dashboard