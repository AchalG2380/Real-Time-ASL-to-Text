import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../input_screen/widgets/glass_container.dart'; // Reusing our magic sauce!

class OutputView extends StatelessWidget {
  const OutputView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // Maintaining that premium Maneora dark metallic aesthetic
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF232526),
              Color(0xFF414345),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
              // ---------------------------------------------------------
              // LEFT SIDE: Massive Chat Interface (60%)
              // ---------------------------------------------------------
              Expanded(
                flex: 6,
                child: GlassContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header with Title and Text-to-Speech Button
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Live ASL Translation",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.volume_up, color: Colors.white),
                              tooltip: 'Convert Text to Speech',
                              onPressed: () {
                                // TODO: Implement TTS functionality
                              },
                            ),
                          ],
                        ),
                      ),
                      const Divider(color: Colors.white24, height: 1),
                      
                      // The main conversation area
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          child: const Center(
                            child: Text(
                              "Awaiting customer input...",
                              style: TextStyle(color: Colors.white54, fontSize: 18),
                            ),
                          ),
                        ),
                      ),
                      
                      // Cashier Keyboard Input
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: TextField(
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: "Type your response to the customer...",
                            filled: true,
                            fillColor: Colors.white12,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            suffixIcon: Container(
                              margin: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.send, color: Colors.white),
                                onPressed: () {},
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // SPACER
              const SizedBox(width: 24),

              // ---------------------------------------------------------
              // RIGHT SIDE: Camera Mirror, Suggestions & Settings (30%)
              // ---------------------------------------------------------
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    // Mirrored Camera Feed (Small View)
                    Expanded(
                      flex: 3,
                      child: GlassContainer(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const Center(
                              child: Text(
                                "Customer \nCamera Mirror",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white54),
                              ),
                            ),
                            // Small indicator that the camera is active
                            Positioned(
                              top: 16,
                              right: 16,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Cashier Smart Suggestions (Vertical list for the side panel)
                    Expanded(
                      flex: 4,
                      child: GlassContainer(
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            const Text(
                              "Smart Replies",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 12),
                            ...AppConstants.outputSuggestions.map((suggestion) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  ),
                                  onPressed: () {},
                                  child: Text(suggestion),
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Settings & Switch Window Controls
                    SizedBox(
                      height: 70,
                      child: GlassContainer(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildControlButton(Icons.settings, "Settings", () {
                               // TODO: Open settings modal (font size, offline mode)
                            }),
                            const VerticalDivider(color: Colors.white24, indent: 15, endIndent: 15),
                            _buildControlButton(Icons.swap_horiz, "Switch", () {
                              Navigator.pop(context);
                            }),
                          ],
                        ),
                      ),
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

  // Helper for the bottom control buttons
  Widget _buildControlButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}