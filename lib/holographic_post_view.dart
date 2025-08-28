import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'formatters.dart';
import 'content_preview.dart';
import 'CommentScreen.dart'; // Import the CommentScreen

// Color palette
const Color primaryBlue = Color(0xFF1976D2);
const Color lightBlue = Color(0xFF64B5F6);
const Color veryLightBlue = Color(0xFFE3F2FD);
const Color darkBlue = Color(0xFF0D47A1);
const Color accentBlue = Color(0xFF29B6F6);

class HolographicPostView extends StatefulWidget {
  final Map<String, dynamic> data;

  const HolographicPostView({Key? key, required this.data}) : super(key: key);

  @override
  State<HolographicPostView> createState() => _HolographicPostViewState();
}

class _HolographicPostViewState extends State<HolographicPostView> {
  // Cache for user data to avoid repeated fetches
  Map<String, dynamic>? _userData;
  bool _isLoadingUserData = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Method to load user data from Firestore
  Future<void> _loadUserData() async {
    if (widget.data['uid'] == null || widget.data['uid'].toString().isEmpty) {
      return;
    }

    setState(() {
      _isLoadingUserData = true;
    });

    try {
      final userData = await _getUserData(widget.data['uid']);

      setState(() {
        _userData = userData;
        _isLoadingUserData = false;
      });
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoadingUserData = false;
      });
    }
  }

  // Helper function to get user data from Firestore
  Future<Map<String, dynamic>> _getUserData(String userId) async {
    Map<String, dynamic> userData = {'name': widget.data['author'] ?? 'Unknown User'};

    try {
      // Try studentprofile collection first
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('studentprofile')
          .doc(userId)
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        // Get name from fullName field
        String? name = data['fullName'] ??
            data['name'] ??
            data['displayName'] ??
            data['userName'];

        if (name != null) {
          userData['name'] = name;
        }

        // Get profile picture from imageUrl field
        String? photoURL = data['imageUrl'] ??
            data['photoURL'] ??
            data['profilePic'] ??
            data['avatar'];

        if (photoURL != null) {
          userData['photoURL'] = photoURL;
        }

        return userData;
      }

      // If not found in studentprofile, try users collection as fallback
      doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        String? name = data['fullName'] ??
            data['name'] ??
            data['displayName'] ??
            data['userName'] ??
            data['username'];

        if (name != null) {
          userData['name'] = name;
        }

        String? photoURL = data['imageUrl'] ??
            data['photoURL'] ??
            data['profilePic'] ??
            data['avatar'];

        if (photoURL != null) {
          userData['photoURL'] = photoURL;
        }
      }
    } catch (e) {
      print("Error fetching user data: $e");
    }

    return userData;
  }

  // Helper function to validate image URLs
  bool _isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) {
      return false;
    }

    // Basic URL validation
    return url.startsWith('http://') || url.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    // Set status bar color to match our theme
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: primaryBlue, // Match status bar to our app color
      statusBarIconBrightness: Brightness.light, // White status bar icons
      statusBarBrightness: Brightness.dark, // Dark status bar (iOS)
    ));

    // Get the user's name and photo from cached data or post data
    final String authorName = _userData?['name'] ?? widget.data['author'] ?? 'Unknown';
    final String? photoURL = _userData?['photoURL'] ?? widget.data['photoURL'];

    // Check if photoURL is valid
    final bool hasValidImage = _isValidImageUrl(photoURL);

    // Get first letter for avatar fallback
    final String firstLetter = authorName.isNotEmpty ? authorName[0].toUpperCase() : 'U';

    // Check if there's media content
    final bool hasMedia = widget.data['mediaUrl'] != null &&
        widget.data['mediaUrl'].toString().isNotEmpty;

    // Determine if it's a video post
    final bool isVideoPost = hasMedia && widget.data['type'] == 'video';

    // Check if there's content text
    final bool hasContent = widget.data['content'] != null &&
        widget.data['content'].toString().isNotEmpty;

    return Scaffold(
      backgroundColor: veryLightBlue,
      extendBodyBehindAppBar: true,
      // No app bar, just a safe area with a back button
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(0), // Zero height app bar
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false, // Remove default back button
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: primaryBlue, // Ensures status bar color is set
            statusBarIconBrightness: Brightness.light,
          ),
        ),
      ),
      body: Column(
        children: [
          // Custom top bar with back button
          Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
            color: primaryBlue,
            child: SafeArea(
              bottom: false, // Don't add padding at the bottom
              child: Row(
                children: [
                  // Back button
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),

                  // Avatar with subtle border
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.7), width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 40,
                        height: 40,
                        child: hasValidImage
                            ? CachedNetworkImage(
                          imageUrl: photoURL!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: lightBlue.withOpacity(0.3),
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
                                ),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: lightBlue.withOpacity(0.3),
                            child: Center(
                              child: Text(
                                firstLetter,
                                style: TextStyle(
                                  color: primaryBlue,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        )
                            : Container(
                          color: lightBlue.withOpacity(0.3),
                          child: Center(
                            child: Text(
                              firstLetter,
                              style: TextStyle(
                                color: primaryBlue,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
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
                          authorName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          widget.data['timestamp'] != null
                              ? formatTimestamp(widget.data['timestamp'])
                              : 'Just now',
                          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                  // Comments Button
                  IconButton(
                    icon: Icon(Icons.chat_bubble_outline, color: Colors.white),
                    onPressed: () {
                      // Navigate to CommentScreen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CommentScreen(postId: widget.data['postId']),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Main content (scrollable)
          Expanded(
            child: SingleChildScrollView(
              physics: BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main Content Container
                  Container(
                    width: double.infinity,
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
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title with enhanced styling
                          if (widget.data['title'] != null && widget.data['title'].toString().isNotEmpty)
                            _buildTitleSection(),

                          // Content text with better formatting
                          if (hasContent)
                            _buildContentSection(hasMedia),

                          // Media content with enhanced container
                          if (hasMedia)
                            _buildMediaContainer(context, isVideoPost),

                          // For text-only posts, add some visual elements
                          if (!hasMedia && hasContent)
                            _buildTextOnlyDecorations(),

                          // Domain tag if available
                          if (widget.data['domain'] != null && widget.data['domain'].toString().isNotEmpty)
                            _buildDomainTag(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Navigation Bar for Comments
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, -3),
                ),
              ],
            ),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Comments Count
                  Row(
                    children: [
                      Icon(Icons.chat_bubble_outline, color: primaryBlue, size: 20),
                      SizedBox(width: 8),
                      Text(
                        '${widget.data['commentCount'] ?? 0} Comments',
                        style: TextStyle(
                          color: darkBlue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  // View Comments Button
                  ElevatedButton(
                    onPressed: () {
                      // Navigate to CommentScreen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CommentScreen(postId: widget.data['postId']),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    child: Text('View Comments'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Title section with bottom border
  Widget _buildTitleSection() {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: lightBlue.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Text(
        widget.data['title'] ?? '',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: darkBlue,
          height: 1.3,
        ),
      ),
    );
  }

  // Content section with text
  Widget _buildContentSection(bool hasMedia) {
    // Add extra bottom margin for text-only posts
    final bottomMargin = hasMedia ? 20.0 : 30.0;

    return Container(
      margin: EdgeInsets.only(bottom: bottomMargin),
      child: Text(
        widget.data['content'] ?? '',
        style: TextStyle(
          fontSize: 16,
          color: Colors.black87,
          height: 1.5,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  // Special decorations for text-only posts
  Widget _buildTextOnlyDecorations() {
    return Container(
      margin: EdgeInsets.only(bottom: 20, top: 10),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: lightBlue.withOpacity(0.3),
              thickness: 1,
            ),
          ),
          Container(
            margin: EdgeInsets.symmetric(horizontal: 10),
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: veryLightBlue,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.format_quote,
              color: primaryBlue,
              size: 18,
            ),
          ),
          Expanded(
            child: Divider(
              color: lightBlue.withOpacity(0.3),
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }

  // Domain tag
  Widget _buildDomainTag() {
    return Container(
      margin: EdgeInsets.only(top: 16),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: accentBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentBlue.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.tag, size: 14, color: accentBlue),
          SizedBox(width: 4),
          Text(
            widget.data['domain'] ?? '',
            style: TextStyle(
              color: accentBlue,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build media container with proper styling
  Widget _buildMediaContainer(BuildContext context, bool isVideoPost) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Determine appropriate height based on media type
    double mediaHeight;
    if (isVideoPost) {
      // Videos use 16:9 ratio (standard video format)
      mediaHeight = screenHeight * 0.35; // Fixed height for videos
    } else {
      // For images, determine based on device size and orientation
      final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;

      if (isPortrait) {
        // In portrait, we can use a larger portion of the screen
        mediaHeight = screenHeight * 0.4; // Taller in portrait
      } else {
        // In landscape, we need to be more conservative with height
        mediaHeight = screenHeight * 0.6; // Still visible in landscape
      }

      // Adjust height based on screen size (smaller for phones, larger for tablets)
      if (screenWidth > 600) { // Tablet-sized device
        mediaHeight = mediaHeight * 0.8; // Slightly smaller on tablets
      }
    }

    // Clamp height to reasonable min/max values
    mediaHeight = mediaHeight.clamp(200.0, screenHeight * 0.65);

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: darkBlue.withOpacity(0.15),
            blurRadius: 10,
            offset: Offset(0, 5),
            spreadRadius: 1,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias, // Ensures the border radius is applied
      child: Stack(
        children: [
          // Content preview with calculated height
          buildContentPreview(
            context,
            widget.data,
            height: mediaHeight,
          ),

          // Video play button
          if (isVideoPost)
            Positioned.fill(
              child: Center(
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primaryBlue.withOpacity(0.7),
                  ),
                  child: Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}