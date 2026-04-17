import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../output_screen/output_view.dart';
import 'widgets/glass_container.dart';

class InputView extends StatelessWidget {
  const InputView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ---------------------------------------------------------
          // 1. THE ATMOSPHERE (Background Colors & Glows)
          // ---------------------------------------------------------
          // Deepest background color
          Container(color: const Color(0xFF16181A)), 
          
          // Top Left Subtle Silver Glow
          Positioned(
            top: -150,
            left: -150,
            child: Container(
              width: 600,
              height: 600,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.03), 
                boxShadow: [
                  BoxShadow(color: Colors.white.withOpacity(0.04), blurRadius: 150, spreadRadius: 50),
                ],
              ),
            ),
          ),
          
          // Bottom Right Metallic Slate Glow
          Positioned(
            bottom: -200,
            right: -100,
            child: Container(
              width: 700,
              height: 700,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF5A6B7C).withOpacity(0.15), 
                boxShadow: [
                  BoxShadow(color: const Color(0xFF5A6B7C).withOpacity(0.15), blurRadius: 200, spreadRadius: 100),
                ],
              ),
            ),
          ),

          // ---------------------------------------------------------
          // 2. THE MAIN UI (Sitting on top of the glows)
          // ---------------------------------------------------------
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  // LEFT SIDE: Camera + Suggestions
                  Expanded(
                    flex: 6,
                    child: Column(
                      children: [
                        // Camera Viewport
                        Expanded(
                          flex: 4,
                          child: GlassContainer(
                            child: Center(
                              child: Text(
                                AppConstants.cameraPlaceholder,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white.withOpacity(0.7), letterSpacing: 0.5),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Smart Suggestions Row
                        Expanded(
                          flex: 1,
                          child: GlassContainer(
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.all(16),
                              children: AppConstants.inputSuggestions.map((suggestion) {
                                return _buildSuggestionChip(suggestion);
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(width: 24), // Spacer

                  // RIGHT SIDE: Chatbox + Button
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        // Chat Box
                        Expanded(
                          flex: 5,
                          child: GlassContainer(
                            child: Column(
                              children: [
                                const Padding(
                                  padding: EdgeInsets.all(20.0),
                                  child: Text(
                                    "Live Translation",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                Divider(color: Colors.white.withOpacity(0.1), height: 1),
                                Expanded(child: Container()), 
                                // Input field
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: TextField(
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      hintText: "Type a reply...",
                                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                                      filled: true,
                                      fillColor: Colors.white.withOpacity(0.05),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide.none,
                                      ),
                                      suffixIcon: Container(
                                        margin: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(Icons.send, color: Colors.white, size: 18),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Premium View Stock Button
                        SizedBox(
                          height: 64,
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.1),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(color: Colors.white.withOpacity(0.2)),
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const OutputView(),
                                ),
                              );
                            },
                            child: const Text(
                              "View Available Items",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
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
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Center(
        child: Text(
          text, 
          style: TextStyle(color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}