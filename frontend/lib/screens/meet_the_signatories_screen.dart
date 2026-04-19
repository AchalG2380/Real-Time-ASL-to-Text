import 'package:flutter/material.dart';

class MeetTheSignatoriesScreen extends StatelessWidget {
  const MeetTheSignatoriesScreen({super.key});

  static const _team = [
    {
      'name': 'Khushi Katiyar',
      'role': 'Backend, Model Training',
      'photo': 'assets/images/khushi.jpg',
      'bio': 'Built the dual-screen UI, camera overlay, and chat system.',
      'color': Color(0xFF4ECDC4),
    },
    {
      'name': 'Vanshvi Jain',
      'role': 'Feature Integration',
      'photo': 'assets/images/vanshvi.jpg',
      'bio': 'Trained the ASL gesture classifier and built the inference pipeline.',
      'color': Color(0xFF7B68EE),
    },
    {
      'name': 'Deepanshi Mane',
      'role': 'Flutter Frontend',
      'photo': 'assets/images/deepanshi.jpg',
      'bio': 'Built the smart suggestions engine, translation, and speech APIs.',
      'color': Color(0xFFFF6B9D),
    },
    {
      'name': 'Achal Goyal',
      'role': 'Backend, Model Training',
      'photo': 'assets/images/achal.jpg',
      'bio': 'Wired everything together and made the demo actually work.',
      'color': Color(0xFFFFD93D),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF16181A),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back button
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios,
                    color: Colors.white70, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShaderMask(
                    shaderCallback: (b) => const LinearGradient(
                      colors: [Colors.white, Color(0xFF4ECDC4)],
                    ).createShader(b),
                    child: const Text(
                      'Meet the\nSignatories',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.2,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'The team behind CosmicSigns.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Team cards
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _team.length,
                itemBuilder: (context, i) {
                  final member = _team[i];
                  final color = member['color'] as Color;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: color.withOpacity(0.3),
                        ),
                        gradient: LinearGradient(
                          colors: [
                            color.withOpacity(0.08),
                            Colors.transparent,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Photo
                          Stack(
                            children: [
                              Container(
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: color.withOpacity(0.6),
                                    width: 2,
                                  ),
                                ),
                                child: ClipOval(
                                  child: Image.asset(
                                    member['photo'] as String,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: color.withOpacity(0.15),
                                      child: Center(
                                        child: Text(
                                          (member['name'] as String)[0],
                                          style: TextStyle(
                                            color: color,
                                            fontSize: 26,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Role badge
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: color,
                                  ),
                                  child: const Icon(
                                    Icons.star,
                                    color: Colors.white,
                                    size: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 18),

                          // Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  member['name'] as String,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    color: color.withOpacity(0.15),
                                    border: Border.all(
                                        color: color.withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    member['role'] as String,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: color,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  member['bio'] as String,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white54,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}