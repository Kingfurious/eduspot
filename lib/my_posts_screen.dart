// START OF FILE my_posts_screen.dart
import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

// Constants and Utils (Ensure these files exist and are correctly imported)
import 'app_colors.dart';
import 'formatters.dart';

// Widgets (Ensure these files exist and are correctly imported)
import 'content_preview.dart';
import 'VideoWidget.dart'; // Required by content_preview

// Screens needed for navigation (Ensure these files exist and are correctly imported)
import 'holographic_post_view.dart';
import 'insight_screen.dart';
import 'CommentScreen.dart';
import 'Chat_screen.dart';
import 'UploadPostScreen.dart'; // For the "Create Post" button

class MyPostsScreen extends StatefulWidget {
  const MyPostsScreen({Key? key}) : super(key: key);

  @override
  _MyPostsScreenState createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends State<MyPostsScreen> {
  final Map<String, bool> _likedPosts = {};
  User? _currentUser; // Store current user state
  Stream<QuerySnapshot>? _postsStream; // Store the stream instance

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser; // Get initial user state
    // Initialize the stream *once* in initState if the user is logged in
    if (_currentUser != null) {
      _initializeStream(_currentUser!.uid);
      _fetchInitialLikedStatuses(_currentUser!.uid); // Pass UID for clarity
    } else {
      // Handle case where user is somehow null when screen is first built
      print("MyPostsScreen initState: User is null.");
    }
  }

  // Helper to initialize the stream
  void _initializeStream(String userId) {
    print("Initializing posts stream for user: $userId");
    // Assign the stream result to the state variable
    _postsStream = FirebaseFirestore.instance
        .collection('posts')
        .where('uid', isEqualTo: userId) // Filter by the provided user ID
        .orderBy('timestamp', descending: true)
        .snapshots();
    // Trigger a rebuild now that the stream is potentially available
    // (though build method will handle the stream variable anyway)
    if (mounted) {
      setState(() {});
    }
  }


  // Fetch initial like status for the current user's posts
  void _fetchInitialLikedStatuses(String userId) async {
    // No need to check _currentUser again, already checked before calling
    try {
      QuerySnapshot initialPosts = await FirebaseFirestore.instance
          .collection('posts')
          .where('uid', isEqualTo: userId) // Use passed userId
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      if (!mounted) return; // Check after await

      for (var postDoc in initialPosts.docs) {
        final postId = postDoc.id;
        final likeRef = FirebaseFirestore.instance
            .collection('posts')
            .doc(postId)
            .collection('likes')
            .doc(userId); // Check like status based on the *logged-in* user
        final likeDoc = await likeRef.get();

        if (!mounted) return; // Check again inside loop after await

        setState(() {
          _likedPosts[postId] = likeDoc.exists;
        });
      }
    } catch (e) {
      print("Error fetching initial liked statuses for My Posts: $e");
    }
  }

  // Fetch like status for a specific post for the current user
  void _fetchSpecificLikedStatus(String postId) async {
    if (_currentUser == null || postId.isEmpty) return;
    if (_likedPosts.containsKey(postId)) return;

    try {
      final likeRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .collection('likes')
          .doc(_currentUser!.uid); // Use current user's UID
      final likeDoc = await likeRef.get();
      if (mounted) {
        setState(() {
          _likedPosts[postId] = likeDoc.exists;
        });
      }
    } catch (e) {
      print("Error fetching specific like status for $postId in My Posts: $e");
    }
  }

  // NOTE: _getUserPostsStream() function is removed as the stream is now
  // initialized once in initState and stored in _postsStream variable.

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Use FirebaseAuth.instance.authStateChanges() for robustness if needed,
    // but checking _currentUser and using the stored _postsStream is often sufficient
    // if the screen rebuilds upon auth state changes.

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Posts'),
        backgroundColor: Colors.white,
        foregroundColor: kTextPrimary,
        elevation: 1,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [kBackgroundGradientStart, kBackgroundGradientEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: _currentUser == null
              ? _buildLoginPrompt() // Extracted login prompt widget
          // If user exists, check if the stream has been initialized
              : _postsStream == null
              ? Center(child: CircularProgressIndicator(color: kPrimaryTeal)) // Show loading while stream initializes (should be quick)
              : StreamBuilder<QuerySnapshot>(
            // Use the stream instance stored in the state variable
            stream: _postsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                // Show loading only if waiting AND no data has arrived yet
                // This prevents flicker if stream emits cached data quickly
                print("StreamBuilder: Waiting for posts...");
                return Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(kPrimaryTeal),
                  ).animate().fadeIn(),
                );
              }
              if (snapshot.hasError) {
                print("StreamBuilder Error fetching posts (uid: ${_currentUser!.uid}): ${snapshot.error}");
                return Center(
                    child: Text('Error loading your posts.\nPlease try again later.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.red.shade300, fontSize: 16)));
              }
              // Check hasData *after* checking for error
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                print('StreamBuilder: No posts found for user: ${_currentUser!.uid}');
                // Use the extracted "empty" state widget
                return _buildEmptyState();
              }

              // If we reach here, we have data
              var posts = snapshot.data!.docs;
              print('StreamBuilder: Rendering ${posts.length} posts for user: ${_currentUser!.uid}');

              return ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02, vertical: 8.0),
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  var post = posts[index];
                  try {
                    var data = post.data() as Map<String, dynamic>;
                    data['postId'] = post.id;

                    // Fetch like status if not already cached
                    // This check might be less critical now but harmless
                    if (!_likedPosts.containsKey(data['postId'])) {
                      _fetchSpecificLikedStatus(data['postId']);
                    }

                    // Use the existing card builder
                    return _buildInteractivePostCard(context, data, index, screenWidth);
                  } catch (e) {
                    print("Error processing user post data at index $index: $e");
                    print("Problematic Post ID: ${post.id}");
                    return Card( /* ... Error Card UI ... */ );
                  }
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // Extracted widget for the "Please Log In" message
  Widget _buildLoginPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.login, size: 50, color: kTextSecondary),
          SizedBox(height: 16),
          Text(
            'Please log in to see your posts.',
            style: TextStyle(color: kTextSecondary, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pushNamedAndRemoveUntil('/auth', (route) => false);
            },
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryTeal),
            child: Text('Login', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  // Extracted widget for the "No Posts Yet" message
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.dynamic_feed_outlined, size: 60, color: kTextSecondary.withOpacity(0.7)), // Changed Icon
          SizedBox(height: 20),
          Text(
            'No Posts Yet', // Clearer heading
            style: TextStyle(color: kTextPrimary, fontSize: 20, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'Create your first post to share your projects and ideas!', // Encouraging text
            style: TextStyle(color: kTextSecondary, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            icon: Icon(Icons.add, color: Colors.white),
            label: Text('Create Post', style: TextStyle(color: Colors.white, fontSize: 16)),
            style: ElevatedButton.styleFrom(
                backgroundColor: kSecondaryCoral,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
            ),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const UploadPostScreen()));
            },
          )
        ],
      ).animate().fadeIn(duration: 300.ms).scale(begin: Offset(0.95, 0.95)),
    );
  }


  // --- START: Reused Card Building and Action Logic ---
  // (No changes needed in the functions below from the previous correct version)

  // --- Interactive Post Card Widget ---
  Widget _buildInteractivePostCard(BuildContext context, Map<String, dynamic> data, int index, double screenWidth) {
    final String postId = data['postId'] ?? 'error_id_${index}';
    final bool isLiked = _likedPosts[postId] ?? false;

    return Card(
      elevation: 3,
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: screenWidth * 0.01),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: kCardBackground,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPostCardHeader(context, data, screenWidth),
          if (data['title'] != null && data['title'].toString().isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04, vertical: 8),
              child: Text( data['title'], style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: kTextPrimary,), maxLines: 2, overflow: TextOverflow.ellipsis,),
            ),
          GestureDetector(
            onTap: data['type'] != 'video' ? () { Navigator.push(context, MaterialPageRoute(builder: (context) => HolographicPostView(data: data))); } : null,
            child: Container(
              width: double.infinity, height: MediaQuery.of(context).size.height * 0.28, color: kBackgroundGradientEnd.withOpacity(0.1),
              child: buildContentPreview(context, data, height: MediaQuery.of(context).size.height * 0.28),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row( // Left Actions
                  children: [
                    _buildInteractiveButton( icon: isLiked ? Icons.favorite : Icons.favorite_border, countStream: FirebaseFirestore.instance.collection('posts').doc(postId).collection('likes').snapshots(), onTap: () => _likePost(context, data), color: isLiked ? Colors.red.shade600 : kIconInactive, tooltip: isLiked ? 'Unlike' : 'Like',),
                    SizedBox(width: screenWidth * 0.04),
                    _buildInteractiveButton( icon: Icons.chat_bubble_outline, countStream: FirebaseFirestore.instance.collection('posts').doc(postId).collection('comments').snapshots(), onTap: () => _openCommentSection(context, data), color: kIconInactive, tooltip: 'Comment',),
                  ],
                ),
                Row( // Right Actions
                  children: [
                    _buildInteractiveButton( icon: Icons.insights, onTap: () => _showInsights(context, data), color: kIconInactive, tooltip: 'View Insights', showCount: false,),
                    SizedBox(width: screenWidth * 0.03),
                    _buildInteractiveButton( icon: Icons.share_outlined, countStream: FirebaseFirestore.instance.collection('posts').doc(postId).snapshots(), countExtractor: (snapshot) { if (snapshot is DocumentSnapshot && snapshot.exists) { final d = snapshot.data() as Map<String, dynamic>; return (d['shares'] is int) ? d['shares'] : 0; } return 0; }, onTap: () => _sharePost(context, data), color: kIconInactive, tooltip: 'Share',),
                    SizedBox(width: screenWidth * 0.03),
                    _buildInteractiveButton( icon: Icons.bookmark_border, onTap: () => _bookmarkProject(context, data), color: kIconInactive, tooltip: 'Bookmark', showCount: false,),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: (index % 10 * 50).ms).slideY(begin: 0.1, duration: 300.ms);
  }

  // --- Post Card Header ---
  Widget _buildPostCardHeader(BuildContext context, Map<String, dynamic> data, double screenWidth) {
    final String userId = data['uid'] ?? '';
    final String authorName = data['author'] ?? 'Unknown User';
    return Padding(
      padding: EdgeInsets.all(screenWidth * 0.03),
      child: Row(
        children: [
          GestureDetector(
            onTap: () { ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text("This is your post.")),); },
            child: CircleAvatar( radius: 18, backgroundColor: kPrimaryTeal.withOpacity(0.15), backgroundImage: (data['photoURL'] != null && data['photoURL'].toString().isNotEmpty) ? NetworkImage(data['photoURL']) : null, child: (data['photoURL'] == null || data['photoURL'].toString().isEmpty) ? Icon(Icons.person_outline, color: kPrimaryTeal, size: 20) : null,).animate().fadeIn(duration: 400.ms),
          ),
          SizedBox(width: screenWidth * 0.03),
          Expanded(
            child: Column( crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text( authorName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kTextPrimary), overflow: TextOverflow.ellipsis,),
                if (data['timestamp'] != null) Text( formatTimestamp(data['timestamp']), style: TextStyle(color: kTextSecondary, fontSize: 11),),
              ],
            ),
          ),
          IconButton( icon: const Icon(Icons.more_vert, color: kIconInactive, size: 20), padding: EdgeInsets.zero, constraints: BoxConstraints(), tooltip: 'More options', onPressed: () => _showPostOptions(context, data),),
        ],
      ),
    );
  }

  // --- Interactive Button Widget ---
  Widget _buildInteractiveButton({ required IconData icon, required VoidCallback onTap, required Color color, String? tooltip, Stream<dynamic>? countStream, int Function(dynamic)? countExtractor, bool showCount = true, }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton( icon: Icon(icon, color: color, size: 22), onPressed: onTap, splashRadius: 20, padding: EdgeInsets.all(6), constraints: BoxConstraints(), tooltip: tooltip, visualDensity: VisualDensity.compact,),
        if (showCount && countStream != null)
          StreamBuilder<dynamic>( stream: countStream, builder: (context, snapshot) { int count = 0; if (snapshot.hasData) { try { if (countExtractor != null) { count = countExtractor(snapshot.data); } else if (snapshot.data is QuerySnapshot) { count = (snapshot.data as QuerySnapshot).docs.length; } } catch (e) { count = 0; } } if (count > 0) { return Padding( padding: const EdgeInsets.only(left: 0), child: Text('$count', style: TextStyle(color: kTextSecondary, fontSize: 13, fontWeight: FontWeight.w500)),); } else { return const SizedBox.shrink(); } },),
        if (showCount && countStream == null) Padding( padding: const EdgeInsets.only(left: 0), child: Text('0', style: TextStyle(color: kTextSecondary, fontSize: 13, fontWeight: FontWeight.w500)),),
      ],
    );
  }

  // --- Like/Unlike Post Logic ---
  void _likePost(BuildContext context, Map<String, dynamic> data) async {
    if (_currentUser == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to like posts'))); return; }
    final postId = data['postId'] as String?; final postOwnerId = data['uid'] as String?;
    if (postId == null || postId.isEmpty) { print("Error: Cannot like post with null or empty postId."); return; }
    final likeRef = FirebaseFirestore.instance.collection('posts').doc(postId).collection('likes').doc(_currentUser!.uid); final bool currentlyLiked = _likedPosts[postId] ?? false;
    setState(() { _likedPosts[postId] = !currentlyLiked; });
    try {
      final likeDoc = await likeRef.get();
      if (likeDoc.exists) { await likeRef.delete(); print("Post unliked: $postId by ${_currentUser!.uid}"); }
      else { await likeRef.set({'userId': _currentUser!.uid, 'timestamp': FieldValue.serverTimestamp()}); print("Post liked: $postId by ${_currentUser!.uid}");
      // Send Notification
      if (postOwnerId != null && postOwnerId != _currentUser!.uid) { QuerySnapshot existingNotifs = await FirebaseFirestore.instance.collection('notifications').where('userId', isEqualTo: postOwnerId).where('actorId', isEqualTo: _currentUser!.uid).where('postId', isEqualTo: postId).where('type', isEqualTo: 'like').where('timestamp', isGreaterThan: Timestamp.fromDate(DateTime.now().subtract(Duration(hours: 1)))).limit(1).get(); if (existingNotifs.docs.isEmpty) { await FirebaseFirestore.instance.collection('notifications').add({'userId': postOwnerId, 'type': 'like', 'postId': postId, 'actorId': _currentUser!.uid, 'actorName': _currentUser!.displayName ?? 'Someone', 'timestamp': FieldValue.serverTimestamp(), 'read': false, 'postTitle': data['title'] ?? '',}); }}
      }
    } catch (e) { print("Error liking/unliking post $postId in My Posts: $e"); setState(() { _likedPosts[postId] = currentlyLiked; }); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error updating like status.'))); }
  }

  // --- Bookmark Function ---
  void _bookmarkProject(BuildContext context, Map<String, dynamic> data) async {
    if (_currentUser == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to bookmark posts'))); return; }
    final String? postId = data['postId']; if (postId == null || postId.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Cannot bookmark post with invalid ID.'))); return; }
    final bookmarkRef = FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).collection('bookmarks').doc(postId);
    try {
      final bookmarkDoc = await bookmarkRef.get(); final String postTitle = data['title'] ?? 'this post';
      if (bookmarkDoc.exists) { await bookmarkRef.delete(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Removed "$postTitle" from bookmarks!'), backgroundColor: kSecondaryCoral)); }
      else { await bookmarkRef.set({'postId': postId, 'title': data['title'] ?? 'Untitled Post', 'author': data['author'] ?? 'Unknown Author', 'timestamp': FieldValue.serverTimestamp(), 'previewImage': (data['type'] == 'image' && data['mediaUrl'] != null) ? data['mediaUrl'] : null, 'type': data['type'] ?? 'text',}); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bookmarked "$postTitle"!'), backgroundColor: kPrimaryTeal)); }
    } catch (e) { print("Error bookmarking post $postId: $e"); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating bookmarks.'))); }
  }

  // --- Navigate to Comment Section ---
  void _openCommentSection(BuildContext context, Map<String, dynamic> data) {
    final postId = data['postId'] as String?; if (postId == null || postId.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Cannot open comments for invalid post ID."))); return; }
    Navigator.push(context, MaterialPageRoute(builder: (context) => CommentScreen(postId: postId)));
  }

  // --- Navigate to Insights Screen ---
  void _showInsights(BuildContext context, Map<String, dynamic> data) {
    final postId = data['postId'] as String?; if (postId == null || postId.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Cannot show insights for invalid post ID."))); return; }
    Navigator.push(context, MaterialPageRoute(builder: (context) => InsightScreen(data: data)));
  }

  // --- Share Post Logic ---
  Future<void> _sharePost(BuildContext context, Map<String, dynamic> data) async {
    final String postTitle = data['title'] ?? 'Check out this post!'; final String? postMediaUrl = data['mediaUrl'] is String ? data['mediaUrl'] : null; final String postId = data['postId'] ?? ''; final String postLink = "https://yourapp.example.com/post/$postId";
    String shareText = "$postTitle\n\nView post: $postLink";
    try {
      XFile? sharedFile;
      if (!kIsWeb && postMediaUrl != null && postMediaUrl.isNotEmpty) { final directory = await getTemporaryDirectory(); final String fileExtension = data['type'] == 'video' ? 'mp4' : 'jpg'; final filePath = '${directory.path}/share_media.$fileExtension'; final file = File(filePath); try { final response = await http.get(Uri.parse(postMediaUrl)).timeout(Duration(seconds: 15)); if (response.statusCode == 200) { await file.writeAsBytes(response.bodyBytes); sharedFile = XFile(file.path); } } catch (e) { print("Error downloading media for sharing: $e"); } }
      if (sharedFile != null) { await Share.shareXFiles([sharedFile], text: shareText); } else { await Share.share(shareText); }
      if (postId.isNotEmpty) { await FirebaseFirestore.instance.collection('posts').doc(postId).update({'shares': FieldValue.increment(1)}); }
    } catch (e) { print('Error sharing post $postId: $e'); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to share post.'))); }
  }

  // --- Show Post Options (Delete, Edit) ---
  void _showPostOptions(BuildContext context, Map<String, dynamic> data) {
    final String postId = data['postId'] ?? ''; if (postId.isEmpty || _currentUser == null || data['uid'] != _currentUser!.uid) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cannot modify this post."))); return; }
    showModalBottomSheet(context: context, backgroundColor: kCardBackground, shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        builder: (BuildContext bc) {
          return Wrap( children: <Widget>[
            ListTile( leading: Icon(Icons.edit_outlined, color: kPrimaryTeal), title: Text('Edit Post', style: TextStyle(color: kTextPrimary)), onTap: () { Navigator.pop(bc); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Edit Post functionality (TODO)"))); }),
            ListTile( leading: Icon(Icons.delete_outline, color: Colors.red), title: Text('Delete Post', style: TextStyle(color: Colors.red)), onTap: () async { Navigator.pop(bc); bool? confirmDelete = await showDialog<bool>(context: context, builder: (BuildContext context) { return AlertDialog( title: const Text('Confirm Delete'), content: const Text('Are you sure you want to permanently delete this post? This includes all likes and comments. This action cannot be undone.'), actions: <Widget>[ TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop(false)), TextButton(child: Text('Delete', style: TextStyle(color: Colors.red.shade700)), onPressed: () => Navigator.of(context).pop(true)),],);},); if (confirmDelete == true) { _deletePost(context, postId); } }),
          ],);});
  }

  // --- Delete Post Logic ---
  Future<void> _deletePost(BuildContext context, String postId) async {
    if (postId.isEmpty) return; if (!mounted) return;
    showDialog(context: context, barrierDismissible: false, builder: (context) => Center(child: CircularProgressIndicator(color: kPrimaryTeal)));
    try {
      final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);
      var likesSnapshot = await postRef.collection('likes').get(); WriteBatch batch = FirebaseFirestore.instance.batch(); for (var doc in likesSnapshot.docs) { batch.delete(doc.reference); }
      var commentsSnapshot = await postRef.collection('comments').get(); for (var doc in commentsSnapshot.docs) { batch.delete(doc.reference); }
      batch.delete(postRef); await batch.commit();
      // TODO: Implement storage file deletion if needed/possible
      if (!mounted) return; Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Post deleted successfully'), backgroundColor: kPrimaryTeal));
    } catch (e) { if (!mounted) return; Navigator.pop(context); print("Error deleting post $postId: $e"); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting post: ${e.toString()}'), backgroundColor: Colors.red)); }
  }

// --- END: Reused Card Building and Action Logic ---

}
// END OF FILE my_posts_screen.dart