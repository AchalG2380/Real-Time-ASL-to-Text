import 'package:flutter/material.dart';
import 'api_service.dart';
import 'socket_service.dart';
import 'process_service.dart';

class AppState extends ChangeNotifier {
  // ── SETTINGS ─────────────────────────────────────────────────
  bool isOnline = false;
  String storeType = 'default';
  String windowMode = 'customer_A_input';
  bool isLoading = true;
  String errorMessage = '';

  // ── SESSION ──────────────────────────────────────────────────
  String sessionId = '';
  String greeting = 'Hi! Please sign or type what you would like to say.';

  // ── MESSAGES ─────────────────────────────────────────────────
  // Each entry: {'sender': 'A'/'B', 'text': '...', 'originalText': '...'}
  List<Map<String, String>> messages = [];

  // ── LANGUAGE ─────────────────────────────────────────────────
  String currentLanguage = 'en';

  // ── SUGGESTIONS ──────────────────────────────────────────────
  List<String> currentSuggestions = [];
  List<String> followupSuggestions = [];
  bool loadingSuggestions = false;

  // ── ML SOCKET ────────────────────────────────────────────────
  final SocketService socketService = SocketService();

  // ── ASL ENGINE PROCESS ───────────────────────────────────────
  final ProcessService processService = ProcessService();
  bool get aslEngineRunning => processService.isRunning;
  String get aslEngineStatus => processService.statusMessage;

  // ── ADMIN ─────────────────────────────────────────────────────
  String adminToken = '';
  bool isAdminLoggedIn = false;

  // ─────────────────────────────────────────────────────────────
  // STARTUP
  // ─────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    isLoading = true;
    errorMessage = '';
    notifyListeners();

    // ── 1. Launch the Python ASL engine ──────────────────────────
    processService.onStatusChange = notifyListeners;
    processService.startAslEngine(); // fire-and-forget; UI reacts via onStatusChange

    // ── 2. Fetch backend settings ─────────────────────────────────
    try {
      final settings = await ApiService.getPublicSettings();
      isOnline = settings['is_online'] ?? false;
      storeType = settings['store_type'] ?? 'default';
      windowMode = settings['window_mode'] ?? 'customer_A_input';
    } catch (e) {
      errorMessage = 'Could not reach server. Running in offline mode.';
      isOnline = false;
    }

    // ── 3. Start chat session ─────────────────────────────────────
    try {
      final session = await ApiService.startSession();
      sessionId = session['session_id'] ?? '';
      greeting = session['greeting'] ?? greeting;
    } catch (e) {
      errorMessage = 'Could not start session. Please restart the app.';
    }

    // ── 4. Connect WebSocket (give Python ~3 s to start its WS server)
    await Future.delayed(const Duration(seconds: 3));
    socketService.connect((sign, confidence, source) {
      handleIncomingSign(sign, windowMode == 'customer_A_input' ? 'A' : 'B');
    });

    isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    socketService.disconnect();
    processService.stop();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // SESSION
  // ─────────────────────────────────────────────────────────────

  Future<void> resetConversation() async {
    if (sessionId.isNotEmpty) {
      await ApiService.clearSession(sessionId);
    }
    final session = await ApiService.startSession();
    sessionId = session['session_id'] ?? '';
    messages = [];
    currentSuggestions = [];
    followupSuggestions = [];
    currentLanguage = 'en';
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────
  // MESSAGES
  // ─────────────────────────────────────────────────────────────

  Future<void> addMessage(String sender, String text) async {
    messages.add({'sender': sender, 'text': text, 'originalText': text});
    notifyListeners();

    if (sessionId.isNotEmpty) {
      await ApiService.sendMessage(sessionId, sender, text);
    }
  }

  // Returns true if edit succeeded, false if blocked
  Future<bool> editMessage(int index, String newText, String sender) async {
    if (sessionId.isEmpty) return false;
    final result = await ApiService.editMessage(
      sessionId,
      index,
      newText,
      sender,
    );
    if (!result.containsKey('error')) {
      messages[index]['text'] = newText;
      messages[index]['originalText'] = newText;
      notifyListeners();
      return true;
    }
    return false;
  }

  // ─────────────────────────────────────────────────────────────
  // SIGN HANDLING — called by Person 4's bridge
  // ─────────────────────────────────────────────────────────────

  Future<void> handleIncomingSign(String sign, String screen) async {
    // 1. Paraphrase sign and auto-post to chat
    final recentHistory = _getRecentHistory();
    final paraphrase = await ApiService.paraphraseSign(
      sign,
      recentHistory,
      screen,
      storeType,
    );
    final sentence =
        paraphrase['paraphrased'] ?? 'I need ${sign.toLowerCase()}';
    await addMessage(screen, sentence);

    // 2. Load suggestions for side panel at the same time
    await _loadSuggestions(sign, screen);
  }

  Future<void> _loadSuggestions(String sign, String screen) async {
    loadingSuggestions = true;
    currentSuggestions = [];
    followupSuggestions = [];
    notifyListeners();

    if (isOnline) {
      final template = await ApiService.getTemplateSuggestions(sign, screen);
      if (template['matched'] == true) {
        currentSuggestions = List<String>.from(template['suggestions'] ?? []);
      } else {
        final smart = await ApiService.getSmartSuggestions(
          sign,
          _getRecentHistory(),
          screen,
          storeType,
        );
        currentSuggestions = List<String>.from(smart['suggestions'] ?? []);
      }
    } else {
      final pre = await ApiService.getPredefinedSuggestions(storeType, screen);
      currentSuggestions = List<String>.from(pre['suggestions'] ?? []);
    }

    loadingSuggestions = false;
    notifyListeners();
  }

  Future<void> onSuggestionTapped(String suggestion, String sender) async {
    await addMessage(sender, suggestion);
    currentSuggestions = [];
    notifyListeners();

    if (isOnline) {
      final followup = await ApiService.getFollowupSuggestions(
        suggestion,
        _getRecentHistory(),
        storeType,
      );
      followupSuggestions = List<String>.from(followup['suggestions'] ?? []);
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // LANGUAGE
  // ─────────────────────────────────────────────────────────────

  Future<void> switchLanguage(String langCode) async {
    if (langCode == currentLanguage) return;
    currentLanguage = langCode;

    if (langCode == 'en') {
      for (var msg in messages) {
        msg['text'] = msg['originalText'] ?? msg['text']!;
      }
    } else {
      for (var msg in messages) {
        final result = await ApiService.translate(
          msg['originalText'] ?? msg['text']!,
          langCode,
        );
        msg['text'] = result['translated'] ?? msg['text']!;
      }
    }
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────
  // ADMIN
  // ─────────────────────────────────────────────────────────────

  Future<bool> adminLogin(String password) async {
    final result = await ApiService.adminLogin(password);
    if (result['token'] == 'admin_authenticated') {
      adminToken = result['token'];
      isAdminLoggedIn = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<Map<String, dynamic>> loadAdminSettings() async {
    return await ApiService.getAdminSettings(adminToken);
  }

  Future<void> saveAdminSettings(
    String password,
    Map<String, dynamic> updates,
  ) async {
    await ApiService.updateAdminSettings(password, updates);
    if (updates.containsKey('is_online')) isOnline = updates['is_online'];
    if (updates.containsKey('store_type')) storeType = updates['store_type'];
    if (updates.containsKey('window_mode')) windowMode = updates['window_mode'];
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────

  List<Map<String, String>> _getRecentHistory() {
    final recent = messages.length > 4
        ? messages.sublist(messages.length - 4)
        : messages;
    return recent
        .map(
          (m) => {
            'sender': m['sender']!,
            'text': m['originalText'] ?? m['text']!,
          },
        )
        .toList();
  }
}
