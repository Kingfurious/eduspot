import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'Learnpagesubmission.dart';

class ProblemListPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final String domain = ModalRoute.of(context)!.settings.arguments as String;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          '$domain Problems',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: _getDomainColor(domain),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection(domain).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(_getDomainColor(domain)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading $domain problems...',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading problems',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.red[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please check your connection and try again',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.code_off,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No problems found',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Check back later for new $domain challenges',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }

          final problems = snapshot.data!.docs;

          return Column(
            children: [
              // Header with problem count
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _getDomainColor(domain),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${problems.length} ${problems.length == 1 ? 'Problem' : 'Problems'} Available',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Master $domain with hands-on coding challenges',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),

              // Problems list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: problems.length,
                  itemBuilder: (context, index) {
                    final problem = problems[index];
                    final problemData = problem.data() as Map<String, dynamic>;

                    // Extract problem details with your exact field names
                    String exerciseName = problemData['exercise_name'] ?? 'Untitled Problem';
                    String exerciseDetails = problemData['exercise_details'] ?? 'No description available';
                    String difficulty = problemData['difficulty'] ?? 'Beginner';
                    String expectedAnswer = problemData['expected_answer'] ?? '';
                    List<dynamic> learningSteps = problemData['learning_steps'] ?? [];

                    // Estimate time based on learning steps count and difficulty
                    int estimatedMinutes = _calculateEstimatedTime(difficulty, learningSteps.length);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            // Navigate to ExerciseSubmissionPage with proper arguments
                            _navigateToSubmissionPage(
                              context,
                              problemId: problem.id,
                              domain: domain,
                              exerciseName: exerciseName,
                              domainColor: _getDomainColor(domain),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header with title and difficulty
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        exerciseName,
                                        style: GoogleFonts.poppins(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[800],
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    _buildDifficultyBadge(difficulty),
                                  ],
                                ),

                                const SizedBox(height: 12),

                                // Description
                                Text(
                                  exerciseDetails,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                    height: 1.5,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),

                                const SizedBox(height: 16),

                                // Learning steps indicator
                                if (learningSteps.isNotEmpty) ...[
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.auto_stories,
                                        size: 16,
                                        color: Colors.grey[500],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${learningSteps.length} learning steps included',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: Colors.grey[500],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                ],

                                // Footer with time and start button
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Time estimate
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          size: 16,
                                          color: Colors.grey[500],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '~${estimatedMinutes} min',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: Colors.grey[500],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),

                                    // Start button
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getDomainColor(domain),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Start Quest',
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          const Icon(
                                            Icons.arrow_forward,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Navigation method using direct navigation
  void _navigateToSubmissionPage(
      BuildContext context, {
        required String problemId,
        required String domain,
        required String exerciseName,
        required Color domainColor,
      }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExerciseSubmissionPage(),
        settings: RouteSettings(
          arguments: {
            'exerciseId': problemId,
            'domain': domain,
            'exerciseName': exerciseName,
            'domainColor': domainColor,
            'language': domain,        // For backward compatibility
            'problemId': problemId,    // For backward compatibility
          },
        ),
      ),
    );
  }

  Widget _buildDifficultyBadge(String difficulty) {
    Color color;
    IconData icon;

    switch (difficulty.toLowerCase()) {
      case 'beginner':
      case 'easy':
        color = Colors.green[600]!;
        icon = Icons.circle;
        break;
      case 'intermediate':
      case 'medium':
        color = Colors.orange[600]!;
        icon = Icons.change_history;
        break;
      case 'advanced':
      case 'hard':
        color = Colors.red[600]!;
        icon = Icons.square;
        break;
      default:
        color = Colors.grey[600]!;
        icon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            difficulty,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  int _calculateEstimatedTime(String difficulty, int stepsCount) {
    int baseTime;

    switch (difficulty.toLowerCase()) {
      case 'beginner':
      case 'easy':
        baseTime = 15;
        break;
      case 'intermediate':
      case 'medium':
        baseTime = 25;
        break;
      case 'advanced':
      case 'hard':
        baseTime = 35;
        break;
      default:
        baseTime = 20;
    }

    // Add 5 minutes per learning step
    return baseTime + (stepsCount * 5);
  }

  Color _getDomainColor(String domain) {
    switch (domain.toLowerCase()) {
      case 'ai':
        return const Color(0xFF9C27B0); // Purple
      case 'c++':
        return const Color(0xFF607D8B); // Blue Grey
      case 'flutter':
        return const Color(0xFF02569B); // Flutter Blue
      case 'java':
        return const Color(0xFFF44336); // Red
      case 'javascript':
        return const Color(0xFFFF9800); // Orange
      case 'python':
        return const Color(0xFF3F51B5); // Indigo
      case 'machine learning':
        return const Color(0xFF4CAF50); // Green
      case 'web development':
        return const Color(0xFF2196F3); // Blue
      default:
        return const Color(0xFF6200EA); // Default Purple
    }
  }
}