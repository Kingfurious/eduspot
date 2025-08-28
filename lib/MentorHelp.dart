import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class MentorHelpPage extends StatefulWidget {
  final String caseStudyId;
  final String caseStudyTitle;
  final int currentLevel;

  const MentorHelpPage({
    required this.caseStudyId,
    required this.caseStudyTitle,
    required this.currentLevel,
  });

  @override
  _MentorHelpPageState createState() => _MentorHelpPageState();
}

class _MentorHelpPageState extends State<MentorHelpPage> {
  final TextEditingController _questionController = TextEditingController();
  bool _isLoading = false;
  List<Map<String, dynamic>> _previousQuestions = [];
  int _selectedTopic = 0;

  final List<String> _topicOptions = [
    'All Topics',
    'Understanding the Problem',
    'Data Collection',
    'Solution Strategy',
    'Implementation',
    'Testing & Validation',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadPreviousQuestions();
  }

  Future<void> _loadPreviousQuestions() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final questionsQuery = await FirebaseFirestore.instance
          .collection('mentor_questions')
          .where('userId', isEqualTo: user.uid)
          .where('caseStudyId', isEqualTo: widget.caseStudyId)
          .orderBy('timestamp', descending: true)
          .get();

      setState(() {
        _previousQuestions = questionsQuery.docs
            .map((doc) {
          var data = doc.data();
          data['id'] = doc.id; // Store document ID for reference
          return data;
        })
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading previous questions: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading questions: $e')),
      );
    }
  }

  Future<void> _submitQuestion() async {
    if (_questionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter your question')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You must be logged in to submit a question')),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Get user profile
      final profileDoc = await FirebaseFirestore.instance
          .collection('studentprofile')
          .doc(user.uid)
          .get();

      final String topic = _selectedTopic > 0
          ? _topicOptions[_selectedTopic]
          : 'General';

      final questionData = {
        'userId': user.uid,
        'userName': profileDoc.data()?['fullName'] ?? user.email ?? 'Anonymous',
        'userEmail': user.email,
        'userPhotoUrl': user.photoURL,
        'caseStudyId': widget.caseStudyId,
        'caseStudyTitle': widget.caseStudyTitle,
        'level': widget.currentLevel,
        'topic': topic,
        'question': _questionController.text,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending', // pending, answered, closed
        'answer': null,
        'answerTimestamp': null,
        'mentorId': null,
        'mentorName': null,
      };

      // Add to Firestore
      DocumentReference docRef = await FirebaseFirestore.instance
          .collection('mentor_questions')
          .add(questionData);

      // Update local state with the document ID
      questionData['id'] = docRef.id;

      setState(() {
        _previousQuestions.insert(0, questionData);
        _questionController.clear();
        _selectedTopic = 0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Question submitted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting question: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshQuestions() async {
    await _loadPreviousQuestions();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Questions refreshed')),
    );
  }

  void _closeQuestion(String questionId) async {
    try {
      await FirebaseFirestore.instance
          .collection('mentor_questions')
          .doc(questionId)
          .update({
        'status': 'closed',
      });

      setState(() {
        final questionIndex = _previousQuestions.indexWhere((q) => q['id'] == questionId);
        if (questionIndex >= 0) {
          _previousQuestions[questionIndex]['status'] = 'closed';
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Question marked as closed')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error closing question: $e')),
      );
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';

    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return DateFormat('MMM d, yyyy').format(date);
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'answered':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_empty;
      case 'answered':
        return Icons.check_circle;
      case 'closed':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    throw UnimplementedError();
  }
  }