import 'package:flutter/material.dart';
import '../../core/constants.dart';
import 'widgets/glass_container.dart';
import '../output_screen/output_view.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class InputView extends StatefulWidget {
  final bool isAdmin;
  const InputView({Key? key, required this.isAdmin}) : super(key: key);

  @override
  State<InputView> createState() => _InputViewState();
}

class _InputViewState extends State<InputView> {
  // 8 Compact Predefined Suggestions
  final List<String> _suggestions = ["Hello", "Yes", "No", "Thanks", "Help", "Price", "Card", "Cash"];
  
  // Fake Chat Memory for Demo
  final List<Map<String, dynamic>> _messages = [
    {"text": ".", "isMe": false},
  ];

  // Frontend Mic Engine
  late stt.SpeechToText _speech;
  bool _isListening = false;
  final TextEditingController _chatController = TextEditingController();

  // Settings State
  bool _isOnlineMode = false;
  String _storeType = "Retail";

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(color: const Color(0xFF16181A)),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                // LEFT SIDE (Camera & 8 Small Suggestions)
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      const Expanded(flex: 5, child: GlassContainer(child: Center(child: Text("Camera Feed", style: TextStyle(color: Colors.white70))))),
                      const SizedBox(height: 16),
                      // THE 8 SMALL SUGGESTIONS
                      GlassContainer(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Wrap(
                            spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
                            children: _suggestions.map((text) => _buildSmallChip(text)).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),

                // RIGHT SIDE (Chat & Settings)
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      Expanded(
                        flex: 5,
                        child: GlassContainer(
                          child: Column(
                            children: [
                              const Padding(padding: EdgeInsets.all(16.0), child: Text("Live Translation", style: TextStyle(color: Colors.white, fontSize: 18))),
                              Divider(color: Colors.white.withOpacity(0.1), height: 1),
                              
                              // CHAT HISTORY
                              Expanded(
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: _messages.length,
                                  itemBuilder: (context, index) => _buildChatBubble(_messages[index]["text"], _messages[index]["isMe"]),
                                ),
                              ),

                              // INPUT FIELD WITH MIC
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: TextField(
                                  controller: _chatController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText: "Type or speak...",
                                    hintStyle: const TextStyle(color: Colors.white38),
                                    filled: true, fillColor: Colors.white.withOpacity(0.05),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                    // THE NEW MIC BUTTON
                                    prefixIcon: IconButton(
                                      icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: _isListening ? Colors.green : Colors.white70),
                                      onPressed: _listen,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.send, color: Colors.white),
                                      onPressed: () {
                                        if (_chatController.text.isNotEmpty) {
                                          setState(() => _messages.add({"text": _chatController.text, "isMe": true}));
                                          _chatController.clear();
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // SETTINGS ROW
                      widget.isAdmin ? _buildAdminSettingsRow() : const SizedBox(),
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

  // 1. SMALL SUGGESTION CHIP
  Widget _buildSmallChip(String text) {
    return GestureDetector(
      onTap: () => setState(() => _messages.add({"text": text, "isMe": true})),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ),
    );
  }

  // 2. CHAT BUBBLE WITH AUDIO BUTTON (Ready for Backend)
  Widget _buildChatBubble(String text, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF4A5C6D) : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(text, style: const TextStyle(color: Colors.white, fontSize: 14)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () {
                // TODO: Call your Backend API (/speech/speak) here!
                print("Calling backend to generate audio for: $text");
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.volume_up, size: 12, color: Colors.white.withOpacity(0.5)),
                  const SizedBox(width: 4),
                  Text("Listen", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  
  // 3. ADMIN SETTINGS
  Widget _buildAdminSettingsRow() {
    return SizedBox(
      height: 60,
      child: GlassContainer(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(icon: const Icon(Icons.settings, color: Colors.white), onPressed: _showSettingsDialog),
            IconButton(
              icon: const Icon(Icons.swap_horiz, color: Colors.white), 
              onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const OutputView(isAdmin: true))),
            ),
          ],
        ),
      ),
    );
  }

  // THE NEW SETTINGS PORTAL POPUP
  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder( // StatefulBuilder allows the popup to update its own switches
          builder: (context, setPopupState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF16181A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.white.withOpacity(0.1))),
              title: const Text("Admin Settings", style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Portal Switch
                  ListTile(
                    title: const Text("Current Portal", style: TextStyle(color: Colors.white70)),
                    subtitle: const Text("Input Mode (Sign)", style: TextStyle(color: Colors.greenAccent)),
                    trailing: IconButton(
                      icon: const Icon(Icons.swap_horiz, color: Colors.white),
                      onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const OutputView(isAdmin: true))),
                    ),
                  ),
                  const Divider(color: Colors.white24),
                  // Online/Offline Toggle
                  SwitchListTile(
                    title: const Text("AI Suggestions (Online Mode)", style: TextStyle(color: Colors.white)),
                    subtitle: Text(_isOnlineMode ? "Using AI API" : "Using Predefined Offline Store Data", style: const TextStyle(color: Colors.white38, fontSize: 12)),
                    value: _isOnlineMode,
                    activeColor: Colors.blueAccent,
                    onChanged: (val) {
                      setPopupState(() => _isOnlineMode = val);
                      setState(() => _isOnlineMode = val);
                    },
                  ),
                  const Divider(color: Colors.white24),
                  // Store Type Dropdown
                  ListTile(
                    title: const Text("Store Category", style: TextStyle(color: Colors.white)),
                    trailing: DropdownButton<String>(
                      dropdownColor: const Color(0xFF2A2D32),
                      value: _storeType,
                      style: const TextStyle(color: Colors.white),
                      items: ["Retail", "Bakery", "Cafe"].map((String value) {
                        return DropdownMenuItem<String>(value: value, child: Text(value));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setPopupState(() => _storeType = val);
                          setState(() => _storeType = val);
                        }
                      },
                    ),
                  ),
                ],
              ),
            );
          }
        );
      }
    );
  }
}