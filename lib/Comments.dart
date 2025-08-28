import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'helpers.dart';

class CommentScreen extends StatefulWidget {
  final String postId;

  const CommentScreen({Key? key, required this.postId}) : super(key: key);

  @override
  _CommentScreenState createState() => _CommentScreenState();
}

class _CommentScreenState extends State<CommentScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _commentController = TextEditingController();
  String? _authorName;
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final List<String> _reactions = ['👍', '❤', '😂', '😮', '😢', '😡'];
  final Set<String> _expandedComments = {};

  @override
  void initState() {
    super.initState();
    _getAuthorName();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
  }

  void _getAuthorName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('studentprofile').doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          _authorName = doc.data()?['fullName'];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Hero(tag: 'comment_icon', child: Icon(Icons.comment, color: kPrimaryTeal)),
            const SizedBox(width: 10),
            AnimatedTextKit(
              animatedTexts: [
                TypewriterAnimatedText(
                  'Comments',
                  speed: const Duration(milliseconds: 100),
                  textStyle: TextStyle(color: kTextPrimary),
                ),
              ],
              totalRepeatCount: 1,
            ),
          ],
        ),
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('posts').doc(widget.postId).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              var postData = snapshot.data?.data() as Map<String, dynamic>?;
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Chip(
                  label: Text('${postData?['commentCount'] ?? 0} comments', style: TextStyle(color: kTextPrimary)),
                  backgroundColor: kBackgroundGradientEnd,
                ),
              );
            },
          ),
        ],
        elevation: 2,
        backgroundColor: kCardBackground,
        foregroundColor: kTextPrimary,
      ),
      body: Column(
        children: [
          _buildPostSummary(),
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('posts')
                    .doc(widget.postId)
                    .collection('comments')
                    .orderBy('timestamp', descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: kPrimaryTeal));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.comment_outlined, size: 80, color: kTextSecondary),
                          const SizedBox(height: 16),
                          Text("No comments yet.", style: TextStyle(fontSize: 18, color: kTextSecondary)),
                          const SizedBox(height: 8),
                          Text("Be the first to share your thoughts!", style: TextStyle(fontSize: 14, color: kTextSecondary)),
                        ],
                      ),
                    );
                  }

                  var comments = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      var comment = comments[index];
                      var commentData = comment.data() as Map<String, dynamic>;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        transform: Matrix4.translationValues(0, index < _animationController.value * comments.length ? 0 : 50, 0),
                        child: _buildCommentCard(comment, commentData),
                      );
                    },
                  );
                },
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: kCardBackground,
              boxShadow: [BoxShadow(color: kShadowColor, spreadRadius: 1, blurRadius: 3, offset: const Offset(0, -1))],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: kPrimaryTeal.withOpacity(0.2),
                  child: Text(
                    _authorName?.isNotEmpty == true ? _authorName![0].toUpperCase() : 'A',
                    style: TextStyle(color: kPrimaryTeal, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: "Add a comment...",
                      hintStyle: TextStyle(color: kTextSecondary),
                      filled: true,
                      fillColor: kBackgroundGradientEnd.withOpacity(0.5),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.photo_camera, color: kPrimaryTeal),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Image upload coming soon!")));
                        },
                      ),
                    ),
                    style: TextStyle(color: kTextPrimary),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(color: kPrimaryTeal, shape: BoxShape.circle),
                  child: _isLoading
                      ? const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                  )
                      : IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: () {
                      if (_commentController.text.trim().isNotEmpty) {
                        setState(() => _isLoading = true);
                        _postComment(_commentController.text.trim()).then((_) {
                          setState(() => _isLoading = false);
                        });
                        _commentController.clear();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostSummary() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('posts').doc(widget.postId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        var postData = snapshot.data?.data() as Map<String, dynamic>?;
        if (postData == null) return const SizedBox();

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: kBackgroundGradientEnd.withOpacity(0.5),
            border: Border(bottom: BorderSide(color: kTextSecondary.withOpacity(0.3), width: 1)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundImage: postData['authorImage'] != null ? NetworkImage(postData['authorImage']) : null,
                backgroundColor: kPrimaryTeal.withOpacity(0.2),
                child: postData['authorImage'] == null ? Icon(Icons.person, color: kPrimaryTeal) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      postData['title'] ?? 'Post Title',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kTextPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(postData['author'] ?? 'Unknown Author', style: TextStyle(color: kTextSecondary, fontSize: 14)),
                    if (postData['content'] != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        postData['content'],
                        style: TextStyle(fontSize: 14, color: kTextPrimary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
    final formattedTime = timestamp != null ? timeago.format(timestamp.toDate()) : 'Just now';
    final isExpanded = _expandedComments.contains(comment.id);

    return Slidable(
      key: ValueKey(comment.id),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (context) => _reportComment(comment.id),
            backgroundColor: kSecondaryCoral,
            foregroundColor: Colors.white,
            icon: Icons.flag,
            label: 'Report',
          ),
        ],
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: kCardBackground,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Hero(
                  tag: 'avatar_${comment.id}',
                  child: CircleAvatar(
                    backgroundColor: kPrimaryTeal.withOpacity(0.2),
                    child: Text(
                      (commentData['author'] ?? 'U')[0].toUpperCase(),
                      style: TextStyle(color: kPrimaryTeal, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        commentData['author'] ?? 'Unknown',
                        style: TextStyle(fontWeight: FontWeight.bold, color: kTextPrimary),
                      ),
                    ),
                    Text(formattedTime, style: TextStyle(fontSize: 12, color: kTextSecondary)),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    commentData['content'] ?? 'No content',
                    style: TextStyle(fontSize: 16, color: kTextPrimary),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      LikeButton(
                        isLiked: (commentData['likes'] ?? []).contains(FirebaseAuth.instance.currentUser?.uid),
                        likeCount: commentData['likes']?.length ?? 0,
                        onTap: () {
                          _toggleLike(comment.id);
                          return Future.value(!(commentData['likes'] ?? []).contains(FirebaseAuth.instance.currentUser?.uid));
                        },
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _showReactionsSheet(comment.id),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: kBackgroundGradientEnd.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.add_reaction_outlined, size: 16, color: kTextSecondary),
                              const SizedBox(width: 4),
                              Text("React", style: TextStyle(fontSize: 12, color: kTextSecondary)),
                            ],
                          ),
                        ),
                      ),
                      if (commentData['reactions'] != null)
                        ..._reactions.map((reaction) {
                          var count = commentData['reactions'][reaction] ?? 0;
                          if (count > 0) {
                            return Row(
                              children: [
                                Text(reaction, style: TextStyle(fontSize: 16, color: kPrimaryTeal)),
                                Text(' $count', style: TextStyle(fontSize: 12, color: kPrimaryTeal)),
                                const SizedBox(width: 4),
                              ],
                            );
                          }
                          return const SizedBox();
                        }).toList(),
                    ],
                  ),
                  TextButton(
                    onPressed: () => _showReplyDialog(comment.id),
                    child: Text("Reply", style: TextStyle(color: kPrimaryTeal)),
                  ),
                ],
              ),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('posts')
                    .doc(widget.postId)
                    .collection('comments')
                    .doc(comment.id)
                    .collection('replies')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox();
                  return Column(
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            if (isExpanded) {
                              _expandedComments.remove(comment.id);
                            } else {
                              _expandedComments.add(comment.id);
                            }
                          });
                        },
                        child: Text(isExpanded ? "Hide Replies" : "Show Replies", style: TextStyle(color: kPrimaryTeal)),
                      ),
                      if (isExpanded)
                        ...snapshot.data!.docs.map((reply) {
                          var replyData = reply.data() as Map<String, dynamic>;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Hero(
                              tag: 'avatar_${reply.id}',
                              child: CircleAvatar(
                                backgroundColor: kPrimaryTeal.withOpacity(0.2),
                                child: Text(
                                  (replyData['author'] ?? 'U')[0].toUpperCase(),
                                  style: TextStyle(color: kPrimaryTeal, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            title: Text(replyData['author'] ?? 'Unknown', style: TextStyle(fontWeight: FontWeight.bold, color: kTextPrimary)),
                            subtitle: Text(replyData['content'] ?? 'No content', style: TextStyle(fontSize: 16, color: kTextPrimary)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (replyData['reactions'] != null)
                                  ..._reactions.map((reaction) {
                                    var count = replyData['reactions'][reaction] ?? 0;
                                    if (count > 0) {
                                      return Row(
                                        children: [
                                          Text(reaction, style: TextStyle(fontSize: 16, color: kPrimaryTeal)),
                                          Text(' $count', style: TextStyle(fontSize: 12, color: kPrimaryTeal)),
                                          const SizedBox(width: 4),
                                        ],
                                      );
                                    }
                                    return const SizedBox();
                                  }).toList(),
                                InkWell(
                                  onTap: () => _showReactionsSheetForReply(comment.id, reply.id),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: kBackgroundGradientEnd.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.add_reaction_outlined, size: 16, color: kTextSecondary),
                                        const SizedBox(width: 4),
                                        Text("React", style: TextStyle(fontSize: 12, color: kTextSecondary)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _postComment(String content) async {
    if (content.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please log in to comment.")));
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('studentprofile').doc(user.uid).get();
      String authorName = doc.exists ? (doc.data()?['fullName'] ?? 'Anonymous') : 'Anonymous';

      await FirebaseFirestore.instance.collection('posts').doc(widget.postId).collection('comments').add({
        'author': authorName,
        'content': content,
        'timestamp': FieldValue.serverTimestamp(),
        'likes': [],
        'reactions': {},
      });

      await FirebaseFirestore.instance.collection('posts').doc(widget.postId).update({
        'commentCount': FieldValue.increment(1),
      });

      var postDoc = await FirebaseFirestore.instance.collection('posts').doc(widget.postId).get();
      String postOwnerId = postDoc['userId'];
      if (postOwnerId != user.uid) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': postOwnerId,
          'type': 'comment',
          'postId': widget.postId,
          'actorId': user.uid,
          'actorName': authorName,
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
        });
      }
    } catch (e) {
      print("Error posting comment: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to post comment. Please try again.")));
    }
  }

  void _toggleLike(String commentId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    DocumentReference commentRef =
    FirebaseFirestore.instance.collection('posts').doc(widget.postId).collection('comments').doc(commentId);

    final doc = await commentRef.get();
    if (doc.exists) {
      var commentData = doc.data() as Map<String, dynamic>;
      if ((commentData['likes'] ?? []).contains(user.uid)) {
        commentRef.update({'likes': FieldValue.arrayRemove([user.uid])});
      } else {
        commentRef.update({'likes': FieldValue.arrayUnion([user.uid])});
      }
    }
  }

  void _reportComment(String commentId) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Report comment coming soon!")));
  }

  void _showReactionsSheet(String commentId) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Reactions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextPrimary)),
              const SizedBox(height: 16),
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('posts')
                    .doc(widget.postId)
                    .collection('comments')
                    .doc(commentId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox();
                  var commentData = snapshot.data?.data() as Map<String, dynamic>?;
                  if (commentData == null) return const SizedBox();
                  var reactions = commentData['reactions'] ?? {};

                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _reactions.map((reaction) {
                      return GestureDetector(
                        onTap: () {
                          _postReaction(commentId, reaction);
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: kBackgroundGradientEnd.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Text(
                                reaction,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: reactions.containsKey(reaction) && reactions[reaction] > 0 ? kPrimaryTeal : kTextSecondary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${reactions[reaction] ?? 0}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: reactions.containsKey(reaction) && reactions[reaction] > 0 ? kPrimaryTeal : kTextSecondary,
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
            ],
          ),
        );
      },
    );
  }

  void _postReaction(String commentId, String reaction) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    DocumentReference commentRef =
    FirebaseFirestore.instance.collection('posts').doc(widget.postId).collection('comments').doc(commentId);

    final doc = await commentRef.get();
    if (doc.exists) {
      var commentData = doc.data() as Map<String, dynamic>;
      var reactions = commentData['reactions'] ?? {};

      for (var existingReaction in reactions.keys) {
        if (existingReaction != reaction && reactions[existingReaction] > 0) {
          if (reactions[existingReaction] == 1) {
            commentRef.update({'reactions.$existingReaction': FieldValue.delete()});
          } else {
            commentRef.update({'reactions.$existingReaction': FieldValue.increment(-1)});
          }
        }
      }

      if (reactions.containsKey(reaction)) {
        if (reactions[reaction] == 1) {
          commentRef.update({'reactions.$reaction': FieldValue.delete()});
        } else {
          commentRef.update({'reactions.$reaction': FieldValue.increment(-1)});
        }
      } else {
        commentRef.update({'reactions.$reaction': FieldValue.increment(1)});
      }
    }
  }

  void _showReactionsSheetForReply(String commentId, String replyId) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Reactions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextPrimary)),
              const SizedBox(height: 16),
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('posts')
                    .doc(widget.postId)
                    .collection('comments')
                    .doc(commentId)
                    .collection('replies')
                    .doc(replyId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox();
                  var replyData = snapshot.data?.data() as Map<String, dynamic>?;
                  if (replyData == null) return const SizedBox();
                  var reactions = replyData['reactions'] ?? {};

                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _reactions.map((reaction) {
                      return GestureDetector(
                        onTap: () {
                          _postReactionForReply(commentId, replyId, reaction);
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: kBackgroundGradientEnd.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Text(
                                reaction,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: reactions.containsKey(reaction) && reactions[reaction] > 0 ? kPrimaryTeal : kTextSecondary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${reactions[reaction] ?? 0}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: reactions.containsKey(reaction) && reactions[reaction] > 0 ? kPrimaryTeal : kTextSecondary,
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
            ],
          ),
        );
      },
    );
  }

  void _postReactionForReply(String commentId, String replyId, String reaction) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    DocumentReference replyRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .doc(replyId);

    final doc = await replyRef.get();
    if (doc.exists) {
      var replyData = doc.data() as Map<String, dynamic>;
      var reactions = replyData['reactions'] ?? {};

      for (var existingReaction in reactions.keys) {
        if (existingReaction != reaction && reactions[existingReaction] > 0) {
          if (reactions[existingReaction] == 1) {
            replyRef.update({'reactions.$existingReaction': FieldValue.delete()});
          } else {
            replyRef.update({'reactions.$existingReaction': FieldValue.increment(-1)});
          }
        }
      }

      if (reactions.containsKey(reaction)) {
        if (reactions[reaction] == 1) {
          replyRef.update({'reactions.$reaction': FieldValue.delete()});
        } else {
          replyRef.update({'reactions.$reaction': FieldValue.increment(-1)});
        }
      } else {
        replyRef.update({'reactions.$reaction': FieldValue.increment(1)});
      }
    }
  }

  void _showReplyDialog(String commentId) {
    TextEditingController replyController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Reply to Comment", style: TextStyle(color: kTextPrimary)),
          content: TextField(
            controller: replyController,
            decoration: InputDecoration(hintText: "Enter your reply...", hintStyle: TextStyle(color: kTextSecondary)),
            style: TextStyle(color: kTextPrimary),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel", style: TextStyle(color: kTextSecondary))),
            TextButton(
              onPressed: () {
                _postReply(commentId, replyController.text.trim());
                Navigator.pop(context);
              },
              child: Text("Reply", style: TextStyle(color: kPrimaryTeal)),
            ),
          ],
        );
      },
    );
  }

  void _postReply(String commentId, String content) async {
    if (content.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('studentprofile').doc(user.uid).get();
      String authorName = doc.exists ? (doc.data()?['fullName'] ?? 'Anonymous') : 'Anonymous';

      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(commentId)
          .collection('replies')
          .add({
        'author': authorName,
        'content': content,
        'timestamp': FieldValue.serverTimestamp(),
        'reactions': {},
      });

      var commentDoc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(commentId)
          .get();
      String commentAuthor = commentDoc['author'];
      var postDoc = await FirebaseFirestore.instance.collection('posts').doc(widget.postId).get();
      String postOwnerId = postDoc['userId'];

      if (commentAuthor != authorName) {
        var commentAuthorDoc = await FirebaseFirestore.instance
            .collection('studentprofile')
            .where('fullName', isEqualTo: commentAuthor)
            .get();
        if (commentAuthorDoc.docs.isNotEmpty) {
          String commentAuthorId = commentAuthorDoc.docs.first.id;
          if (commentAuthorId != user.uid) {
            await FirebaseFirestore.instance.collection('notifications').add({
              'userId': commentAuthorId,
              'type': 'reply',
              'postId': widget.postId,
              'commentId': commentId,
              'actorId': user.uid,
              'actorName': authorName,
              'timestamp': FieldValue.serverTimestamp(),
              'read': false,
            });
          }
        }
      }
    } catch (e) {
      print("Error posting reply: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to post reply. Please try again.")));
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _animationController.dispose();
    super.dispose();
  }
}

class LikeButton extends StatefulWidget {
  final bool isLiked;
  final int likeCount;
  final Function onTap;

  const LikeButton({
    Key? key,
    required this.isLiked,
    required this.likeCount,
    required this.onTap,
  }) : super(key: key);

  @override
  _LikeButtonState createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => widget.onTap(),
      child: Row(
        children: [
          Icon(widget.isLiked ? Icons.thumb_up : Icons.thumb_up_outlined, color: widget.isLiked ? kPrimaryTeal : kIconInactive),
          const SizedBox(width: 4),
          Text('${widget.likeCount} likes', style: TextStyle(color: kTextSecondary)),
        ],
      ),
    );
  }
}