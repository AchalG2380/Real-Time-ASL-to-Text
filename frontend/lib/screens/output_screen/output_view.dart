import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
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
  final TextEditingController _sessionController = TextEditingController();
  final FlutterTts _flutterTts = FlutterTts();
  final ScrollController _scrollController = ScrollController();
  Timer? _sessionPromptTimer;

  @override
  void initState() {
    super.initState();
    // Device B: auto-prompt session link if not connected in 6s
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final isDeviceB = AppConstants.aslEngineHost != 'localhost';
      if (isDeviceB) {
        _sessionPromptTimer = Timer(const Duration(seconds: 6), () {
          if (!mounted) return;
          final state = context.read<AppState>();
          if (state.linkedSessionId.isEmpty) {
            _showSessionDialog();
          }
        });
      }
    });
  }

  // Settings state — lifted to widget state so they persist while screen is open
  bool _isOnlineMode = false;
  String _storeType = 'Retail';
  final List<String> _customSuggestions = [];
  final TextEditingController _customSuggestionController =
      TextEditingController();

  @override
  void dispose() {
    _replyController.dispose();
    _sessionController.dispose();
    _sessionPromptTimer?.cancel();
    _flutterTts.stop();
    _scrollController.dispose();
    _customSuggestionController.dispose();
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

<<<<<<< HEAD
    // Merge smart suggestions + custom suggestions
    final List<String> allSuggestions = [
      ...appState.currentSuggestions.isNotEmpty
          ? appState.currentSuggestions
          : (widget.isAdmin
              ? AppConstants.adminSuggestions
              : AppConstants.customerSuggestions),
      ..._customSuggestions,
    ];
=======
    return Scaffold(
      // ── Session link FAB — orange=unlinked, green=linked ──
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Consumer<AppState>(
          builder: (ctx, state, _) {
            final linked = state.linkedSessionId.isNotEmpty;
            return FloatingActionButton.small(
              heroTag: 'output_session_fab',
              backgroundColor: linked
                  ? Colors.greenAccent.withOpacity(0.85)
                  : Colors.orangeAccent.withOpacity(0.85),
              tooltip: linked ? 'Session Linked — tap to manage' : 'Connect to Customer Session',
              onPressed: _showSessionDialog,
              child: Icon(
                linked ? Icons.link : Icons.link_off,
                color: Colors.black87, size: 20,
              ),
            );
          },
        ),
      ),
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
>>>>>>> 1a3b0abd1de31dcce9b5d89a02d3f6dc24505f17

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                // ── LEFT: Chat ─────────────────────────────────────────
                Expanded(
                  flex: 6,
                  child: GlassContainer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Live ASL Translation',
                                style: TextStyle(
                                  fontFamily: 'ArchivoBlack',
                                  fontSize: 22,
                                  fontWeight: FontWeight.w400,
                                  color: AppTheme.textPrimary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.volume_up,
                                    color: AppTheme.textSecondary),
                                onPressed: () {},
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Divider(
                          color: AppTheme.borderDefault.withOpacity(0.6),
                          height: 1,
                          thickness: 1,
                        ),

                        // Messages
                        Expanded(
                          child: appState.messages.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.sign_language,
                                        size: 48,
                                        color: AppTheme.textMuted
                                            .withOpacity(0.2),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Awaiting input...',
                                        style: TextStyle(
                                          fontFamily: 'Outfit',
                                          color: AppTheme.textMuted,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.all(20),
                                  itemCount: appState.messages.length,
                                  itemBuilder: (context, index) {
                                    final msg = appState.messages[index];
                                    final isB = msg['sender'] ==
                                        AppConstants.kSenderB;
                                    return Align(
                                      alignment: isB
                                          ? Alignment.centerRight
                                          : Alignment.centerLeft,
                                      child: GestureDetector(
                                        onTap: () =>
                                            _speakText(msg['text'] ?? ''),
                                        child: Container(
                                          margin: const EdgeInsets.only(
                                              bottom: 14),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 18, vertical: 14),
                                          constraints: const BoxConstraints(
                                              maxWidth: 400),
                                          decoration: BoxDecoration(
                                            color: isB
                                                ? AppTheme.bgCard
                                                : AppTheme.bgSurface
                                                    .withOpacity(0.55),
                                            borderRadius: BorderRadius.only(
                                              topLeft:
                                                  const Radius.circular(20),
                                              topRight:
                                                  const Radius.circular(20),
                                              bottomLeft: Radius.circular(
                                                  isB ? 20 : 4),
                                              bottomRight: Radius.circular(
                                                  isB ? 4 : 20),
                                            ),
                                            border: Border.all(
                                              color: isB
                                                  ? AppTheme.borderAmber
                                                  : AppTheme.borderDefault,
                                              width: 1.5,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.2),
                                                blurRadius: 8,
                                                offset: const Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            crossAxisAlignment: isB
                                                ? CrossAxisAlignment.end
                                                : CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                msg['text'] ?? '',
                                                style: const TextStyle(
                                                  fontFamily: 'Outfit',
                                                  color: AppTheme.textPrimary,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                  height: 1.4,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              const Icon(Icons.volume_up,
                                                  size: 12,
                                                  color: AppTheme.textMuted),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),

                        // Input
                        Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.bgSurface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: AppTheme.borderAmber, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _replyController,
                              style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.w500),
                              onSubmitted: (_) => _sendReply(),
                              decoration: InputDecoration(
                                hintText: 'Type a reply...',
                                hintStyle: const TextStyle(
                                    color: AppTheme.textMuted,
                                    fontFamily: 'Outfit'),
                                fillColor: Colors.transparent,
                                filled: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                prefixIcon: IconButton(
                                  icon: const Icon(Icons.mic_none,
                                      color: AppTheme.textMuted),
                                  onPressed: () {},
                                ),
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Tooltip(
                                      message: 'Smart Suggestions',
                                      child: PopupMenuButton<String>(
                                        icon: const Icon(Icons.auto_awesome,
                                            color: AppTheme.accentAmber,
                                            size: 20),
                                        color: AppTheme.bgCard,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          side: const BorderSide(
                                              color: AppTheme.borderAmber,
                                              width: 1.5),
                                        ),
                                        tooltip: '',
                                        itemBuilder: (BuildContext context) {
                                          final appState =
                                              context.read<AppState>();
                                          final suggestions = appState
                                                  .currentSuggestions
                                                  .isNotEmpty
                                              ? appState.currentSuggestions
                                              : AppConstants.adminSuggestions;
                                          final combined = [
                                            ...suggestions,
                                            ..._customSuggestions,
                                          ];
                                          return combined.map((choice) {
                                            return PopupMenuItem<String>(
                                              value: choice,
                                              child: Text(choice,
                                                  style: const TextStyle(
                                                      fontFamily: 'Outfit',
                                                      color:
                                                          AppTheme.textPrimary,
                                                      fontWeight:
                                                          FontWeight.w600)),
                                            );
                                          }).toList();
                                        },
                                        onSelected: (value) {
                                          final appState =
                                              context.read<AppState>();
                                          appState.onSuggestionTapped(
                                              value, AppConstants.kSenderB);
                                          _replyController.text = value;
                                        },
                                      ),
                                    ),
                                    Container(
                                      margin: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: AppTheme.borderAmber
                                            .withOpacity(0.15),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: IconButton(
                                        icon: const Icon(Icons.send,
                                            color: AppTheme.amber,
                                            size: 18),
                                        onPressed: _sendReply,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 24),

                // ── RIGHT: Camera Mirror + Smart Replies + Controls ──
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      // Camera mirror card
                      Expanded(
                        flex: 3,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.bgSurface.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: AppTheme.borderDefault.withOpacity(0.9),
                              width: 5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(23),
                            child: Stack(
                              children: [
                                Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.videocam_off_outlined,
                                          size: 32,
                                          color: AppTheme.textMuted
                                              .withOpacity(0.3)),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Camera Mirror',
                                        style: TextStyle(
                                          fontFamily: 'Outfit',
                                          color: AppTheme.textMuted
                                              .withOpacity(0.5),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  top: 14,
                                  right: 14,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color:
                                          Colors.redAccent.withOpacity(0.7),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.redAccent
                                              .withOpacity(0.4),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Smart Replies
                      Expanded(
                        flex: 4,
                        child: GlassContainer(
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              const Text(
                                'Smart Replies',
                                style: TextStyle(
                                  fontFamily: 'ArchivoBlack',
                                  fontWeight: FontWeight.w400,
                                  color: AppTheme.textPrimary,
                                  fontSize: 14,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ...allSuggestions.map((suggestion) {
                                return Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 8.0),
                                  child: GestureDetector(
                                    onTap: () {
                                      appState.onSuggestionTapped(
                                          suggestion,
                                          AppConstants.kSenderB);
                                      _replyController.text = suggestion;
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 13),
                                      decoration: BoxDecoration(
                                        color: AppTheme.bgCard,
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        border: Border.all(
                                            color: AppTheme.borderAmber,
                                            width: 1.5),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withOpacity(0.15),
                                            blurRadius: 5,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        suggestion,
                                        style: const TextStyle(
                                          fontFamily: 'Outfit',
                                          color: AppTheme.textPrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Admin controls or spacer
                      widget.isAdmin
                          ? _buildAdminSettingsRow(context)
                          : const SizedBox(height: 64),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdminSettingsRow(BuildContext context) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderAmber, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.settings, color: AppTheme.textSecondary),
            onPressed: () => _showSettingsDialog(context),
          ),
          Container(width: 1, height: 28, color: AppTheme.borderDefault),
          IconButton(
            icon:
                const Icon(Icons.swap_horiz, color: AppTheme.textSecondary),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const InputView(isAdmin: true),
              ),
            ),
          ),
        ],
      ),
    );
  }

<<<<<<< HEAD
=======
  // ── Session Connect Dialog ────────────────────────────────────
  void _showSessionDialog() {
    final appState = context.read<AppState>();
    _sessionController.text = appState.linkedSessionId;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final linked = appState.linkedSessionId.isNotEmpty;
          return AlertDialog(
            backgroundColor: const Color(0xFF1A1D21),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.blueAccent.withOpacity(0.3)),
            ),
            title: Row(children: [
              Icon(linked ? Icons.link : Icons.link_off,
                  color: linked ? Colors.greenAccent : Colors.orangeAccent),
              const SizedBox(width: 10),
              Text(linked ? 'Session Linked ✓' : 'Connect to Customer',
                  style: const TextStyle(color: Colors.white, fontSize: 18)),
            ]),
            content: SizedBox(
              width: 400,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Show Device A's session ID
                Container(
                  padding: const EdgeInsets.all(12),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('📱 Customer Device Session ID:',
                        style: TextStyle(color: Colors.white54, fontSize: 11)),
                    const SizedBox(height: 6),
                    SelectableText(
                      appState.sessionId.isEmpty ? 'Loading...' : appState.sessionId,
                      style: const TextStyle(color: Colors.amber, fontSize: 13, fontFamily: 'monospace', letterSpacing: 1),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                const Text('💻 Enter Customer Session ID below:',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: _sessionController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Paste session ID here...',
                    hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.06),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onChanged: (_) => setS(() {}),
                ),
                if (linked) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      const Icon(Icons.check_circle, color: Colors.greenAccent, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Linked: ${appState.linkedSessionId}',
                          style: const TextStyle(color: Colors.greenAccent, fontSize: 11), overflow: TextOverflow.ellipsis)),
                    ]),
                  ),
                ],
              ]),
            ),
            actions: [
              if (linked)
                TextButton(
                  onPressed: () { context.read<AppState>().joinSession(''); setS(() {}); },
                  child: const Text('Unlink', style: TextStyle(color: Colors.redAccent)),
                ),
              TextButton(onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close', style: TextStyle(color: Colors.white54))),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                icon: const Icon(Icons.link, size: 18),
                label: const Text('Connect'),
                onPressed: () {
                  final id = _sessionController.text.trim();
                  if (id.isNotEmpty) {
                    context.read<AppState>().joinSession(id);
                    setS(() {});
                    Future.delayed(const Duration(milliseconds: 600), () {
                      if (mounted) Navigator.pop(ctx);
                    });
                  }
                },
              ),
            ],
          );
        },
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

>>>>>>> 1a3b0abd1de31dcce9b5d89a02d3f6dc24505f17
  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setPopupState) {
            return Dialog(
              backgroundColor: AppTheme.bgCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side:
                    const BorderSide(color: AppTheme.borderAmber, width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Admin Settings',
                        style: TextStyle(
                          fontFamily: 'ArchivoBlack',
                          fontWeight: FontWeight.w400,
                          fontSize: 20,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Current portal indicator
                      _card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Current Portal',
                                style: TextStyle(
                                    color: AppTheme.textMuted,
                                    fontFamily: 'Outfit',
                                    fontSize: 12)),
                            Text('Output Mode (Read)',
                                style: TextStyle(
                                    color: AppTheme.accentGreen,
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Online Mode toggle
                      _card(
                        child: Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Online Mode',
                                      style: TextStyle(
                                          fontFamily: 'Outfit',
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.textPrimary)),
                                  Text('Toggle online/offline mode',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textMuted,
                                          fontFamily: 'Outfit')),
                                ],
                              ),
                            ),
                            Switch(
                              value: _isOnlineMode,
                              activeColor: AppTheme.accentGreen,
                              onChanged: (val) {
                                setPopupState(() => _isOnlineMode = val);
                                setState(() => _isOnlineMode = val);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Store Category
                      _card(
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text('Store Category',
                                  style: TextStyle(
                                      fontFamily: 'Outfit',
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimary)),
                            ),
                            DropdownButton<String>(
                              dropdownColor: AppTheme.bgCard,
                              value: _storeType,
                              underline: const SizedBox(),
                              style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.w600),
                              items: ['Retail', 'Bakery', 'Cafe']
                                  .map((v) => DropdownMenuItem(
                                      value: v, child: Text(v)))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setPopupState(() => _storeType = val);
                                  setState(() => _storeType = val);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Custom suggestions
                      const Text(
                        'Custom Suggestions',
                        style: TextStyle(
                          fontFamily: 'ArchivoBlack',
                          fontWeight: FontWeight.w400,
                          fontSize: 15,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Add your own reply chips to the output screen.',
                        style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 12,
                            fontFamily: 'Outfit'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppTheme.bgSurface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: AppTheme.borderAmber, width: 1.5),
                              ),
                              child: TextField(
                                controller: _customSuggestionController,
                                style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: 'e.g. Here is your order!',
                                  hintStyle: const TextStyle(
                                      color: AppTheme.textMuted,
                                      fontFamily: 'Outfit',
                                      fontSize: 13),
                                  fillColor: Colors.transparent,
                                  filled: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
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
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.bgSurface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: AppTheme.borderAmber, width: 1.5),
                              ),
                              child: const Icon(Icons.add,
                                  color: AppTheme.amber, size: 20),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_customSuggestions.isNotEmpty)
                        ..._customSuggestions.asMap().entries.map((e) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.bgSurface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: AppTheme.borderDefault, width: 1.5),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(e.value,
                                      style: const TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontFamily: 'Outfit',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600)),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    setPopupState(() =>
                                        _customSuggestions.removeAt(e.key));
                                    setState(() {});
                                  },
                                  child: const Icon(Icons.close,
                                      color: AppTheme.textMuted, size: 16),
                                ),
                              ],
                            ),
                          );
                        })
                      else
                        const Text('No custom suggestions added yet.',
                            style: TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 12,
                                fontFamily: 'Outfit')),
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Done'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderDefault, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}