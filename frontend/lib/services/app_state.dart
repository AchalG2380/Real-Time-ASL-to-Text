import 'dart:async';
import 'package:flutter/material.dart';
import '../core/constants.dart';
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

  // ── DEBOUNCE FILTER ───────────────────────────────────────────
  // A sign must arrive ≥2 times within 1.2 s to be confirmed.
  // This suppresses single-frame transitional detections.
  String? _pendingSign;
  int _pendingCount = 0;
  Timer? _debounceTimer;
  static const int _minSignCount = 2;
  static const int _debouncMs = 1200;

  // ── POLLING (Device B / cashier sync) ────────────────────────
  Timer? _pollTimer;

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
    socketService.setHost(AppConstants.aslEngineHost);
    socketService.connect((sign, confidence, source) {
      // Route through debounce filter — only stable signs reach handleIncomingSign
      _onSignReceived(sign, confidence, source);
    });

    // ── 5. Start polling for new messages (Device B / cashier real-time sync)
    _startPolling();

    isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _pollTimer?.cancel();
    socketService.disconnect();
    processService.stop();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // DEBOUNCE FILTER
  // ─────────────────────────────────────────────────────────────

  void _onSignReceived(String sign, double confidence, String source) {
    final sender = windowMode == 'customer_A_input' ? 'A' : 'B';

    if (sign == _pendingSign) {
      _pendingCount++;
    } else {
      // Different sign detected — reset counter
      _pendingSign = sign;
      _pendingCount = 1;
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(Duration(milliseconds: _debouncMs), () {
      if (_pendingCount >= _minSignCount && _pendingSign != null) {
        handleIncomingSign(_pendingSign!, sender);
      }
      _pendingSign = null;
      _pendingCount = 0;
    });
  }

  // ─────────────────────────────────────────────────────────────
  // POLLING — keeps Device B (cashier) in sync with Device A
  // ─────────────────────────────────────────────────────────────

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (sessionId.isEmpty) return;
      try {
        final result = await ApiService.getMessages(sessionId);
        final remote = List<Map<String, String>>.from(
          (result['messages'] as List? ?? []).map(
            (m) => {'sender': m['sender'] as String, 'text': m['text'] as String, 'originalText': m['text'] as String},
          ),
        );
        // Only update if something new arrived
        if (remote.length != messages.length) {
          messages = remote;
          notifyListeners();
        }
      } catch (_) {} // silently ignore poll failures
    });
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
    // Signs go to SUGGESTIONS first — user taps to confirm → then goes to chat.
    // Run paraphrase + template suggestions in parallel.
    loadingSuggestions = true;
    currentSuggestions = [];
    followupSuggestions = [];
    notifyListeners();

    final recentHistory = _getRecentHistory();
    try {
      final results = await Future.wait([
        ApiService.paraphraseSign(sign, recentHistory, screen, storeType),
        isOnline
            ? ApiService.getTemplateSuggestions(sign, screen)
            : ApiService.getPredefinedSuggestions(storeType, screen),
      ]);

      final sentence = results[0]['paraphrased'] ?? 'I need ${sign.toLowerCase()}';
      final extraSuggestions = List<String>.from(results[1]['suggestions'] ?? []);

      // Paraphrased sentence is first chip; add template suggestions below (deduped)
      currentSuggestions = [
        sentence,
        ...extraSuggestions.where((s) => s.trim().toLowerCase() != sentence.trim().toLowerCase()),
      ].take(5).toList();
    } catch (e) {
      currentSuggestions = ['I need ${sign.toLowerCase()}'];
    }

    loadingSuggestions = false;
    notifyListeners();
    // NOTE: addMessage() is NOT called here.
    // The user must tap a suggestion chip to send it to chat.
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
