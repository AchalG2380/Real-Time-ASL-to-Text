import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../services/app_state.dart';
import '../../services/api_service.dart';
import '../input_screen/widgets/glass_container.dart';
import '../input_screen/input_view.dart';
import 'package:flutter_tts/flutter_tts.dart';

class OutputView extends StatefulWidget {
  final bool isAdmin;
  const OutputView({Key? key, required this.isAdmin}) : super(key: key);

  @override
  State<OutputView> createState() => _OutputViewState();
}

class _OutputViewState extends State<OutputView> {
  final TextEditingController _replyController = TextEditingController();
  final FlutterTts _flutterTts = FlutterTts();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _replyController.dispose();
    _flutterTts.stop();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _speakText(String text) async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.speak(text);
  }

  void _sendReply() {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;
    final appState = context.read<AppState>();
    appState.addMessage(AppConstants.kSenderB, text);
    _replyController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      body: Stack(
        children: [
          // 1. BACKGROUND
          Container(color: const Color(0xFF16181A)), 
          Positioned(
            top: -150, left: -150,
            child: Container(
              width: 600, height: 600,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.03), 
                boxShadow: [BoxShadow(color: Colors.white.withOpacity(0.04), blurRadius: 150, spreadRadius: 50)],
              ),
            ),
          ),
          Positioned(
            bottom: -200, right: -100,
            child: Container(
              width: 700, height: 700,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF5A6B7C).withOpacity(0.15), 
                boxShadow: [BoxShadow(color: const Color(0xFF5A6B7C).withOpacity(0.15), blurRadius: 200, spreadRadius: 100)],
              ),
            ),
          ),

          // 2. MAIN UI
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  // LEFT SIDE (Chat)
                  Expanded(
                    flex: 6,
                    child: GlassContainer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Live ASL Translation", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                                IconButton(icon: const Icon(Icons.volume_up, color: Colors.white), onPressed: () {}),
                              ],
                            ),
                          ),
                          Divider(color: Colors.white.withOpacity(0.1), height: 1),
                          Expanded(
                            child: appState.messages.isEmpty
                                ? const Center(
                                    child: Text(
                                      "Awaiting input...",
                                      style: TextStyle(color: Colors.white54, fontSize: 18),
                                    ),
                                  )
                                : ListView.builder(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.all(16),
                                    itemCount: appState.messages.length,
                                    itemBuilder: (context, index) {
                                      final msg = appState.messages[index];
                                      final isB = msg['sender'] == AppConstants.kSenderB;
                                      return Align(
                                        alignment: isB
                                            ? Alignment.centerRight
                                            : Alignment.centerLeft,
                                        child: GestureDetector(
                                          onTap: () => _speakText(msg['text'] ?? ''),
                                          child: Container(
                                            margin: const EdgeInsets.only(bottom: 12),
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: isB
                                                  ? const Color(0xFF4A5C6D)
                                                  : Colors.white.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: isB
                                                  ? CrossAxisAlignment.end
                                                  : CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  msg['text'] ?? '',
                                                  style: const TextStyle(
                                                      color: Colors.white, fontSize: 16),
                                                ),
                                                const SizedBox(height: 4),
                                                Icon(Icons.volume_up,
                                                    size: 12,
                                                    color: Colors.white.withOpacity(0.4)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          
                          // --- THE SAFE TEXT BOX WITH MAGIC WAND ---
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: TextField(
                              controller: _replyController,
                              style: const TextStyle(color: Colors.white),
                              onSubmitted: (_) => _sendReply(),
                              decoration: InputDecoration(
                                hintText: "Type or speak...",
                                hintStyle: const TextStyle(color: Colors.white38),
                                filled: true, fillColor: Colors.white.withOpacity(0.05),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                prefixIcon: IconButton(
                                  icon: const Icon(Icons.mic_none, color: Colors.white70),
                                  onPressed: () {},
                                ),
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Tooltip(
                                      message: "Smart Suggestions",
                                      child: PopupMenuButton<String>(
                                        icon: const Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 20),
                                        color: const Color(0xFF2A2D32),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        tooltip: "",
                                        itemBuilder: (BuildContext context) {
                                          final appState = context.read<AppState>();
                                          final suggestions = appState.currentSuggestions.isNotEmpty
                                              ? appState.currentSuggestions
                                              : AppConstants.adminSuggestions;
                                          return suggestions.map((String choice) {
                                            return PopupMenuItem<String>(
                                              value: choice,
                                              child: Text(choice, style: const TextStyle(color: Colors.white70)),
                                            );
                                          }).toList();
                                        },
                                        onSelected: (String value) {
                                          final appState = context.read<AppState>();
                                          appState.onSuggestionTapped(value, AppConstants.kSenderB);
                                          _replyController.text = value;
                                        },
                                      ),
                                    ),
                                    Container(
                                      margin: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: IconButton(
                                        icon: const Icon(Icons.send, color: Colors.white, size: 18),
                                        onPressed: _sendReply,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),

                  // RIGHT SIDE (Controls)
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        Expanded(
                          flex: 3,
                          child: GlassContainer(
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                const Center(child: Text("Camera Mirror", textAlign: TextAlign.center, style: TextStyle(color: Colors.white54))),
                                Positioned(top: 16, right: 16, child: Container(width: 12, height: 12, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle))),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          flex: 4,
                          child: GlassContainer(
                            child: ListView(
                              padding: const EdgeInsets.all(16),
                              children: [
                                const Text("Smart Replies", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 12),
                                ...(appState.currentSuggestions.isNotEmpty
                                        ? appState.currentSuggestions
                                        : (widget.isAdmin
                                            ? AppConstants.adminSuggestions
                                            : AppConstants.customerSuggestions))
                                    .map((suggestion) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white.withOpacity(0.05),
                                        foregroundColor: Colors.white70,
                                        alignment: Alignment.centerLeft,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          side: BorderSide(color: Colors.white.withOpacity(0.1)),
                                        ),
                                      ),
                                      onPressed: () {
                                        appState.onSuggestionTapped(suggestion, AppConstants.kSenderB);
                                        _replyController.text = suggestion;
                                      },
                                      child: Text(suggestion),
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        widget.isAdmin ? _buildAdminSettingsRow(context) : const SizedBox(height: 64),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- SAFE SETTINGS ROW & POPUP ---
  Widget _buildAdminSettingsRow(BuildContext context) {
    return SizedBox(
      height: 64,
      child: GlassContainer(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(icon: const Icon(Icons.settings, color: Colors.white), onPressed: () => _showSettingsDialog(context)),
            VerticalDivider(color: Colors.white.withOpacity(0.2), indent: 12, endIndent: 12),
            IconButton(
              icon: const Icon(Icons.swap_horiz, color: Colors.white), 
              onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const InputView(isAdmin: true)))
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    bool isOnlineMode = false;
    String storeType = "Retail";

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder( 
          builder: (context, setPopupState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF16181A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.white.withOpacity(0.1))),
              title: const Text("Admin Settings", style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text("Current Portal", style: TextStyle(color: Colors.white70)),
                    subtitle: const Text("Output Mode (Read)", style: TextStyle(color: Colors.blueAccent)),
                  ),
                  const Divider(color: Colors.white24),
                  SwitchListTile(
                    title: const Text("AI Suggestions", style: TextStyle(color: Colors.white)),
                    subtitle: Text(isOnlineMode ? "Online API Mode" : "Offline Predefined Mode", style: const TextStyle(color: Colors.white38, fontSize: 12)),
                    value: isOnlineMode,
                    activeColor: Colors.blueAccent,
                    onChanged: (val) => setPopupState(() => isOnlineMode = val),
                  ),
                  const Divider(color: Colors.white24),
                  ListTile(
                    title: const Text("Store Category", style: TextStyle(color: Colors.white)),
                    trailing: DropdownButton<String>(
                      dropdownColor: const Color(0xFF2A2D32), value: storeType, style: const TextStyle(color: Colors.white),
                      items: ["Retail", "Bakery", "Cafe"].map((String value) => DropdownMenuItem<String>(value: value, child: Text(value))).toList(),
                      onChanged: (val) {
                        if (val != null) setPopupState(() => storeType = val);
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