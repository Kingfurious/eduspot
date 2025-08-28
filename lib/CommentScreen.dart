import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'Services/explore_notification_service.dart'; // Import the NotificationService

// Define the color palette
const Color primaryBlue = Color(0xFF1976D2);
const Color lightBlue = Color(0xFF64B5F6);
const Color veryLightBlue = Color(0xFFE3F2FD);
const Color darkBlue = Color(0xFF0D47A1);
const Color accentBlue = Color(0xFF29B6F6);

class CommentScreen extends StatefulWidget {
  final String postId;

  const CommentScreen({Key? key, required this.postId}) : super(key: key);

  @override
  _CommentScreenState createState() => _CommentScreenState();
}

class _CommentScreenState extends State<CommentScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _commentController = TextEditingController();
  String? _authorName;
  String? _userId;
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Keep track of the scroll position
  final ScrollController _scrollController = ScrollController();

  // For emoji reactions
  final List<String> _reactions = ['👍', '❤', '😂', '😮', '😢', '😡'];

  // Instance of NotificationService
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _getUserInfo(); // Fetch user info on init

    // Verify and fix comment counts
    verifyCommentCounts();

    // Initialize animation controller - ONLY ONCE
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    // Start animation after a short delay to allow initial build
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) { // Ensure widget is still mounted
        _animationController.forward();
      }
    });
  }

  bool _isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) {
      return false;
    }

    // Basic URL validation
    return url.startsWith('http://') || url.startsWith('https://');
  }

  // --- IMPROVED: Get User Info (both ID and Name) ---
  void _getUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      if (mounted) {
        setState(() {
          _userId = user.uid;
        });
      }

      try {
        if (user.displayName != null && user.displayName!.isNotEmpty) {
          if (mounted) {
            setState(() {
              _authorName = user.displayName;
            });
          }
          return;
        }

        final doc = await FirebaseFirestore.instance.collection('studentprofile').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data();
          if (data != null && data.containsKey('fullName')) {
            final name = data['fullName'] as String?;
            if (mounted) {
              setState(() {
                _authorName = (name != null && name.isNotEmpty) ? name : 'User ${user.uid.substring(0, 4)}';
              });
            }
          } else if (data != null && data.containsKey('name')) {
            final name = data['name'] as String?;
            if (mounted) {
              setState(() {
                _authorName = (name != null && name.isNotEmpty) ? name : 'User ${user.uid.substring(0, 4)}';
              });
            }
          } else {
            if (user.email != null && user.email!.isNotEmpty) {
              if (mounted) {
                setState(() {
                  _authorName = user.email!.split('@')[0];
                });
              }
            } else {
              if (mounted) {
                setState(() {
                  _authorName = 'User ${user.uid.substring(0, 4)}';
                });
              }
            }
          }
        } else {
          if (user.email != null && user.email!.isNotEmpty) {
            if (mounted) {
              setState(() {
                _authorName = user.email!.split('@')[0];
              });
            }
          } else {
            if (mounted) {
              setState(() {
                _authorName = 'User ${user.uid.substring(0, 4)}';
              });
            }
          }
        }
      } catch (e) {
        print("Error fetching author name: $e");
        if (mounted) {
          setState(() {
            _authorName = user.email != null ? user.email!.split('@')[0] : 'User ${user.uid.substring(0, 4)}';
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _authorName = 'Guest User';
          _userId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: veryLightBlue,
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Column(
            children: [
              _buildModernAppBar(),
              _buildPostSummary(),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('posts')
                        .doc(widget.postId)
                        .collection('comments')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: CircularProgressIndicator(
                            color: primaryBlue,
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            "Error loading comments: ${snapshot.error}",
                            style: TextStyle(color: darkBlue),
                          ),
                        );
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_outline, size: 80, color: lightBlue),
                              const SizedBox(height: 16),
                              Text(
                                "No comments yet.",
                                style: TextStyle(
                                  fontSize: 18,
                                  color: primaryBlue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Be the first to share your thoughts!",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: darkBlue.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      var comments = snapshot.data!.docs;
                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(bottom: 16),
                        physics: const BouncingScrollPhysics(),
                        itemCount: comments.length,
                        itemBuilder: (context, index) {
                          var comment = comments[index];
                          var commentData = comment.data() as Map<String, dynamic>?;
                          if (commentData == null) {
                            return const SizedBox.shrink();
                          }

                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOut,
                            transform: Matrix4.translationValues(
                                0,
                                index < (_animationController.value * comments.length) ? 0 : 50,
                                0),
                            child: _buildCommentCard(comment, commentData),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        spreadRadius: 1,
                        blurRadius: 10,
                        offset: const Offset(0, -3),
                      ),
                    ],
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: primaryBlue,
                        child: Text(
                          _authorName != null && _authorName!.isNotEmpty
                              ? _authorName![0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          constraints: BoxConstraints(maxHeight: 100),
                          decoration: BoxDecoration(
                            color: veryLightBlue,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: lightBlue.withOpacity(0.3)),
                          ),
                          child: TextField(
                            controller: _commentController,
                            maxLines: null,
                            minLines: 1,
                            keyboardType: TextInputType.multiline,
                            textCapitalization: TextCapitalization.sentences,
                            style: TextStyle(fontSize: 16),
                            decoration: InputDecoration(
                              hintText: "Add a comment...",
                              hintStyle: TextStyle(color: darkBlue.withOpacity(0.6)),
                              filled: false,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 40,
                        width: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: _isLoading ? lightBlue : primaryBlue,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: primaryBlue.withOpacity(0.3),
                                spreadRadius: 1,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: _isLoading
                              ? Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          )
                              : IconButton(
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(),
                            icon: const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: () {
                              final commentText = _commentController.text.trim();
                              if (commentText.isNotEmpty) {
                                _postComment(commentText);
                                FocusScope.of(context).unfocus();
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernAppBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: veryLightBlue,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded, color: primaryBlue, size: 20),
            ),
          ),
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('posts').doc(widget.postId).snapshots(),
              builder: (context, snapshot) {
                int commentCount = 0;
                if (snapshot.hasData && snapshot.data!.exists) {
                  var postData = snapshot.data?.data() as Map<String, dynamic>?;
                  commentCount = postData?['commentCount'] as int? ?? 0;
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        AnimatedTextKit(
                          animatedTexts: [
                            TypewriterAnimatedText(
                              'Comments',
                              speed: const Duration(milliseconds: 100),
                              textStyle: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: darkBlue,
                              ),
                            ),
                          ],
                          totalRepeatCount: 1,
                          displayFullTextOnTap: true,
                          stopPauseOnTap: true,
                        ),
                        if (snapshot.hasData)
                          Text(
                            "$commentCount ${commentCount == 1 ? 'comment' : 'comments'}",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildPostSummary() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('posts').doc(widget.postId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return LinearProgressIndicator(
            backgroundColor: veryLightBlue,
            color: accentBlue,
            minHeight: 3,
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Text(
              "Original post not found.",
              style: TextStyle(color: darkBlue.withOpacity(0.7)),
            ),
          );
        }

        var postData = snapshot.data?.data() as Map<String, dynamic>?;
        if (postData == null) return const SizedBox.shrink();

        String authorImageUrl = postData['authorImage'] as String? ?? '';
        String authorName = postData['author'] as String? ?? 'Unknown Author';
        String title = postData['title'] as String? ?? 'Post Title';
        String content = postData['content'] as String? ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: primaryBlue.withOpacity(0.8),
                backgroundImage: _isValidImageUrl(authorImageUrl)
                    ? NetworkImage(authorImageUrl) as ImageProvider
                    : null,
                child: !_isValidImageUrl(authorImageUrl)
                    ? Text(
                  authorName.isNotEmpty ? authorName[0].toUpperCase() : "U",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: darkBlue,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "by $authorName",
                      style: TextStyle(
                        color: primaryBlue,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (content.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: veryLightBlue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          content,
                          style: TextStyle(fontSize: 14, color: Colors.black87),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCommentCard(QueryDocumentSnapshot comment, Map<String, dynamic> commentData) {
    final timestamp = commentData['timestamp'] as Timestamp?;
    final formattedTime = timestamp != null
        ? timeago.format(timestamp.toDate())
        : 'Just now';

    final String author = commentData['author'] as String? ?? 'Unknown';
    final String content = commentData['content'] as String? ?? 'No content';
    final List<dynamic> likes = commentData['likes'] as List<dynamic>? ?? [];
    final Map<String, dynamic> reactions = commentData['reactions'] as Map<String, dynamic>? ?? {};
    final String commentUserId = commentData['userId'] as String? ?? '';
    final String currentUserId = _userId ?? '';

    final bool isLiked = likes.contains(currentUserId);
    final int likeCount = likes.length;

    return FutureBuilder<Map<String, dynamic>>(
      future: _getUserProfileData(commentUserId),
      builder: (context, userSnapshot) {
        String? userProfileUrl;
        String displayName = author;

        if (userSnapshot.hasData && userSnapshot.connectionState == ConnectionState.done) {
          userProfileUrl = userSnapshot.data?['photoURL'];
          final userName = userSnapshot.data?['name'];
          if (userName != null && userName.toString().isNotEmpty) {
            displayName = userName.toString();
          }
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 12.0),
          child: Slidable(
            key: ValueKey(comment.id),
            endActionPane: ActionPane(
              motion: const ScrollMotion(),
              extentRatio: 0.25,
              children: [
                SlidableAction(
                  onPressed: (context) => _reportComment(comment.id, commentData),
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  icon: Icons.flag_rounded,
                  label: 'Report',
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
                if (commentUserId == currentUserId)
                  SlidableAction(
                    onPressed: (context) => _deleteComment(comment.id),
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    icon: Icons.delete_rounded,
                    label: 'Delete',
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
              ],
            ),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.primaries[displayName.hashCode % Colors.primaries.length],
                          backgroundImage: _isValidImageUrl(userProfileUrl)
                              ? NetworkImage(userProfileUrl!) as ImageProvider
                              : null,
                          child: !_isValidImageUrl(userProfileUrl)
                              ? Text(
                            displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    displayName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: darkBlue,
                                    ),
                                  ),
                                  Spacer(),
                                  Text(
                                    formattedTime,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: veryLightBlue,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  content,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () => _toggleLike(comment.id),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                              decoration: BoxDecoration(
                                color: isLiked ? lightBlue.withOpacity(0.2) : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                                    color: isLiked ? primaryBlue : Colors.grey[600],
                                    size: 18,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$likeCount',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isLiked ? FontWeight.bold : FontWeight.normal,
                                      color: isLiked ? primaryBlue : Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => _showReactionsSheet(comment.id),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.add_reaction_outlined,
                                    size: 18,
                                    color: accentBlue,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ...reactions.entries
                              .where((entry) => (entry.value as int? ?? 0) > 0)
                              .map((entry) {
                            String reaction = entry.key;
                            int count = entry.value as int? ?? 0;
                            return Container(
                              margin: const EdgeInsets.only(right: 6.0),
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: veryLightBlue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$reaction $count',
                                style: TextStyle(fontSize: 14),
                              ),
                            );
                          }).toList(),
                        ],
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

  Future<Map<String, dynamic>> _getUserProfileData(String userId) async {
    Map<String, dynamic> userData = {'name': 'Unknown User'};

    if (userId.isEmpty) {
      print("Error: Empty user ID provided to _getUserProfileData");
      return userData;
    }

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('studentprofile')
          .doc(userId)
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        print("Found user data in studentprofile: $data");

        String? name = data['fullName'] ??
            data['name'] ??
            data['displayName'] ??
            data['userName'];

        if (name != null) {
          userData['name'] = name;
        }

        String? photoURL = data['imageUrl'] ??
            data['photoURL'] ??
            data['profilePic'] ??
            data['avatar'];

        if (photoURL != null) {
          print("Found photoURL: $photoURL");
          userData['photoURL'] = photoURL;
        } else {
          print("No profile image found in studentprofile for user $userId");
        }

        return userData;
      }

      doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        print("Found user data in users collection: $data");

        String? name = data['fullName'] ??
            data['name'] ??
            data['displayName'] ??
            data['userName'];

        if (name != null) {
          userData['name'] = name;
        }

        String? photoURL = data['imageUrl'] ??
            data['photoURL'] ??
            data['profilePic'] ??
            data['avatar'];

        if (photoURL != null) {
          print("Found photoURL: $photoURL");
          userData['photoURL'] = photoURL;
        } else {
          print("No profile image found in users collection for user $userId");
        }
      } else {
        print("User $userId not found in either studentprofile or users collection");
      }
    } catch (e) {
      print("Error fetching user data for $userId: $e");
    }

    return userData;
  }

  // --- UPDATED: Post Comment with Notification ---
  Future<void> _postComment(String content) async {
    if (content.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Please log in to comment."),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            backgroundColor: darkBlue,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    String authorNameToPost = _authorName ?? 'Anonymous';

    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();

      DocumentReference commentRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .doc();

      batch.set(commentRef, {
        'author': authorNameToPost,
        'content': content,
        'timestamp': FieldValue.serverTimestamp(),
        'likes': [],
        'reactions': {},
        'userReactions': {},
        'userId': user.uid,
      });

      DocumentReference postRef = FirebaseFirestore.instance.collection('posts').doc(widget.postId);
      batch.update(postRef, {
        'commentCount': FieldValue.increment(1),
      });

      await batch.commit();

      // Fetch post data to get the owner and post details for notification
      DocumentSnapshot postDoc = await postRef.get();
      if (postDoc.exists) {
        Map<String, dynamic> postData = postDoc.data() as Map<String, dynamic>;
        String? postOwnerId = postData['uid'] as String?;
        String postTitle = postData['title'] as String? ?? 'Untitled Post';
        String? postImageUrl = postData['mediaUrl'] as String?;

        if (postOwnerId != null && postOwnerId != user.uid) {
          await _notificationService.createNotification(
            userId: postOwnerId,
            type: NotificationService.TYPE_COMMENT,
            actorId: user.uid,
            actorName: user.displayName ?? authorNameToPost,
            actorPhotoURL: user.photoURL,
            postId: widget.postId,
            postTitle: postTitle,
            postImageURL: postImageUrl,
            commentId: commentRef.id,
          );
        }
      }

      if (mounted) {
        _commentController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Comment posted successfully"),
            backgroundColor: primaryBlue,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print("Error posting comment: $e");
      String errorMessage = "Failed to post comment. Please try again.";
      if (e is FirebaseException) {
        errorMessage = "Failed to post comment: ${e.message ?? e.code}";
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red[600]),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _toggleLike(String commentId) async {
    if (_userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please log in to like comments."),
          backgroundColor: primaryBlue,
        ),
      );
      return;
    }

    DocumentReference commentRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .doc(commentId);

    FirebaseFirestore.instance.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(commentRef);

      if (!snapshot.exists) {
        throw Exception("Comment does not exist!");
      }

      Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
      List<dynamic> likes = List.from(data['likes'] ?? []);

      if (likes.contains(_userId)) {
        likes.remove(_userId);
      } else {
        likes.add(_userId);
      }
      transaction.update(commentRef, {'likes': likes});
    }).catchError((error) {
      print("Failed to toggle like: $error");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Could not update like. Please try again."),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    });
  }

  void _reportComment(String commentId, Map<String, dynamic> commentData) async {
    bool confirmReport = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          "Report Comment",
          style: TextStyle(color: darkBlue, fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Are you sure you want to report this comment? This will notify moderators to review it.",
          style: TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              "Cancel",
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text("Report"),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmReport) return;

    print("Reporting comment: $commentId by user ${commentData['userId']}");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Comment reported for review. Thank you for helping keep our community safe."),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _deleteComment(String commentId) async {
    bool confirmDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          "Delete Comment?",
          style: TextStyle(color: darkBlue, fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Are you sure you want to permanently delete this comment? This action cannot be undone.",
          style: TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              "Cancel",
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text("Delete"),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmDelete) return;

    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();

      DocumentReference commentRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(commentId);
      batch.delete(commentRef);

      DocumentReference postRef = FirebaseFirestore.instance.collection('posts').doc(widget.postId);
      batch.update(postRef, {
        'commentCount': FieldValue.increment(-1),
      });

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Comment deleted successfully."),
            backgroundColor: primaryBlue,
          ),
        );
      }
    } catch (e) {
      print("Error deleting comment: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to delete comment: ${e.toString()}"),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
  }

  void _showReactionsSheet(String commentId) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      backgroundColor: Colors.white,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  "React to comment",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: darkBlue,
                  ),
                ),
                const SizedBox(height: 24),
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('posts')
                      .doc(widget.postId)
                      .collection('comments')
                      .doc(commentId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(color: primaryBlue),
                      );
                    }

                    Map<String, dynamic> reactions = {};
                    Map<String, dynamic> userReactions = {};
                    String? currentUserReaction;

                    if (snapshot.hasData && snapshot.data!.exists) {
                      var commentData = snapshot.data?.data() as Map<String, dynamic>?;
                      reactions = commentData?['reactions'] as Map<String, dynamic>? ?? {};
                      userReactions = commentData?['userReactions'] as Map<String, dynamic>? ?? {};

                      if (_userId != null) {
                        currentUserReaction = userReactions[_userId];
                      }
                    }

                    return Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 16,
                      runSpacing: 16,
                      children: _reactions.map((reaction) {
                        int count = reactions[reaction] as int? ?? 0;
                        bool isSelected = currentUserReaction == reaction;

                        return InkWell(
                          onTap: () {
                            if (_userId != null) {
                              _postReaction(commentId, reaction);
                              Navigator.pop(context);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Please log in to react to comments."),
                                  backgroundColor: primaryBlue,
                                ),
                              );
                            }
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected ? lightBlue.withOpacity(0.2) : veryLightBlue,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? primaryBlue : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  reaction,
                                  style: TextStyle(
                                    fontSize: 32,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (count > 0)
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: lightBlue.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$count',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: primaryBlue,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  void _postReaction(String commentId, String reaction) async {
    if (_userId == null) return;

    DocumentReference commentRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .doc(commentId);

    FirebaseFirestore.instance.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(commentRef);
      if (!snapshot.exists) {
        throw Exception("Comment does not exist!");
      }

      Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
      Map<String, dynamic> reactions = Map<String, dynamic>.from(data['reactions'] ?? {});
      Map<String, dynamic> userReactions = Map<String, dynamic>.from(data['userReactions'] ?? {});

      String? currentReaction = userReactions[_userId];

      if (currentReaction != null) {
        int currentCount = reactions[currentReaction] as int? ?? 0;
        if (currentCount > 0) {
          reactions[currentReaction] = currentCount - 1;
        }

        if (currentReaction == reaction) {
          userReactions.remove(_userId);
          transaction.update(commentRef, {
            'reactions': reactions,
            'userReactions': userReactions,
          });
          return;
        }
      }

      reactions[reaction] = (reactions[reaction] as int? ?? 0) + 1;
      userReactions[_userId!] = reaction;

      transaction.update(commentRef, {
        'reactions': reactions,
        'userReactions': userReactions,
      });
    }).catchError((error) {
      print("Failed to post reaction: $error");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Could not add reaction. Please try again."),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    });
  }

  Future<void> verifyCommentCounts() async {
    try {
      DocumentSnapshot postDoc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .get();

      if (!postDoc.exists) return;

      QuerySnapshot commentsSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .get();

      int actualCommentCount = commentsSnapshot.size;
      Map<String, dynamic>? postData = postDoc.data() as Map<String, dynamic>?;
      int storedCommentCount = postData?['commentCount'] as int? ?? 0;

      if (actualCommentCount != storedCommentCount) {
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.postId)
            .update({'commentCount': actualCommentCount});
        print('Fixed comment count: $storedCommentCount → $actualCommentCount');
      }
    } catch (e) {
      print('Error verifying comment counts: $e');
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class AppTheme {
  static const Color primaryBlue = Color(0xFF1976D2);
  static const Color lightBlue = Color(0xFF64B5F6);
  static const Color veryLightBlue = Color(0xFFE3F2FD);
  static const Color darkBlue = Color(0xFF0D47A1);
  static const Color accentBlue = Color(0xFF29B6F6);

  static const TextStyle headingStyle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: darkBlue,
  );

  static const TextStyle titleStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: darkBlue,
  );

  static const TextStyle subtitleStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: primaryBlue,
  );

  static const TextStyle bodyStyle = TextStyle(
    fontSize: 15,
    color: Colors.black87,
  );

  static const TextStyle captionStyle = TextStyle(
    fontSize: 12,
    color: Color(0xFF757575),
  );

  static final ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: primaryBlue,
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
  );

  static final ButtonStyle secondaryButtonStyle = OutlinedButton.styleFrom(
    foregroundColor: primaryBlue,
    side: const BorderSide(color: primaryBlue),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
  );

  static InputDecoration textFieldDecoration({String? hintText}) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: veryLightBlue,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryBlue, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      hintStyle: const TextStyle(color: Color(0xFFAAABAE)),
    );
  }

  static BoxDecoration cardDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 10,
        offset: Offset(0, 2),
      ),
    ],
  );
}