import 'package:flutter/material.dart';
import 'input_screen/input_view.dart';
import 'output_screen/output_view.dart';
import 'input_screen/widgets/glass_container.dart';
import 'meet_the_signatories_screen.dart';


class LoginScreen extends StatelessWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(color: const Color(0xFF16181A)), 
          Center(
            child: SizedBox(
              width: 800, 
              child: GlassContainer(
                child: Padding(
                  padding: const EdgeInsets.all(60.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    
// Replace your existing logo/title widget with this:
GestureDetector(
  onTap: () => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const MeetTheSignatoriesScreen(),
    ),
  ),
  child: Column(
    children: [
      Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF4ECDC4), width: 2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4ECDC4).withOpacity(0.3),
              blurRadius: 16,
            ),
          ],
        ),
        child: ClipOval(
          child: Image.asset(
            'assets/images/logo.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF4ECDC4), Color(0xFF2ECC71)],
                ),
              ),
              child: const Icon(Icons.sign_language,
                  color: Colors.black, size: 30),
            ),
          ),
        ),
      ),  
      
    ],
  ),
),

                      Row(
                        children: [
                          // STAFF BUTTON
                          Expanded(
                            child: _buildRoleButton(
                              title: "Staff Terminal",
                              icon: Icons.admin_panel_settings_outlined,
                              onTap: () => _showAdminPortalChoices(context),
                            ),
                          ),
                          const SizedBox(width: 30),
                          // CUSTOMER BUTTON (Directly to Customer Interface)
                          Expanded(
                            child: _buildRoleButton(
                              title: "Guest Tablet",
                              icon: Icons.tablet_mac_outlined,
                              onTap: () {
                                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const InputView(isAdmin: false)));
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleButton({required String title, required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 48, color: Colors.white70),
            const SizedBox(height: 24),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  // Pop-up specifically for the Admin to choose their screen!
  void _showAdminPortalChoices(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16181A),
        title: const Text("Select Staff Portal", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.sign_language, color: Colors.white),
              title: const Text("I will Sign (Input Mode)", style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const InputView(isAdmin: true))),
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble, color: Colors.white),
              title: const Text("I will Read (Output Mode)", style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const OutputView(isAdmin: true))),
            ),
          ],
        ),
      ),
    );
  }
}