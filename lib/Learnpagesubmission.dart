import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
// Import your innovation score service
import 'innovation_score_service.dart';

class ExerciseSubmissionPage extends StatefulWidget {
  @override
  _ExerciseSubmissionPageState createState() => _ExerciseSubmissionPageState();
}

class _ExerciseSubmissionPageState extends State<ExerciseSubmissionPage> {
  final TextEditingController _codeController = TextEditingController();
  String _result = '';
  bool _isVerifying = false;
  bool _isCorrect = false;
  int _score = 0;
  bool _hasUpdatedScore = false; // Prevent multiple score updates

  Future<void> verifyCodeWithGemini(String userCode, Map<String, dynamic> problemData) async {
    const apiKey = 'AIzaSyAvQcRty4FsLjeV_cHQ7FK1nunKWUJvqV8';
    const url = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro:generateContent';

    setState(() {
      _isVerifying = true;
      _result = 'Verifying your code...';
    });

    // Extract problem details
    String exerciseName = problemData['exercise_name'] ?? 'Unknown Problem';
    String exerciseDetails = problemData['exercise_details'] ?? 'No description';
    String expectedAnswer = problemData['expected_answer'] ?? '';
    String difficulty = problemData['difficulty'] ?? 'Unknown';

    final prompt = '''
You are a coding instructor. Please verify if the user's submitted code correctly solves the given programming problem.

**PROBLEM DETAILS:**
Problem Title: $exerciseName
Difficulty: $difficulty
Problem Description: $exerciseDetails

**EXPECTED SOLUTION:**
```
$expectedAnswer
```

**USER'S SUBMITTED CODE:**
```
$userCode
```

**VERIFICATION REQUIREMENTS:**
1. Check if the user's code addresses the exact problem described
2. Verify if the logic and algorithm are correct
3. Check if the code would produce the expected output for the given problem
4. Consider edge cases and error handling
5. Evaluate code quality and best practices

**RESPONSE FORMAT:**
Please respond with a JSON object containing:
{
  "correct": boolean (true if code correctly solves the problem, false otherwise),
  "score": number (0-100, where 100 is perfect solution),
  "message": "Detailed explanation of the verification result",
  "issues": ["List of specific issues found, if any"],
  "suggestions": ["List of suggestions for improvement, if needed"],
  "test_cases_passed": number (estimated number of test cases that would pass)
}

**IMPORTANT:**
- Be strict about correctness - the code must solve the EXACT problem described
- If the user submitted addition code for a subtraction problem, mark it as incorrect
- Consider syntax errors, logical errors, and algorithmic correctness
- Provide constructive feedback for learning
''';

    try {
      final response = await http.post(
        Uri.parse('$url?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.1,
            'maxOutputTokens': 1000,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final resultText = data['candidates'][0]['content']['parts'][0]['text'];

        String cleanedText = resultText.trim();
        if (cleanedText.startsWith('```json')) {
          cleanedText = cleanedText.substring(7);
        }
        if (cleanedText.endsWith('```')) {
          cleanedText = cleanedText.substring(0, cleanedText.length - 3);
        }
        cleanedText = cleanedText.trim();

        try {
          final result = jsonDecode(cleanedText);

          setState(() {
            _isCorrect = result['correct'] ?? false;
            _score = result['score'] ?? 0;
            _result = result['message'] ?? 'Verification completed';
            _isVerifying = false;
          });

          // Update innovation score if correct and not already updated
          if (_isCorrect && !_hasUpdatedScore) {
            await _updateInnovationScore(problemData);
            _hasUpdatedScore = true;
          }

          // Show detailed result dialog
          _showResultDialog(result);

        } catch (jsonError) {
          setState(() {
            _isCorrect = resultText.toLowerCase().contains('correct') &&
                !resultText.toLowerCase().contains('incorrect');
            _score = _isCorrect ? 85 : 30;
            _result = resultText;
            _isVerifying = false;
          });

          // Update innovation score if correct and not already updated
          if (_isCorrect && !_hasUpdatedScore) {
            await _updateInnovationScore(problemData);
            _hasUpdatedScore = true;
          }
        }

      } else {
        setState(() {
          _result = 'Error verifying code: ${response.statusCode}';
          _isVerifying = false;
        });
      }
    } catch (e) {
      setState(() {
        _result = 'Network error: $e';
        _isVerifying = false;
      });
    }
  }

  Future<void> _updateInnovationScore(Map<String, dynamic> problemData) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Calculate points based on difficulty
      int pointsToAdd = _calculatePointsByDifficulty(problemData['difficulty'] ?? 'Easy');

      // Get problem ID for duplicate checking
      final Map arguments = ModalRoute.of(context)!.settings.arguments as Map;
      final String problemId = arguments['problemId'] ?? arguments['exerciseId'];
      final String language = arguments['language'] ?? arguments['domain'];

      // Check if this problem was already solved
      final submissionExists = await _checkIfAlreadySolved(user.uid, problemId, language);

      if (submissionExists) {
        print('Problem already solved, no points awarded');
        return;
      }

      // Add submission record to prevent duplicate scoring
      await FirebaseFirestore.instance
          .collection('exercise_submissions')
          .add({
        'user_id': user.uid,
        'problem_id': problemId,
        'language': language,
        'score': _score,
        'points_awarded': pointsToAdd,
        'submitted_at': FieldValue.serverTimestamp(),
        'problem_name': problemData['exercise_name'] ?? 'Unknown',
        'difficulty': problemData['difficulty'] ?? 'Unknown',
      });

      // Update innovation score using the service
      await InnovationScoreService().addPoints(
        pointsToAdd,
        'Exercise Completed: ${problemData['exercise_name'] ?? 'Unknown Problem'}',
      );

      // Show points notification
      _showPointsNotification(pointsToAdd);

    } catch (e) {
      print('Error updating innovation score: $e');
    }
  }

  int _calculatePointsByDifficulty(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return 10;
      case 'medium':
        return 20;
      case 'hard':
        return 30;
      case 'expert':
        return 50;
      default:
        return 10; // Default to easy level
    }
  }

  Future<bool> _checkIfAlreadySolved(String userId, String problemId, String language) async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('exercise_submissions')
          .where('user_id', isEqualTo: userId)
          .where('problem_id', isEqualTo: problemId)
          .where('language', isEqualTo: language)
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      print('Error checking submission history: $e');
      return false;
    }
  }

  void _showPointsNotification(int points) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.star,
                  color: Colors.yellow[300],
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Innovation Score Updated!',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '+$points points added to your score',
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showResultDialog(Map<String, dynamic> result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                _isCorrect ? Icons.check_circle : Icons.error,
                color: _isCorrect ? Colors.green : Colors.red,
                size: 28,
              ),
              const SizedBox(width: 10),
              Text(
                _isCorrect ? 'Success!' : 'Try Again',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: _isCorrect ? Colors.green : Colors.red,
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
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isCorrect ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Score: $_score/100',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: _isCorrect ? Colors.green[700] : Colors.red[700],
                        ),
                      ),
                    ],
                  ),
                ),

                // Points awarded notification (only if correct)
                if (_isCorrect) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.blue.withOpacity(0.1),
                          Colors.purple.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Innovation points will be added to your score!',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Main message
                Text(
                  result['message'] ?? _result,
                  style: GoogleFonts.inter(fontSize: 14, height: 1.4),
                ),

                // Issues (if any)
                if (result['issues'] != null && (result['issues'] as List).isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Issues Found:',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: Colors.red[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...(result['issues'] as List).map((issue) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error_outline, size: 16, color: Colors.red[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            issue.toString(),
                            style: GoogleFonts.inter(fontSize: 13, color: Colors.red[600]),
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                ],

                // Suggestions (if any)
                if (result['suggestions'] != null && (result['suggestions'] as List).isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Suggestions:',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...(result['suggestions'] as List).map((suggestion) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lightbulb_outline, size: 16, color: Colors.blue[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            suggestion.toString(),
                            style: GoogleFonts.inter(fontSize: 13, color: Colors.blue[600]),
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                ],

                // Test cases info
                if (result['test_cases_passed'] != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Estimated test cases passed: ${result['test_cases_passed']}/10',
                      style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[700]),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: GoogleFonts.inter(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (_isCorrect) {
                  // Navigate back or to next challenge
                  Navigator.of(context).pop();
                } else {
                  // Clear the code editor for retry
                  setState(() {
                    _result = 'Try again with the suggested improvements!';
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _isCorrect ? Colors.green : Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: Text(
                _isCorrect ? 'Continue' : 'Try Again',
                style: GoogleFonts.inter(),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Map arguments = ModalRoute.of(context)!.settings.arguments as Map;
    final String language = arguments['language'] ?? arguments['domain'];
    final String problemId = arguments['problemId'] ?? arguments['exerciseId'];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Problem Solution',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF6200EA),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection(language)
            .doc(problemId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            );
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Problem not found'));
          }

          final problemData = snapshot.data!.data() as Map<String, dynamic>;
          final learningSteps = List<Map<String, dynamic>>.from(problemData['learning_steps'] ?? []);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Problem Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF6200EA).withOpacity(0.1),
                        const Color(0xFF9C27B0).withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.purple[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        problemData['exercise_name'] ?? 'Untitled Problem',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6200EA).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Difficulty: ${problemData['difficulty'] ?? 'Unknown'}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF6200EA),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Points indicator
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star, size: 14, color: Colors.amber[700]),
                                const SizedBox(width: 4),
                                Text(
                                  '${_calculatePointsByDifficulty(problemData['difficulty'] ?? 'Easy')} pts',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.amber[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        problemData['exercise_details'] ?? 'No description available',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey[700],
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Learning Steps
                if (learningSteps.isNotEmpty) ...[
                  Text(
                    'Learning Steps:',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...learningSteps.asMap().entries.map((entry) {
                    final index = entry.key;
                    final step = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: const Color(0xFF6200EA),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  step['title'] ?? 'Untitled Step',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  step['content'] ?? 'No content',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (step['image_url'] != null && step['image_url'] != 'null')
                            Icon(Icons.image, color: Colors.grey[400], size: 20),
                        ],
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 24),
                ],

                // Code Submission Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.code, color: const Color(0xFF6200EA), size: 24),
                          const SizedBox(width: 8),
                          Text(
                            'Submit Your Solution:',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _codeController,
                        maxLines: 12,
                        style: GoogleFonts.firaCode(fontSize: 14),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF6200EA), width: 2),
                          ),
                          hintText: 'Enter your ${language} code here...',
                          hintStyle: GoogleFonts.firaCode(color: Colors.grey[400]),
                          fillColor: Colors.grey[50],
                          filled: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isVerifying ? null : () {
                            if (_codeController.text.trim().isEmpty) {
                              setState(() {
                                _result = 'Please enter some code to submit';
                              });
                              return;
                            }
                            verifyCodeWithGemini(_codeController.text, problemData);
                          },
                          icon: _isVerifying
                              ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                              : Icon(Icons.send, size: 20),
                          label: Text(
                            _isVerifying ? 'Verifying...' : 'Submit & Verify Code',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6200EA),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Result Display
                if (_result.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _isCorrect ? Colors.green[50] : (_result.contains('Error') ? Colors.red[50] : Colors.blue[50]),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isCorrect ? Colors.green[300]! : (_result.contains('Error') ? Colors.red[300]! : Colors.blue[300]!),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isCorrect ? Icons.check_circle : (_result.contains('Error') ? Icons.error : Icons.info),
                          color: _isCorrect ? Colors.green[700] : (_result.contains('Error') ? Colors.red[700] : Colors.blue[700]),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _result,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: _isCorrect ? Colors.green[700] : (_result.contains('Error') ? Colors.red[700] : Colors.blue[700]),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}