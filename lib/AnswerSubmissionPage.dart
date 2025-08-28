import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:confetti/confetti.dart';
import 'dart:async';
import 'dart:math' as math;

// Define color palette as constants
const Color primaryBlue = Color(0xFF1976D2);
const Color lightBlue = Color(0xFF64B5F6);
const Color veryLightBlue = Color(0xFFE3F2FD);
const Color darkBlue = Color(0xFF0D47A1);
const Color accentBlue = Color(0xFF29B6F6);

class AnswerSubmissionPage extends StatefulWidget {
  final String projectId;
  final String levelName;
  final String levelDescription;
  final int totalLevels;

  const AnswerSubmissionPage({
    super.key,
    required this.projectId,
    required this.levelName,
    required this.levelDescription,
    required this.totalLevels,
  });

  @override
  State<AnswerSubmissionPage> createState() => _AnswerSubmissionPageState();
}

class _AnswerSubmissionPageState extends State<AnswerSubmissionPage> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _outputController = TextEditingController();
  final TextEditingController _textController = TextEditingController();
  File? _file;
  String? _submissionType;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // Level completion tracking
  bool _levelCompleted = false;

  // Submission state
  bool _isSubmitting = false;

  // Animation controllers
  late ConfettiController _confettiController;

  // Cache for verification criteria to reduce Firestore reads
  static Map<String, Map<String, dynamic>> _criteriaCache = {};

  // API key management
  static List<String> _apiKeys = [
    'AIzaSyAvQcRty4FsLjeV_cHQ7FK1nunKWUJvqV8',

  ];
  static int _currentApiKeyIndex = 0;

  // API rate limiter
  static int _apiCallsInLastMinute = 0;
  static DateTime _lastApiCallTime = DateTime.now();
  static const int _maxApiCallsPerMinute = 300; // Adjust based on your API quota

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _fetchSubmissionType();
    _checkLevelCompletion();
  }

  // Get the next available API key with rate limiting
  String _getApiKey() {
    final now = DateTime.now();

    // Reset counter if a minute has passed
    if (now.difference(_lastApiCallTime) > Duration(minutes: 1)) {
      _apiCallsInLastMinute = 0;
      _lastApiCallTime = now;
    }

    // If we're at rate limit, use fallback verification instead
    if (_apiCallsInLastMinute >= _maxApiCallsPerMinute) {
      throw Exception('API rate limit reached. Using fallback verification.');
    }

    // Increment call counter
    _apiCallsInLastMinute++;

    // Rotate through available API keys for load distribution
    _currentApiKeyIndex = (_currentApiKeyIndex + 1) % _apiKeys.length;
    return _apiKeys[_currentApiKeyIndex];
  }

  Future<void> _fetchSubmissionType() async {
    // Check if criteria is in cache
    final cacheKey = "${widget.projectId}_${widget.levelName}";

    if (_criteriaCache.containsKey(cacheKey)) {
      setState(() {
        _submissionType = _criteriaCache[cacheKey]?['submissionType'] ?? 'text';
      });
      return;
    }

    // Not in cache, need to fetch from Firestore
    try {
      final doc = await _firestore
          .collection('answers')
          .doc(widget.projectId)
          .collection('levels')
          .doc(widget.levelName)
          .get();

      if (doc.exists) {
        // Cache the entire criteria for future use
        _criteriaCache[cacheKey] = doc.data() ?? {};
      }

      setState(() {
        _submissionType = doc.data()?['submissionType']?.toString() ?? 'text';
      });
    } catch (e) {
      print('Error fetching submission type: $e');
      // Default to text if there's an error
      setState(() {
        _submissionType = 'text';
      });
    }
  }

  Future<void> _checkLevelCompletion() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final userLevelDoc = _firestore
          .collection('user_answers')
          .doc(user.uid)
          .collection('projects')
          .doc(widget.projectId)
          .collection('levels')
          .doc(widget.levelName);

      final doc = await userLevelDoc.get();
      if (doc.exists && doc.data()?['isCorrect'] == true) {
        setState(() {
          _levelCompleted = true;
        });
      }
    } catch (e) {
      print('Error checking level completion: $e');
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['dart', 'py', 'txt', 'jpg', 'png', 'csv'],
      );
      if (result != null) {
        setState(() => _file = File(result.files.single.path!));
      }
    } catch (e) {
      print('Error picking file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting file: ${e.toString()}'),
          backgroundColor: Colors.red[700],
        ),
      );
    }
  }

  // Enhanced normalizeText method that ignores punctuation, spaces, and case
  // It extracts numbers with their associated metrics for comparison
  String _normalizeText(String text) {
    if (text == null || text.isEmpty) {
      return '';
    }

    // Convert to lowercase and remove excess whitespace
    String normalized = text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

    // Extract performance metrics - numbers with % signs
    List<String> extractedMetrics = [];

    // Pattern to match numbers with percentages (e.g., "95%" or "95.5%")
    RegExp percentPattern = RegExp(r'(\d+\.?\d*)%');
    Iterable<RegExpMatch> percentMatches = percentPattern.allMatches(normalized);

    for (RegExpMatch match in percentMatches) {
      extractedMetrics.add(match.group(0) ?? '');
    }

    // If no percentages found, check for decimal numbers that might be accuracy values
    if (extractedMetrics.isEmpty) {
      RegExp decimalPattern = RegExp(r'0\.\d+');
      Iterable<RegExpMatch> decimalMatches = decimalPattern.allMatches(normalized);

      for (RegExpMatch match in decimalMatches) {
        // Convert to percentage format for consistency
        double value = double.tryParse(match.group(0) ?? '0') ?? 0;
        extractedMetrics.add('${(value * 100).toStringAsFixed(1)}%');
      }
    }

    // Sort metrics for consistent ordering regardless of input order
    extractedMetrics.sort();

    return extractedMetrics.join(' ');
  }

  // Helper method to compare metrics - more flexible than exact matching
  bool _compareMetrics(String metrics1, String metrics2) {
    if (metrics1 == metrics2) {
      return true; // Exact match
    }

    // If either is empty, they don't match
    if (metrics1.isEmpty || metrics2.isEmpty) {
      return false;
    }

    // Split the metrics into individual values
    List<String> values1 = metrics1.split(' ');
    List<String> values2 = metrics2.split(' ');

    // If different number of metrics, they might not match
    if (values1.length != values2.length) {
      // But let's be flexible - if all metrics from one list are in the other, consider it a match
      if (values1.length < values2.length) {
        return values1.every((value) => values2.contains(value));
      } else {
        return values2.every((value) => values1.contains(value));
      }
    }

    // Compare each metric - allow small differences (±2%)
    for (int i = 0; i < values1.length; i++) {
      // Extract the numeric part
      double num1 = _extractNumber(values1[i]);
      double num2 = _extractNumber(values2[i]);

      // If we couldn't parse the numbers or they're too different
      if (num1 < 0 || num2 < 0 || (num1 - num2).abs() > 2.0) {
        return false;
      }
    }

    return true;
  }

  // Helper to extract number from a string like "95%" -> 95.0
  double _extractNumber(String value) {
    RegExp regExp = RegExp(r'(\d+\.?\d*)');
    Match? match = regExp.firstMatch(value);
    if (match != null) {
      return double.tryParse(match.group(1) ?? '0') ?? -1;
    }
    return -1;
  }

  // AI-first verification for text submissions with keyword fallback
  Future<void> _verifyTextSubmission(String submittedText, String? fileUrl) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Show loading indicator
    setState(() {
      _isSubmitting = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: veryLightBlue,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
            ),
            SizedBox(height: 20),
            Text(
              'Analyzing your submission...',
              style: TextStyle(
                color: darkBlue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );

    try {
      // 1. Get verification criteria from cache or Firestore
      final cacheKey = "${widget.projectId}_${widget.levelName}";
      Map<String, dynamic> data = {};

      if (_criteriaCache.containsKey(cacheKey)) {
        data = _criteriaCache[cacheKey] ?? {};
      } else {
        final doc = await _firestore
            .collection('answers')
            .doc(widget.projectId)
            .collection('levels')
            .doc(widget.levelName)
            .get();

        if (!doc.exists) {
          Navigator.pop(context); // Close loading dialog
          setState(() {
            _isSubmitting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Verification criteria not found'),
              backgroundColor: Colors.red[700],
            ),
          );
          return;
        }

        data = doc.data() ?? {};
        _criteriaCache[cacheKey] = data; // Cache for future use
      }

      final List<String> requiredKeywords = List<String>.from(data['expectedKeywords'] ?? []);
      final double passingThreshold = data['passingScore'] ?? 70.0; // Default 70% passing threshold

      // 2. First try AI-based verification using Gemini
      try {
        // Get API key with load balancing and rate limiting
        final String apiKey = _getApiKey();
        final String apiUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro:generateContent?key=$apiKey';

        // Get project context
        final cacheProjectKey = widget.projectId;
        Map<String, dynamic>? projectData;

        // Check if project data is cached
        // When getting project data, use this approach:
        if (_criteriaCache.containsKey(cacheProjectKey + "_project")) {
          projectData = _criteriaCache[cacheProjectKey + "_project"] ?? {};
        } else {
          final projectDoc = await _firestore.collection('projects').doc(widget.projectId).get();
          projectData = projectDoc.data() ?? {};
          _criteriaCache[cacheProjectKey + "_project"] = projectData; // Cache project data
        }

        final projectTitle = projectData?['title'] ?? 'Project';
        final projectDescription = projectData?['description'] ?? '';

        // Build AI evaluation prompt
        String prompt = '''
I need to evaluate a student's answer for a project assignment.

Project: ${projectTitle}
Level: ${widget.levelName}
Description: ${widget.levelDescription}

REQUIRED CONCEPTS (keywords that should be addressed):
${requiredKeywords.join(', ')}

STUDENT'S ANSWER:
${submittedText}

Please evaluate this submission on a scale of 0-100:
1. Quality and relevance to the task
2. Coverage of the required concepts
3. Technical correctness

Provide your evaluation in the following JSON format:
{
  "score": 85.5,
  "isCorrect": true/false,
  "feedback": "Brief explanation of score",
  "keywordsFeedback": "Specific feedback about keywords",
  "conceptsCovered": ["concept1", "concept2"],
  "missingConcepts": ["concept3", "concept4"]
}

A score of ${passingThreshold}% or higher should be considered passing (isCorrect: true).
Focus on the key concepts rather than exact wording. Be generous if the student demonstrates understanding.
''';

        // Make API request
        final response = await http.post(
          Uri.parse(apiUrl),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'contents': [{
              'parts': [{
                'text': prompt
              }]
            }],
            'generationConfig': {
              'temperature': 0.1, // Lower temperature for more consistent results
              'topK': 1,
              'topP': 0.8,
              'maxOutputTokens': 8192,
            }
          }),
        );

        if (response.statusCode != 200) {
          throw Exception('Gemini API error: ${response.body}');
        }

        // Parse AI response
        final jsonResponse = jsonDecode(response.body);
        final String responseText = jsonResponse['candidates'][0]['content']['parts'][0]['text'];

        // Extract JSON from response
        final RegExp jsonPattern = RegExp(r'\{[\s\S]*\}');
        final Match? match = jsonPattern.firstMatch(responseText);

        if (match == null) {
          throw Exception('Could not extract JSON from Gemini response');
        }

        final String jsonString = match.group(0) ?? '{}';
        Map<String, dynamic> aiResult = jsonDecode(jsonString);

        // Extract AI judgment
        final double score = aiResult['score'] is int ?
        aiResult['score'].toDouble() : (aiResult['score'] ?? 0.0);

        final bool isPassing = score >= passingThreshold;

        // AI verification succeeded - save results and finish
        final List<String> conceptsCovered = List<String>.from(aiResult['conceptsCovered'] ?? []);
        final List<String> missingConcepts = List<String>.from(aiResult['missingConcepts'] ?? []);

        // Create verification result structure
        Map<String, dynamic> verificationResult = {
          'isCorrect': isPassing,
          'totalScore': score,
          'maxScore': 100.0,
          'passingThreshold': passingThreshold,
          'verificationMethod': 'ai',
          'conceptsCovered': conceptsCovered,
          'missingConcepts': missingConcepts,
          'feedback': aiResult['feedback'] ?? '',
          'keywordsFeedback': aiResult['keywordsFeedback'] ?? '',
          'aiResponse': aiResult
        };

        // Save results to Firestore
        await _firestore
            .collection('user_answers')
            .doc(user.uid)
            .collection('projects')
            .doc(widget.projectId)
            .collection('levels')
            .doc(widget.levelName)
            .set({
          'text': submittedText,
          'fileUrl': fileUrl,
          'submittedAt': FieldValue.serverTimestamp(),
          'isCorrect': isPassing,
          'totalScore': score,
          'verificationMethod': 'ai',
          'verificationResult': verificationResult,
        }, SetOptions(merge: true));

        // Close loading dialog
        Navigator.pop(context);
        setState(() {
          _isSubmitting = false;
        });

        // Show results or complete
        if (isPassing) {
          _updateProgressAndComplete();
        } else {
          _showAIFeedback(verificationResult);
        }

        return; // AI verification complete, exit function

      } catch (e) {
        // AI verification failed, fall back to keyword matching
        print('AI verification failed, falling back to keyword matching: $e');
        // Continue to fallback verification
      }

      // 3. Fallback to basic keyword matching
      print('Using fallback keyword verification');
      final String normalizedText = submittedText.toLowerCase();
      List<String> foundKeywords = [];
      List<String> missingKeywords = [];

      for (final keyword in requiredKeywords) {
        if (normalizedText.contains(keyword.toLowerCase())) {
          foundKeywords.add(keyword);
        } else {
          missingKeywords.add(keyword);
        }
      }

      // Calculate match percentage
      final double matchPercentage = requiredKeywords.isEmpty ?
      100.0 : (foundKeywords.length / requiredKeywords.length) * 100.0;

      // Check if enough keywords were found to pass (only 50% needed for fallback)
      final bool isCorrect = matchPercentage >= 50.0; // ONLY NEED 50% for fallback verification

      // Create fallback verification result
      Map<String, dynamic> fallbackResult = {
        'isCorrect': isCorrect,
        'totalScore': matchPercentage,
        'maxScore': 100.0,
        'passingThreshold': 50.0, // Lower threshold for fallback
        'verificationMethod': 'keyword-fallback',
        'foundKeywords': foundKeywords,
        'missingKeywords': missingKeywords,
        'feedback': isCorrect ?
        'Your answer includes sufficient required concepts.' :
        'Your answer is missing too many required concepts.'
      };

      // Save fallback results to Firestore
      await _firestore
          .collection('user_answers')
          .doc(user.uid)
          .collection('projects')
          .doc(widget.projectId)
          .collection('levels')
          .doc(widget.levelName)
          .set({
        'text': submittedText,
        'fileUrl': fileUrl,
        'submittedAt': FieldValue.serverTimestamp(),
        'isCorrect': isCorrect,
        'totalScore': matchPercentage,
        'verificationMethod': 'keyword-fallback',
        'verificationResult': fallbackResult,
      }, SetOptions(merge: true));

      // Close loading dialog
      Navigator.pop(context);
      setState(() {
        _isSubmitting = false;
      });

      if (isCorrect) {
        _updateProgressAndComplete();
      } else {
        _showKeywordFeedback(fallbackResult);
      }

    } catch (e) {
      print('Error during verification: $e');
      // Close loading dialog if open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error verifying submission: ${e.toString()}'),
          backgroundColor: Colors.red[700],
        ),
      );
    }
  }

  // Show feedback from AI verification
  void _showAIFeedback(Map<String, dynamic> result) {
    final double score = result['totalScore'] ?? 0.0;
    final String feedback = result['feedback'] ?? '';
    final String keywordsFeedback = result['keywordsFeedback'] ?? '';
    final double passingThreshold = result['passingThreshold'] ?? 70.0;
    final List<String> conceptsCovered = List<String>.from(result['conceptsCovered'] ?? []);
    final List<String> missingConcepts = List<String>.from(result['missingConcepts'] ?? []);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titlePadding: EdgeInsets.all(16),
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Icon(
              Icons.psychology,
              color: score >= passingThreshold ? Colors.green : Colors.orange,
              size: 28,
            ),
            SizedBox(width: 12),
            Text(
              'AI Assessment',
              style: TextStyle(
                color: darkBlue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Score display
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _getScoreColor(score).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _getScoreColor(score)),
                ),
                child: Column(
                  children: [
                    Text(
                      'Score: ${score.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _getScoreColor(score),
                      ),
                    ),
                    SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: score / 100,
                      backgroundColor: Colors.grey[200],
                      color: _getScoreColor(score),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Passing threshold: ${passingThreshold.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20),

              // Concepts covered
              if (conceptsCovered.isNotEmpty) ...[
                Text(
                  'Concepts Covered:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: darkBlue,
                  ),
                ),
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: conceptsCovered.map((concept) => Chip(
                    label: Text(concept, style: TextStyle(fontSize: 12, color: Colors.white)),
                    backgroundColor: Colors.green[600],
                    avatar: Icon(Icons.check_circle, size: 16, color: Colors.white),
                    padding: EdgeInsets.symmetric(horizontal: 4),
                  )).toList(),
                ),
                SizedBox(height: 16),
              ],

              // Missing concepts
              if (missingConcepts.isNotEmpty) ...[
                Text(
                  'Missing Concepts:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: darkBlue,
                  ),
                ),
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: missingConcepts.map((concept) => Chip(
                    label: Text(concept, style: TextStyle(fontSize: 12, color: Colors.white)),
                    backgroundColor: Colors.red[600],
                    avatar: Icon(Icons.cancel, size: 16, color: Colors.white),
                    padding: EdgeInsets.symmetric(horizontal: 4),
                  )).toList(),
                ),
                SizedBox(height: 16),
              ],

              // AI Feedback
              Text(
                'Feedback:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: darkBlue,
                ),
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: veryLightBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  feedback,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),

              if (keywordsFeedback.isNotEmpty) ...[
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Keyword Analysis:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        keywordsFeedback,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              SizedBox(height: 20),

              // Suggestions
              if (score < passingThreshold)
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: lightBlue.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: lightBlue.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lightbulb_outline, color: primaryBlue, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'How to improve:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: darkBlue,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Make sure your answer addresses all the required concepts for this level. Be specific and thorough in your explanation.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: darkBlue.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: primaryBlue,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Fallback keyword feedback UI
  void _showKeywordFeedback(Map<String, dynamic> result) {
    final double matchPercentage = result['totalScore'] ?? 0.0;
    final List<String> foundKeywords = List<String>.from(result['foundKeywords'] ?? []);
    final List<String> missingKeywords = List<String>.from(result['missingKeywords'] ?? []);

    showDialog(
        context: context,
        builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.white,
        titlePadding: EdgeInsets.all(16),
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        title: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: matchPercentage >= 50.0 ? Colors.green[600] : Colors.orange,
              size: 28,
            ),
            SizedBox(width: 12),
            Text(
              'Keyword Assessment',
              style: TextStyle(
                color: darkBlue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
    Container(
    padding: EdgeInsets.all(12),
    decoration: BoxDecoration(
    color: matchPercentage >= 50.0 ? Colors.green[50] : Colors.orange[50],
    borderRadius: BorderRadius.circular(8),
    border: Border.all(
    color: matchPercentage >= 50.0 ? Colors.green[300]! : Colors.orange[300]!,
    ),
    ),
    child: Text(
    matchPercentage >= 50.0 ?
    'Your answer includes sufficient required concepts.' :
    'Your answer is missing too many required concepts.',
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: matchPercentage >= 50.0 ? Colors.green[700] : Colors.orange[800],
      ),
    ),
    ),

          SizedBox(height: 20),

          // Score display
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getScoreColor(matchPercentage).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _getScoreColor(matchPercentage)),
            ),
            child: Column(
              children: [
                Text(
                  'Match: ${matchPercentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _getScoreColor(matchPercentage),
                  ),
                ),
                SizedBox(height: 12),
                LinearProgressIndicator(
                  value: matchPercentage / 100,
                  backgroundColor: Colors.grey[200],
                  color: _getScoreColor(matchPercentage),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                SizedBox(height: 12),
                Text(
                  'Passing threshold: 50.0%',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 20),

          // Found concepts
          if (foundKeywords.isNotEmpty) ...[
            Text(
              'Included concepts:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: darkBlue,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: foundKeywords.map((keyword) => Chip(
                label: Text(keyword, style: TextStyle(fontSize: 12, color: Colors.white)),
                backgroundColor: Colors.green[600],
                avatar: Icon(Icons.check_circle, size: 16, color: Colors.white),
                padding: EdgeInsets.symmetric(horizontal: 4),
              )).toList(),
            ),
            SizedBox(height: 20),
          ],

          // Missing concepts
          if (missingKeywords.isNotEmpty) ...[
            Text(
              'Missing concepts:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: darkBlue,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: missingKeywords.map((keyword) => Chip(
                label: Text(keyword, style: TextStyle(fontSize: 12, color: Colors.white)),
                backgroundColor: Colors.red[600],
                avatar: Icon(Icons.cancel, size: 16, color: Colors.white),
                padding: EdgeInsets.symmetric(horizontal: 4),
              )).toList(),
            ),

            // Improvement tips
            SizedBox(height: 20),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: lightBlue.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: lightBlue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: primaryBlue, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'How to improve:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: darkBlue,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Make sure to include all the required concepts in your answer. Try elaborating on: ${missingKeywords.join(", ")}',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: darkBlue.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
        ),
        ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: primaryBlue,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
    );
  }

  // Code submission verification
  Future<void> _verifySubmission(String submittedCode, String submittedOutput, String? fileUrl) async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() {
      _isSubmitting = true;
    });

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: veryLightBlue,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
            ),
            SizedBox(height: 20),
            Text(
              'Analyzing your submission...',
              style: TextStyle(
                color: darkBlue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );

    try {
      // 1. Get verification criteria from cache or Firestore
      final cacheKey = "${widget.projectId}_${widget.levelName}";
      Map<String, dynamic> data = {};

      if (_criteriaCache.containsKey(cacheKey)) {
        data = _criteriaCache[cacheKey] ?? {};
      } else {
        final doc = await _firestore
            .collection('answers')
            .doc(widget.projectId)
            .collection('levels')
            .doc(widget.levelName)
            .get();

        if (!doc.exists) {
          Navigator.pop(context); // Close loading dialog
          setState(() {
            _isSubmitting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Verification criteria not found'),
              backgroundColor: Colors.red[700],
            ),
          );
          return;
        }

        data = doc.data() ?? {};
        _criteriaCache[cacheKey] = data; // Cache for future use
      }

      // Check if we should use the AI verification
      final bool useAIVerification = data.containsKey('useAIVerification') ?
      data['useAIVerification'] : false;

      if (useAIVerification) {
        // AI-based code verification
        try {
          // Get API key with load balancing
          final String apiKey = _getApiKey();
          final String apiUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro:generateContent?key=$apiKey';

          // Get project context from cache if available
          final cacheProjectKey = widget.projectId;
          Map<String, dynamic>? projectData;

          // When getting project data, use this approach:
          if (_criteriaCache.containsKey(cacheProjectKey + "_project")) {
            projectData = _criteriaCache[cacheProjectKey + "_project"] ?? {};
          } else {
            final projectDoc = await _firestore.collection('projects').doc(widget.projectId).get();
            projectData = projectDoc.data() ?? {};
            _criteriaCache[cacheProjectKey + "_project"] = projectData; // Cache project data
          }

          final projectTitle = projectData?['title'] ?? 'Project';
          final projectDescription = projectData?['description'] ?? '';

          // Extract criteria from Firestore
          final expectedOutput = data['expectedOutput']?.toString() ?? '';
          final List<String> expectedOutputs = List<String>.from(data['expectedOutputs'] ?? []);
          final List<String> requiredKeywords = List<String>.from(data['expectedKeywords'] ?? []);
          final double passingScore = data['passingScore'] ?? 70.0;

          // Build improved AI evaluation prompt
          String prompt = '''
I need to evaluate a student's code submission for a programming assignment.

Project: ${projectTitle}
Level: ${widget.levelName}
Description: ${widget.levelDescription}

EXPECTED OUTPUT METRICS:
${expectedOutput}

ALTERNATIVE EXPECTED OUTPUTS (if any):
${expectedOutputs.join('\n')}

REQUIRED KEYWORDS/CONCEPTS IN CODE:
${requiredKeywords.join(', ')}

STUDENT'S CODE:
${submittedCode}

STUDENT'S OUTPUT:
${submittedOutput}

IMPORTANT: When evaluating the output, focus ONLY on performance metrics (numbers and percentages). 
Ignore formatting differences such as spaces, punctuation, capitalization, and exact wording.
For example, "Accuracy: 95%" and "accuracy:95%" should be considered the same.

Please evaluate this submission on a scale of 0-100 based on:
1. Code Structure (40%): Does it contain the required keywords/patterns?
2. Output Correctness (60%): Do the performance metrics in the output match the expected metrics?

Provide your evaluation in the following JSON format:
{
  "score": 85.5,
  "isCorrect": true/false,
  "feedback": "Brief explanation of score",
  "codeQuality": {
    "score": 35.0,
    "feedback": "Code structure feedback"
  },
  "outputQuality": {
    "score": 50.5,
    "feedback": "Output evaluation feedback"
  },
  "metricsFound": ["95%", "99%"],
  "metricsExpected": ["95%", "99%"],
  "conceptsCovered": ["cnn model", "training"]
}

A score of ${passingScore}% or higher should be considered passing (isCorrect: true).
Focus on the performance metrics rather than exact string matching for the output.
''';

          // Make API request with retry mechanism
          http.Response? response;
          int retries = 0;
          const maxRetries = 3;

          while (retries < maxRetries) {
            try {
              response = await http.post(
                Uri.parse(apiUrl),
                headers: {
                  'Content-Type': 'application/json',
                },
                body: jsonEncode({
                  'contents': [{
                    'parts': [{
                      'text': prompt
                    }]
                  }],
                  'generationConfig': {
                    'temperature': 0.1, // Lower temperature for more consistent evaluation
                    'topK': 1,
                    'topP': 0.8,
                    'maxOutputTokens': 8192,
                  }
                }),
              );

              if (response.statusCode == 200) {
                break; // Success, exit retry loop
              }

              // If we get rate limited (429) or server error (5xx), retry
              if (response.statusCode == 429 || response.statusCode >= 500) {
                retries++;
                // Exponential backoff: wait longer with each retry
                await Future.delayed(Duration(milliseconds: 200 * math.pow(2, retries).toInt()));

                // Rotate to next API key if available
                _currentApiKeyIndex = (_currentApiKeyIndex + 1) % _apiKeys.length;
                continue;
              }

              // For other error codes, don't retry
              throw Exception('Gemini API error: ${response.body}');

            } catch (e) {
              retries++;
              if (retries >= maxRetries) throw e;
              await Future.delayed(Duration(milliseconds: 200 * math.pow(2, retries).toInt()));
            }
          }

          if (response == null || response.statusCode != 200) {
            throw Exception('Failed to get valid response after $maxRetries retries');
          }

          // Parse AI response
          final jsonResponse = jsonDecode(response.body);
          final String responseText = jsonResponse['candidates'][0]['content']['parts'][0]['text'];

          // Extract JSON from response
          final RegExp jsonPattern = RegExp(r'\{[\s\S]*\}');
          final Match? match = jsonPattern.firstMatch(responseText);

          if (match == null) {
            throw Exception('Could not extract JSON from Gemini response');
          }

          final String jsonString = match.group(0) ?? '{}';
          Map<String, dynamic> aiResult = jsonDecode(jsonString);

          // Extract AI judgment
          final double score = aiResult['score'] is int ?
          aiResult['score'].toDouble() : (aiResult['score'] ?? 0.0);

          final bool isPassing = score >= passingScore;

          // Create verification result structure
          Map<String, dynamic> verificationResult = {
            'isCorrect': isPassing,
            'totalScore': score,
            'maxScore': 100.0,
            'passingThreshold': passingScore,
            'verificationMethod': 'ai',
            'metricsFound': aiResult['metricsFound'] ?? [],
            'metricsExpected': aiResult['metricsExpected'] ?? [],
            'conceptsCovered': aiResult['conceptsCovered'] ?? [],
            'feedback': aiResult['feedback'] ?? '',
            'codeQuality': aiResult['codeQuality'] ?? {},
            'outputQuality': aiResult['outputQuality'] ?? {},
          };

          // For debugging - print to console what metrics were found
          print('AI found metrics: ${verificationResult['metricsFound']}');
          print('AI expected metrics: ${verificationResult['metricsExpected']}');

          // Save results to Firestore
          await _firestore
              .collection('user_answers')
              .doc(user.uid)
              .collection('projects')
              .doc(widget.projectId)
              .collection('levels')
              .doc(widget.levelName)
              .set({
            'code': submittedCode,
            'output': submittedOutput,
            'fileUrl': fileUrl,
            'submittedAt': FieldValue.serverTimestamp(),
            'isCorrect': isPassing,
            'totalScore': score,
            'verificationMethod': 'ai',
            'verificationResult': verificationResult,
          }, SetOptions(merge: true));

          // Close loading dialog
          Navigator.pop(context);
          setState(() {
            _isSubmitting = false;
          });

          // Show results or complete
          if (isPassing) {
            _updateProgressAndComplete();
          } else {
            _showCodeAIFeedback(verificationResult);
          }

          return; // AI verification complete, exit function
        } catch (e) {
          // AI verification failed, fall back to improved basic verification
          print('AI code verification failed, falling back to basic: $e');
        }
      }

      // Improved basic code verification (fallback)
      final expectedOutput = data['expectedOutput']?.toString().trim();
      final List<String> expectedOutputs = List<String>.from(data['expectedOutputs'] ?? []);
      final List<String> requiredKeywords = List<String>.from(data['expectedKeywords'] ?? []);

      // Normalize the expected and submitted outputs to extract metrics
      final normalizedSubmittedOutput = _normalizeText(submittedOutput);
      print('Normalized submitted output: $normalizedSubmittedOutput');

      String normalizedExpectedOutput = '';
      if (expectedOutput != null && expectedOutput.isNotEmpty) {
        normalizedExpectedOutput = _normalizeText(expectedOutput);
        print('Normalized expected output: $normalizedExpectedOutput');
      }

      List<String> normalizedExpectedOutputs = [];
      if (expectedOutputs.isNotEmpty) {
        normalizedExpectedOutputs = expectedOutputs.map((output) => _normalizeText(output)).toList();
        print('Normalized expected outputs: $normalizedExpectedOutputs');
      }

      // Check code keywords
      bool isCodeValid = requiredKeywords.isEmpty ||
          requiredKeywords.every((keyword) => submittedCode.toLowerCase().contains(keyword.toLowerCase()));

      // Check output metrics with improved logic
      bool isOutputCorrect = false;

      // If we have multiple expected outputs, check if any match
      if (normalizedExpectedOutputs.isNotEmpty) {
        isOutputCorrect = normalizedExpectedOutputs.any((output) {
          // Check if metrics are similar - they don't need to be exact matches
          return _compareMetrics(normalizedSubmittedOutput, output);
        });
      }
      // Otherwise check against the single expected output
      else if (normalizedExpectedOutput.isNotEmpty) {
        isOutputCorrect = _compareMetrics(normalizedSubmittedOutput, normalizedExpectedOutput);
      }

      // Calculate scores
      double keywordScore = 0.0;
      List<String> foundKeywords = [];
      List<String> missingKeywords = [];

      if (requiredKeywords.isNotEmpty) {
        for (final keyword in requiredKeywords) {
          if (submittedCode.toLowerCase().contains(keyword.toLowerCase())) {
            foundKeywords.add(keyword);
          } else {
            missingKeywords.add(keyword);
          }
        }
        keywordScore = (foundKeywords.length / requiredKeywords.length) * 40.0;
      } else {
        keywordScore = 40.0; // Full score if no keywords required
      }

      double outputScore = isOutputCorrect ? 60.0 : 0.0;

      // Give partial credit for close matches
      if (!isOutputCorrect && normalizedSubmittedOutput.isNotEmpty) {
        // If they have some metrics but not exact match
        if (normalizedSubmittedOutput.contains('%')) {
          outputScore = 30.0; // Half credit
        }
      }

      final totalScore = keywordScore + outputScore;

      // Use a 50% passing threshold in fallback mode
      final bool isCorrect = totalScore >= 50.0;

      // Create structured result with more detailed information
      Map<String, dynamic> verificationResult = {
        'isCorrect': isCorrect,
        'totalScore': totalScore,
        'maxScore': 100.0,
        'passingThreshold': 50.0, // 50% for fallback mode
        'verificationMethod': 'basic-improved',
        'components': {
          'codeStructure': {
            'score': keywordScore,
            'maxScore': 40.0,
            'isValid': isCodeValid,
            'foundKeywords': foundKeywords,
            'missingKeywords': missingKeywords,
          },
          'output': {
            'score': outputScore,
            'maxScore': 60.0,
            'isValid': isOutputCorrect,
            'submittedMetrics': normalizedSubmittedOutput,
            'expectedMetrics': normalizedExpectedOutput.isNotEmpty ?
            normalizedExpectedOutput :
            normalizedExpectedOutputs.join(' OR '),
          }
        },
        'feedback': {
          'codeStructure': isCodeValid
              ? ['Your code includes the required elements.']
              : ['Your code is missing some required elements.'],
          'output': isOutputCorrect
              ? ['Your output metrics match the expected values.']
              : ['Your output metrics don\'t match the expected values.'],
        }
      };

      // Save results to Firestore with batched writes for scalability
      final batch = _firestore.batch();

      // Reference to student answer document
      final userAnswerRef = _firestore
          .collection('user_answers')
          .doc(user.uid)
          .collection('projects')
          .doc(widget.projectId)
          .collection('levels')
          .doc(widget.levelName);

      // Write verification result
      batch.set(userAnswerRef, {
        'code': submittedCode,
        'output': submittedOutput,
        'fileUrl': fileUrl,
        'submittedAt': FieldValue.serverTimestamp(),
        'isCorrect': isCorrect,
        'totalScore': totalScore,
        'verificationMethod': 'basic-improved',
        'verificationResult': verificationResult,
      }, SetOptions(merge: true));

      // Commit the batch
      await batch.commit();

      // Close loading dialog
      Navigator.pop(context);
      setState(() {
        _isSubmitting = false;
      });

      if (isCorrect) {
        _updateProgressAndComplete();
      } else {
        _showCodeFeedback(verificationResult);
      }
    } catch (e) {
      print('Error during verification: $e');
      // Close loading dialog if open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error verifying submission: ${e.toString()}'),
          backgroundColor: Colors.red[700],
        ),
      );
    }
  }

  // Show feedback for code submissions with AI verification
  void _showCodeAIFeedback(Map<String, dynamic> result) {
    final double score = result['totalScore'] ?? 0.0;
    final String feedback = result['feedback'] ?? '';
    final double passingThreshold = result['passingThreshold'] ?? 70.0;
    final List<String> metricsFound = List<String>.from(result['metricsFound'] ?? []);
    final List<String> metricsExpected = List<String>.from(result['metricsExpected'] ?? []);
    final List<String> conceptsCovered = List<String>.from(result['conceptsCovered'] ?? []);

    // Get component scores
    final Map<String, dynamic> codeQuality = result['codeQuality'] ?? {};
    final Map<String, dynamic> outputQuality = result['outputQuality'] ?? {};

    showDialog(
        context: context,
        builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: Colors.white,
            titlePadding: EdgeInsets.all(16),
            contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            title: Row(
              children: [
                Icon(
                  Icons.code,
                  color: score >= passingThreshold ? Colors.green[600] : Colors.orange,
                  size: 28,
                ),
                SizedBox(width: 12),
                Text(
                  'AI Code Assessment',
                  style: TextStyle(
                    color: darkBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
              // Overall score display
              Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getScoreColor(score).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _getScoreColor(score)),
              ),
              child: Column(
                children: [
                  Text(
                    'Overall Score: ${score.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _getScoreColor(score),
                    ),
                  ),
                  SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: score / 100,
                    backgroundColor: Colors.grey[200],
                    color: _getScoreColor(score),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Passing threshold: ${passingThreshold.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),

            // Metrics comparison
            if (metricsFound.isNotEmpty || metricsExpected.isNotEmpty) ...[
    Container(
    padding: EdgeInsets.all(16),
    decoration: BoxDecoration(
    color: veryLightBlue,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: lightBlue.withOpacity(0.5)),
    ),
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Text(
    'Metrics Comparison:',
    style: TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 16,
    color: darkBlue,
    ),
    ),
    SizedBox(height: 12),
    Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Expanded(
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Text(
    'Found:',
    style: TextStyle(
    fontWeight: FontWeight.w600,
    color: darkBlue,
    ),
    ),
    SizedBox(height: 6),
    ...metricsFound.map((metric) => Padding(
    padding: EdgeInsets.only(bottom: 4),
    child: Row(
    children: [
    Icon(
    metricsExpected.contains(metric) ? Icons.check_circle : Icons.error,
    size: 16,
    color: metricsExpected.contains(metric) ? Colors.green[600] : Colors.red[600],
    ),
    SizedBox(width: 8),
    Text(
    metric,
    style: TextStyle(
    color: metricsExpected.contains(metric) ? Colors.green[700] : Colors.red[700],
    fontWeight: FontWeight.w500,
    ),
    ),
    ],
    ),
    )).toList(),
    if (metricsFound.isEmpty)
    Text(
    'None',
    style: TextStyle(
    color: Colors.red[700],
    fontStyle: FontStyle.italic,
    ),
    ),
    ],
    ),
    ),
    SizedBox(width: 20),
    Expanded(
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Text(
    'Expected:',
    style: TextStyle(
    fontWeight: FontWeight.w600,
    color: darkBlue,
    ),
    ),
    SizedBox(height: 6),
    ...metricsExpected.map((metric) => Padding(
    padding: EdgeInsets.only(bottom: 4),
    child: Row(
    children: [
    Icon(
    metricsFound.contains(metric) ? Icons.check_circle : Icons.error,
    size: 16,
    color: metricsFound.contains(metric) ? Colors.green[600] : Colors.orange,
    ),
    SizedBox(width: 8),
    Text(
    metric,
    style: TextStyle(
    color: metricsFound.contains(metric) ? Colors.green[700] : Colors.orange[800],
    fontWeight: FontWeight.w500,
    ),
    ),
    ],
    ),
    )).toList(),
    if (metricsExpected.isEmpty)
    Text(
    'None specified',
    style: TextStyle(
    color: Colors.grey[700],
    fontStyle: FontStyle.italic,
    ),
    ),
    ],
    ),
    ),
    ],
    ),
    ],
    ),
    ),
    SizedBox(height: 20),
    ],

    // Concepts covered
    if (conceptsCovered.isNotEmpty) ...[
    Text(
    'Concepts in Code:',
    style: TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 16,
    color: darkBlue,
    ),
    ),
    SizedBox(height: 8),
    Wrap(
    spacing: 8,
    runSpacing: 8,
    children: conceptsCovered.map((concept) => Chip(
    label: Text(concept, style: TextStyle(fontSize: 12, color: Colors.white)),
    backgroundColor: Colors.green[600],
    avatar: Icon(Icons.check_circle, size: 16, color: Colors.white),
    padding: EdgeInsets.symmetric(horizontal: 4),
    )).toList(),
    ),
    SizedBox(height: 20),
    ],

    // Component scores
    Container(
    padding: EdgeInsets.all(16),
    decoration: BoxDecoration(
    color: veryLightBlue,
    borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    // Code Quality
    if (codeQuality.isNotEmpty) ...[
    Row(
    children: [
    Icon(Icons.code, size: 20, color: primaryBlue),
    SizedBox(width: 8),
    Text(
    'Code Structure:',
    style: TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 15,
    color: darkBlue,
    ),
    ),
    Spacer(),
    Container(
    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
    color: _getComponentScoreColor(codeQuality['score'] ?? 0),
    borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
    '${(codeQuality['score'] ?? 0).toStringAsFixed(1)}/40',
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
    ),
    ),
    ],
    ),
      SizedBox(height: 8),
      Text(
        codeQuality['feedback'] ?? 'No specific feedback available.',
        style: TextStyle(
          fontSize: 13,
          height: 1.5,
          color: Colors.grey[800],
        ),
      ),
      SizedBox(height: 16),
    ],

      // Output Quality
      if (outputQuality.isNotEmpty) ...[
        Row(
          children: [
            Icon(Icons.analytics, size: 20, color: primaryBlue),
            SizedBox(width: 8),
            Text(
              'Output Quality:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: darkBlue,
              ),
            ),
            Spacer(),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getComponentScoreColor(outputQuality['score'] ?? 0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${(outputQuality['score'] ?? 0).toStringAsFixed(1)}/60',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Text(
          outputQuality['feedback'] ?? 'No specific feedback available.',
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
            color: Colors.grey[800],
          ),
        ),
      ],
    ],
    ),
    ),

                    SizedBox(height: 20),

                    // Overall feedback
                    Text(
                      'Overall Feedback:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: darkBlue,
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: veryLightBlue,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: lightBlue.withOpacity(0.5)),
                      ),
                      child: Text(
                        feedback,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: darkBlue.withOpacity(0.8),
                        ),
                      ),
                    ),

                    SizedBox(height: 20),

                    // Suggestions
                    if (score < passingThreshold)
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: lightBlue.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: lightBlue.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.lightbulb_outline, color: primaryBlue, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'How to improve:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: darkBlue,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Make sure your code produces the expected output metrics and includes all required concepts. Check your implementation and ensure the results match what\'s expected.',
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: darkBlue.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
              ),
            ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: primaryBlue,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
    );
  }

  // Show feedback for code submissions with basic verification
  void _showCodeFeedback(Map<String, dynamic> result) {
    final totalScore = result['totalScore'] ?? 0.0;
    final maxScore = result['maxScore'] ?? 100.0;
    final double percentScore = maxScore > 0 ? (totalScore / maxScore * 100) : 0.0;
    final passingThreshold = result['passingThreshold'] ?? 50.0;

    final Map<String, dynamic> components = result['components'] ?? {};
    final Map<String, dynamic> feedback = result['feedback'] ?? {};

    // Get feedback items and keywords
    final List<String> codeFeedback = List<String>.from(feedback['codeStructure'] ?? []);
    final List<String> outputFeedback = List<String>.from(feedback['output'] ?? []);

    final List<String> foundKeywords = components['codeStructure']?['foundKeywords'] ?? [];
    final List<String> missingKeywords = components['codeStructure']?['missingKeywords'] ?? [];

    // Metrics
    final String submittedMetrics = components['output']?['submittedMetrics'] ?? '';
    final String expectedMetrics = components['output']?['expectedMetrics'] ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.white,
        titlePadding: EdgeInsets.all(16),
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        title: Row(
          children: [
            Icon(
              Icons.code,
              color: totalScore >= passingThreshold ? Colors.green[600] : Colors.orange,
              size: 28,
            ),
            SizedBox(width: 12),
            Text(
              'Code Assessment',
              style: TextStyle(
                color: darkBlue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Overall score indicator
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _getScoreColor(percentScore).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _getScoreColor(percentScore)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Score: ',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: darkBlue,
                          ),
                        ),
                        Text(
                          '${totalScore.toStringAsFixed(1)} / ${maxScore.toStringAsFixed(1)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _getScoreColor(percentScore),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: percentScore / 100,
                      backgroundColor: Colors.grey[200],
                      color: _getScoreColor(percentScore),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Passing threshold: ${passingThreshold.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20),

              // Code structure assessment
              if (components.containsKey('codeStructure'))
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: veryLightBlue,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: lightBlue.withOpacity(0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.code, size: 20, color: primaryBlue),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Code Structure',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: darkBlue,
                              ),
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getComponentScoreColor(components['codeStructure']['score']),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${components['codeStructure']['score'].toStringAsFixed(1)} / ${components['codeStructure']['maxScore'].toStringAsFixed(1)}',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),

                      // Found keywords
                      if (foundKeywords.isNotEmpty) ...[
                        Text(
                          'Found concepts:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: darkBlue,
                          ),
                        ),
                        SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: foundKeywords.map((keyword) => Chip(
                            avatar: Icon(Icons.check_circle, size: 16, color: Colors.white),
                            label: Text(keyword, style: TextStyle(fontSize: 12, color: Colors.white)),
                            backgroundColor: Colors.green[600],
                            padding: EdgeInsets.symmetric(horizontal: 4),
                          )).toList(),
                        ),
                        SizedBox(height: 12),
                      ],

                      // Missing keywords
                      if (missingKeywords.isNotEmpty) ...[
                        Text(
                          'Missing concepts:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: darkBlue,
                          ),
                        ),
                        SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: missingKeywords.map((keyword) => Chip(
                            avatar: Icon(Icons.cancel, size: 16, color: Colors.white),
                            label: Text(keyword, style: TextStyle(fontSize: 12, color: Colors.white)),
                            backgroundColor: Colors.red[600],
                            padding: EdgeInsets.symmetric(horizontal: 4),
                          )).toList(),
                        ),
                        SizedBox(height: 12),
                      ],

                      // Feedback text
                      if (codeFeedback.isNotEmpty) ...[
                        ...codeFeedback.map((item) => Padding(
                          padding: EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: darkBlue.withOpacity(0.7),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                    color: darkBlue.withOpacity(0.8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )).toList(),
                      ],
                    ],
                  ),
                ),

              SizedBox(height: 16),

              // Output assessment
              if (components.containsKey('output'))
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: veryLightBlue,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: lightBlue.withOpacity(0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.analytics, size: 20, color: primaryBlue),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Output Assessment',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: darkBlue,
                              ),
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getComponentScoreColor(components['output']['score']),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${components['output']['score'].toStringAsFixed(1)} / ${components['output']['maxScore'].toStringAsFixed(1)}',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),

                      // Metrics comparison
                      if (submittedMetrics.isNotEmpty || expectedMetrics.isNotEmpty) ...[
                        Text(
                          'Metrics Comparison:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: darkBlue,
                          ),
                        ),
                        SizedBox(height: 8),
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Your metrics: ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: darkBlue,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      submittedMetrics.isEmpty ? 'None found' : submittedMetrics,
                                      style: TextStyle(
                                        color: submittedMetrics.isEmpty ? Colors.red[700] : darkBlue.withOpacity(0.8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Expected: ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: darkBlue,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      expectedMetrics.isEmpty ? 'None specified' : expectedMetrics,
                                      style: TextStyle(
                                        color: darkBlue.withOpacity(0.8),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 12),
                      ],

                      // Output feedback
                      if (outputFeedback.isNotEmpty) ...[
                        ...outputFeedback.map((item) => Padding(
                          padding: EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                components['output']['isValid'] ? Icons.check_circle : Icons.error_outline,
                                size: 16,
                                color: components['output']['isValid'] ? Colors.green[600] : Colors.red[600],
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                    color: darkBlue.withOpacity(0.8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )).toList(),
                      ],
                    ],
                  ),
                ),

              // Suggestions for improvement
              if (totalScore < passingThreshold) ...[
                SizedBox(height: 20),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: lightBlue.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: lightBlue.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lightbulb_outline, color: primaryBlue, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'How to improve:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: darkBlue,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      if (missingKeywords.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Make sure your code includes: ${missingKeywords.join(", ")}',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: darkBlue.withOpacity(0.8),
                            ),
                          ),
                        ),
                      if (!components['output']['isValid'])
                        Text(
                          'Ensure your output includes the metrics: $expectedMetrics',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: darkBlue.withOpacity(0.8),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: primaryBlue,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _submitAnswer() async {
    if (_isSubmitting) {
      // Prevent multiple submissions
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please log in to submit your answer'),
          backgroundColor: Colors.red[700],
        ),
      );
      return;
    }

    if (_submissionType == 'code') {
      final submittedCode = _codeController.text.trim();
      final submittedOutput = _outputController.text.trim();

      if (submittedCode.isEmpty || submittedOutput.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please enter both code and output'),
            backgroundColor: Colors.red[700],
          ),
        );
        return;
      }

      // Upload file if provided
      String? fileUrl;
      if (_file != null) {
        try {
          final ref = _storage.ref().child('user_files/${user.uid}/${widget.projectId}/${widget.levelName}');
          await ref.putFile(_file!);
          fileUrl = await ref.getDownloadURL();
        } catch (e) {
          print('Error uploading file: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error uploading file, but continuing with submission'),
              backgroundColor: Colors.orange[700],
            ),
          );
        }
      }

      // Verify code submission
      _verifySubmission(submittedCode, submittedOutput, fileUrl);
    } else {
      // Text submission
      final submittedText = _textController.text.trim();
      if (submittedText.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please enter your answer'),
            backgroundColor: Colors.red[700],
          ),
        );
        return;
      }

      // Upload file if provided
      String? fileUrl;
      if (_file != null) {
        try {
          final ref = _storage.ref().child('user_files/${user.uid}/${widget.projectId}/${widget.levelName}');
          await ref.putFile(_file!);
          fileUrl = await ref.getDownloadURL();
        } catch (e) {
          print('Error uploading file: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error uploading file, but continuing with submission'),
              backgroundColor: Colors.orange[700],
            ),
          );
        }
      }

      // Use the AI-first text verification
      _verifyTextSubmission(submittedText, fileUrl);
    }
  }

  Future<void> _updateProgressAndComplete() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Parse the level number from the name (e.g., "Level 1" -> 1)
    int currentLevelIndex = 1; // Default to 1 if parsing fails
    try {
      final levelNameParts = widget.levelName.split(' ');
      if (levelNameParts.length > 1) {
        currentLevelIndex = int.parse(levelNameParts.last);
      }
    } catch (e) {
      print('Error parsing level number: $e');
    }

    final newProgress = currentLevelIndex / widget.totalLevels;

    try {
      // Use batched writes for better performance
      final batch = _firestore.batch();

      // Update project progress
      final projectRef = _firestore
          .collection('user_answers')
          .doc(user.uid)
          .collection('projects')
          .doc(widget.projectId);

      batch.set(projectRef, {
        'progress': newProgress > 1.0 ? 1.0 : newProgress,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Commit the batch
      await batch.commit();

      setState(() {
        _levelCompleted = true;
      });

      _confettiController.play();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Text('Correct! Level completed.'),
            ],
          ),
          backgroundColor: Colors.green[700],
          duration: Duration(seconds: 3),
        ),
      );

      // Show completion dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.white,
          title: Row(
            children: [
              Icon(Icons.emoji_events, color: Colors.amber, size: 28),
              SizedBox(width: 10),
              Text(
                'Level Completed!',
                style: TextStyle(
                  color: darkBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 200,
                height: 150,
                alignment: Alignment.center,
                child: Stack(
                  children: [
                    Center(
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: veryLightBlue,
                          border: Border.all(color: primaryBlue, width: 3),
                        ),
                        child: Icon(Icons.check, color: primaryBlue, size: 60),
                      ),
                    ),
                    ConfettiWidget(
                      confettiController: _confettiController,
                      blastDirectionality: BlastDirectionality.explosive,
                      shouldLoop: false,
                      colors: const [primaryBlue, lightBlue, accentBlue, Colors.green, Colors.purple],
                      emissionFrequency: 0.05,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Congratulations!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: darkBlue,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 10),
              Text(
                'You\'ve successfully completed this level.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[800],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: veryLightBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primaryBlue,
                      ),
                      child: Text(
                        '$currentLevelIndex',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentLevelIndex < widget.totalLevels ? 'Next up:' : 'All levels completed!',
                            style: TextStyle(
                              color: darkBlue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            currentLevelIndex < widget.totalLevels
                                ? 'Continue to Level ${currentLevelIndex + 1}'
                                : 'You\'ve completed all levels for this project!',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Return to projects page
              },
              style: TextButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: Text('Continue', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } catch (e) {
      print('Error updating progress: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Level completed, but error updating progress.'),
          backgroundColor: Colors.orange[700],
        ),
      );
    }
  }

  Widget _buildSubmissionForm() {
    if (_levelCompleted) {
      return Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green[400]!),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
        Row(
        children: [
        Icon(Icons.check_circle, color: Colors.green[600], size: 30),
        SizedBox(width: 12),
        Text(
          'Level Completed!',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.green[700],
          ),
        ),
        ],
      ),
    SizedBox(height: 16),
    Text(
    'You\'ve already completed this level successfully.',
    style: TextStyle(
    fontSize: 15,
    color: Colors.grey[800],
    ),
    ),
    SizedBox(height: 20),
    ElevatedButton.icon(
    onPressed: () => Navigator.pop(context),
    icon: Icon(Icons.arrow_back),
    label: Text('Return to Project'),
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
            ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_turned_in, color: primaryBlue, size: 24),
              SizedBox(width: 10),
              Text(
                'Submission Form',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: darkBlue,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          if (_submissionType == 'code') ...[
            _buildLabelWithTooltip(
              'Paste your code below:',
              'Include all implementation details that satisfy the requirements.',
            ),
            SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: TextField(
                controller: _codeController,
                decoration: InputDecoration(
                  labelText: 'Your Code',
                  labelStyle: TextStyle(color: primaryBlue),
                  floatingLabelBehavior: FloatingLabelBehavior.never,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  hintText: 'Paste your code here...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  contentPadding: EdgeInsets.all(16),
                ),
                maxLines: 10,
                keyboardType: TextInputType.multiline,
                style: TextStyle(
                  fontFamily: 'Courier New',
                  fontSize: 14,
                ),
              ),
            ),
            SizedBox(height: 16),
            _buildLabelWithTooltip(
              'Enter the output your code produces:',
              'Include accuracy, metrics, or other results generated by your code.',
            ),
            SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: TextField(
                controller: _outputController,
                decoration: InputDecoration(
                  labelText: 'Your Output',
                  labelStyle: TextStyle(color: primaryBlue),
                  floatingLabelBehavior: FloatingLabelBehavior.never,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  hintText: 'Paste the output here...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  contentPadding: EdgeInsets.all(16),
                ),
                maxLines: 4,
                style: TextStyle(
                  fontFamily: 'Courier New',
                  fontSize: 14,
                ),
              ),
            ),
          ] else ...[
            _buildLabelWithTooltip(
              'Enter your answer below:',
              'Provide a comprehensive explanation covering all required concepts.',
            ),
            SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: TextField(
                controller: _textController,
                decoration: InputDecoration(
                  labelText: 'Your Answer',
                  labelStyle: TextStyle(color: primaryBlue),
                  floatingLabelBehavior: FloatingLabelBehavior.never,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  hintText: 'Type your answer here...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  contentPadding: EdgeInsets.all(16),
                ),
                maxLines: 6,
                keyboardType: TextInputType.multiline,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ),
          ],
          SizedBox(height: 20),

          // File upload section
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: veryLightBlue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Attachments (Optional)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: darkBlue,
                  ),
                ),
                SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _pickFile,
                  icon: Icon(Icons.attach_file),
                  label: Text('Upload File'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: lightBlue,
                    foregroundColor: darkBlue,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    elevation: 0,
                  ),
                ),
                if (_file != null)
                  Container(
                    margin: EdgeInsets.only(top: 12),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: lightBlue),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green[600], size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'File selected: ${_file!.path.split('/').last}',
                            style: TextStyle(fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, size: 18, color: Colors.grey[600]),
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                          onPressed: _isSubmitting
                              ? null
                              : () {
                            setState(() {
                              _file = null;
                            });
                          },
                        )
                      ],
                    ),
                  ),
                SizedBox(height: 8),
                Text(
                  'Supported formats: .dart, .py, .txt, .jpg, .png, .csv',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 24),

          // Submit button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitAnswer,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                disabledBackgroundColor: Colors.grey[400],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
              child: _isSubmitting
                  ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Submitting...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
                  : Text(
                'Submit Answer',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Tip box
          if (_submissionType == 'code') ...[
            SizedBox(height: 24),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: lightBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: lightBlue.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline, color: accentBlue, size: 22),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Submission Tip',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: darkBlue,
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Make sure your output includes the required metrics (e.g., "accuracy: 99%"). The evaluation focuses more on the numerical results than the exact text formatting.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: darkBlue.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Helper for creating labeled form fields with tooltips
  Widget _buildLabelWithTooltip(String labelText, String tooltipText) {
    return Row(
      children: [
        Text(
          labelText,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: darkBlue,
          ),
        ),
        SizedBox(width: 6),
        Tooltip(
          message: tooltipText,
          textStyle: TextStyle(color: Colors.white, fontSize: 12),
          decoration: BoxDecoration(
            color: darkBlue.withOpacity(0.9),
            borderRadius: BorderRadius.circular(4),
          ),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          preferBelow: true,
          showDuration: Duration(seconds: 2),
          child: Icon(
            Icons.info_outline,
            size: 16,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  // Helper methods for UI colors
  Color _getScoreColor(double percent) {
    if (percent >= 80) return Colors.green[600]!;
    if (percent >= 60) return primaryBlue;
    if (percent >= 40) return Colors.orange[700]!;
    return Colors.red[600]!;
  }

  Color _getComponentScoreColor(double score) {
    if (score >= 32) return Colors.green[600]!; // 80% of 40
    if (score >= 24) return primaryBlue; // 60% of 40
    if (score >= 16) return Colors.orange[700]!; // 40% of 40
    return Colors.red[600]!;
  }

  @override
  Widget build(BuildContext context) {
    if (_submissionType == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
              ),
              SizedBox(height: 16),
              Text(
                'Loading submission form...',
                style: TextStyle(
                  color: darkBlue,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.levelName,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: primaryBlue,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  title: Row(
                    children: [
                      Icon(Icons.info_outline, color: primaryBlue),
                      SizedBox(width: 10),
                      Text(
                        'Level Requirements',
                        style: TextStyle(
                          color: darkBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'To complete this level, your submission will be evaluated based on:',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 16),
                      _buildRequirementItem(
                        'Required Concepts',
                        'Your submission must include all the required concepts and keywords for this level.',
                        Icons.check_circle_outline,
                      ),
                      SizedBox(height: 12),
                      _buildRequirementItem(
                        'Output Correctness',
                        'For code submissions, your output should match the expected results or metrics.',
                        Icons.analytics_outlined,
                      ),
                      SizedBox(height: 12),
                      _buildRequirementItem(
                        'Supporting Materials',
                        'You can optionally upload files to support your submission.',
                        Icons.attach_file,
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: primaryBlue,
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      child: Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        color: Colors.grey[50],
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Problem Statement Card
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: lightBlue.withOpacity(0.5)),
                  ),
                  margin: const EdgeInsets.only(bottom: 20),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.assignment, color: primaryBlue, size: 24),
                            SizedBox(width: 10),
                            Text(
                              'Problem Statement',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: darkBlue,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: veryLightBlue,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.levelDescription,
                            style: TextStyle(
                              height: 1.5,
                              fontSize: 15,
                              color: darkBlue.withOpacity(0.9),
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: primaryBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: primaryBlue.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _submissionType == 'code' ? Icons.code : Icons.text_fields,
                                    size: 16,
                                    color: primaryBlue,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    _submissionType == 'code' ? 'Code Submission' : 'Text Submission',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: primaryBlue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 10),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[400]!),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.numbers,
                                    size: 16,
                                    color: Colors.grey[700],
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Level ${widget.levelName.split(' ').last} of ${widget.totalLevels}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[700],
                                    ),
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

                _buildSubmissionForm(),

                // Confetti overlay for celebrations
                Align(
                  alignment: Alignment.center,
                  child: ConfettiWidget(
                    confettiController: _confettiController,
                    blastDirectionality: BlastDirectionality.explosive,
                    shouldLoop: false,
                    colors: const [primaryBlue, lightBlue, accentBlue, Colors.green, Colors.purple],
                    emissionFrequency: 0.05,
                    numberOfParticles: 50,
                    maxBlastForce: 20,
                    minBlastForce: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper method for building requirement items in the help dialog
  Widget _buildRequirementItem(String title, String description, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: primaryBlue, size: 20),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: darkBlue,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _codeController.dispose();
    _outputController.dispose();
    _textController.dispose();
    super.dispose();
  }
}