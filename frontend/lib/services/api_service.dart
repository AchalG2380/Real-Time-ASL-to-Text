import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../core/constants.dart';

class ApiService {
  static const String baseUrl = AppConstants.localApiBaseUrl;

  // ── SETTINGS ─────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getPublicSettings() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/admin/settings/public'))
          .timeout(const Duration(seconds: 60));
      return jsonDecode(res.body);
    } catch (e) {
      print('getPublicSettings error: $e');
      return {
        'is_online': false,
        'store_type': 'default',
        'window_mode': 'customer_A_input',
      };
    }
  }

  // ── SESSION ──────────────────────────────────────────────────

  static Future<Map<String, dynamic>> startSession() async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/chat/session/start'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({}),
          )
          .timeout(const Duration(seconds: 60));
      return jsonDecode(res.body);
    } catch (e) {
      print('startSession error: $e');
      return {
        'session_id': '',
        'greeting': 'Hi! Please sign or type what you would like to say.',
      };
    }
  }

  static Future<Map<String, dynamic>> sendMessage(
    String sessionId,
    String sender,
    String text,
  ) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/chat/session/message'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'session_id': sessionId,
              'sender': sender,
              'text': text,
            }),
          )
          .timeout(const Duration(seconds: 10));
      return jsonDecode(res.body);
    } catch (e) {
      print('sendMessage error: $e');
      return {'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getHistory(String sessionId) async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/chat/session/$sessionId/history'))
          .timeout(const Duration(seconds: 10));
      return jsonDecode(res.body);
    } catch (e) {
      print('getHistory error: $e');
      return {'history': []};
    }
  }

  /// Polls the shared backend for all messages in a session.
  /// Used by Device B (cashier) to stay in sync with Device A (customer).
  static Future<Map<String, dynamic>> getMessages(String sessionId) async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/chat/session/$sessionId/history'))
          .timeout(const Duration(seconds: 8));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      // Backend returns 'history'; normalise to 'messages' key
      return {
        'messages': data['history'] ?? data['messages'] ?? [],
      };
    } catch (e) {
      return {'messages': []};
    }
  }

  static Future<void> clearSession(String sessionId) async {
    try {
      await http
          .post(
            Uri.parse('$baseUrl/chat/session/clear'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'session_id': sessionId}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      print('clearSession error: $e');
    }
  }

  static Future<Map<String, dynamic>> editMessage(
    String sessionId,
    int index,
    String newText,
    String sender,
  ) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/chat/session/message/edit'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'session_id': sessionId,
              'message_index': index,
              'new_text': newText,
              'sender': sender,
            }),
          )
          .timeout(const Duration(seconds: 10));
      return jsonDecode(res.body);
    } catch (e) {
      print('editMessage error: $e');
      return {'error': e.toString()};
    }
  }

  // ── SUGGESTIONS ──────────────────────────────────────────────

  static Future<Map<String, dynamic>> getTemplateSuggestions(
    String sign,
    String screen,
  ) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/suggestions/template'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'detected_sign': sign, 'screen': screen}),
          )
          .timeout(const Duration(seconds: 8));
      return jsonDecode(res.body);
    } catch (e) {
      print('getTemplateSuggestions error: $e');
      return {'matched': false, 'suggestions': []};
    }
  }

  static Future<Map<String, dynamic>> getSmartSuggestions(
    String sign,
    List history,
    String screen,
    String storeType,
  ) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/suggestions/smart'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'detected_sign': sign,
              'conversation_history': history,
              'screen': screen,
              'store_type': storeType,
            }),
          )
          .timeout(const Duration(seconds: 8));
      return jsonDecode(res.body);
    } catch (e) {
      print('getSmartSuggestions error: $e');
      return {'suggestions': []};
    }
  }

  static Future<Map<String, dynamic>> getPredefinedSuggestions(
    String storeType,
    String screen,
  ) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/suggestions/predefined'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'store_type': storeType, 'screen': screen}),
          )
          .timeout(const Duration(seconds: 8));
      return jsonDecode(res.body);
    } catch (e) {
      print('getPredefinedSuggestions error: $e');
      return {'suggestions': []};
    }
  }

  static Future<Map<String, dynamic>> getFollowupSuggestions(
    String chosen,
    List history,
    String storeType,
  ) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/suggestions/followup'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'chosen_suggestion': chosen,
              'conversation_history': history,
              'store_type': storeType,
            }),
          )
          .timeout(const Duration(seconds: 8));
      return jsonDecode(res.body);
    } catch (e) {
      print('getFollowupSuggestions error: $e');
      return {'suggestions': []};
    }
  }

  static Future<Map<String, dynamic>> paraphraseSign(
    String sign,
    List history,
    String screen,
    String storeType,
  ) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/suggestions/paraphrase'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'raw_sign': sign,
              'conversation_history': history,
              'screen': screen,
              'store_type': storeType,
            }),
          )
          .timeout(const Duration(seconds: 8));
      return jsonDecode(res.body);
    } catch (e) {
      print('paraphraseSign error: $e');
      return {'paraphrased': 'I need ${sign.toLowerCase()}', 'raw': sign};
    }
  }

  // ── TRANSLATION ───────────────────────────────────────────────

  static Future<Map<String, dynamic>> translate(
    String text,
    String targetLang,
  ) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/chat/translate'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'text': text, 'target_language': targetLang}),
          )
          .timeout(const Duration(seconds: 10));
      return jsonDecode(res.body);
    } catch (e) {
      print('translate error: $e');
      return {'translated': text};
    }
  }

  // ── SPEECH ────────────────────────────────────────────────────

  static Future<Uint8List> textToSpeech(String text) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/speech/speak'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'text': text}),
          )
          .timeout(const Duration(seconds: 15));
      return res.bodyBytes;
    } catch (e) {
      print('textToSpeech error: $e');
      return Uint8List(0);
    }
  }

  static Future<Map<String, dynamic>> transcribeAudio(
    List<int> audioBytes,
    String filename,
  ) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/speech/transcribe'),
      );
      request.files.add(
        http.MultipartFile.fromBytes('audio', audioBytes, filename: filename),
      );
      final streamed = await request.send().timeout(
        const Duration(seconds: 20),
      );
      final res = await http.Response.fromStream(streamed);
      return jsonDecode(res.body);
    } catch (e) {
      print('transcribeAudio error: $e');
      return {'text': ''};
    }
  }

  // ── ADMIN ─────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> adminLogin(String password) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/admin/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'password': password}),
          )
          .timeout(const Duration(seconds: 10));
      return jsonDecode(res.body);
    } catch (e) {
      print('adminLogin error: $e');
      return {'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getAdminSettings(String token) async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/admin/settings?token=$token'))
          .timeout(const Duration(seconds: 10));
      return jsonDecode(res.body);
    } catch (e) {
      print('getAdminSettings error: $e');
      return {'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> updateAdminSettings(
    String password,
    Map<String, dynamic> updates,
  ) async {
    try {
      final body = {'password': password, ...updates};
      final res = await http
          .post(
            Uri.parse('$baseUrl/admin/settings/update'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
      return jsonDecode(res.body);
    } catch (e) {
      print('updateAdminSettings error: $e');
      return {'error': e.toString()};
    }
  }
}
