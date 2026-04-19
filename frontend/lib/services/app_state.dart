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
  /// Device B sets this to Device A's session ID to receive their messages.
  String linkedSessionId = '';
  /// Returns linkedSessionId if set, otherwise own sessionId.
  String get activeSessionId => linkedSessionId.isNotEmpty ? linkedSessionId : sessionId;
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

    // ── 1. Launch the Python ASL engine (Device A only) ────────────
    // On Device B (cashier) the engine isn't available — skip silently.
    if (windowMode == 'customer_A_input' || AppConstants.aslEngineHost == 'localhost') {
      processService.onStatusChange = notifyListeners;
      processService.startAslEngine();
    }

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

    // Device B: auto-join Device A's session when Python relays it
    socketService.onSessionInfo = (String remoteSessionId) {
      if (linkedSessionId != remoteSessionId) {
        joinSession(remoteSessionId);
        print('[AppState] Auto-joined session from Device A: $remoteSessionId');
      }
    };

    socketService.connect(
      (sign, confidence, source) => _onSignReceived(sign, confidence, source),
      mySessionId: sessionId, // Device A registers this; Device B ignores it
    );

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

    // ── Word model signs are already confirmed by Python's own
    //    consecutive-frame logic → pass through immediately.
    if (source == 'word_model') {
      _pendingSign = null;
      _pendingCount = 0;
      _debounceTimer?.cancel();
      handleIncomingSign(sign, sender);
      return;
    }

    // ── Alphabet model: require _minSignCount consecutive same letter.
    //    Use count-based (not timer-based) so continuous signing doesn't
    //    perpetually reset and block delivery.
    if (sign != _pendingSign) {
      _pendingSign = sign;
      _pendingCount = 1;
    } else {
      _pendingCount++;
      if (_pendingCount >= _minSignCount) {
        _pendingSign = null;
        _pendingCount = 0;
        handleIncomingSign(sign, sender);
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  // POLLING — keeps Device B (cashier) in sync with Device A
  // ─────────────────────────────────────────────────────────────

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (activeSessionId.isEmpty) return;
      try {
        final result = await ApiService.getMessages(activeSessionId);
        final rawList = result['messages'] as List? ?? [];
        final remote = rawList.map((m) {
          // Backend may return 'sender'/'text' or 'role'/'content' — handle both
          final sender = (m['sender'] ?? m['role'] ?? 'A') as String;
          final text   = (m['text']   ?? m['content'] ?? '') as String;
          return <String, String>{'sender': sender, 'text': text, 'originalText': text};
        }).toList();
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

  /// Device B calls this with Device A's session ID to sync messages.
  void joinSession(String remoteSessionId) {
    linkedSessionId = remoteSessionId.trim();
    messages = [];          // clear local; polling will fill them in
    notifyListeners();
    print('[AppState] Joined session: $linkedSessionId');
  }

  // ─────────────────────────────────────────────────────────────
  // MESSAGES
  // ─────────────────────────────────────────────────────────────

  Future<void> addMessage(String sender, String text) async {
    messages.add({'sender': sender, 'text': text, 'originalText': text});
    notifyListeners();

    // Use activeSessionId so Device B's replies go to Device A's shared session
    final sid = activeSessionId;
    if (sid.isNotEmpty) {
      await ApiService.sendMessage(sid, sender, text);
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
    // ── Show instant fallback chips RIGHT NOW (no network wait) ──
    final capitalized = sign[0].toUpperCase() + sign.substring(1).toLowerCase();
    currentSuggestions = [
      'I need $capitalized',
      'Can I get $capitalized please?',
      capitalized,
    ];
    loadingSuggestions = true;
    followupSuggestions = [];
    notifyListeners(); // UI updates instantly

    // ── Then enhance with backend paraphrase + template suggestions ──
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

      currentSuggestions = List<String>.from([
        sentence,
        ...extraSuggestions.where((s) => s.trim().toLowerCase() != sentence.trim().toLowerCase()),
<<<<<<< HEAD
      ].take(5).toList().cast<String>();
=======
      ].take(5));
>>>>>>> 1a3b0abd1de31dcce9b5d89a02d3f6dc24505f17
    } catch (e) {
      // Keep the instant fallback chips already shown — don't wipe them
    }

    loadingSuggestions = false;
    notifyListeners();
    // NOTE: addMessage() is NOT called here.
    // The user taps a suggestion chip to send to chat.
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