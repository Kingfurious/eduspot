import 'package:eduspark/UploadProjectForm.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'Learnscreenhome.dart';
import 'LearnScreen.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ProjectDetailsPage.dart';
import 'AnswerSubmissionPage.dart';
import 'CertificateScreen.dart'; // Import only - implementation is in separate file
import 'ChatbotPage.dart';
import 'innovation_score_service.dart'; // Import InnovationScoreService

// Color Palette
const Color primaryBlue = Color(0xFF1976D2);
const Color lightBlue = Color(0xFF64B5F6);
const Color veryLightBlue = Color(0xFFE3F2FD);
const Color darkBlue = Color(0xFF0D47A1);
const Color accentBlue = Color(0xFF29B6F6);



class AskMentorPage extends StatelessWidget {
  const AskMentorPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Ask Mentor', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: primaryBlue,
          elevation: 2,
          iconTheme: const IconThemeData(color: Colors.white),
          titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
        ),
        body: Container(
            color: veryLightBlue,
            child: const Center(
                child: Text(
                    'Ask a Mentor',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlue)
                )
            )
        )
    );
  }
}

// Project Details Page
class ProjectDetailPage extends StatefulWidget {
  final String projectId;

  const ProjectDetailPage({super.key, required this.projectId});

  @override
  State<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<ProjectDetailPage> with SingleTickerProviderStateMixin {
  int _selectedTabIndex = 0;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late TabController _tabController;
  bool isLoading = true;
  bool _isDescriptionExpanded = false;
  bool _isOverviewVisible = true;
  final ScrollController _scrollController = ScrollController();
  final InnovationScoreService _innovationScoreService = InnovationScoreService(); // Create an instance

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedTabIndex = _tabController.index;
      });
    });

    // Add scroll listener to auto-hide description when scrolling down
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // Handle scrolling behavior
  void _onScroll() {
    if (_scrollController.offset > 50 && _isOverviewVisible) {
      setState(() {
        _isOverviewVisible = false;
      });
    } else if (_scrollController.offset <= 50 && !_isOverviewVisible) {
      setState(() {
        _isOverviewVisible = true;
      });
    }
  }

  // Helper method to get a preview of the description
  String _getDescriptionPreview(String description) {
    if (description.length <= 80) {
      return description;
    }
    return '${description.substring(0, 80)}...';
  }

  Future<bool> _isLevelCompleted(String userId, String projectId, String levelName) async {
    final doc = await FirebaseFirestore.instance
        .collection('user_answers')
        .doc(userId)
        .collection('projects')
        .doc(projectId)
        .collection('levels')
        .doc(levelName)
        .get();
    return doc.exists && (doc.data()?['isCorrect'] as bool? ?? false);
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final screenSize = MediaQuery.of(context).size;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('projects').doc(widget.projectId).get(),
      builder: (context, snapshot) {
        // ... existing code for loading states ...

        final projectData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final roadmap = (projectData['roadmap'] as List<dynamic>?) ?? [];
        final projectTitle = projectData['title'] ?? 'Untitled Project';
        final projectDescription = projectData['description'] ?? 'No description available';

        return FutureBuilder<double>(
          future: user != null ? _getUserProgress(user.uid, widget.projectId) : Future.value(0.0),
          builder: (context, progressSnapshot) {
            final progress = progressSnapshot.data ?? 0.0;

            return Scaffold(
              backgroundColor: veryLightBlue,
              // Enhanced App Bar with more space for the title
              appBar: AppBar(
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      projectTitle.length > 25 ? '${projectTitle.substring(0, 25)}...' : projectTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    Text(
                      '${(progress * 100).toInt()}% Complete',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
                backgroundColor: primaryBlue,
                elevation: 0,
                centerTitle: false,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                // Add info button to app bar
                actions: [
                  IconButton(
                    icon: const Icon(Icons.info_outline, color: Colors.white),
                    onPressed: () {
                      _showProjectInfoSheet(projectTitle, projectDescription, projectData);
                    },
                    tooltip: 'Project Information',
                  ),
                ],
              ),
              body: Stack(
                children: [
                  // Main content
                  Column(
                    children: [
                      // Progress indicator bar
                      LinearProgressIndicator(
                        value: progress,
                        backgroundColor: primaryBlue.withOpacity(0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(accentBlue),
                        minHeight: 6,
                      ),

                      // Custom tab bar with pill design
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Row(
                            children: [
                              _buildPillTab(0, "Roadmap", Icons.timeline),
                              _buildPillTab(1, "Skills", Icons.psychology),
                              _buildPillTab(2, "Resources", Icons.menu_book),
                            ],
                          ),
                        ),
                      ),

                      // Content area
                      Expanded(
                        child: IndexedStack(
                          index: _selectedTabIndex,
                          children: [
                            // Roadmap content with modern cards
                            _buildRoadmapContent(roadmap, progress, user?.uid),

                            // Skills Grid
                            _buildSkillsGrid(projectData),

                            // Resources List
                            _buildResourcesList(projectData),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Removed the original info button that was conditional
                ],
              ),

              // Updated Floating Action Buttons with Learn and Mentor navigation
              floatingActionButton: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Chatbot button
                  FloatingActionButton.small(
                    heroTag: 'chatbot',
                    backgroundColor: accentBlue,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    onPressed: () {
                      final firstIncompleteLevelIndex = (progress * roadmap.length).ceil();
                      final levelName = roadmap.isNotEmpty
                          ? (firstIncompleteLevelIndex < roadmap.length
                          ? roadmap[firstIncompleteLevelIndex]['level']
                          : roadmap.last['level'])
                          : null;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatbotPage(
                            projectId: widget.projectId,
                            levelName: levelName,
                          ),
                        ),
                      );
                    },
                    child: const Icon(Icons.chat),
                  ),
                  const SizedBox(height: 12),

                  // Learn page button
                  FloatingActionButton.small(
                    heroTag: 'learn',
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => LearnHomePage()),
                      );
                    },
                    child: const Icon(Icons.school),
                  ),
                  const SizedBox(height: 12),

                  // Mentor page button
                  FloatingActionButton.small(
                    heroTag: 'mentor',
                    backgroundColor: darkBlue,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AskMentorPage()),
                      );
                    },
                    child: const Icon(Icons.question_answer),
                  ),
                  const SizedBox(height: 12),

                  // Tips button (main action)
                  FloatingActionButton(
                    heroTag: 'tips',
                    backgroundColor: accentBlue,
                    elevation: 6,
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        builder: (context) => DraggableScrollableSheet(
                          initialChildSize: 0.4,
                          minChildSize: 0.3,
                          maxChildSize: 0.7,
                          expand: false,
                          builder: (context, scrollController) => _buildTipsSheet(scrollController),
                        ),
                      );
                    },
                    child: const Icon(Icons.lightbulb_outline, color: Colors.white),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // New method to show project info in a bottom sheet
  void _showProjectInfoSheet(String title, String description, Map<String, dynamic> projectData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => _buildProjectInfoSheet(
            scrollController,
            title,
            description,
            projectData
        ),
      ),
    );
  }

  // New method to build the project info bottom sheet
  Widget _buildProjectInfoSheet(
      ScrollController controller,
      String title,
      String description,
      Map<String, dynamic> projectData,
      ) {
    final tags = (projectData['tags'] as List<dynamic>?) ?? [];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: ListView(
        controller: controller,
        padding: const EdgeInsets.all(24),
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Project title with decoration
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: primaryBlue.withOpacity(0.2),
                  width: 2,
                ),
              ),
            ),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: darkBlue,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Description section
          const Text(
            'Project Description',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: darkBlue,
            ),
          ),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              description,
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Tags section
          if (tags.isNotEmpty) ...[
            const Text(
              'Tags',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: darkBlue,
              ),
            ),

            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.map<Widget>((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: lightBlue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: lightBlue.withOpacity(0.5)),
                  ),
                  child: Text(
                    tag.toString(),
                    style: const TextStyle(color: darkBlue, fontSize: 14),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),
          ],

          // Close button
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: primaryBlue,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Pill-shaped tab selector
  Widget _buildPillTab(int index, String label, IconData icon) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTabIndex = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 40,
          decoration: BoxDecoration(
            color: isSelected ? primaryBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Roadmap content with horizontal scroll for levels
  Widget _buildRoadmapContent(List<dynamic> roadmap, double progress, String? userId) {
    final totalLevels = roadmap.length;

    if (roadmap.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No roadmap available for this project',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        // Journey Map visualization
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  "Your Journey",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: darkBlue,
                  ),
                ),
              ),

              // Journey progress visualization
              Container(
                height: 80,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Row(
                  children: [
                    // Path line with dots
                    ...List.generate(
                      roadmap.length,
                          (index) {
                        final isCompleted = index < (progress * totalLevels).ceil();
                        return Expanded(
                          child: Row(
                            children: [
                              // Level dot
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isCompleted ? Colors.green :
                                  index == (progress * totalLevels).ceil() ? primaryBlue : Colors.grey[300],
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: isCompleted
                                    ? const Icon(Icons.check, color: Colors.white, size: 14)
                                    : Text(
                                  "${index + 1}",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: index == (progress * totalLevels).ceil() ? Colors.white : Colors.grey[600],
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),

                              // Connector line (not on last item)
                              if (index < roadmap.length - 1)
                                Expanded(
                                  child: Container(
                                    height: 2,
                                    color: isCompleted ? Colors.green : Colors.grey[300],
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),

                    // Certificate icon at the end
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: progress >= 0.95 ? Colors.amber : Colors.grey[300],
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.emoji_events,
                        color: progress >= 0.95 ? Colors.white : Colors.grey[400],
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),

              // Current level indicator
              Container(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        "Current Level: ${roadmap[(progress * totalLevels).ceil() < roadmap.length ? (progress * totalLevels).ceil() : roadmap.length - 1]['level']}",
                        style: const TextStyle(
                          color: primaryBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      "${(progress * 100).toInt()}% Complete",
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Level cards with detailed information
        ...List.generate(
          roadmap.length,
              (index) => _buildLevelCard(
            index: index,
            level: roadmap[index] as Map<String, dynamic>,
            isCompleted: index < (progress * totalLevels).ceil(),
            isPreviousLevelCompleted: index == 0 ? true : index - 1 < (progress * totalLevels).ceil(),
            totalLevels: totalLevels,
            userId: userId,
          ),
        ),

        // Certificate card at the end
        _buildCertificateCard(progress, totalLevels),
      ],
    );
  }

  // Level card with modern design
  Widget _buildLevelCard({
    required int index,
    required Map<String, dynamic> level,
    required bool isCompleted,
    required bool isPreviousLevelCompleted,
    required int totalLevels,
    String? userId,
  }) {
    final levelName = level['level'] as String? ?? 'Unknown Level';
    final levelDesc = level['description'] as String? ?? 'No description';
    final levelNumber = int.parse(levelName.split(' ').last);

    // Design with card and status indicators
    return Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
    BoxShadow(
    color: Colors.black.withOpacity(0.05),
    blurRadius: 6,
    offset: const Offset(0, 2),
    ),
    ],
    border: Border.all(
    color: isCompleted ? Colors.green.withOpacity(0.3) :
    isPreviousLevelCompleted ? primaryBlue.withOpacity(0.3) : Colors.grey[300]!,
    width: 1.5,
    ),
    ),
    child: Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
    borderRadius: BorderRadius.circular(16),
    onTap: isPreviousLevelCompleted ? () {
    Navigator.push(
    context,
    MaterialPageRoute(
    builder: (context) => AnswerSubmissionPage(
    projectId: widget.projectId,
    levelName: levelName,
    levelDescription: levelDesc,
    totalLevels: totalLevels,
    ),
    ),
    ).then((_) => setState(() {}));
    } : null,
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    // Level header with number and status
    Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
    color: isCompleted ? Colors.green.withOpacity(0.05) :
    isPreviousLevelCompleted ? primaryBlue.withOpacity(0.05) : Colors.grey[100],
    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
    ),
    child: Row(
    children: [
    // Level number & icon
    Container(
    width: 32,
    height: 32,
    decoration: BoxDecoration(
    shape: BoxShape.circle,
    color: isCompleted ? Colors.green :
    isPreviousLevelCompleted ? primaryBlue : Colors.grey[400],
    ),
    child: Center(
    child: isCompleted ?
    const Icon(Icons.check, color: Colors.white, size: 16) :
    Text(
    "$levelNumber",
    style: const TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.bold,
    ),
    ),
    ),
    ),
    const SizedBox(width: 12),

    // Level name
    Expanded(
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Text(
    levelName,
    style: TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: isCompleted ? Colors.green[700] :
    isPreviousLevelCompleted ? darkBlue : Colors.grey[700],
    ),
    ),
    Text(
    isCompleted ? "Completed" :
    isPreviousLevelCompleted ? "Available" : "Locked",
    style: TextStyle(
    fontSize: 12,
    color: isCompleted ? Colors.green :
    isPreviousLevelCompleted ? primaryBlue : Colors.grey[600],
    fontWeight: FontWeight.w500,
    ),
    ),
    ],
    ),
    ),

    // Status icon
    Container(
    width: 32,
    height: 32,
    decoration: BoxDecoration(
    shape: BoxShape.circle,
    color: isCompleted ? Colors.green.withOpacity(0.1) :
    isPreviousLevelCompleted ? primaryBlue.withOpacity(0.1) : Colors.grey[200],
    ),
    child: Icon(
    isCompleted ? Icons.check_circle :
    isPreviousLevelCompleted ? Icons.play_circle_fill : Icons.lock,
    size: 20,
    color: isCompleted ? Colors.green :
    isPreviousLevelCompleted ? primaryBlue : Colors.grey[500],
    ),
    ),
    ],
    ),
    ),

    // Level description
    Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Text(
    levelDesc,
    style: const TextStyle(
      fontSize: 14,
      color: Colors.black87,
      height: 1.4,
    ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    ),

      const SizedBox(height: 16),

      // Action button
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: isPreviousLevelCompleted ? () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AnswerSubmissionPage(
                  projectId: widget.projectId,
                  levelName: levelName,
                  levelDescription: levelDesc,
                  totalLevels: totalLevels,
                ),
              ),
            ).then((_) => setState(() {}));
          } : null,
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: isCompleted ? Colors.green :
            isPreviousLevelCompleted ? primaryBlue : Colors.grey[400],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
            elevation: 0,
          ),
          child: Text(
            isCompleted ? "Review Level" :
            isPreviousLevelCompleted ? "Start Level" : "Locked",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
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

  // Certificate card with trophy design
  Widget _buildCertificateCard(double progress, int totalLevels) {
    final bool isUnlocked = progress >= 0.95;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isUnlocked
              ? [
            const Color(0xFFFFD700).withOpacity(0.7),
            const Color(0xFFFFA500).withOpacity(0.7),
          ]
              : [
            Colors.grey[300]!,
            Colors.grey[400]!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isUnlocked
                ? Colors.amber.withOpacity(0.3)
                : Colors.grey.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _handleCertificateTap(progress, totalLevels),
          child: Stack(
            children: [
              // Background elements (decorative)
              if (isUnlocked)
                ...List.generate(5, (index) {
                  return Positioned(
                    left: index * 50.0,
                    top: index * 20.0,
                    child: Opacity(
                      opacity: 0.1,
                      child: Icon(
                        Icons.star,
                        size: 24,
                        color: Colors.white,
                      ),
                    ),
                  );
                }),

              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    // Trophy icon
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.emoji_events,
                          color: isUnlocked ? Colors.amber[700] : Colors.grey[400],
                          size: 40,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Text content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isUnlocked ? 'Certificate Ready!' : 'Get Your Certificate',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isUnlocked ? Colors.brown[900] : Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isUnlocked
                                ? 'You\'ve completed the project! Tap to view.'
                                : 'Complete 95% of the project to unlock your certificate.',
                            style: TextStyle(
                              fontSize: 13,
                              color: isUnlocked ? Colors.brown[800] : Colors.grey[600],
                            ),
                          ),
                          if (isUnlocked)
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.visibility,
                                    size: 14,
                                    color: Colors.brown[900],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'View Certificate',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.brown[900],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Indicator icon
                    Icon(
                      isUnlocked ? Icons.arrow_forward_ios : Icons.lock_outline,
                      size: 16,
                      color: isUnlocked ? Colors.brown[800] : Colors.grey[500],
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

  // Quick tips bottom sheet
  Widget _buildTipsSheet(ScrollController controller) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: ListView(
        controller: controller,
        padding: const EdgeInsets.all(24),
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Title
          const Text(
            'Tips to Complete Your Project',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: darkBlue,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          // Tips list
          _buildTipItem(
            icon: Icons.check_circle_outline,
            title: 'Complete each level in order',
            description: 'Levels build on each other. Make sure to master each one before moving to the next.',
          ),

          _buildTipItem(
            icon: Icons.chat_bubble_outline,
            title: 'Use the chatbot for guidance',
            description: 'Stuck on a level? The AI chatbot can provide helpful hints and explanations.',
          ),

          _buildTipItem(
            icon: Icons.menu_book,
            title: 'Check resources tab',
            description: 'We\'ve curated helpful links and materials to support your learning journey.',
          ),

          _buildTipItem(
            icon: Icons.emoji_events_outlined,
            title: 'Get your certificate',
            description: 'Complete at least 95% of the project to unlock your personalized certificate.',
          ),

          const SizedBox(height: 24),

          // Close button
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: primaryBlue,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  // Individual tip item
  Widget _buildTipItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryBlue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: primaryBlue,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: darkBlue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Skills grid with colorful cards
  Widget _buildSkillsGrid(Map<String, dynamic> projectData) {
    final skillsList = (projectData['skillsNeeded'] as List<dynamic>?) ?? [];

    if (skillsList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.psychology_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No skills specified for this project',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.0,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: skillsList.length,
      itemBuilder: (context, index) {
        final skill = skillsList[index].toString();

        // Define different background colors for variety
        final List<Map<String, dynamic>> skillStyles = [
          {
            'gradient': [Colors.blue[100]!, Colors.blue[400]!],
            'icon': Icons.code,
          },
          {
            'gradient': [Colors.purple[100]!, Colors.purple[400]!],
            'icon': Icons.lightbulb_outline,
          },
          {
            'gradient': [Colors.green[100]!, Colors.green[400]!],
            'icon': Icons.design_services,
          },
          {
            'gradient': [Colors.amber[100]!, Colors.amber[400]!],
            'icon': Icons.architecture,
          },
          {
            'gradient': [Colors.cyan[100]!, Colors.cyan[400]!],
            'icon': Icons.analytics_outlined,
          },
          {
            'gradient': [Colors.teal[100]!, Colors.teal[400]!],
            'icon': Icons.layers,
          },
        ];

        final skillStyle = skillStyles[index % skillStyles.length];

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                skillStyle['gradient'][0],
                skillStyle['gradient'][1],
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: skillStyle['gradient'][1].withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                // Show skill details dialog
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(
                      skill,
                      style: const TextStyle(color: darkBlue),
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          skillStyle['icon'],
                          size: 48,
                          color: skillStyle['gradient'][1],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'This skill is essential for completing this project successfully. Focus on mastering it to enhance your learning experience.',
                          style: TextStyle(
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                );
              },
              child: Stack(
                children: [
                  // Background pattern
                  Positioned(
                    bottom: -20,
                    right: -20,
                    child: Icon(
                      skillStyle['icon'],
                      size: 100,
                      color: Colors.white.withOpacity(0.15),
                    ),
                  ),

                  // Content
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          skillStyle['icon'],
                          size: 36,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          skill,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Resources tab with modern cards
  Widget _buildResourcesList(Map<String, dynamic> projectData) {
    final resourcesList = (projectData['resources'] as List<dynamic>?) ?? [];

    if (resourcesList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No resources available for this project',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: resourcesList.length,
      itemBuilder: (context, index) {
        final resource = resourcesList[index].toString();
        final bool isLink = resource.startsWith('http://') || resource.startsWith('https://');

        // Determine resource type
        IconData resourceIcon;
        String resourceType;
        Color resourceColor;
        String resourceTitle;

        if (isLink) {
          Uri uri = Uri.parse(resource);
          resourceTitle = uri.host.replaceFirst('www.', '');

          if (resource.contains('youtube') || resource.contains('youtu.be')) {
            resourceIcon = Icons.video_library;
            resourceType = 'Video Tutorial';
            resourceColor = Colors.red;
          } else if (resource.contains('.pdf')) {
            resourceIcon = Icons.picture_as_pdf;
            resourceType = 'PDF Document';
            resourceColor = Colors.red[700]!;
          } else if (resource.contains('github')) {
            resourceIcon = Icons.code;
            resourceType = 'Code Repository';
            resourceColor = Colors.purple;
          } else if (resource.contains('coursera') || resource.contains('udemy') || resource.contains('course')) {
            resourceIcon = Icons.school;
            resourceType = 'Online Course';
            resourceColor = Colors.green[700]!;
          } else {
            resourceIcon = Icons.language;
            resourceType = 'Website';
            resourceColor = accentBlue;
          }
        } else {
          resourceIcon = Icons.text_snippet;
          resourceType = 'Reading Material';
          resourceColor = Colors.amber[700]!;
          resourceTitle = resource.length > 30 ? '${resource.substring(0, 30)}...' : resource;
        }

        // Enhanced resource card
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: resourceColor.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: resourceColor.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: isLink ? () => _launchUrl(resource) : null,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Resource type and title row
                    Row(
                      children: [
                        // Resource icon
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: resourceColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(
                              resourceIcon,
                              size: 24,
                              color: resourceColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Resource title
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Type badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: resourceColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  resourceType,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: resourceColor,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),

                              // Title
                              Text(
                                resourceTitle,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Action button
                        if (isLink)
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: resourceColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.open_in_new,
                              size: 16,
                              color: resourceColor,
                            ),
                          ),
                      ],
                    ),

                    // URL display if it's a link
                    if (isLink)
                      Padding(
                        padding: const EdgeInsets.only(left: 60, top: 8),
                        child: Text(
                          resource,
                          style: TextStyle(
                            fontSize: 12,
                            color: accentBlue,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Get user progress
  Future<double> _getUserProgress(String userId, String projectId) async {
    final doc = await FirebaseFirestore.instance
        .collection('user_answers')
        .doc(userId)
        .collection('projects')
        .doc(projectId)
        .get();
    final progress = doc.data()?['progress'];
    return (progress is num) ? progress.toDouble() : 0.0;
  }

  // Handle certificate tap
  void _handleCertificateTap(double progress, int totalLevels) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to request a certificate'),
          backgroundColor: darkBlue,
        ),
      );
      return;
    }

    if (progress < 0.95) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.amber),
              const SizedBox(width: 8),
              const Expanded(child: Text('Not Yet Complete')),
            ],
          ),
          content: const Text('You need to complete at least 95% of the project to unlock your certificate.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(color: primaryBlue)),
            ),
          ],
        ),
      );
    } else {
      // Project is completed (>= 95% progress), calculate and update innovation score
      _innovationScoreService.calculateAndSetInnovationScore(user.uid); // Use the instance

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CertificateRequestPage(projectId: widget.projectId),
        ),
      );
    }
  }
}