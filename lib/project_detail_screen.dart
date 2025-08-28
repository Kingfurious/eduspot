import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

// Placeholder ChatbotScreen
class ChatbotScreen extends StatelessWidget {
  const ChatbotScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chatbot')),
    body: const Center(child: Text('Chatbot Interface')),
  );
}

// Placeholder LearnScreen
class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Learn')),
    body: const Center(child: Text('Learn More About This Project')),
  );
}

// CertificateScreen with Payment and Email
class CertificateScreen extends StatelessWidget {
  final String projectId;
  final String projectTitle;
  final String userId;

  const CertificateScreen({
    super.key,
    required this.projectId,
    required this.projectTitle,
    required this.userId,
  });

  Future<void> _processPaymentAndRequestCertificate(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Processing payment...')),
    );
    await Future.delayed(const Duration(seconds: 2)); // Simulated delay

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No user signed in. Please log in.')),
      );
      return;
    }

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final userName = user.displayName ?? userDoc.data()?['name'] as String? ?? 'Unknown User';
    final userEmail = user.email ?? 'unknown@example.com';

    print('User ID: $userId');
    print('User Name: $userName');
    print('User Email: $userEmail');
    print('Project Title: $projectTitle');
    print('Project ID: $projectId');

    await _sendCertificateRequestEmail(userName, userEmail, projectTitle);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payment successful! Certificate request sent to admin.')),
    );
    Navigator.pop(context, true);
  }

  Future<void> _sendCertificateRequestEmail(String userName, String userEmail, String projectTitle) async {
    const adminEmail = 'vijaygokul120@gmail.com';
    final url = Uri.parse('https://your-server.com/send-email'); // Replace with your server endpoint
    final response = await http.post(
      url,
      body: {
        'to': adminEmail,
        'subject': 'Certificate Request for $projectTitle',
        'body': '''
          Certificate Request Details:
          Student Name: $userName
          Student Email: $userEmail
          Project Title: $projectTitle
          Project ID: $projectId
          Status: Awaiting Verification and Certificate Delivery
        ''',
      },
    );

    if (response.statusCode == 200) {
      print('Email request sent successfully');
    } else {
      print('Failed to send email request: ${response.body}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Certificate Payment')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Complete your payment to request your certificate!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _processPaymentAndRequestCertificate(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('Pay Now'),
            ),
          ],
        ),
      ),
    );
  }
}

// LevelDetailScreen
class LevelDetailScreen extends StatelessWidget {
  final Map<String, dynamic> level;
  final String projectId;
  final double projectProgress;
  final int totalLevels;

  const LevelDetailScreen({
    super.key,
    required this.level,
    required this.projectId,
    required this.projectProgress,
    required this.totalLevels,
  });

  @override
  Widget build(BuildContext context) {
    return _LevelDetailScreenStateful(
      level: level,
      projectId: projectId,
      projectProgress: projectProgress,
      totalLevels: totalLevels,
    );
  }
}

class _LevelDetailScreenStateful extends StatefulWidget {
  final Map<String, dynamic> level;
  final String projectId;
  final double projectProgress;
  final int totalLevels;

  const _LevelDetailScreenStateful({
    required this.level,
    required this.projectId,
    required this.projectProgress,
    required this.totalLevels,
  });

  @override
  State<_LevelDetailScreenStateful> createState() => _LevelDetailScreenState();
}

class _LevelDetailScreenState extends State<_LevelDetailScreenStateful> {
  final TextEditingController _answerController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _submitAnswer() async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to submit an answer')),
      );
      return;
    }

    final userAnswer = _answerController.text.trim();
    if (userAnswer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an answer')),
      );
      return;
    }

    final originalAnswerDoc = await _firestore
        .collection('original_answers')
        .doc(widget.projectId)
        .collection('levels')
        .doc(widget.level['level'])
        .get();

    if (!originalAnswerDoc.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Original answer not found')),
      );
      return;
    }

    final originalAnswer = originalAnswerDoc['answer'] as String;
    final isCorrect = userAnswer.toLowerCase().contains(originalAnswer.toLowerCase());

    // Save the answer
    await _firestore
        .collection('user_answers')
        .doc(user.uid)
        .collection('projects')
        .doc(widget.projectId)
        .collection('levels')
        .doc(widget.level['level'])
        .set({
      'answer': userAnswer,
      'submitted_at': FieldValue.serverTimestamp(),
      'is_correct': isCorrect,
    });

    if (isCorrect) {
      final currentLevelIndex = int.parse(widget.level['level'].split(' ').last);
      final newProgress = currentLevelIndex / widget.totalLevels;

      // Update user-specific progress
      await _firestore
          .collection('user_answers')
          .doc(user.uid)
          .collection('projects')
          .doc(widget.projectId)
          .set({
        'progress': newProgress > 1.0 ? 1.0 : newProgress,
        'last_updated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Correct! Level completed.')),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect answer. Try again!')),
      );
    }

    _answerController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = widget.level['level'].split(' ').last == '1'
        ? widget.projectProgress >= 0.33
        : widget.level['level'].split(' ').last == '2'
        ? widget.projectProgress >= 0.66
        : widget.projectProgress >= 1.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.level['title']),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.level['level'],
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF2563EB)),
            ),
            const SizedBox(height: 8),
            Text(
              widget.level['description'],
              style: const TextStyle(fontSize: 16, color: Color(0xFF334155), height: 1.5),
            ),
            const SizedBox(height: 24),
            if (!isCompleted) ...[
              TextField(
                controller: _answerController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Enter your answer',
                ),
                maxLines: 5,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _submitAnswer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text('Submit Answer'),
              ),
            ] else
              const Text(
                'Level Completed!',
                style: TextStyle(fontSize: 18, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
              ),
          ],
        ),
      ),
    );
  }
}

// ProjectDetailScreen
class ProjectDetailScreen extends StatefulWidget {
  final Map<String, dynamic> project;

  const ProjectDetailScreen({Key? key, required this.project}) : super(key: key);

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  int _selectedTabIndex = 0;
  bool _chatbotPressed = false;
  bool _learnPressed = false;

  @override
  void initState() {
    super.initState();
    Firebase.initializeApp();
  }

  Future<double> getUserProgress(String userId, String projectId) async {
    final doc = await FirebaseFirestore.instance
        .collection('user_answers')
        .doc(userId)
        .collection('projects')
        .doc(projectId)
        .get();
    final progress = doc.data()?['progress'];
    if (progress is int) return progress.toDouble();
    if (progress is double) return progress;
    return 0.0; // Default to 0 if no progress exists
  }

  Widget _buildFloatingBarButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required bool isPressed,
  }) {
    return GestureDetector(
      onTapDown: (_) => setState(() => isPressed ? _chatbotPressed = true : _learnPressed = true),
      onTapUp: (_) {
        setState(() => isPressed ? _chatbotPressed = false : _learnPressed = false);
        onPressed();
      },
      onTapCancel: () => setState(() => isPressed ? _chatbotPressed = false : _learnPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        transform: Matrix4.identity()..scale(isPressed ? 0.95 : 1.0),
        child: TextButton.icon(
          onPressed: null,
          icon: Icon(icon, color: Colors.white, size: 20),
          label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final projectId = widget.project['id'] ?? 'unknown_project_id';

    return FutureBuilder<double>(
      future: user != null ? getUserProgress(user.uid, projectId) : Future.value(0.0),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final progress = snapshot.data ?? 0.0;
        final progressPercent = (progress * 100).toInt();

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 40, 16, 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade50, Colors.white],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Flexible(
                            child: Text(
                              widget.project['title'] ?? 'Untitled Project',
                              style: GoogleFonts.inter(
                                textStyle: const TextStyle(
                                  color: Color(0xFF1E293B),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: _getProgressColor(progress).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: _getProgressColor(progress),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _getProgressStatus(progress),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: _getProgressColor(progress),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '$progressPercent% complete',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: const Color(0xFFE2E8F0),
                          valueColor: AlwaysStoppedAnimation<Color>(_getProgressColor(progress)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.project['description'] ?? 'No description available',
                            style: const TextStyle(fontSize: 16, color: Color(0xFF334155), height: 1.5),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: (widget.project['tags'] as List<dynamic>? ?? []).map((tag) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFBFDBFE)),
                                ),
                                child: Text(
                                  tag.toString(),
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF3B82F6)),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
                    Container(
                      height: 56,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
                      ),
                      child: Row(
                        children: [
                          _buildTabItem(0, 'Roadmap'),
                          _buildTabItem(1, 'Skills Needed'),
                          _buildTabItem(2, 'Resources'),
                        ],
                      ),
                    ),
                    if (_selectedTabIndex == 0) _buildRoadmapContent(progress),
                    if (_selectedTabIndex == 1) _buildSkillsContent(),
                    if (_selectedTabIndex == 2) _buildResourcesContent(),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildFloatingBarButton(
                  label: 'Chatbot',
                  icon: Icons.chat,
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatbotScreen())),
                  isPressed: _chatbotPressed,
                ),
                const SizedBox(width: 16),
                _buildFloatingBarButton(
                  label: 'Learn',
                  icon: Icons.school,
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LearnScreen())),
                  isPressed: _learnPressed,
                ),
              ],
            ),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        );
      },
    );
  }

  Widget _buildTabItem(int index, String title) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTabIndex = index),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoadmapContent(double progress) {
    final roadmap = widget.project['roadmap'] as List<dynamic>;
    final totalLevels = roadmap.length;
    final updatedRoadmap = List.from(roadmap)
      ..add({
        'level': 'Certificate',
        'title': 'Request Certificate',
        'description': 'Pay and request your certificate after completing the project.',
      });

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Project Roadmap',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 16),
          ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: updatedRoadmap.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final level = updatedRoadmap[index];
              final isCertificateLevel = level['level'] == 'Certificate';
              final isCompleted = isCertificateLevel ? false : index < (progress * roadmap.length).ceil();

              return GestureDetector(
                onTap: () async {
                  if (isCertificateLevel) {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please log in to request a certificate')),
                      );
                      return;
                    }

                    if (progress < 0.95) {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Incomplete Project'),
                          content: const Text('Please complete at least 95% of the project to request a certificate.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    } else {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CertificateScreen(
                            projectId: widget.project['id'] ?? 'unknown_project_id',
                            projectTitle: widget.project['title'] ?? 'Untitled Project',
                            userId: user.uid,
                          ),
                        ),
                      );
                      if (result == true) {
                        setState(() {});
                      }
                    }
                  } else {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LevelDetailScreen(
                          level: level,
                          projectId: widget.project['id'] ?? 'unknown_project_id',
                          projectProgress: progress,
                          totalLevels: totalLevels,
                        ),
                      ),
                    );
                    if (result == true) {
                      setState(() {});
                    }
                  }
                },
                child: _buildRoadmapLevel(
                  level['level'] ?? 'Unknown Level',
                  level['title'] ?? 'Untitled',
                  level['description'] ?? 'No description',
                  isCompleted,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRoadmapLevel(String level, String title, String description, bool isCompleted) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isCompleted ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                shape: BoxShape.circle,
              ),
              child: isCompleted ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          level,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        isCompleted ? 'Completed' : 'In Progress',
                        style: TextStyle(
                          fontSize: 12,
                          color: isCompleted ? const Color(0xFF10B981) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillsContent() {
    final skills = widget.project['skillsNeeded'] as List<dynamic>? ?? [];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Skills Required',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 8),
          const Text(
            'To effectively contribute to this project, the following skills are needed:',
            style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          ...skills.map((skill) => _buildSkillItem(skill.toString())).toList(),
        ],
      ),
    );
  }

  Widget _buildResourcesContent() {
    final resources = widget.project['resources'] as List<dynamic>? ?? [];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Project Resources',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Resources to assist with this project:',
            style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          if (resources.isEmpty)
            const Text(
              'No resources available yet.',
              style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            )
          else
            ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: resources.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final resource = resources[index];
                return GestureDetector(
                  onTap: () async {
                    final url = Uri.parse(resource.toString());
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Cannot open this resource')),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.link, color: Color(0xFF2563EB), size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            resource.toString(),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF2563EB),
                              decoration: TextDecoration.underline,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSkillItem(String skill) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.code, size: 18, color: Color(0xFF2563EB)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              skill,
              style: const TextStyle(fontSize: 15, color: Color(0xFF334155)),
            ),
          ),
        ],
      ),
    );
  }

  Color _getProgressColor(double progress) {
    if (progress < 0.3) return const Color(0xFFEF4444);
    if (progress < 0.7) return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }

  String _getProgressStatus(double progress) {
    if (progress < 0.3) return 'Early Stage';
    if (progress < 0.7) return 'In Progress';
    if (progress < 0.95) return 'Almost Done';
    return 'Completed';
  }
}

// Main function to test the app
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MaterialApp(
    home: ProjectDetailScreen(
      project: {
        'id': 'project123',
        'askHelp': false,
        'description': 'this project aims to make a eye disease detection project by simply adding the dataset you can check the disease',
        // Remove 'progress' from here since it's user-specific now
        'resources': [],
        'roadmap': [
          {
            'description': 'here you wanti to upload the colum names of your dataset ',
            'level': 'Level 1',
            'title': 'dataset collection '
          },
          {
            'description': 'here u want to train the cnn model to get high accuracy ',
            'level': 'Level 2',
            'title': 'model training'
          },
          {
            'description': 'here you want upload the f1 scores etc',
            'level': 'Level 3',
            'title': 'model testing '
          }
        ],
        'skillsNeeded': ['Machine learning', 'AI', 'Python'],
        'tags': ['Python', 'ML', 'AI'],
        'title': 'eye disease detection using ml',
      },
    ),
  ));
}