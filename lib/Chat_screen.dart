import 'dart:async'; // For Timer
import 'dart:io'; // For File class
import 'package:flutter/material.dart';
import 'dart:ui'; // For ImageFilter
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart'; // For uploads/deletes
import 'package:image_picker/image_picker.dart'; // For images/videos
import 'package:file_picker/file_picker.dart'; // For audio files
import 'package:intl/intl.dart'; // For date formatting
import 'package:uuid/uuid.dart'; // For unique filenames
import 'package:path/path.dart' as p; // For getting filename extension
import 'package:permission_handler/permission_handler.dart'; // For permissions
import 'package:record/record.dart'; // For audio recording

// Import models, constants, widgets
import 'message.dart'; // Ensure updated with 'isRead' and 'readTimestamp' fields
import 'audio_player_widget.dart';
import 'video_player_widget.dart';
import 'full_screen_image_viewer.dart';
import 'ProfileScreen.dart';

// Updated color palette
class AppColors {
  static const Color primaryBlue = Color(0xFF1976D2);
  static const Color lightBlue = Color(0xFF64B5F6);
  static const Color veryLightBlue = Color(0xFFE3F2FD);
  static const Color darkBlue = Color(0xFF0D47A1);
  static const Color accentBlue = Color(0xFF29B6F6);

  // Additional colors
  static const Color textPrimary = Color(0xFF263238);
  static const Color textSecondary = Color(0xFF607D8B);
  static const Color background = Color(0xFFF5F7FA);
  static const Color cardBackground = Colors.white;
  static const Color shadowColor = Color(0xFF000000);
  static const Color errorColor = Color(0xFFD32F2F);
  static const Color successColor = Color(0xFF388E3C);
  static const Color readBlue = Color(0xFF64B5F6); // Color for read receipts
}

// Custom painter for the arc design in the header
class HeaderArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.05),
          Colors.white.withOpacity(0.2),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    // Main arc
    final Path mainArc = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height * 0.7)
      ..quadraticBezierTo(
          size.width * 0.45, size.height * 0.75, size.width * 0.8, size.height * 0.6)
      ..quadraticBezierTo(size.width * 0.98, size.height * 0.5, size.width, size.height * 0.65)
      ..lineTo(size.width, size.height)
      ..close();

    // Second arc (decoration)
    final Path secondaryArc = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height * 0.8)
      ..quadraticBezierTo(size.width * 0.3, size.height * 0.9, size.width * 0.6, size.height * 0.75)
      ..quadraticBezierTo(size.width * 0.85, size.height * 0.65, size.width, size.height * 0.8)
      ..lineTo(size.width, size.height)
      ..close();

    // Draw the arcs
    canvas.drawPath(mainArc, paint);

    // Change the opacity for the second arc
    paint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.white.withOpacity(0.1),
        Colors.white.withOpacity(0.2),
      ],
    ).createShader(Rect.fromLTWH(0, size.height * 0.7, size.width, size.height * 0.3));

    canvas.drawPath(secondaryArc, paint);

    // Small decorative dots
    final dotPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.4), 3, dotPaint);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.25), 4, dotPaint);
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.4), 5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ChatScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;

  const ChatScreen({
    Key? key,
    required this.otherUserId,
    required this.otherUserName,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = Uuid();

  // Audio Recording State
  late AudioRecorder _audioRecorder;
  bool _isRecording = false;
  String? _recordingPath;
  Timer? _recordingTimer;
  Duration _recordingDuration = Duration.zero;

  // Upload State
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  // Input Mode State
  bool _showMicButton = true;

  // Block Status
  bool _isUserBlocked = false;
  bool _amIBlocked = false;
  bool _isCheckingBlockStatus = true;

  // Read Status Tracking
  StreamSubscription<QuerySnapshot>? _readStatusSubscription;
  String? _lastSeenMessageId;
  bool _hasNewMessages = false;

  // Active status variables
  bool _isUserActive = false;
  Timer? _presenceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audioRecorder = AudioRecorder();

    // Optimize controller listener to reduce setState calls
    _messageController.addListener(_updateInputButton);
    _updateInputButton();

    // Check block status when screen loads
    _checkBlockStatus();

    // Update user's active status
    _updateUserPresence(true);
    // Start timer to update presence periodically
    _startPresenceTimer();

    // Mark messages as read when chat is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isUserBlocked && !_amIBlocked) {
        _markMessagesAsRead();
        _listenForReadStatusChanges();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.removeListener(_updateInputButton);
    _messageController.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    _recordingTimer?.cancel();
    _readStatusSubscription?.cancel();
    _presenceTimer?.cancel();

    // Update user's inactive status when leaving
    _updateUserPresence(false);

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-check permissions when app resumes
      _checkPermissions();
      // Re-check block status when app resumes
      _checkBlockStatus();
      // Mark messages as read when app resumes
      if (!_isUserBlocked && !_amIBlocked) {
        _markMessagesAsRead();
      }
      // Update user's active status
      _updateUserPresence(true);
      _startPresenceTimer();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      // Update user's inactive status
      _updateUserPresence(false);
      _presenceTimer?.cancel();
    }
  }

  // Start timer to update user presence every 4 minutes
  void _startPresenceTimer() {
    _presenceTimer?.cancel();
    _presenceTimer = Timer.periodic(Duration(minutes: 4), (timer) {
      _updateUserPresence(true);
    });
  }

  // Update user's presence in Firestore
  Future<void> _updateUserPresence(bool isActive) async {
    if (currentUser == null) return;

    try {
      await _firestore.collection('users').doc(currentUser!.uid).update({
        'lastActive': FieldValue.serverTimestamp(),
        'isOnline': isActive,
      });
    } catch (e) {
      print("Error updating user presence: $e");
    }
  }

  // Function to mark received messages as read
  Future<void> _markMessagesAsRead() async {
    if (currentUser == null || currentUser!.uid == widget.otherUserId) return;

    String chatId = _getChatId(currentUser!.uid, widget.otherUserId);

    try {
      // Get all unread messages sent by the other user
      final unreadMessages = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('senderId', isEqualTo: widget.otherUserId)
          .where('receiverId', isEqualTo: currentUser!.uid)
          .where('isRead', isEqualTo: false)
          .get();

      // Create a batch to update all messages at once
      if (unreadMessages.docs.isNotEmpty) {
        WriteBatch batch = _firestore.batch();
        final Timestamp now = Timestamp.now();

        for (final doc in unreadMessages.docs) {
          batch.update(doc.reference, {
            'isRead': true,
            'readTimestamp': now,
          });
        }

        await batch.commit();
        print('Marked ${unreadMessages.docs.length} messages as read');
      }
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  // Listen for changes in read status of sent messages
  void _listenForReadStatusChanges() {
    if (currentUser == null) return;

    String chatId = _getChatId(currentUser!.uid, widget.otherUserId);

    _readStatusSubscription = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('senderId', isEqualTo: currentUser!.uid)
        .where('isRead', isEqualTo: true)
        .orderBy('readTimestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        if (mounted) {
          setState(() {
            _lastSeenMessageId = snapshot.docs.first.id;
          });
        }
      }
    }, onError: (e) {
      print('Error in read status subscription: $e');
    });
  }

  // Function to check if either user has blocked the other
  Future<void> _checkBlockStatus() async {
    if (currentUser == null) return;

    setState(() {
      _isCheckingBlockStatus = true;
    });

    try {
      // Check if current user blocked the other user
      final currentUserDoc = await _firestore.collection('users').doc(currentUser!.uid).get();
      if (currentUserDoc.exists) {
        final userData = currentUserDoc.data() as Map<String, dynamic>?;
        if (userData != null && userData['blockedUsers'] is List) {
          List<dynamic> blockedUsers = userData['blockedUsers'];
          _isUserBlocked = blockedUsers.contains(widget.otherUserId);
        }
      }

      // Check if current user is blocked by the other user
      final otherUserDoc = await _firestore.collection('users').doc(widget.otherUserId).get();
      if (otherUserDoc.exists) {
        final userData = otherUserDoc.data() as Map<String, dynamic>?;
        if (userData != null && userData['blockedUsers'] is List) {
          List<dynamic> blockedUsers = userData['blockedUsers'];
          _amIBlocked = blockedUsers.contains(currentUser!.uid);
        }
      }
    } catch (e) {
      print("Error checking block status: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingBlockStatus = false;
        });
      }
    }
  }

  // New method to proactively check permissions
  Future<void> _checkPermissions() async {
    // Can be expanded to check various permissions as needed
    if (Platform.isAndroid) {
      await Permission.storage.status;
      await Permission.camera.status;
      await Permission.microphone.status;
    } else if (Platform.isIOS) {
      await Permission.photos.status;
      await Permission.camera.status;
      await Permission.microphone.status;
    }
  }

  // --- Helper Functions ---
  void _updateInputButton() {
    final bool shouldShowMic = _messageController.text.trim().isEmpty;

    // Only update state if the button type actually needs to change
    if (mounted && shouldShowMic != _showMicButton) {
      setState(() {
        _showMicButton = shouldShowMic;
      });
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  String _formatMessageTimestamp(Timestamp timestamp) {
    return DateFormat('h:mm a').format(timestamp.toDate());
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  String _formatDateSeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCompare = DateTime(date.year, date.month, date.day);

    if (dateToCompare == today) {
      return 'Today';
    } else if (dateToCompare == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('MMMM d, y').format(date);
    }
  }

  String _getChatId(String userId1, String userId2) {
    return userId1.compareTo(userId2) < 0
        ? '$userId1-$userId2'
        : '$userId2-$userId1';
  }

  // --- Build Method (Main UI) ---
  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return _buildErrorScaffold("Authentication Required. Please log in.");
    }
    if (widget.otherUserId.isEmpty) {
      print("Error: ChatScreen received empty otherUserId.");
      return _buildErrorScaffold("Cannot load chat.\nInvalid user specified.");
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.veryLightBlue, AppColors.background],
          ),
        ),
        child: Column(
          children: [
            Expanded(child: _buildMessagesList()),
            if (_isUploading) _buildUploadProgressIndicator(),
            if (_isRecording) _buildRecordingIndicator(),
            _buildMessageInputArea(),
          ],
        ),
      ),
    );
  }

  PreferredSize _buildAppBar() {
    return PreferredSize(
      preferredSize: Size.fromHeight(70.0),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.darkBlue,
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowColor.withOpacity(0.3),
              blurRadius: 5,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                // Back button
                Container(
                  height: 36,
                  width: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.white, size: 18),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                  ),
                ),

                SizedBox(width: 16),

                // Username with online status
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProfileScreen(
                            username: widget.otherUserName,
                            userId: widget.otherUserId,
                            isCurrentUser: false,
                          ),
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.otherUserName,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2),
                        StreamBuilder<DocumentSnapshot>(
                          stream: _firestore.collection('users').doc(widget.otherUserId).snapshots(),
                          builder: (context, snapshot) {
                            bool isOnline = false;
                            String statusText = 'Offline';

                            if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
                              final userData = snapshot.data!.data() as Map<String, dynamic>?;
                              if (userData != null) {
                                // First check explicit online status if available
                                if (userData['isOnline'] == true) {
                                  isOnline = true;
                                } else if (userData['lastActive'] is Timestamp) {
                                  final lastActive = (userData['lastActive'] as Timestamp).toDate();
                                  final now = DateTime.now();
                                  final difference = now.difference(lastActive);

                                  // User is online if lastActive is within 5 minutes
                                  isOnline = difference.inMinutes <= 5;

                                  if (!isOnline) {
                                    if (difference.inMinutes < 1) {
                                      statusText = 'Just now';
                                    } else if (difference.inHours < 1) {
                                      statusText = '${difference.inMinutes}m ago';
                                    } else if (difference.inDays < 1) {
                                      statusText = '${difference.inHours}h ago';
                                    } else if (difference.inDays < 7) {
                                      statusText = '${difference.inDays}d ago';
                                    } else {
                                      statusText = DateFormat('MMM d').format(lastActive);
                                    }
                                  }
                                }
                              }
                            }

                            return Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: isOnline ? Colors.greenAccent : Colors.grey,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  isOnline ? 'Online' : statusText,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // Menu button
                Container(
                  height: 36,
                  width: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.more_vert, color: Colors.white, size: 20),
                    onPressed: _showChatOptions,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showChatOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Divider(height: 1, indent: 70, endIndent: 20),

            // Block/Unblock user based on current status
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _isUserBlocked
                      ? AppColors.primaryBlue.withOpacity(0.1)
                      : AppColors.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _isUserBlocked ? Icons.person_add : Icons.block,
                  color: _isUserBlocked ? AppColors.primaryBlue : AppColors.errorColor,
                ),
              ),
              title: Text(
                _isUserBlocked ? 'Unblock user' : 'Block user',
                style: TextStyle(
                  color: _isUserBlocked ? AppColors.primaryBlue : AppColors.errorColor,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                if (_isUserBlocked) {
                  _showUnblockUserConfirmation();
                } else {
                  _showBlockUserConfirmation();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Scaffold _buildErrorScaffold(String message) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Error", style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: AppColors.primaryBlue,
      ),
      body: Center(
        child: Container(
          padding: EdgeInsets.all(24),
          margin: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowColor.withOpacity(0.1),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                color: AppColors.errorColor,
                size: 56,
              ),
              SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.errorColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text("Go Back"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- UPDATED: Messages List Builder ---
  Widget _buildMessagesList() {
    // If still checking block status, show loading indicator
    if (_isCheckingBlockStatus) {
      return Center(
        child: CircularProgressIndicator(
          color: AppColors.primaryBlue,
          strokeWidth: 3,
        ),
      );
    }

    // If either user has blocked the other, display appropriate message
    if (_isUserBlocked || _amIBlocked) {
      return Center(
          child: Container(
            padding: EdgeInsets.all(24),
            margin: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowColor.withOpacity(0.08),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
            Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.errorColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.block,
              size: 40,
              color: AppColors.errorColor,
            ),
          ),
          SizedBox(height: 24),
          Text(
            _isUserBlocked
                ? 'You blocked ${widget.otherUserName}'
                : 'You cannot message this user',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),
          Text(
            _isUserBlocked
                ? 'You cannot exchange messages until you unblock them.'
                : 'This user has blocked you from sending messages.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 24),
                  if (_isUserBlocked)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _showUnblockUserConfirmation,
                      child: Text("Unblock User"),
                    ),
                ],
            ),
          ),
      );
    }

    String currentUserId = currentUser!.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: _getMessagesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: AppColors.primaryBlue,
              strokeWidth: 3,
            ),
          );
        }

        if (snapshot.hasError) {
          print("Chat Stream Error: ${snapshot.error}");
          return Center(
            child: Container(
              padding: EdgeInsets.all(16),
              margin: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, color: AppColors.errorColor),
                  SizedBox(height: 8),
                  Text(
                    'Error loading messages.',
                    style: TextStyle(color: AppColors.errorColor),
                  ),
                  SizedBox(height: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      // Refresh the stream
                      setState(() {});
                    },
                    child: Text("Try Again"),
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyChatPlaceholder();
        }

        // Process messages, filtering locally deleted ones
        var messageDocs = snapshot.data!.docs;
        List<QueryDocumentSnapshot> visibleMessages = messageDocs.where((doc) {
          var data = doc.data() as Map<String, dynamic>? ?? {};
          List<dynamic>? deletedForList = data['deletedFor'] as List<dynamic>?;
          return deletedForList == null || !deletedForList.contains(currentUserId);
        }).toList();

        if (visibleMessages.isEmpty) {
          return _buildEmptyChatPlaceholder();
        }

        // Auto-scroll to bottom for new messages
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients &&
              _scrollController.position.maxScrollExtent > 0 &&
              _scrollController.position.extentAfter < 200) {
            _scrollController.animateTo(
              _scrollController.position.minScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });

        // Check if we have new messages from the other user and mark them as read
        for (var doc in visibleMessages) {
          var data = doc.data() as Map<String, dynamic>;
          if (data['senderId'] == widget.otherUserId &&
              data['receiverId'] == currentUser!.uid &&
              (data['isRead'] == null || data['isRead'] == false)) {
            _hasNewMessages = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _markMessagesAsRead();
            });
            break;
          }
        }

        return ListView.builder(
          controller: _scrollController,
          reverse: true,
          padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
          itemCount: visibleMessages.length,
          itemBuilder: (context, index) {
            final messageDoc = visibleMessages[index];
            Message message;

            try {
              var messageData = messageDoc.data() as Map<String, dynamic>? ?? {};
              message = Message.fromMap(messageData);
            } catch (e) {
              print("Error parsing message at index $index for doc ${messageDoc.id}: $e");
              print("Message Data: ${messageDoc.data()}");
              return _buildErrorBubble();
            }

            final bool isMe = message.senderId == currentUserId;
            bool showDateSeparator = false;
            final currentMessageDate = message.timestamp.toDate();

            // Date separator logic
            if (index == visibleMessages.length - 1) {
              showDateSeparator = true;
            } else {
              final nextMessageDoc = visibleMessages[index + 1];
              var nextMessageData = nextMessageDoc.data() as Map<String, dynamic>?;
              if (nextMessageData != null && nextMessageData['timestamp'] is Timestamp) {
                final nextMessageTimestamp = nextMessageData['timestamp'] as Timestamp;
                final nextMessageDate = nextMessageTimestamp.toDate();
                if (!_isSameDay(currentMessageDate, nextMessageDate)) {
                  showDateSeparator = true;
                }
              }
            }

            // Check if this is the last read message
            bool isLastReadMessage = isMe && message.isRead &&
                messageDoc.id == _lastSeenMessageId;

            final messageBubble = _buildMessageBubble(message, isMe, messageDoc.id, isLastReadMessage);

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showDateSeparator)
                  _buildDateSeparatorWidget(currentMessageDate),
                messageBubble,
              ],
            );
          },
        );
      },
    );
  }

  // Block/Unblock functionality
  void _showBlockUserConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10.0,
                  offset: Offset(0.0, 10.0),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.errorColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.block,
                    color: AppColors.errorColor,
                    size: 40,
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  'Block ${widget.otherUserName}?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                Text(
                  'They won\'t be able to message you and you won\'t see their messages.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(fontSize: 16),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.errorColor,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Block',
                          style: TextStyle(fontSize: 16),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          _blockUser();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showUnblockUserConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10.0,
                  offset: Offset(0.0, 10.0),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_add,
                    color: AppColors.primaryBlue,
                    size: 40,
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  'Unblock ${widget.otherUserName}?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                Text(
                  'They will be able to message you again.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(fontSize: 16),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Unblock',
                          style: TextStyle(fontSize: 16),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          _unblockUser();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                  strokeWidth: 3,
                ),
                SizedBox(width: 16),
                Flexible(
                  child: Text(
                    message,
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _blockUser() async {
    if (currentUser == null) return;

    try {
      // Show loading indicator
      _showLoadingDialog('Blocking user...');

      // Update user's blocked list in Firestore
      await _firestore.collection('users').doc(currentUser!.uid).update({
        'blockedUsers': FieldValue.arrayUnion([widget.otherUserId]),
      });

      // Update local state
      setState(() {
        _isUserBlocked = true;
      });

      // Hide loading indicator
      Navigator.of(context).pop();

      // Show confirmation
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${widget.otherUserName} has been blocked'),
        backgroundColor: AppColors.successColor,
        duration: Duration(seconds: 2),
      ));
    } catch (e) {
      // Hide loading indicator if showing
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Show error
      _showErrorSnackbar('Failed to block user. Please try again.', isError: true);
      print('Error blocking user: $e');
    }
  }

  Future<void> _unblockUser() async {
    if (currentUser == null) return;

    try {
      // Show loading indicator
      _showLoadingDialog('Unblocking user...');

      // Update user's blocked list in Firestore
      await _firestore.collection('users').doc(currentUser!.uid).update({
        'blockedUsers': FieldValue.arrayRemove([widget.otherUserId]),
      });

      // Update local state
      setState(() {
        _isUserBlocked = false;
      });

      // Hide loading indicator
      Navigator.of(context).pop();

      // Show confirmation
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${widget.otherUserName} has been unblocked'),
        backgroundColor: AppColors.successColor,
        duration: Duration(seconds: 2),
      ));
    } catch (e) {
      // Hide loading indicator if showing
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Show error
      _showErrorSnackbar('Failed to unblock user. Please try again.', isError: true);
      print('Error unblocking user: $e');
    }
  }

  Widget _buildDateSeparatorWidget(DateTime date) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 14.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: AppColors.primaryBlue.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16.0),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowColor.withOpacity(0.05),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          _formatDateSeparator(date),
          style: TextStyle(
            color: AppColors.primaryBlue,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyChatPlaceholder() {
    return Center(
      child: Container(
        padding: EdgeInsets.all(24),
        margin: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowColor.withOpacity(0.08),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.veryLightBlue,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline,
                size: 48,
                color: AppColors.primaryBlue,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'No messages yet',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Start the conversation with ${widget.otherUserName}!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(Icons.send),
              label: Text("Say Hello"),
              onPressed: () {
                _messageController.text = "Hello ${widget.otherUserName}! How are you?";
                _updateInputButton();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBubble() {
    return Container(
      alignment: Alignment.center,
      padding: EdgeInsets.all(12),
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.errorColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.errorColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            color: AppColors.errorColor,
            size: 16,
          ),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              "Error displaying message",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.errorColor,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message, bool isMe, String messageId, bool isLastReadMessage) {
    final BorderRadius messageBorderRadius = BorderRadius.only(
      topLeft: Radius.circular(20),
      topRight: Radius.circular(20),
      bottomLeft: isMe ? Radius.circular(20) : Radius.circular(5),
      bottomRight: isMe ? Radius.circular(5) : Radius.circular(20),
    );

    Widget messageContent;
    if (message.type == 'deleted') {
      messageContent = _buildDeletedContent(isMe);
    } else {
      switch (message.type) {
        case 'image':
          messageContent = _buildImageContent(message, isMe);
          break;
        case 'video':
          messageContent = _buildVideoPlaceholder(message, isMe);
          break;
        case 'audio':
          messageContent = _buildAudioContent(message, isMe);
          break;
        case 'text':
        default:
          messageContent = _buildTextContent(message, isMe);
          break;
      }
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            GestureDetector(
              onLongPress: () {
                if (message.type != 'deleted' && !_isUploading && !_isRecording) {
                  _showDeleteOptions(context, message, isMe, messageId);
                }
              },
              child: Container(
                margin: EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                ),
                decoration: BoxDecoration(
                  color: isMe ? AppColors.primaryBlue : AppColors.cardBackground,
                  borderRadius: messageBorderRadius,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadowColor.withOpacity(0.1),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    messageContent,
                    if (message.type != 'deleted') ...[
                      SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatMessageTimestamp(message.timestamp),
                            style: TextStyle(
                              color: isMe ? Colors.white70 : AppColors.textSecondary.withOpacity(0.8),
                              fontSize: 10,
                            ),
                          ),
                          if (isMe) ...[
                            SizedBox(width: 4),
                            Text(
                              message.isRead ? "Seen" : "Sent",
                              style: TextStyle(
                                color: message.isRead ? Colors.white : Colors.white70,
                                fontSize: 10,
                                fontWeight: message.isRead ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
        // "Seen" indicator for the last read message
        if (isLastReadMessage)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                margin: EdgeInsets.only(right: 16, top: 2, bottom: 8),
                child: Text(
                  'Seen at ${message.readTimestamp != null ? _formatMessageTimestamp(message.readTimestamp!) : "now"}',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildTextContent(Message message, bool isMe) {
    return Text(
      message.content ?? "[Empty Message]",
      style: TextStyle(
        color: isMe ? Colors.white : AppColors.textPrimary,
        fontSize: 16,
      ),
    );
  }

  Widget _buildDeletedContent(bool isMe) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.white.withOpacity(0.15)
            : AppColors.textSecondary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.block,
            size: 14,
            color: isMe ? Colors.white70 : AppColors.textSecondary.withOpacity(0.8),
          ),
          SizedBox(width: 6),
          Text(
            "Message deleted",
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: isMe ? Colors.white70 : AppColors.textSecondary.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageContent(Message message, bool isMe) {
    if (message.mediaUrl == null || message.mediaUrl!.isEmpty) {
      return Text(
        "[Image unavailable]",
        style: TextStyle(
          color: isMe ? Colors.white70 : AppColors.errorColor,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FullScreenImageViewer(imageUrl: message.mediaUrl!),
        ),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.3,
          maxWidth: MediaQuery.of(context).size.width * 0.6,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                message.mediaUrl!,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: isMe
                          ? Colors.white.withOpacity(0.2)
                          : AppColors.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isMe ? Colors.white : AppColors.primaryBlue,
                        ),
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  print("Error loading image ${message.mediaUrl}: $error");
                  return Container(
                    height: 120,
                    width: 120,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isMe
                          ? Colors.white.withOpacity(0.2)
                          : AppColors.errorColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image,
                          color: isMe
                              ? Colors.white70
                              : AppColors.errorColor,
                          size: 32,
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Failed to load image",
                          style: TextStyle(
                            color: isMe
                                ? Colors.white70
                                : AppColors.errorColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.fullscreen,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlaceholder(Message message, bool isMe) {
    if (message.mediaUrl == null || message.mediaUrl!.isEmpty) {
      return Text(
        "[Video unavailable]",
        style: TextStyle(
          color: isMe ? Colors.white70 : AppColors.errorColor,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => VideoPlayerScreen(videoUrl: message.mediaUrl!)
        ),
      ),
      child: Container(
        height: 150,
        width: 200,
        decoration: BoxDecoration(
          color: isMe ? Colors.black.withOpacity(0.3) : AppColors.primaryBlue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Blurred thumbnail could be added here if available
            Icon(
              Icons.play_circle_fill,
              color: isMe ? Colors.white.withOpacity(0.9) : AppColors.primaryBlue,
              size: 48,
            ),
            Positioned(
              bottom: 8,
              left: 8,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Video',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioContent(Message message, bool isMe) {
    if (message.mediaUrl == null || message.mediaUrl!.isEmpty) {
      return Text(
        "[Audio unavailable]",
        style: TextStyle(
          color: isMe ? Colors.white70 : AppColors.errorColor,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isMe ? Colors.white.withOpacity(0.15) : AppColors.veryLightBlue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: AudioPlayerWidget(
        sourceUrl: message.mediaUrl!,
        isMe: isMe,
        fileName: message.fileName,
      ),
    );
  }

  Widget _buildUploadProgressIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withOpacity(0.1),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_upload, color: AppColors.primaryBlue, size: 16),
              SizedBox(width: 8),
              Text(
                'Uploading media...',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Spacer(),
              Text(
                '${(_uploadProgress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          LinearProgressIndicator(
            value: _uploadProgress > 0 ? _uploadProgress : null,
            backgroundColor: AppColors.veryLightBlue,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withOpacity(0.1),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mic,
                  color: Colors.red,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Recording audio...",
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    _formatDuration(_recordingDuration),
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.stop_circle, color: Colors.red, size: 28),
            onPressed: () {
              if (_isRecording) {
                _stopRecording();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInputArea() {
    bool inputDisabled = _isUserBlocked || _amIBlocked || _isRecording;
    // Remove _isUploading from inputDisabled check for text inputs

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withOpacity(0.15),
            spreadRadius: 0,
            blurRadius: 12,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: _isUserBlocked || _amIBlocked
            ? Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Text(
            _isUserBlocked
                ? 'You blocked this user. Unblock to send messages.'
                : 'You cannot message this user.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        )
            : Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Attachment Button
            Container(
              decoration: BoxDecoration(
                color: AppColors.veryLightBlue,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(Icons.add, color: AppColors.primaryBlue),
                // Allow attaching media even when uploading text
                onPressed: (inputDisabled || (_isUploading && !_showMicButton)) ? null : _showAttachmentMenu,
                tooltip: 'Attach media',
                splashRadius: 24,
              ),
            ),
            SizedBox(width: 8),

            // Text Field
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.veryLightBlue,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _messageController.text.isEmpty
                        ? Colors.transparent
                        : AppColors.primaryBlue.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: TextField(
                  // Allow text input even when uploading other media
                  enabled: !inputDisabled && !(_isUploading && !_showMicButton),
                  controller: _messageController,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 1,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: _isRecording ? 'Recording...' : 'Type a message...',
                    hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.8)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: false,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    isDense: true,
                  ),
                  style: TextStyle(color: AppColors.textPrimary),
                  onSubmitted: (_) {
                    if (!_showMicButton) _sendTextMessage();
                  },
                ),
              ),
            ),
            SizedBox(width: 8),

            // Send / Mic Button
            _buildSendOrMicButton(),
          ],
        ),
      ),
    );
  }

  // Update send text message to check block status
  void _sendTextMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || currentUser == null || _isUploading || _isRecording) return;

    // Check block status before sending
    if (_isUserBlocked) {
      _showErrorSnackbar('Cannot send message. You have blocked this user.', isError: true);
      return;
    }

    if (_amIBlocked) {
      _showErrorSnackbar('Cannot send message. You have been blocked by this user.', isError: true);
      return;
    }

    // Clear the text first - do NOT set uploading state for text messages
    final String tempText = text;
    _messageController.clear();

    // Send the message without triggering the loading indicator
    await _sendMessage(text: tempText, type: 'text');
  }

  // Update the sendMessage function to handle text messages separately
  Future<void> _sendMessage({
    String? text,
    required String type,
    String? mediaUrl,
    String? fileName,
    String? storagePath,
  }) async {
    if (currentUser == null || widget.otherUserId.isEmpty) return;

    // For text messages, don't use a loading indicator
    bool isTextMessage = type == 'text';

    // Only set uploading state for media messages, not text
    if (!isTextMessage && mounted) {
      setState(() {
        _isUploading = true;
      });
    }

    final Timestamp now = Timestamp.now();
    String chatId = _getChatId(currentUser!.uid, widget.otherUserId);

    // Create the message with read status fields
    Message message = Message(
      senderId: currentUser!.uid,
      receiverId: widget.otherUserId,
      content: text,
      timestamp: now,
      type: type,
      mediaUrl: mediaUrl,
      fileName: fileName,
      storagePath: storagePath,
      deletedFor: [],
      isRead: false, // Initialize as unread
      readTimestamp: null, // No read timestamp initially
    );

    try {
      String lastMessagePreview = _getLastMessagePreview(type, text, fileName);

      // Use a batch write for atomicity
      WriteBatch batch = _firestore.batch();

      // Update chat document (last message info)
      DocumentReference chatDocRef = _firestore.collection('chats').doc(chatId);
      batch.set(chatDocRef, {
        'participants': [currentUser!.uid, widget.otherUserId],
        'lastMessageTimestamp': now,
        'lastMessageContent': lastMessagePreview,
        'lastSenderId': currentUser!.uid,
        'participantNames': {
          currentUser!.uid: currentUser!.displayName ?? "User ${currentUser!.uid.substring(0,4)}",
          widget.otherUserId: widget.otherUserName,
        },
        'participantIds': [currentUser!.uid, widget.otherUserId],
        'lastMessageIsRead': false, // Add read status to the chat document
      }, SetOptions(merge: true));

      // Add the actual message to the messages subcollection
      DocumentReference messageDocRef = chatDocRef.collection('messages').doc();
      batch.set(messageDocRef, message.toMap());

      await batch.commit();

      print("Message (type: $type) sent successfully to chat $chatId");

    } catch (e) {
      print("Error sending message (type: $type): $e");
      _showErrorSnackbar('Failed to send message. Please try again.', isError: true);

      if (type == 'text' && text != null && _messageController.text.isEmpty && mounted) {
        _messageController.text = text;
        _messageController.selection = TextSelection.fromPosition(
            TextPosition(offset: _messageController.text.length)
        );
        _updateInputButton();
      }
    } finally {
      // Only reset uploading state if this is a media message
      if (!isTextMessage && mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  Widget _buildSendOrMicButton() {
    // Only show loading for media uploads, not text messages
    if (_isUploading && !_showMicButton) {
      return Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.veryLightBlue,
          shape: BoxShape.circle,
        ),
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
          ),
        ),
      );
    } else if (_showMicButton) {
      return Listener(
        onPointerDown: (_) async {
          print("--- onPointerDown FIRED ---");
          bool permissionGranted = await _checkAndRequestMicPermission();
          if (permissionGranted && mounted) {
            _startRecording();
          } else if (mounted) {
            _showPermissionRequiredDialog(
                permission: 'microphone',
                requiredFor: 'recording audio messages'
            );
          }
        },
        onPointerUp: (_) {
          if (_isRecording) {
            print("--- onPointerUp FIRED ---");
            _stopRecording();
          } else {
            print("--- onPointerUp FIRED but wasn't recording ---");
          }
        },
        onPointerCancel: (_) {
          if (_isRecording) {
            print("--- onPointerCancel FIRED ---");
            _cancelRecording();
          }
        },
        child: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _isRecording ? Colors.red : AppColors.primaryBlue,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: (_isRecording ? Colors.red : AppColors.primaryBlue).withOpacity(0.4),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.mic,
            color: Colors.white,
            size: 24,
          ),
        ),
      );
    } else {
      return Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primaryBlue,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryBlue.withOpacity(0.4),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          onTap: _sendTextMessage,
          child: Icon(
            Icons.send,
            color: Colors.white,
            size: 24,
          ),
        ),
      );
    }
  }

  // --- Attachment and Media Picking ---
  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.image, color: AppColors.primaryBlue),
              ),
              title: Text('Send Image'),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.videocam, color: AppColors.primaryBlue),
              ),
              title: Text('Send Video'),
              onTap: () {
                Navigator.pop(context);
                _pickVideo();
              },
            ),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.audiotrack, color: AppColors.primaryBlue),
              ),
              title: Text('Send Audio'),
              onTap: () {
                Navigator.pop(context);
                _pickAudio();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      final File file = File(image.path);
      final String fileName = "${_uuid.v4()}${p.extension(image.path)}";
      await _uploadFile(file, fileName, 'image');
    } catch (e) {
      _showErrorSnackbar('Failed to pick image. Please try again.', isError: true);
      print('Error picking image: $e');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video == null) return;

      final File file = File(video.path);
      final String fileName = "${_uuid.v4()}${p.extension(video.path)}";
      await _uploadFile(file, fileName, 'video');
    } catch (e) {
      _showErrorSnackbar('Failed to pick video. Please try again.', isError: true);
      print('Error picking video: $e');
    }
  }

  Future<void> _pickAudio() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
      );
      if (result == null || result.files.single.path == null) return;

      final File file = File(result.files.single.path!);
      final String fileName = "${_uuid.v4()}${p.extension(result.files.single.path!)}";
      await _uploadFile(file, fileName, 'audio');
    } catch (e) {
      _showErrorSnackbar('Failed to pick audio. Please try again.', isError: true);
      print('Error picking audio: $e');
    }
  }

  Future<void> _uploadFile(File file, String fileName, String type) async {
    if (currentUser == null) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      final storagePath = 'chats/${_getChatId(currentUser!.uid, widget.otherUserId)}/$fileName';
      final Reference storageRef = _storage.ref().child(storagePath);
      final UploadTask uploadTask = storageRef.putFile(file);

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        if (mounted) {
          setState(() {
            _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
          });
        }
      }, onError: (e) {
        _showErrorSnackbar('Upload failed. Please try again.', isError: true);
        print('Upload error: $e');
      });

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      await _sendMessage(
        type: type,
        mediaUrl: downloadUrl,
        fileName: fileName,
        storagePath: storagePath,
      );
    } catch (e) {
      _showErrorSnackbar('Failed to upload $type. Please try again.', isError: true);
      print('Error uploading $type: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  Future<void> _startRecording() async {
    if (_isRecording) return;

    try {
      if (await _audioRecorder.hasPermission()) {
        final String fileName = "${_uuid.v4()}.m4a";
        final String path = await _getTemporaryPath(fileName);

        await _audioRecorder.start(
          const RecordConfig(),
          path: path,
        );

        setState(() {
          _isRecording = true;
          _recordingPath = path;
          _recordingDuration = Duration.zero;
        });

        _recordingTimer = Timer.periodic(Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() {
              _recordingDuration += Duration(seconds: 1);
            });
          }
        });
      } else {
        _showPermissionRequiredDialog(
          permission: 'microphone',
          requiredFor: 'recording audio messages',
        );
      }
    } catch (e) {
      _showErrorSnackbar('Failed to start recording. Please try again.', isError: true);
      print('Error starting recording: $e');
      if (mounted) {
        setState(() {
          _isRecording = false;
          _recordingPath = null;
        });
      }
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording || _recordingPath == null) return;

    try {
      await _audioRecorder.stop();
      _recordingTimer?.cancel();

      final File audioFile = File(_recordingPath!);
      final String fileName = "${_uuid.v4()}.m4a";
      await _uploadFile(audioFile, fileName, 'audio');

      // Clean up temporary file
      if (await audioFile.exists()) {
        await audioFile.delete();
      }
    } catch (e) {
      _showErrorSnackbar('Failed to save recording. Please try again.', isError: true);
      print('Error stopping recording: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRecording = false;
          _recordingPath = null;
          _recordingDuration = Duration.zero;
        });
      }
      _recordingTimer?.cancel();
    }
  }

  Future<void> _cancelRecording() async {
    if (!_isRecording || _recordingPath == null) return;

    try {
      await _audioRecorder.stop();
      _recordingTimer?.cancel();

      final File audioFile = File(_recordingPath!);
      if (await audioFile.exists()) {
        await audioFile.delete();
      }
    } catch (e) {
      print('Error cancelling recording: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRecording = false;
          _recordingPath = null;
          _recordingDuration = Duration.zero;
        });
      }
      _recordingTimer?.cancel();
    }
  }

  Future<bool> _checkAndRequestMicPermission() async {
    if (await Permission.microphone.isGranted) {
      return true;
    }

    PermissionStatus status = await Permission.microphone.request();
    return status.isGranted;
  }

  void _showPermissionRequiredDialog({
    required String permission,
    required String requiredFor,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Permission Required',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: Text(
            'Please grant $permission permission to enable $requiredFor.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryBlue,
              ),
              onPressed: () async {
                Navigator.of(context).pop();
                await openAppSettings();
              },
              child: Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteOptions(BuildContext context, Message message, bool isMe, String messageId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.delete, color: AppColors.errorColor),
              ),
              title: Text(
                'Delete for me',
                style: TextStyle(color: AppColors.errorColor),
              ),
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(messageId, message.storagePath, forEveryone: false);
              },
            ),
            if (isMe)
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.errorColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.delete_forever, color: AppColors.errorColor),
                ),
                title: Text(
                  'Delete for everyone',
                  style: TextStyle(color: AppColors.errorColor),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(messageId, message.storagePath, forEveryone: true);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMessage(String messageId, String? storagePath, {required bool forEveryone}) async {
    if (currentUser == null) return;

    try {
      String chatId = _getChatId(currentUser!.uid, widget.otherUserId);
      DocumentReference messageRef =
      _firestore.collection('chats').doc(chatId).collection('messages').doc(messageId);

      if (forEveryone) {
        // Delete for everyone: update message to 'deleted' type and clear content
        await messageRef.update({
          'type': 'deleted',
          'content': null,
          'mediaUrl': null,
          'fileName': null,
          'storagePath': null,
        });

        // Delete file from storage if applicable
        if (storagePath != null && storagePath.isNotEmpty) {
          try {
            await _storage.ref(storagePath).delete();
          } catch (e) {
            print('Error deleting file from storage: $e');
          }
        }

        // Update last message in chat if this was the latest message
        final latestMessageSnapshot = await _firestore
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();

        if (latestMessageSnapshot.docs.isNotEmpty) {
          final latestMessage = latestMessageSnapshot.docs.first;
          if (latestMessage.id == messageId) {
            await _firestore.collection('chats').doc(chatId).update({
              'lastMessageContent': 'Message deleted',
              'lastMessageTimestamp': latestMessage['timestamp'],
              'lastSenderId': latestMessage['senderId'],
            });
          }
        }
      } else {
        // Delete for me: add current user to deletedFor list
        await messageRef.update({
          'deletedFor': FieldValue.arrayUnion([currentUser!.uid]),
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Message deleted ${forEveryone ? 'for everyone' : 'for you'}'),
          backgroundColor: AppColors.successColor,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      _showErrorSnackbar('Failed to delete message. Please try again.', isError: true);
      print('Error deleting message: $e');
    }
  }

  Stream<QuerySnapshot> _getMessagesStream() {
    String chatId = _getChatId(currentUser!.uid, widget.otherUserId);
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  String _getLastMessagePreview(String type, String? content, String? fileName) {
    switch (type) {
      case 'image':
        return 'Image';
      case 'video':
        return 'Video';
      case 'audio':
        return 'Audio';
      case 'deleted':
        return 'Message deleted';
      case 'text':
      default:
        return content != null && content.isNotEmpty ? content : '[Empty Message]';
    }
  }

  void _showErrorSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
      content: Text(
      message,
      style: TextStyle(color: Colors.white),
    ),
    backgroundColor: isError ? AppColors.errorColor : AppColors.primaryBlue,
    duration: Duration(seconds: 3),
    behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // Helper method to get temporary path for recordings
  Future<String> _getTemporaryPath(String fileName) async {
    final directory = await Directory.systemTemp.createTemp();
    return '${directory.path}/$fileName';
  }
}

// VideoPlayerScreen class - assuming you already have this from original code
class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerScreen({Key? key, required this.videoUrl}) : super(key: key);

  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  // Implementation should be in a separate file
  @override
  Widget build(BuildContext context) {
    return Scaffold();
  }
}