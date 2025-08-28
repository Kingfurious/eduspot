import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_html/flutter_html.dart';
import 'dart:convert';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:highlight/highlight.dart' show highlight, Node;
import 'package:highlight/languages/all.dart';
import 'package:flutter_highlighter/themes/monokai-sublime.dart';
import 'package:url_launcher/url_launcher.dart';
// import 'package:video_player/video_player.dart'; // <<< YOUTUBE CHANGE: No longer needed for this page's video playback
import 'package:youtube_player_flutter/youtube_player_flutter.dart'; // <<< YOUTUBE CHANGE: Import youtube_player_flutter
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart'; // <-- Import for Clipboard
import 'Learnpagesubmission.dart';



class DomainExercisesPage extends StatefulWidget {
  final String domain;
  final Color? domainColor;

  const DomainExercisesPage({
    super.key,
    required this.domain,
    this.domainColor,
  });

  @override
  State<DomainExercisesPage> createState() => _DomainExercisesPageState();
}

class _DomainExercisesPageState extends State<DomainExercisesPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = true;
  List<DocumentSnapshot> _allExercises = [];
  List<DocumentSnapshot> _filteredExercises = [];

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadExercises() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final QuerySnapshot snapshot =
      await FirebaseFirestore.instance.collection(widget.domain).get();

      if (mounted) {
        setState(() {
          _allExercises = snapshot.docs;
          _filteredExercises = _allExercises;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Show error snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading exercises: $e'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

    }
  }

  String _getDurationText(int exerciseCount) {
    // Logic to determine duration based on number of exercises
    if (exerciseCount <= 3) {
      return '5 minutes';
    } else if (exerciseCount <= 6) {
      return '10 minutes';
    } else if (exerciseCount <= 9) {
      return '15 minutes';
    } else if (exerciseCount <= 12) {
      return '20 minutes';
    } else {
      return '30+ minutes';
    }
  }

  void _filterExercises(String query) {
    setState(() {
      _searchQuery = query;

      if (query.isEmpty) {
        _filteredExercises = _allExercises;
      } else {
        _filteredExercises = _allExercises.where((doc) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          final String exerciseName = data['exercise_name'] as String? ?? '';
          final String exerciseDetails = data['exercise_details'] as String? ?? '';

          return exerciseName.toLowerCase().contains(query.toLowerCase()) ||
              exerciseDetails.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Default color if none provided
    final Color domainColor = widget.domainColor ?? const Color(0xFF2196F3);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.grey[50]!,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            // Gradient header background
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 230,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      domainColor,
                      domainColor.withOpacity(0.8),
                    ],
                  ),
                ),
              ),
            ),

            // Main Content
            SafeArea(
              child: Column(
                children: [
                  // Header section
                  _buildHeader(context, domainColor),

                  // Search bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 15),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _filterExercises,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: Colors.grey[800],
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search ${widget.domain} exercises...',
                          hintStyle: GoogleFonts.inter(
                            fontSize: 16,
                            color: Colors.grey[400],
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Colors.grey,
                            size: 22,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                            icon: const Icon(
                              Icons.clear_rounded,
                              color: Colors.grey,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _filterExercises('');
                              });
                            },
                          )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                  ),


                  // Exercises Count
                  // Exercises Count
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 15),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'All Exercises',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: domainColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _getDurationText(_filteredExercises.length),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: domainColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Exercises List
                  Expanded(
                    child: _isLoading
                        ? _buildLoadingIndicator(domainColor)
                        : _filteredExercises.isEmpty
                        ? _buildEmptyState()
                        : _buildExercisesList(domainColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color domainColor) {
    return Container(
        padding: const EdgeInsets.all(20),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
        // App bar with back button
        Row(
        children: [
        // Circular back button
        GestureDetector(
        onTap: () => Navigator.pop(context),
    child: Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
    color: Colors.white.withOpacity(0.2),
    borderRadius: BorderRadius.circular(12),
    ),
    child: const Icon(
    Icons.arrow_back_ios_new_rounded,
    color: Colors.white,
    size: 20,
    ),
    ),
    ),
    const Spacer(),

    // Domain code in rounded container
    Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
    color: Colors.white.withOpacity(0.2),
    borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
    children: [
    const Icon(
    Icons.code_rounded,
    color: Colors.white,
    size: 18,
    ),
    const SizedBox(width: 6),
    Text(
    _getDomainCode(widget.domain),
    style: GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    ),
    ),
    ],
    ),
    ),
    ],
    ),

    const SizedBox(height: 25),

    // Domain title and subtitle
    Text(
    widget.domain,
    style: GoogleFonts.poppins(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    letterSpacing: -0.5,
    ),
    ),
    const SizedBox(height: 8),
    Text(
    'Master ${widget.domain} with hands-on exercises',
    style: GoogleFonts.inter(
    fontSize: 16,
      color: Colors.white.withOpacity(0.85),
      height: 1.4,
    ),
    ),
            ],
        ),
    );
  }

  Widget _buildLoadingIndicator(Color domainColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(domainColor),
            strokeWidth: 3,
          ),
          const SizedBox(height: 20),
          Text(
            'Loading exercises...',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty
                ? 'No exercises available yet'
                : 'No exercises found for "$_searchQuery"',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? 'Check back later for new content'
                : 'Try using different keywords',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (_searchQuery.isNotEmpty)
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _filterExercises('');
                });
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Clear Search'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[200],
                foregroundColor: Colors.grey[800],
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExercisesList(Color domainColor) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: _filteredExercises.length,
      itemBuilder: (context, index) {
        final doc = _filteredExercises[index];
        final data = doc.data() as Map<String, dynamic>? ?? {};

        // Safely extract data with fallbacks
        final String exerciseName = data['exercise_name'] as String? ?? 'Unnamed Exercise';
        final String exerciseDetails = data['exercise_details'] as String? ?? 'No details available';
        final int difficultyLevel = data['difficulty_level'] as int? ?? 1;
        final int estimatedMinutes = data['estimated_minutes'] as int? ?? 15;

        // Get color based on difficulty
        final Color difficultyColor = _getDifficultyColor(difficultyLevel);
        final String difficultyText = _getDifficultyText(difficultyLevel);

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildExerciseCard(
            context,
            exerciseName,
            exerciseDetails,
            difficultyLevel,
            difficultyColor,
            difficultyText,
            estimatedMinutes,
            domainColor,
            doc.id,
          ),
        );
      },
    );
  }

  Widget _buildExerciseCard(
      BuildContext context,
      String title,
      String details,
      int level,
      Color difficultyColor,
      String difficultyText,
      int minutes,
      Color domainColor,
      String exerciseId,
      ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ExerciseSubmissionPage(

            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header section with difficulty badge
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              decoration: BoxDecoration(
                color: domainColor.withOpacity(0.06),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: difficultyColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: difficultyColor.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      difficultyText,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: difficultyColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Details section
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Exercise description
                  Text(
                    details,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 16),

                  // Footer info - removed time estimate, showing only Start button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end, // Align to the right
                    children: [
                      // Start button
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: domainColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
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
                              Icons.arrow_forward_rounded,
                              size: 18,
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
          ],
        ),
      ),
    );
  }

  // Helper methods
  String _getDomainCode(String domain) {
    final Map<String, String> domainCodes = {
      'Python': 'PY',
      'JavaScript': 'JS',
      'Java': 'JV',
      'C++': 'C++',
      'HTML/CSS': 'HTML',
      'Machine Learning': 'ML',
      'AI': 'AI',
      'Flutter': 'FLT',
      'Web Development': 'WEB',
      'App Development': 'APP',
    };

    return domainCodes[domain] ?? domain.substring(0, min(3, domain.length)).toUpperCase();
  }

  int min(int a, int b) => a < b ? a : b;

  Color _getDifficultyColor(int level) {
    switch (level) {
      case 1:
        return Colors.green;
      case 2:
        return Colors.blue;
      case 3:
        return Colors.orange;
      case 4:
        return Colors.deepOrange;
      case 5:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getDifficultyText(int level) {
    switch (level) {
      case 1:
        return 'Beginner';
      case 2:
        return 'Easy';
      case 3:
        return 'Intermediate';
      case 4:
        return 'Advanced';
      case 5:
        return 'Expert';
      default:
        return 'Unknown';
    }
  }
}

