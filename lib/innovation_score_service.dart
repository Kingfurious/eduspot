import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class InnovationScoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream to provide real-time updates of the innovation score
  Stream<int> get innovationScoreStream {
    User? user = _auth.currentUser;
    if (user == null) {
      return Stream.value(0); // Return 0 if no user is logged in
    }

    // Listen to the user's document for score changes
    return _firestore
        .collection('users') // Assuming user data is stored in a 'users' collection
        .doc(user.uid)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        // Assuming the innovation score is stored in a field named 'innovationScore'
        return (data['innovationScore'] as num?)?.toInt() ?? 0;
      } else {
        return 0; // Return 0 if the user document or score field doesn't exist
      }
    }).handleError((error) {
      print("Error fetching innovation score: $error");
      return 0; // Return 0 in case of any error
    });
  }

  // New method to add points to innovation score
  Future<void> addPoints(int points, String description) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print("No user logged in. Cannot add points.");
        return;
      }

      // Get current score
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      int currentScore = 0;

      if (userDoc.exists && userDoc.data() != null) {
        currentScore = (userDoc.data()!['innovationScore'] as num?)?.toInt() ?? 0;
      }

      // Calculate new score
      int newScore = currentScore + points;

      // Update score in Firestore
      await _firestore.collection('users').doc(user.uid).set({
        'innovationScore': newScore,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Log the point addition for tracking
      await _logPointAddition(user.uid, points, description, currentScore, newScore);

      print("Added $points points to user ${user.uid}. New score: $newScore");

    } catch (e) {
      print("Error adding points to innovation score: $e");
    }
  }

  // Method to subtract points (for penalties or corrections)
  Future<void> subtractPoints(int points, String description) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print("No user logged in. Cannot subtract points.");
        return;
      }

      // Get current score
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      int currentScore = 0;

      if (userDoc.exists && userDoc.data() != null) {
        currentScore = (userDoc.data()!['innovationScore'] as num?)?.toInt() ?? 0;
      }

      // Calculate new score (ensure it doesn't go below 0)
      int newScore = (currentScore - points).clamp(0, double.infinity).toInt();

      // Update score in Firestore
      await _firestore.collection('users').doc(user.uid).set({
        'innovationScore': newScore,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Log the point subtraction for tracking
      await _logPointAddition(user.uid, -points, description, currentScore, newScore);

      print("Subtracted $points points from user ${user.uid}. New score: $newScore");

    } catch (e) {
      print("Error subtracting points from innovation score: $e");
    }
  }

  // Method to log point changes for tracking and analytics
  Future<void> _logPointAddition(String userId, int pointsChanged, String description, int previousScore, int newScore) async {
    try {
      await _firestore.collection('score_history').add({
        'userId': userId,
        'pointsChanged': pointsChanged,
        'description': description,
        'previousScore': previousScore,
        'newScore': newScore,
        'timestamp': FieldValue.serverTimestamp(),
        'type': pointsChanged > 0 ? 'addition' : 'subtraction',
      });
    } catch (e) {
      print("Error logging point change: $e");
    }
  }

  // Method to get user's score history
  Future<List<Map<String, dynamic>>> getScoreHistory(String userId, {int limit = 20}) async {
    try {
      final query = await _firestore
          .collection('score_history')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return query.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();

    } catch (e) {
      print("Error fetching score history: $e");
      return [];
    }
  }

  // Method to get current score (one-time fetch)
  Future<int> getCurrentScore() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 0;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (userDoc.exists && userDoc.data() != null) {
        return (userDoc.data()!['innovationScore'] as num?)?.toInt() ?? 0;
      }
      return 0;

    } catch (e) {
      print("Error fetching current score: $e");
      return 0;
    }
  }

  // Method to initialize user score if it doesn't exist
  Future<void> initializeUserScore(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists || userDoc.data()?['innovationScore'] == null) {
        await _firestore.collection('users').doc(userId).set({
          'innovationScore': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        print("Initialized innovation score for user $userId");
      }
    } catch (e) {
      print("Error initializing user score: $e");
    }
  }

  // Method to calculate and update the innovation score (existing functionality)
  Future<void> calculateAndSetInnovationScore(String userId) async {
    if (userId.isEmpty) {
      print("User ID is empty. Cannot calculate score.");
      return;
    }

    int totalScore = 0;

    try {
      // 1. Calculate score from completed exercises (assuming 'isCorrect' means perfect score)
      final exerciseSubmissions = await _firestore
          .collection('user_submissions')
          .where('userId', isEqualTo: userId)
          .get();

      for (var doc in exerciseSubmissions.docs) {
        final data = doc.data();
        final int marks = (data['marks'] as num?)?.toInt() ?? 0;
        final bool isCorrect = (data['isCorrect'] as bool?) ?? false;

        // +10 points for each completed exercise
        totalScore += 10;
        // +5 for perfect exercise scores (assuming marks == 100 implies perfect)
        if (isCorrect && marks == 100) {
          totalScore += 5;
        }
      }

      // 2. Add points from exercise_submissions collection (new submissions)
      final newExerciseSubmissions = await _firestore
          .collection('exercise_submissions')
          .where('user_id', isEqualTo: userId)
          .get();

      for (var doc in newExerciseSubmissions.docs) {
        final data = doc.data();
        final int pointsAwarded = (data['points_awarded'] as num?)?.toInt() ?? 0;
        totalScore += pointsAwarded;
      }

      // 3. Calculate score from completed projects
      // This requires knowing which projects are completed.
      // Assuming a project is completed when all its levels in the roadmap are completed.
      // We need to fetch all projects and check the user's progress for each level.

      final projectsSnapshot = await _firestore.collection('projects').get();

      for (var projectDoc in projectsSnapshot.docs) {
        final projectId = projectDoc.id;
        final projectData = projectDoc.data();
        final roadmap = (projectData['roadmap'] as List<dynamic>?) ?? [];

        bool isProjectCompleted = true;
        if (roadmap.isNotEmpty) {
          for (var level in roadmap) {
            final levelName = level['level'] as String?;
            if (levelName != null) {
              final levelCompletionDoc = await _firestore
                  .collection('user_answers')
                  .doc(userId)
                  .collection('projects')
                  .doc(projectId)
                  .collection('levels')
                  .doc(levelName)
                  .get();

              final bool isLevelCorrect = (levelCompletionDoc.data()?['isCorrect'] as bool?) ?? false;

              if (!isLevelCorrect) {
                isProjectCompleted = false;
                break; // If any level is not completed correctly, the project is not completed
              }
            } else {
              // If a level name is missing, we can't verify completion, assume not completed for safety
              isProjectCompleted = false;
              break;
            }
          }
        } else {
          // If a project has no roadmap, consider it not completable for scoring purposes
          isProjectCompleted = false;
        }


        if (isProjectCompleted) {
          // +50 points for each completed project
          totalScore += 50;
          // Optional: +20 for uploaded projects (Need to determine how to identify uploaded projects)
          // Assuming 'isUploaded' field in project document or user_answers
          final userProjectAnswer = await _firestore
              .collection('user_answers')
              .doc(userId)
              .collection('projects')
              .doc(projectId)
              .get();

          final bool isProjectUploaded = (userProjectAnswer.data()?['isUploaded'] as bool?) ?? false;
          if(isProjectUploaded){
            totalScore += 20;
          }
        }
      }

      // Update the user's innovation score in Firestore
      await _firestore.collection('users').doc(userId).set({
        'innovationScore': totalScore,
        'lastCalculated': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print("Innovation score calculated and updated for user $userId: $totalScore");

    } catch (e) {
      print("Error calculating and setting innovation score: $e");
    }
  }

  // Method to award points for different activities
  Future<void> awardPointsForActivity({
    required String activityType,
    required String activityName,
    String? difficulty,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      int points = 0;
      String description = '';

      switch (activityType.toLowerCase()) {
        case 'exercise':
          points = _calculateExercisePoints(difficulty ?? 'easy');
          description = 'Exercise Completed: $activityName';
          break;
        case 'project':
          points = 50;
          description = 'Project Completed: $activityName';
          break;
        case 'course':
          points = 30;
          description = 'Course Completed: $activityName';
          break;
        case 'upload':
          points = 20;
          description = 'Project Uploaded: $activityName';
          break;
        case 'mentor':
          points = 15;
          description = 'Mentor Session: $activityName';
          break;
        case 'daily_login':
          points = 5;
          description = 'Daily Login Bonus';
          break;
        default:
          points = 10;
          description = 'Activity Completed: $activityName';
      }

      await addPoints(points, description);

    } catch (e) {
      print("Error awarding points for activity: $e");
    }
  }

  // Helper method to calculate points based on exercise difficulty
  int _calculateExercisePoints(String difficulty) {
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
        return 10;
    }
  }

  // Method to get leaderboard data
  Future<List<Map<String, dynamic>>> getLeaderboard({int limit = 10}) async {
    try {
      final query = await _firestore
          .collection('users')
          .orderBy('innovationScore', descending: true)
          .limit(limit)
          .get();

      List<Map<String, dynamic>> leaderboard = [];

      for (int i = 0; i < query.docs.length; i++) {
        final doc = query.docs[i];
        final data = doc.data();

        leaderboard.add({
          'rank': i + 1,
          'userId': doc.id,
          'username': data['username'] ?? data['displayName'] ?? 'Anonymous',
          'innovationScore': (data['innovationScore'] as num?)?.toInt() ?? 0,
          'profileImage': data['profileImage'] ?? data['photoURL'],
        });
      }

      return leaderboard;

    } catch (e) {
      print("Error fetching leaderboard: $e");
      return [];
    }
  }

  // Method to get user's rank
  Future<int> getUserRank(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return 0;

      final userScore = (userDoc.data()!['innovationScore'] as num?)?.toInt() ?? 0;

      final higherScoreCount = await _firestore
          .collection('users')
          .where('innovationScore', isGreaterThan: userScore)
          .get();

      return higherScoreCount.docs.length + 1;

    } catch (e) {
      print("Error getting user rank: $e");
      return 0;
    }
  }

  // Method to check if user has achieved a new milestone
  Future<String?> checkForMilestone(int newScore, int previousScore) async {
    List<int> milestones = [50, 100, 250, 500, 1000, 2000, 5000, 10000];

    for (int milestone in milestones) {
      if (newScore >= milestone && previousScore < milestone) {
        return 'Congratulations! You\'ve reached $milestone innovation points!';
      }
    }

    return null;
  }

  // Method to reset user score (admin function)
  Future<void> resetUserScore(String userId, String reason) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'innovationScore': 0,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Log the reset
      await _firestore.collection('score_history').add({
        'userId': userId,
        'pointsChanged': 0,
        'description': 'Score Reset: $reason',
        'previousScore': await getCurrentScore(),
        'newScore': 0,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'reset',
      });

      print("Reset innovation score for user $userId. Reason: $reason");

    } catch (e) {
      print("Error resetting user score: $e");
    }
  }
}