import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Connects to the combined_asl_live.py WebSocket server running on
/// ws://localhost:8765 and fires [onSign] whenever a sign is detected.
class SocketService {
  static const int _wsPort = 8765;
  static const Duration _reconnectDelay = Duration(seconds: 3);

  String _host = 'localhost';

  /// Call before connect() to point at a different machine's ASL engine.
  void setHost(String host) {
    _host = host.trim().isEmpty ? 'localhost' : host.trim();
  }

  String get wsUrl => 'ws://$_host:$_wsPort';

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;

  // Callback supplied by the caller (AppState)
  void Function(String sign, double confidence, String source)? _onSign;

  bool _manuallyDisconnected = false;

  /// Call this once from AppState.initialize().
  /// [onSign] is called on the UI isolate whenever a sign is confirmed.
  void connect(
    void Function(String sign, double confidence, String source) onSign,
  ) {
    _onSign = onSign;
    _manuallyDisconnected = false;
    _tryConnect();
  }

  Future<void> _tryConnect() async {
    if (_manuallyDisconnected) return;

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      // web_socket_channel v3: must await ready to detect connection failure
      await _channel!.ready;

      print('[SocketService] Connected to $wsUrl');

      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: (err) {
          print('[SocketService] Stream error: $err');
          _scheduleReconnect();
        },
        onDone: () {
          print('[SocketService] Connection closed — reconnecting...');
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      print('[SocketService] Could not connect: $e');
      _channel = null;
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      final sign       = data['sign']       as String? ?? '';
      final confidence = (data['confidence'] as num?)?.toDouble() ?? 0.0;
      final source     = data['source']     as String? ?? '';

      if (sign.isNotEmpty && _onSign != null) {
        _onSign!(sign, confidence, source);
      }
    } catch (e) {
      print('[SocketService] Failed to parse message: $e  raw=$raw');
    }
  }

  void _scheduleReconnect() {
    _subscription?.cancel();
    _subscription = null;
    _channel = null;

    if (_manuallyDisconnected) return;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, _tryConnect);
  }

  /// Cleanly stop the connection and cancel reconnect timers.
  void disconnect() {
    _manuallyDisconnected = true;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    print('[SocketService] Disconnected.');
  }
}
