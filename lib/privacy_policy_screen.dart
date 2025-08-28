import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  _PrivacyPolicyScreenState createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isScrolledToBottom = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.offset >= _scrollController.position.maxScrollExtent - 20) {
      setState(() {
        _isScrolledToBottom = true;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.blue,
        elevation: 0,
        automaticallyImplyLeading: false, // Hides back arrow
        title: const Text(
          "Privacy Policy",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Background color
          Container(color: Colors.white),

          SafeArea(
            child: Column(
              children: [
                // Header section with icon animation
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(Icons.privacy_tip, size: 80, color: Colors.blue)
                          .animate()
                          .fadeIn(duration: 800.ms)
                          .scale(delay: 300.ms),
                      const SizedBox(height: 10),
                      const Text(
                        "EduLearn Privacy Policy",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ).animate().fadeIn(delay: 500.ms).moveY(begin: -10, end: 0),
                    ],
                  ),
                ),

                // Privacy Policy Content
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSection(
                            title: "1. Data Collection",
                            content:
                            "We collect your name, email, and learning progress to provide personalized experiences.",
                            delay: 600,
                          ),
                          _buildSection(
                            title: "2. How We Use Your Data",
                            content:
                            "Your data helps us improve our courses, provide support, and personalize your learning journey.",
                            delay: 700,
                          ),
                          _buildSection(
                            title: "3. Data Protection",
                            content:
                            "We use encryption and security measures to protect your data from unauthorized access.",
                            delay: 800,
                          ),
                          _buildSection(
                            title: "4. Sharing of Information",
                            content:
                            "We do not sell or share your personal information with third parties except as required by law or to improve our services.",
                            delay: 900,
                          ),
                          _buildSection(
                            title: "5. Cookies & Tracking",
                            content:
                            "We use cookies and analytics tools to enhance user experience and improve platform performance.",
                            delay: 1000,
                          ),
                          _buildSection(
                            title: "6. Your Rights & Choices",
                            content:
                            "You can request data deletion, update your preferences, and control what data you share with us.",
                            delay: 1100,
                          ),
                          _buildSection(
                            title: "7. Changes to this Policy",
                            content:
                            "EduLearn may update this Privacy Policy from time to time. Continued use of the platform constitutes acceptance of any changes.",
                            delay: 1200,
                          ),
                          const SizedBox(height: 20),
                          const Center(
                            child: Text(
                              "For full details, visit our official Privacy Policy page.",
                              style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.black),
                            ),
                          ).animate().fadeIn(delay: 1300.ms),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Accept Button (Disabled until user scrolls to bottom)
                Container(
                  width: double.infinity,
                  color: Colors.blue,
                  padding: const EdgeInsets.all(12),
                  child: ElevatedButton(
                    onPressed: _isScrolledToBottom
                        ? () {
                      Navigator.pop(context);
                    }
                        : null, // Button remains disabled until user scrolls
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isScrolledToBottom ? Colors.white : Colors.black54,
                      foregroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: Text(
                      "Accept & Continue",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _isScrolledToBottom ? Colors.blue : Colors.white,
                      ),
                    ),
                  ).animate().fadeIn(delay: 1400.ms).scale(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Section builder with animation
  Widget _buildSection({required String title, required String content, required int delay}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
        ).animate().fadeIn(delay: delay.ms),
        const SizedBox(height: 5),
        Text(
          content,
          style: const TextStyle(fontSize: 16, color: Colors.black),
        ).animate().fadeIn(delay: (delay + 100).ms),
        const Divider(height: 20, thickness: 1, color: Colors.black12),
      ],
    );
  }
}
