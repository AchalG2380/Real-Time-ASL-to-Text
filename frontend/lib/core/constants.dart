class AppConstants {
  // ---------------------------------------------------------
  // 1. API Endpoints (For connecting to your Python Backend)
  // ---------------------------------------------------------
  // Use this when running Python locally on your machine
  static const String localApiBaseUrl = "http://127.0.0.1:5000"; 
  // Update this later when you deploy your backend to Render
  static const String prodApiBaseUrl = "https://your-render-app.onrender.com"; 

  // ---------------------------------------------------------
  // 2. Offline Smart Suggestions (Customer / Input Window)
  // ---------------------------------------------------------
  static const List<String> inputSuggestions = [
    "I need help.",
    "Where is the fitting room?",
    "Do you have this in stock?",
    "What is the price?",
    "Thank you!"
  ];

  // ---------------------------------------------------------
  // 3. Offline Smart Suggestions (Cashier / Output Window)
  // ---------------------------------------------------------
  static const List<String> outputSuggestions = [
    "How can I help you?",
    "Let me check the stock for you.",
    "That will be...",
    "Here is your receipt.",
    "Have a great day!"
  ];

  // ---------------------------------------------------------
  // 4. General App Strings
  // ---------------------------------------------------------
  static const String appName = "Maneora ASL Desk";
  static const String cameraPlaceholder = "Camera Feed \n(MediaPipe Integration Pending)";
  static const String offlineModeWarning = "Offline Mode Active - Using Pre-defined Suggestions";
}