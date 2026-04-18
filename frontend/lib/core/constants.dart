class AppConstants {
  // ---------------------------------------------------------
  // 1. BACKEND SETTINGS
  // ---------------------------------------------------------
  // This is the default local port for Python Flask/FastAPI. 
  // We can change this later when you host your backend!
  static const String localApiBaseUrl = 'http://127.0.0.1:5000'; 

  // ---------------------------------------------------------
  // 2. UI STRINGS
  // ---------------------------------------------------------
  static const String cameraPlaceholder = "Camera Feed\n(MediaPipe Integration Pending)";

  // ---------------------------------------------------------
  // 3. SMART SUGGESTIONS (Dynamic Roles)
  // ---------------------------------------------------------
  // Suggestions for whoever is acting as the Customer
  static const List<String> customerSuggestions = [
    "I need help.",
    "can i get a coffee?",
    "Do you have this in stock?",
    "What is the price?",
  ];

  // Suggestions for whoever is acting as the Admin (Cashier)
  static const List<String> adminSuggestions = [
    "How can I help you?",
    "Let me check the stock for you.",
    "That will be...",
    "Here is your receipt.",
  ];
}