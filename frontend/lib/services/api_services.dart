import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://asl-retail-backend.onrender.com';

  // ── APP LAUNCH ──────────────────────────────────────────────

  static Future<Map<String, dynamic>> getPublicSettings() async {
    final res = await http.get(Uri.parse('$baseUrl/admin/settings/public'));
    return jsonDecode(res.body);
  }

  // ── SESSION ──────────────────────────────────────────────────

  static Future<Map<String, dynamic>> startSession() async {
    final res = await http.post(
      Uri.parse('$baseUrl/chat/session/start'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> sendMessage(
      String sessionId, String sender, String text) async {
    final res = await http.post(
      Uri.parse('$baseUrl/chat/session/message'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'session_id': sessionId,
        'sender': sender,
        'text': text,
      }),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getHistory(String sessionId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/chat/session/$sessionId/history'),
    );
    return jsonDecode(res.body);
  }

  static Future<void> clearSession(String sessionId) async {
    await http.post(
      Uri.parse('$baseUrl/chat/session/clear'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'session_id': sessionId}),
    );
  }

  static Future<Map<String, dynamic>> editMessage(
      String sessionId, int index, String newText, String sender) async {
    final res = await http.post(
      Uri.parse('$baseUrl/chat/session/message/edit'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'session_id': sessionId,
        'message_index': index,
        'new_text': newText,
        'sender': sender,
      }),
    );
    return jsonDecode(res.body);
  }

  // ── SUGGESTIONS ──────────────────────────────────────────────

  static Future<Map<String, dynamic>> getTemplSuggestions(
      String sign, String screen) async {
    final res = await http.post(
      Uri.parse('$baseUrl/suggestions/template'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'detected_sign': sign, 'screen': screen}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getSmartSuggestions(
      String sign, List history, String screen, String storeType) async {
    final res = await http.post(
      Uri.parse('$baseUrl/suggestions/smart'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'detected_sign': sign,
        'conversation_history': history,
        'screen': screen,
        'store_type': storeType,
      }),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getPredefined(
      String storeType, String screen) async {
    final res = await http.post(
      Uri.parse('$baseUrl/suggestions/predefined'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'store_type': storeType, 'screen': screen}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getFollowup(
      String chosen, List history, String storeType) async {
    final res = await http.post(
      Uri.parse('$baseUrl/suggestions/followup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'chosen_suggestion': chosen,
        'conversation_history': history,
        'store_type': storeType,
      }),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> paraphraseSign(
      String sign, List history, String screen, String storeType) async {
    final res = await http.post(
      Uri.parse('$baseUrl/suggestions/paraphrase'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'raw_sign': sign,
        'conversation_history': history,
        'screen': screen,
        'store_type': storeType,
      }),
    );
    return jsonDecode(res.body);
  }

  // ── TRANSLATION ───────────────────────────────────────────────

  static Future<Map<String, dynamic>> translate(
      String text, String targetLang) async {
    final res = await http.post(
      Uri.parse('$baseUrl/chat/translate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'text': text, 'target_language': targetLang}),
    );
    return jsonDecode(res.body);
  }

  // ── SPEECH ────────────────────────────────────────────────────

  static Future<List<int>> textToSpeech(String text) async {
    final res = await http.post(
      Uri.parse('$baseUrl/speech/speak'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'text': text}),
    );
    return res.bodyBytes;
  }

  // For speech-to-text, Person 1 sends a recorded audio file as multipart
  // She handles that directly in her widget — too file-specific for a generic helper

  // ── ADMIN ─────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> adminLogin(String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/admin/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'password': password}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getAdminSettings(String token) async {
    final res = await http.get(
      Uri.parse('$baseUrl/admin/settings?token=$token'),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> updateAdminSettings(
      String password, Map<String, dynamic> updates) async {
    final body = {'password': password, ...updates};
    final res = await http.post(
      Uri.parse('$baseUrl/admin/settings/update'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return jsonDecode(res.body);
  }
}