import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../services/app_state.dart';
import '../../services/api_service.dart';
import 'widgets/glass_container.dart';
import '../output_screen/output_view.dart';
import 'widgets/inventory_panel.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

class InputView extends StatefulWidget {
  final bool isAdmin;
  const InputView({Key? key, required this.isAdmin}) : super(key: key);

  @override
  State<InputView> createState() => _InputViewState();
}

class _InputViewState extends State<InputView> {
  // 8 compact predefined suggestions (no emojis)
  final List<String> _suggestions = [
    "Hello", "Yes", "No", "Thanks", "Help", "Price", "Card", "Cash"
  ];

  final List<Map<String, dynamic>> _messages = [
    {"text": "Hi! Please sign or type what you'd like to say.", "isMe": false},
  ];

  late stt.SpeechToText _speech;
  final FlutterTts _flutterTts = FlutterTts();
  bool _isListening = false;
  final TextEditingController _chatController = TextEditingController();

  bool _isOnlineMode = false;
  String _storeType = "Retail";

  // Custom suggestions added by staff in settings
  final List<String> _customSuggestions = [];
  final TextEditingController _customSuggestionController = TextEditingController();

 @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    // Sync AppState's greeting into messages on first load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      if (appState.messages.isEmpty && appState.greeting.isNotEmpty) {
        appState.addMessage('system', appState.greeting);
      }
    });
  }

  @override
  void dispose() {
    _chatController.dispose();
    _customSuggestionController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    final appState = context.read<AppState>();
    appState.addMessage(AppConstants.kSenderA, text.trim());
    _chatController.clear();
  }

  void onSignReceived(String sign) {
    final appState = context.read<AppState>();
    appState.handleIncomingSign(sign, AppConstants.kScreenA);
  }

  Future<void> _speakText(String text) async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.speak(text);
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(onResult: (val) {
          setState(() {
            _chatController.text = val.recognizedWords;
          });
        });
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  void _showInventory() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => InventoryPanel(
        onItemSelected: (message) {
          _sendMessage(message);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return Scaffold(
      body: Stack(
        children: [
          Container(color: const Color(0xFF16181A)),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                // LEFT SIDE — Camera and suggestion chips
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      const Expanded(
                        flex: 5,
                        child: GlassContainer(
                          child: Center(
                            child: Text(
                              "Camera Feed",
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      GlassContainer(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              // AI/backend suggestions (shown when available)
                              ...appState.currentSuggestions.map((text) =>
                                  _buildSmallChip(text, isAI: true)),
                              // Followup suggestions
                              ...appState.followupSuggestions.map((text) =>
                                  _buildSmallChip(text, isFollowup: true)),
                              // Static fallback chips
                              ..._suggestions.map((text) => _buildSmallChip(text)),
                              ..._customSuggestions.map((text) => _buildSmallChip(text)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),

                // RIGHT SIDE — Chat, input, and bottom action area
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      // Chat window
                      Expanded(
                        flex: 5,
                        child: GlassContainer(
                          child: Column(
                            children: [
                              const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text(
                                  "Live Translation",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              Divider(
                                color: Colors.white.withOpacity(0.1),
                                height: 1,
                              ),
                              // Chat history
                              Expanded(
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: appState.messages.length,
                                  itemBuilder: (context, index) {
                                    final msg = appState.messages[index];
                                    final isMe = msg['sender'] == AppConstants.kSenderA;
                                    return _buildChatBubble(
                                      msg['text'] ?? '',
                                      isMe,
                                      index,
                                      msg['sender'] ?? 'A',
                                    );
                                  },
                                ),
                              ),
                              // Text input
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: TextField(
                                  controller: _chatController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText: "Type or speak...",
                                    hintStyle: const TextStyle(
                                        color: Colors.white38),
                                    filled: true,
                                    fillColor:
                                        Colors.white.withOpacity(0.05),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                    prefixIcon: IconButton(
                                      icon: Icon(
                                        _isListening
                                            ? Icons.mic
                                            : Icons.mic_none,
                                        color: _isListening
                                            ? Colors.green
                                            : Colors.white70,
                                      ),
                                      onPressed: _listen,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.send,
                                          color: Colors.white),
                                      onPressed: () =>
                                          _sendMessage(_chatController.text),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // BOTTOM ACTION AREA
                      // Guest mode: shows "View Available Items" button
                      // Staff/Admin mode: shows settings + switch icons
                      if (!widget.isAdmin)
                        _buildGuestBottomBar()
                      else
                        _buildAdminSettingsRow(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Guest bottom bar — View Available Items button
  Widget _buildGuestBottomBar() {
    return SizedBox(
      height: 60,
      child: GlassContainer(
        child: Center(
          child: TextButton.icon(
            onPressed: _showInventory,
            icon: const Icon(
              Icons.shopping_basket_outlined,
              color: Colors.white70,
              size: 18,
            ),
            label: const Text(
              'View Available Items',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ),
      ),
    );
  }

  // Admin bottom bar — settings and switch icons
  Widget _buildAdminSettingsRow() {
    return SizedBox(
      height: 60,
      child: GlassContainer(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // TEMPORARY TEST BUTTON — remove before final demo
            IconButton(
              icon: const Icon(Icons.science, color: Colors.amberAccent),
              tooltip: 'Test: Send HELP sign',
              onPressed: () => onSignReceived('HELP'),
            ),
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.white),
              onPressed: _showSettingsDialog,
            ),
            IconButton(
              icon: const Icon(Icons.swap_horiz, color: Colors.white),
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const OutputView(isAdmin: true),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallChip(String text, {bool isAI = false, bool isFollowup = false}) {
    final appState = context.read<AppState>();
    return GestureDetector(
      onTap: () {
        if (isAI || isFollowup) {
          appState.onSuggestionTapped(text, AppConstants.kSenderA);
        } else {
          _sendMessage(text);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isAI
              ? Colors.blueAccent.withOpacity(0.15)
              : isFollowup
                  ? Colors.greenAccent.withOpacity(0.1)
                  : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: isAI
              ? Border.all(color: Colors.blueAccent.withOpacity(0.3))
              : null,
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isAI ? Colors.blueAccent : Colors.white,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildChatBubble(String text, bool isMe, int index, String sender) {
    return GestureDetector(
      onLongPress: () async {
        // Long press to edit — only works before next message from same sender
        final controller = TextEditingController(text: text);
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF16181A),
            title: const Text('Edit message', style: TextStyle(color: Colors.white)),
            content: TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final appState = context.read<AppState>();
                  final success = await appState.editMessage(index, controller.text, sender);
                  if (!success && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cannot edit — a newer message exists')),
                    );
                  }
                },
                child: const Text('Save', style: TextStyle(color: Colors.blueAccent)),
              ),
            ],
          ),
        );
      },
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMe
                ? const Color(0xFF4A5C6D)
                : Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(text, style: const TextStyle(color: Colors.white, fontSize: 14)),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => _speakText(text),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.volume_up, size: 12, color: Colors.white.withOpacity(0.5)),
                    const SizedBox(width: 4),
                    Text(
                      "Listen",
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setPopupState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF16181A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              title: const Text(
                "Admin Settings",
                style: TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Portal switch
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        "Current Portal",
                        style: TextStyle(color: Colors.white70),
                      ),
                      subtitle: const Text(
                        "Input Mode (Sign)",
                        style: TextStyle(color: Colors.greenAccent),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.swap_horiz,
                            color: Colors.white),
                        onPressed: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const OutputView(isAdmin: true),
                          ),
                        ),
                      ),
                    ),
                    Divider(color: Colors.white.withOpacity(0.15)),

                    // Online/Offline toggle
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        "AI Suggestions (Online Mode)",
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        _isOnlineMode
                            ? "Using AI API"
                            : "Using Predefined Offline Data",
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12),
                      ),
                      value: _isOnlineMode,
                      activeColor: Colors.blueAccent,
                      onChanged: (val) {
                        setPopupState(() => _isOnlineMode = val);
                        setState(() => _isOnlineMode = val);
                        // Sync to backend
                        final appState = context.read<AppState>();
                        appState.saveAdminSettings(
                          '',
                          {'is_online': val},
                        );
                      },
                    ),
                    Divider(color: Colors.white.withOpacity(0.15)),

                    // Store type dropdown
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        "Store Category",
                        style: TextStyle(color: Colors.white),
                      ),
                      trailing: DropdownButton<String>(
                        dropdownColor: const Color(0xFF2A2D32),
                        value: _storeType,
                        style: const TextStyle(color: Colors.white),
                        items: ["Retail", "Bakery", "Cafe"].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setPopupState(() => _storeType = val);
                            setState(() => _storeType = val);
                          }
                        },
                      ),
                    ),
                    Divider(color: Colors.white.withOpacity(0.15)),

                    // Custom suggestions section
                    const Text(
                      "Custom Suggestions",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Add your own suggestion chips to the sign screen.",
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    const SizedBox(height: 12),

                    // Input row to add new custom suggestion
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _customSuggestionController,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: "e.g. Do you accept UPI?",
                              hintStyle: const TextStyle(
                                  color: Colors.white30, fontSize: 13),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.05),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            final text =
                                _customSuggestionController.text.trim();
                            if (text.isNotEmpty) {
                              setPopupState(() {
                                _customSuggestions.add(text);
                                _customSuggestionController.clear();
                              });
                              setState(() {});
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.blueAccent.withOpacity(0.4)),
                            ),
                            child: const Icon(Icons.add,
                                color: Colors.blueAccent, size: 20),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // List of added custom suggestions
                    if (_customSuggestions.isNotEmpty) ...[
                      ..._customSuggestions.asMap().entries.map((entry) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.08)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  entry.value,
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 13),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  setPopupState(() {
                                    _customSuggestions.removeAt(entry.key);
                                  });
                                  setState(() {});
                                },
                                child: const Icon(Icons.close,
                                    color: Colors.white30, size: 16),
                              ),
                            ],
                          ),
                        );
                      }),
                    ] else
                      const Text(
                        "No custom suggestions added yet.",
                        style:
                            TextStyle(color: Colors.white24, fontSize: 12),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Done",
                    style: TextStyle(color: Colors.blueAccent),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}