// 1. Create a server-side quiz generator service
// This would be implemented as a Cloud Function in Firebase

// quiz_generator.js (Firebase Cloud Function)
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');
admin.initializeApp();

exports.generateQuizQuestions = functions.https.onCall(async (data, context) => {
  // Authenticate the user
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { projectId, levelName, attemptCount } = data;
  const levelIdentifier = `${projectId}_${levelName}_attempt${attemptCount}`;

  // Check if questions already exist
  const quizDoc = await admin.firestore().collection('quiz_questions').doc(levelIdentifier).get();
  if (quizDoc.exists) {
    return { questions: quizDoc.data().questions };
  }

  // Get project and level info
  const projectDoc = await admin.firestore().collection('projects').doc(projectId).get();
  const projectTitle = projectDoc.data()?.title || 'Project';
  const projectDescription = projectDoc.data()?.description || 'No description';
  const levelDescription = data.levelDescription;

  // Create seed for deterministic questions
  const crypto = require('crypto');
  const seed = crypto.createHash('sha256')
    .update(levelIdentifier + Date.now().toString())
    .digest('hex').substring(0, 16);

  // Generate the questions using Gemini API (server-side)
  const GEMINI_API_KEY = process.env.GEMINI_API_KEY; // Stored as environment variable

  try {
    const response = await axios.post(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro:generateContent?key=${GEMINI_API_KEY}`,
      {
        contents: [{
          parts: [{
            text: `
              Generate 8 multiple-choice questions related to the following project and level:

              Project: ${projectTitle}
              Project Description: ${projectDescription}
              Level: ${levelName}
              Level Description: ${levelDescription}

              Please generate the questions in the following JSON format:
              [
                {
                  "question": "Question text here",
                  "options": ["Option A", "Option B", "Option C", "Option D"],
                  "correctAnswerIndex": 0
                },
                ...
              ]

              The questions should test understanding of key concepts needed for this level. Generate exactly 8 questions.

              Important: Use seed value ${seed} to ensure uniqueness.
            `
          }]
        }],
        generationConfig: {
          temperature: 0.5,
          topK: 1,
          topP: 0,
          maxOutputTokens: 8192,
          seed: parseInt(seed, 16) % 2147483647,
        }
      }
    );

    const text = response.data.candidates[0].content.parts[0].text;
    const jsonPattern = /\[\s*\{.*?\}\s*\]/s;
    const match = text.match(jsonPattern);

    if (match) {
      const jsonStr = match[0];
      const questions = JSON.parse(jsonStr);

      // Store in Firestore for future use
      await admin.firestore().collection('quiz_questions').doc(levelIdentifier).set({
        questions,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        projectId,
        levelName,
        attempt: attemptCount,
      });

      return { questions };
    } else {
      throw new Error("Couldn't parse quiz questions from response");
    }
  } catch (error) {
    console.error('Error generating quiz with Gemini:', error);
    throw new functions.https.HttpsError('internal', 'Failed to generate quiz questions');
  }
});

// 2. Batch generate quiz questions for all levels in advance
exports.batchGenerateQuizzes = functions.pubsub.schedule('0 0 * * 0').onRun(async (context) => {
  const projects = await admin.firestore().collection('projects').get();

  for (const project of projects.docs) {
    const projectId = project.id;
    const roadmap = project.data().roadmap || [];

    for (const level of roadmap) {
      const levelName = level.level;
      const levelDescription = level.description;

      // Generate questions for attempt 0 and 1
      for (let attemptCount = 0; attemptCount < 2; attemptCount++) {
        const levelIdentifier = `${projectId}_${levelName}_attempt${attemptCount}`;
        const quizDoc = await admin.firestore().collection('quiz_questions').doc(levelIdentifier).get();

        // Only generate if not already created
        if (!quizDoc.exists) {
          try {
            // Call the question generation logic (refactored to a shared function)
            await generateQuestionsForLevel(projectId, levelName, levelDescription, attemptCount);
            // Add some delay to avoid rate limiting
            await new Promise(resolve => setTimeout(resolve, 1000));
          } catch (error) {
            console.error(`Failed to generate questions for ${levelIdentifier}:`, error);
          }
        }
      }
    }
  }

  return null;
});

// 3. In your Dart code, modify the quiz loading function:

// Modified _loadQuizQuestions method in Dart
Future<void> _loadQuizQuestions() async {
  setState(() {
    _loadingQuiz = true;
  });

  try {
    final String levelIdentifier = '${widget.projectId}_${widget.levelName}_attempt$_attemptCount';
    final quizDoc = await _firestore
        .collection('quiz_questions')
        .doc(levelIdentifier)
        .get();

    if (quizDoc.exists && quizDoc.data() != null && quizDoc.data()!.containsKey('questions')) {
      final List<dynamic> savedQuestions = quizDoc.data()!['questions'];
      setState(() {
        _quizQuestions = _shuffleOptions(savedQuestions.cast<Map<String, dynamic>>());
        _selectedAnswers = List.filled(_quizQuestions.length, -1);
        _currentQuestionIndex = 0;
        _loadingQuiz = false;
        _startTimer();
      });
    } else {
      // Use the Cloud Function instead of directly calling Gemini API
      final functions = FirebaseFunctions.instance;
      final result = await functions.httpsCallable('generateQuizQuestions').call({
        'projectId': widget.projectId,
        'levelName': widget.levelName,
        'levelDescription': widget.levelDescription,
        'attemptCount': _attemptCount,
      });

      final List<dynamic> questions = result.data['questions'];
      setState(() {
        _quizQuestions = _shuffleOptions(questions.cast<Map<String, dynamic>>());
        _selectedAnswers = List.filled(_quizQuestions.length, -1);
        _currentQuestionIndex = 0;
        _loadingQuiz = false;
        _startTimer();
      });
    }
  } catch (e) {
    print('Error loading quiz questions: $e');
    _quizQuestionsFailedToLoad();
  }
}

// 4. Implement more robust answer verification
// Answer verification service (Cloud Function)
exports.verifyCodeSubmission = functions.https.onCall(async (data, context) => {
  // Authenticate the user
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { projectId, levelName, code, output } = data;
  const userId = context.auth.uid;

  // Get the expected answers
  const answerDoc = await admin.firestore()
    .collection('answers')
    .doc(projectId)
    .collection('levels')
    .doc(levelName)
    .get();

  if (!answerDoc.exists) {
    throw new functions.https.HttpsError('not-found', 'Answer criteria not found');
  }

  const answerData = answerDoc.data();
  const requiredKeywords = answerData.requiredKeywords || [];
  const expectedOutput = answerData.expectedOutput;
  const expectedOutputs = answerData.expectedOutputs || [];

  // More sophisticated code analysis
  // 1. Check if required keywords are present
  const keywordCheck = requiredKeywords.every(keyword =>
    code.toLowerCase().includes(keyword.toLowerCase())
  );

  // 2. Check output
  let outputCheck = false;
  if (expectedOutputs.length > 0) {
    const normalizedOutput = output.toLowerCase().replace(/\s+/g, ' ').trim();
    outputCheck = expectedOutputs.some(expected =>
      normalizedOutput === expected.toLowerCase().replace(/\s+/g, ' ').trim()
    );
  } else if (expectedOutput) {
    const normalizedOutput = output.toLowerCase().replace(/\s+/g, ' ').trim();
    const normalizedExpected = expectedOutput.toLowerCase().replace(/\s+/g, ' ').trim();
    outputCheck = normalizedOutput === normalizedExpected;
  }

  // 3. Functional tests (optional, can be expanded)
  let functionalCheck = true;

  // Determine overall correctness
  const isCorrect = keywordCheck && outputCheck && functionalCheck;

  // Save result
  await admin.firestore()
    .collection('user_answers')
    .doc(userId)
    .collection('projects')
    .doc(projectId)
    .collection('levels')
    .doc(levelName)
    .set({
      code,
      output,
      isCorrect,
      submittedAt: admin.firestore.FieldValue.serverTimestamp(),
      keywordCheckPassed: keywordCheck,
      outputCheckPassed: outputCheck,
      functionalCheckPassed: functionalCheck
    }, { merge: true });

  // Return detailed feedback
  return {
    isCorrect,
    feedback: {
      keywordCheck,
      outputCheck,
      functionalCheck,
      missingKeywords: requiredKeywords.filter(keyword =>
        !code.toLowerCase().includes(keyword.toLowerCase())
      ),
      outputFeedback: outputCheck ? 'Output matches expected result' : 'Output does not match expected result'
    }
  };
});

// 5. Implement fallback mechanisms for quiz loading
Future<void> _loadFallbackQuizQuestions() async {
  try {
    // Get pre-generated generic questions for this level type
    final levelType = widget.levelName.split(' ')[0]; // e.g., "Beginner", "Intermediate"
    final fallbackDoc = await _firestore
        .collection('fallback_questions')
        .doc(levelType)
        .get();

    if (fallbackDoc.exists) {
      final List<dynamic> fallbackQuestions = fallbackDoc.data()!['questions'];
      setState(() {
        _quizQuestions = _shuffleOptions(fallbackQuestions.cast<Map<String, dynamic>>());
        _selectedAnswers = List.filled(_quizQuestions.length, -1);
        _currentQuestionIndex = 0;
        _loadingQuiz = false;
        _startTimer();
      });
      return;
    }

    // If no fallback questions, use hardcoded basics
    setState(() {
      _quizQuestions = _getHardcodedBasicQuestions();
      _selectedAnswers = List.filled(_quizQuestions.length, -1);
      _currentQuestionIndex = 0;
      _loadingQuiz = false;
      _startTimer();
    });
  } catch (e) {
    print('Error loading fallback questions: $e');
    _quizQuestionsFailedToLoad();
  }
}

List<Map<String, dynamic>> _getHardcodedBasicQuestions() {
  // Basic programming/CS knowledge questions that apply to most projects
  return [
    {
      'question': 'What is the purpose of a function in programming?',
      'options': [
        'To organize code into reusable blocks',
        'To create variables',
        'To format text on screen',
        'To slow down program execution'
      ],
      'correctAnswerIndex': 0
    },
    {
      'question': 'What does the acronym API stand for?',
      'options': [
        'Application Programming Interface',
        'Automated Program Installation',
        'Advanced Programming Instruction',
        'Application Process Integration'
      ],
      'correctAnswerIndex': 0
    },
    // Add 6 more basic questions
  ];
}

// 6. Implement more sophisticated code verification
bool _validateCode(String code, List<String> requiredKeywords, List<String> requiredFunctions) {
  code = code.toLowerCase();

  // Basic keyword check
  final keywordsPresent = requiredKeywords.every((keyword) => code.contains(keyword));

  // Function signature check
  final functionsPresent = requiredFunctions.every((funcSignature) {
    final pattern = RegExp(funcSignature.toLowerCase());
    return pattern.hasMatch(code);
  });

  // Structure validation (basic)
  bool hasProperStructure = true;
  if (code.contains('class')) {
    // Check if classes have proper opening/closing braces
    final classMatches = RegExp(r'class\s+\w+\s*{').allMatches(code);
    final openBraces = '{'.allMatches(code).length;
    final closeBraces = '}'.allMatches(code).length;
    hasProperStructure = classMatches.isNotEmpty && openBraces == closeBraces;
  }

  return keywordsPresent && functionsPresent && hasProperStructure;
}

// 7. Static Answer Keys (when AI generation fails)
final Map<String, List<Map<String, dynamic>>> _staticQuizBank = {
  'Level 1': [
    {
      'question': 'What is the primary purpose of variables in programming?',
      'options': [
        'To store and manage data',
        'To create user interfaces',
        'To connect to databases',
        'To format output text'
      ],
      'correctAnswerIndex': 0
    },
    // Add more static questions for Level 1
  ],
  'Level 2': [
    // Questions for Level 2
  ],
  // More levels
};