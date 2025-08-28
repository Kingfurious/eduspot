import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

// Color Palette - matching the projects screen
const Color primaryBlue = Color(0xFF1976D2);
const Color lightBlue = Color(0xFF64B5F6);
const Color veryLightBlue = Color(0xFFE3F2FD);
const Color darkBlue = Color(0xFF0D47A1);
const Color accentBlue = Color(0xFF29B6F6);

// Bot message gradient colors
const List<List<Color>> botGradients = [
  [Color(0xFF8E24AA), Color(0xFF5E35B1)], // Purple gradient
  [Color(0xFF00897B), Color(0xFF00796B)], // Teal gradient
  [Color(0xFF3949AB), Color(0xFF303F9F)], // Indigo gradient
  [Color(0xFF00ACC1), Color(0xFF0097A7)], // Cyan gradient
];

// User message gradient colors
const List<Color> userGradient = [Color(0xFF2979FF), Color(0xFF1565C0)];

class ChatbotPage extends StatefulWidget {
  final String? projectId;
  final String? levelName;

  const ChatbotPage({super.key, this.projectId, this.levelName});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  final String _geminiApiKey = "AIzaSyAvQcRty4FsLjeV_cHQ7FK1nunKWUJvqV8";
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // State variables
  bool _isLoading = false;
  bool _showScrollToBottom = false;
  bool _isExpanded = false;
  String? _problemStatement;
  String? _projectTitle;
  List<dynamic> _roadmap = [];
  double _userProgress = 0.0;
  Map<String, List<String>> _resources = {};
  String? _currentLevelName;
  int _currentGradientIndex = 0;

  // Typing indicator animation
  late AnimationController _dotController;
  late Animation<double> _dotAnimation;

  // Quick reply suggestions
  final List<String> _commonQuestions = [
    'What tools should I use?',
    'How do I get started?',
    'What dataset is recommended?',
    'Explain the problem statement',
    'What are the best resources?'
  ];

  @override
  void initState() {
    super.initState();
    _currentLevelName = widget.levelName;
    _fetchProjectData();
    _loadChatHistory();

    // Set up dot animation controller for typing indicator
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    _dotAnimation = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _dotController, curve: Curves.easeInOut));

    // Listen for scroll to show/hide scroll-to-bottom button
    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        final showButton = _scrollController.position.pixels <
            _scrollController.position.maxScrollExtent - 300;
        if (showButton != _showScrollToBottom) {
          setState(() {
            _showScrollToBottom = showButton;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _dotController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      setState(() {
        _showScrollToBottom = false;
      });
    }
  }

  Future<void> _fetchProjectData() async {
    if (widget.projectId != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('projects')
            .doc(widget.projectId)
            .get();

        final projectData = doc.data() ?? {};
        final roadmap = projectData['roadmap'] as List<dynamic>? ?? [];

        setState(() {
          _roadmap = roadmap;
          _projectTitle = projectData['title'] as String? ?? 'Project Assistant';
          _currentLevelName ??= roadmap.isNotEmpty ? roadmap[0]['level'] : null;

          if (_currentLevelName != null) {
            final currentLevel = roadmap.firstWhere(
                  (lvl) => lvl['level'] == _currentLevelName,
              orElse: () => {'description': 'No problem statement available'},
            );

            _problemStatement = currentLevel['description'] as String? ??
                'No problem statement available';

            // Extract resources for each level
            _resources = {};
            for (var level in roadmap) {
              final levelName = level['level'] as String;
              final levelResources = level['resources'] as List<dynamic>? ?? [];
              _resources[levelName] = levelResources.map((r) => r.toString()).toList();
            }
          }
        });

        _fetchUserProgress();
      } catch (e) {
        print('Error fetching project data: $e');
      }
    } else {
      setState(() {
        _problemStatement = 'General assistance mode';
        _addBotMessage('Please provide a project ID and level name to get specific help. I can assist with anything related—except code!');
      });
    }
  }

  Future<void> _fetchUserProgress() async {
    final user = _auth.currentUser;
    if (user != null && widget.projectId != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('user_answers')
            .doc(user.uid)
            .collection('projects')
            .doc(widget.projectId)
            .get();

        final progress = doc.data()?['progress'] as num? ?? 0.0;
        setState(() {
          _userProgress = progress.toDouble();
        });
      } catch (e) {
        print('Error fetching user progress: $e');
      }
    }
  }

  Future<void> _loadChatHistory() async {
    final user = _auth.currentUser;
    if (user != null && widget.projectId != null && _currentLevelName != null) {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('chat_history')
            .doc(widget.projectId)
            .collection(_currentLevelName!)
            .orderBy('timestamp')
            .get();

        setState(() {
          _messages.clear();

          // Parse messages from Firestore
          for (var doc in snapshot.docs) {
            final data = doc.data();
            _messages.add({
              'sender': data['sender'] as String,
              'text': data['text'] as String,
              'timestamp': data['timestamp'] ?? Timestamp.now(),
              'gradientIndex': data['sender'] == 'bot'
                  ? (data['gradientIndex'] as int? ?? 0) % botGradients.length
                  : 0,
            });
          }

          // Add welcome message only if no history exists
          if (_messages.isEmpty && _problemStatement != null) {
            _addBotMessage('I am here to help with $_currentLevelName problem statement:\n\n$_problemStatement\n\nAsk me anything about it—datasets, tools, approaches, anything except coding solutions!');
          }
        });

        Future.delayed(const Duration(milliseconds: 100), () {
          _scrollToBottom();
        });
      } catch (e) {
        print('Error loading chat history: $e');
      }
    }
  }

  void _addBotMessage(String text) {
    // Rotate through gradient colors for bot messages
    _currentGradientIndex = (_currentGradientIndex + 1) % botGradients.length;

    final message = {
      'sender': 'bot',
      'text': text,
      'timestamp': Timestamp.now(),
      'gradientIndex': _currentGradientIndex,
    };

    setState(() {
      _messages.add(message);
    });

    _saveMessage(message);

    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollToBottom();
    });
  }

  Future<void> _saveMessage(Map<String, dynamic> message) async {
    final user = _auth.currentUser;
    if (user != null && widget.projectId != null && _currentLevelName != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('chat_history')
            .doc(widget.projectId)
            .collection(_currentLevelName!)
            .add({
          'sender': message['sender'],
          'text': message['text'],
          'timestamp': message['timestamp'] ?? FieldValue.serverTimestamp(),
          'gradientIndex': message['gradientIndex'] ?? 0,
        });
      } catch (e) {
        print('Error saving message: $e');
      }
    }
  }

  Future<void> _sendMessage([String? predefinedMessage]) async {
    final userMessage = predefinedMessage ?? _messageController.text.trim();
    if (userMessage.isEmpty) return;

    // Add user message
    final userMsg = {
      'sender': 'user',
      'text': userMessage,
      'timestamp': Timestamp.now(),
      'gradientIndex': 0,
    };

    setState(() {
      _messages.add(userMsg);
      _isLoading = true;
    });

    _saveMessage(userMsg);
    _messageController.clear();
    _scrollToBottom();

    try {
      final response = await _getBotResponse(userMessage);
      _addBotMessage(response);
    } catch (e) {
      _addBotMessage('Sorry, I encountered an error. Please try again.');
      print('Error getting bot response: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<String> _getBotResponse(String userMessage) async {
    final user = _auth.currentUser;
    if (user == null) return 'Please log in to use the chatbot.';

    try {
      final prompt = """
      You are a chatbot designed to assist students with educational project problem statements. Your role is to:
      - Answer ALL questions related to the problem statement provided below, including but not limited to:
        - What type of dataset to collect or use.
        - What software, tools, or approaches to consider.
        - Which software or tool is better for the task.
        - How to install software (e.g., Python, Node.js, etc.).
        - Any conceptual clarification, requirements, or strategies related to the problem.
      - Provide progress-based suggestions based on the user's completion percentage: $_userProgress (e.g., "You're 50% done—focus on X next!").
      - Suggest relevant resources if available (e.g., "Check python.org for installation").
      - Strictly refuse to provide coding solutions or sample code (e.g., "I can't provide code solutions, but I can suggest tools, datasets, or explain concepts!").
      - If the question is unrelated to the problem statement, politely redirect (e.g., "Let's focus on the problem statement—how can I assist?").

      Problem Statement: $_problemStatement
      
      User Question: $userMessage
      
      Respond concisely and stay within your role.
      """;

      final response = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro:generateContent?key=$_geminiApiKey'),
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
            'temperature': 0.7,
            'topK': 40,
            'topP': 0.95,
            'maxOutputTokens': 1024,
          }
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        return jsonResponse['candidates'][0]['content']['parts'][0]['text'].trim();
      } else {
        return 'Sorry, I couldn not process that request (Status: ${response.statusCode}). Please try again!';
      }
    } catch (e) {
      return 'An error occurred: $e';
    }
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final dateTime = timestamp.toDate();
    final now = DateTime.now();

    // Format based on date
    if (dateTime.day == now.day && dateTime.month == now.month && dateTime.year == now.year) {
      // Today - show time
      return DateFormat('h:mm a').format(dateTime);
    } else if (dateTime.day == now.day - 1 && dateTime.month == now.month && dateTime.year == now.year) {
      // Yesterday
      return 'Yesterday';
    } else {
      // Other dates
      return DateFormat('MMM d').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentResources = _resources[_currentLevelName] ?? [];

    return Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          backgroundColor: primaryBlue,
          elevation: 2,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _projectTitle ?? 'Chatbot Assistant',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (_currentLevelName != null)
                Text(
                  _currentLevelName!,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
            ],
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            // Level selector dropdown
            if (_roadmap.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _currentLevelName,
                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 20),
                    dropdownColor: darkBlue,
                    elevation: 4,
                    borderRadius: BorderRadius.circular(12),
                    style: const TextStyle(color: Colors.white),
                    items: _roadmap.map((level) {
                      final levelName = level['level'] as String;
                      return DropdownMenuItem<String>(
                        value: levelName,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 150),
                          child: Text(
                            levelName,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (newLevel) {
                      if (newLevel != null && newLevel != _currentLevelName) {
                        setState(() {
                          _currentLevelName = newLevel;
                          _messages.clear();
                        });
                        _fetchProjectData();
                        _loadChatHistory();

                        // Show feedback
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Switched to level: $newLevel'),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
          ],
        ),
        body: Column(
            children: [
            // Problem statement expandable section
            if (_problemStatement != null)
        AnimatedContainer(
        duration: const Duration(milliseconds: 300),
    color: veryLightBlue,
    width: double.infinity,
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    // Header
    InkWell(
    onTap: () {
    setState(() {
    _isExpanded = !_isExpanded;
    });
    HapticFeedback.lightImpact();
    },
    child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(
    children: [
    const Icon(
    Icons.description_outlined,
    color: darkBlue,
    size: 18,
    ),
    const SizedBox(width: 8),
    const Text(
    'Problem Statement',
    style: TextStyle(
    fontWeight: FontWeight.bold,
    color: darkBlue,
    fontSize: 14,
    ),
    ),
    const Spacer(),
    Icon(
    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
    color: darkBlue,
    size: 18,
    ),
    ],
    ),
    ),
    ),

    // Expandable content
    AnimatedSize(
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeInOut,
    child: Container(
    height: _isExpanded ? null : 0,
    padding: EdgeInsets.only(
    left: 16,
    right: 16,
    bottom: _isExpanded ? 16 : 0,
    ),
    child: Text(
    _problemStatement!,
    style: TextStyle(
    fontSize: 14,
    color: Colors.grey.shade800,
    ),
    ),
    ),
    ),
    ],
    ),
    ),

    // Chat messages
    Expanded(
    child: Stack(
    children: [
    // Messages list
    ListView.builder(
    controller: _scrollController,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
    itemCount: _messages.length,
    itemBuilder: (context, index) {
    final message = _messages[index];
    final isUser = message['sender'] == 'user';
    final timestamp = message['timestamp'] as Timestamp?;
    final gradientIndex = message['gradientIndex'] as int? ?? 0;

    final gradientColors = isUser
    ? userGradient
        : botGradients[gradientIndex % botGradients.length];

    // Handle suggested replies for bot messages
    final bool isLastMessage = index == _messages.length - 1;
    final bool showSuggestions = !isUser && isLastMessage && !_isLoading;

    return Align(
    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
    margin: const EdgeInsets.only(bottom: 20),
    constraints: BoxConstraints(
    maxWidth: MediaQuery.of(context).size.width * 0.8,
    ),
    child: Card(
    elevation: 2,
    shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
    ),
    margin: EdgeInsets.zero,
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    // Header with avatar
    Container(
    decoration: BoxDecoration(
    gradient: LinearGradient(
    colors: gradientColors,
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    ),
    borderRadius: const BorderRadius.only(
    topLeft: Radius.circular(16),
    topRight: Radius.circular(16),
    ),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    child: Row(
    mainAxisSize: MainAxisSize.max,
    children: [
    // Avatar
    CircleAvatar(
    backgroundColor: Colors.white.withOpacity(0.3),
    radius: 14,
    child: Icon(
    isUser ? Icons.person : Icons.smart_toy,
    size: 16,
    color: Colors.white,
    ),
    ),
    const SizedBox(width: 8),
    // Name and time
    Expanded(
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Text(
    isUser ? 'You' : 'EduSpark AI',
    style: const TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.bold,
    fontSize: 13,
    ),
    ),
    if (timestamp != null)
    Text(
    _formatTime(timestamp),
    style: TextStyle(
    color: Colors.white.withOpacity(0.8),
    fontSize: 11,
    ),
    ),
    ],
    ),
    ),
    ],
    ),
    ),

    // Message content
    Container(
    padding: const EdgeInsets.all(14),
    decoration: const BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.only(
    bottomLeft: Radius.circular(16),
    bottomRight: Radius.circular(16),
    ),
    ),
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    // Message text
    Text(
    message['text'] as String,
    style: TextStyle(
    fontSize: 14,
    height: 1.4,
    color: Colors.grey.shade800,
    ),
    ),

    // Resources section for bot messages
    if (!isUser && currentResources.isNotEmpty) ...[
    const SizedBox(height: 12),
    const Divider(),
    const SizedBox(height: 6),
    Row(
    children: [
    Icon(Icons.link, size: 14, color: Colors.grey.shade700),
    const SizedBox(width: 6),
    Text(
    'Resources:',
    style: TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.bold,
    color: Colors.grey.shade700,
    ),
    ),
    ],
    ),
    const SizedBox(height: 8),
    // Resource chips
    Wrap(
    spacing: 8,
    runSpacing: 8,
    children: currentResources
        .take(3) // Limit to first 3 resources
        .map((resource) => InkWell(
    onTap: () => _launchUrl(resource),
    child: Container(
    padding: const EdgeInsets.symmetric(
    horizontal: 10,
    vertical: 6,
    ),
    decoration: BoxDecoration(
    color: veryLightBlue,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
    color: accentBlue.withOpacity(0.3),
    width: 1,
    ),
    ),
    child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
    Icon(
    _getResourceIcon(resource),
    size: 14,
    color: primaryBlue,
    ),
    const SizedBox(width: 6),
    Text(
    _getResourceDisplayName(resource),
    style: const TextStyle(
    fontSize: 12,
    color: primaryBlue,
    ),
    ),
    ],
    ),
    ),
    ))
        .toList(),
    ),
    ],

    // Quick reply suggestions
    if (showSuggestions) ...[
    const SizedBox(height: 16),
    const Text(
    'Quick questions:',
    style: TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.bold,
    color: darkBlue,
    ),
    ),
    const SizedBox(height: 8),
    SizedBox(
    height: 36,
    child: ListView.builder(
    scrollDirection: Axis.horizontal,
    itemCount: _commonQuestions.length,
    itemBuilder: (context, index) {
    return Padding(
    padding: const EdgeInsets.only(right: 8),
    child: InkWell(
    onTap: () => _sendMessage(_commonQuestions[index]),
    borderRadius: BorderRadius.circular(18),
    child: Container(
    padding: const EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 8,
    ),
    decoration: BoxDecoration(
    gradient: LinearGradient(
    colors: [
    primaryBlue.withOpacity(0.1),
    accentBlue.withOpacity(0.1),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(
    color: primaryBlue.withOpacity(0.3),
    width: 1,
    ),
    ),
    child: Text(
    _commonQuestions[index],
    style: TextStyle(
    fontSize: 12,
    color: primaryBlue.shade800,
    ),
    ),
    ),
    ),
    );
    },
    ),
    ),
    ],
    ],
    ),
    ),
    ],
    ),
    ),
    ),
    );
    },
    ),

    // Typing indicator
    if (_isLoading)
    Positioned(
    bottom: 16,
    left: 16,
    child: Card(
    shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
    ),
    child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
    CircleAvatar(
    backgroundColor: primaryBlue.withOpacity(0.1),
    radius: 14,
    child: const Icon(
    Icons.smart_toy,
    size: 16,
    color: primaryBlue,
    ),
    ),
    const SizedBox(width: 12),
    _buildTypingDots(),
    ],
    ),
    ),
    ),
    ),

    // Scroll to bottom button
    if (_showScrollToBottom)
    Positioned(
    bottom: 16,
    right: 16,
    child: FloatingActionButton.small(
    backgroundColor: primaryBlue,
    elevation: 4,
    onPressed: _scrollToBottom,
    child: const Icon(
    Icons.keyboard_arrow_down,
    color: Colors.white,
    ),
    ),
    ),
    ],
    ),
    ),

    // Message input bar
    Container(
    decoration: BoxDecoration(
    color: Colors.white,
    boxShadow: [
    BoxShadow(
    color: Colors.black.withOpacity(0.05),
    blurRadius: 10,
    offset: const Offset(0, -2),
    ),
    ],
    ),
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
    child: Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
    // Message input field
    Expanded(
    child: Container(
    decoration: BoxDecoration(
    color: Colors.grey.shade100,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(
    color: Colors.grey.shade300,
    width: 1,
    ),
    ),
      child: TextField(
        controller: _messageController,
        maxLines: 4,
        minLines: 1,
        textCapitalization: TextCapitalization.sentences,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.send,
        onSubmitted: (_) => _sendMessage(),
        style: TextStyle(
          fontSize: 15,
          color: Colors.grey.shade800,
        ),
        decoration: InputDecoration(
          hintText: 'Type your question...',
          hintStyle: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 15,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          border: InputBorder.none,
          isDense: true,
        ),
      ),
    ),
    ),
      const SizedBox(width: 8),

      // Send button
      Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: userGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: userGradient[0].withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _isLoading ? null : _sendMessage,
            child: const Center(
              child: Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    ],
    ),
    ),
            ],
        ),
    );
  }

  // Animated typing indicator dots
  Widget _buildTypingDots() {
    return AnimatedBuilder(
      animation: _dotAnimation,
      builder: (context, child) {
        return Row(
          children: List.generate(3, (index) {
            final delay = index * 0.3;
            final transformValue = _calculateDotAnimation(delay);

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: Color.lerp(
                  Colors.grey.shade400,
                  primaryBlue,
                  transformValue,
                ),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }

  // Calculate animation value with delay
  double _calculateDotAnimation(double delay) {
    final value = _dotAnimation.value;
    final adjustedValue = (value - delay) % 1;
    return adjustedValue < 0 ? 0 : (adjustedValue > 1 ? 1 : adjustedValue);
  }

  Future<void> _launchUrl(String url) async {
    try {
      // Make sure URL has protocol
      final formattedUrl = url.startsWith('http://') || url.startsWith('https://')
          ? url
          : 'https://$url';

      final uri = Uri.parse(formattedUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open: $url'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening URL: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  IconData _getResourceIcon(String resource) {
    final resourceLower = resource.toLowerCase();
    if (resourceLower.contains('video') ||
        resourceLower.contains('youtube') ||
        resourceLower.contains('youtu.be')) {
      return Icons.video_library;
    } else if (resourceLower.contains('book') ||
        resourceLower.contains('pdf')) {
      return Icons.menu_book;
    } else if (resourceLower.contains('article') ||
        resourceLower.contains('blog') ||
        resourceLower.contains('medium')) {
      return Icons.article;
    } else if (resourceLower.contains('github') ||
        resourceLower.contains('code')) {
      return Icons.code;
    } else if (resourceLower.contains('doc') ||
        resourceLower.contains('drive')) {
      return Icons.description;
    } else {
      return Icons.link;
    }
  }

  String _getResourceDisplayName(String resource) {
    // Extract domain name from URL for better display
    try {
      if (resource.startsWith('http://') || resource.startsWith('https://')) {
        final uri = Uri.parse(resource);
        final host = uri.host;

        // Remove www. prefix if present
        final displayHost = host.startsWith('www.')
            ? host.substring(4)
            : host;

        // Extract path for youtube or specific sites
        if (host.contains('youtube.com') && uri.pathSegments.isNotEmpty) {
          return 'YouTube Video';
        } else if (host.contains('github.com') && uri.pathSegments.length >= 2) {
          return 'GitHub: ${uri.pathSegments.skip(1).join('/')}';
        } else if (host.contains('docs.google.com')) {
          return 'Google Docs';
        } else if (host.contains('drive.google.com')) {
          return 'Google Drive';
        } else if (host.contains('medium.com')) {
          return 'Medium Article';
        }

        // Default to domain name
        return displayHost;
      }

      // If not a URL, just return the resource text
      return resource.length > 25
          ? '${resource.substring(0, 22)}...'
          : resource;
    } catch (e) {
      // If parsing fails, just return the original
      return resource.length > 25
          ? '${resource.substring(0, 22)}...'
          : resource;
    }
  }
}

// Extensions to add color operations
extension ColorExtension on Color {
  Color get shade800 {
    int r = (this.red * 0.8).round().clamp(0, 255);
    int g = (this.green * 0.8).round().clamp(0, 255);
    int b = (this.blue * 0.8).round().clamp(0, 255);
    return Color.fromARGB(this.alpha, r, g, b);
  }
}

// Suggestion chip widget for quick replies
class SuggestionChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const SuggestionChip({
    super.key,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: veryLightBlue,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: accentBlue.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: primaryBlue,
          ),
        ),
      ),
    );
  }
}