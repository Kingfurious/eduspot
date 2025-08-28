import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class TermsOfServiceScreen extends StatefulWidget {
  const TermsOfServiceScreen({super.key});

  @override
  _TermsOfServiceScreenState createState() => _TermsOfServiceScreenState();
}

class _TermsOfServiceScreenState extends State<TermsOfServiceScreen> {
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.lightBlue.shade100,
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: Colors.blue.shade900),
                      onPressed: () => Navigator.pop(context),
                    ).animate().fadeIn(delay: 200.ms),
                    Text(
                      "Terms of Service",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ).animate().fadeIn(delay: 300.ms),
                    SizedBox(width: 48), // Spacer for alignment
                  ],
                ),
              ),
              // Content Area
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "EduLearn Terms of Service",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ).animate().fadeIn(delay: 400.ms),
                        const SizedBox(height: 16),
                        Text(
                          "Last Updated: February 26, 2025",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue.shade700,
                            fontStyle: FontStyle.italic,
                          ),
                        ).animate().fadeIn(delay: 500.ms),
                        const SizedBox(height: 24),
                        _buildSection(
                          title: "1. Account Registration",
                          content:
                          "To access certain features of EduLearn, you must create an account with accurate and complete information. You are responsible for maintaining the confidentiality of your account credentials and for all activities that occur under your account.",
                          delay: 600,
                        ),
                        _buildSection(
                          title: "2. User Responsibilities",
                          content:
                          "Users agree to abide by EduLearn’s community guidelines, respect fellow learners, and refrain from engaging in inappropriate behavior, including but not limited to harassment, cheating, or posting offensive content.",
                          delay: 700,
                        ),
                        _buildSection(
                          title: "3. Course Enrollment & Payments",
                          content:
                          "Certain courses may require payment for enrollment. All payments are final unless a refund is explicitly granted as per our refund policy, which can be reviewed on our website.",
                          delay: 800,
                        ),
                        _buildSection(
                          title: "4. Content Ownership",
                          content:
                          "All course materials, including videos, texts, and assessments, are the intellectual property of EduLearn or its instructors. Users may not reproduce, distribute, or sell any content without prior written consent.",
                          delay: 900,
                        ),
                        _buildSection(
                          title: "5. Privacy & Data Security",
                          content:
                          "We are committed to protecting your privacy. Your data is collected and stored securely in accordance with our Privacy Policy, which details how we handle and protect your personal information.",
                          delay: 1000,
                        ),
                        _buildSection(
                          title: "6. Termination of Services",
                          content:
                          "EduLearn reserves the right to suspend or terminate accounts that violate these Terms, including instances of fraud, plagiarism, or abusive behavior, at our sole discretion.",
                          delay: 1100,
                        ),
                        _buildSection(
                          title: "7. Modifications & Updates",
                          content:
                          "We may update these Terms of Service from time to time. Continued use of the platform after such changes constitutes your acceptance of the updated terms.",
                          delay: 1200,
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: Text(
                            "For the complete Terms of Service, please visit our official website.",
                            style: TextStyle(
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                              color: Colors.blue.shade800,
                            ),
                          ).animate().fadeIn(delay: 1300.ms),
                        ),
                        const SizedBox(height: 80), // Space for button
                      ],
                    ),
                  ),
                ),
              ),
              // Footer with Accept Button
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isScrolledToBottom
                        ? () => Navigator.pop(context)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isScrolledToBottom ? Colors.white : Colors.grey.shade300,
                      foregroundColor: Colors.blue.shade900,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                      elevation: _isScrolledToBottom ? 4 : 0,
                    ),
                    child: Text(
                      "Accept & Continue",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _isScrolledToBottom ? Colors.blue.shade900 : Colors.grey.shade600,
                      ),
                    ),
                  ).animate().fadeIn(delay: 1400.ms).scale(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required String content, required int delay}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0), // Corrected here
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade900,
            ),
          ).animate().fadeIn(delay: Duration(milliseconds: delay)),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 16,
              color: Colors.blue.shade800,
              height: 1.5,
            ),
          ).animate().fadeIn(delay: Duration(milliseconds: delay + 100)),
          const SizedBox(height: 16),
          Divider(height: 1, thickness: 1, color: Colors.blue.shade100),
        ],
      ),
    );
  }
}