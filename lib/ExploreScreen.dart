import 'dart:io';
import 'dart:async';
import 'dart:math' show min;
import 'package:eduspark/Services/explore_notification_service.dart';
import 'Fullscreenimage.dart';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:eduspark/ProfileScreen.dart';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
// Constants and Utils
import 'app_colors.dart'; // Using the updated app_colors.dart
import 'formatters.dart';

// Widgets
import 'content_preview.dart';
import 'VideoWidget.dart'; // Required by content_preview

// Screens
import 'holographic_post_view.dart';
import 'insight_screen.dart';
import 'CommentScreen.dart';
import 'Chat_screen.dart'; // Needed for navigation
import 'message_screen.dart'; // Might be needed if navigating elsewhere
import 'UploadPostScreen.dart'; // Placeholder
import 'ProfileScreen.dart'; // Potentially needed for user data if not on chat doc

// Primary and Secondary Brand Colors
const Color kAppPrimary = Color(0xFF1976D2);    // Main brand blue
const Color kAppSecondary = Color(0xFF303F9F);  // Secondary blue (darker)
const Color kAppAccent = Color(0xFF00B0FF);     // Accent blue (brighter)

// Modern UI Color Palette
const Color kModernBackground = Colors.white;   // White background
const Color kModernCard = Colors.white;         // White card background
const Color kModernShadow = Color(0x33000000);  // Shadow color with opacity
const Color kModernTextPrimary = Color(0xFF1F1F1F);  // Almost black text
const Color kModernTextSecondary = Color(0xFF757575);  // Gray secondary text
const Color kModernIcon = Color(0xFF616161);    // Gray icons

// Interaction Colors
const Color kLikeRed = Color(0xFFF44336);       // Red for likes
const Color kSuccessGreen = Color(0xFF4CAF50);  // Green for success states
const Color kWarningYellow = Color(0xFFFFC107); // Yellow for warnings
const Color kErrorRed = Color(0xFFE53935);      // Red for errors

// Gradient Colors
const List<Color> kPrimaryGradient = [
  Color(0xFF1976D2),  // Start with primary
  Color(0xFF2196F3),  // End with lighter blue
];

const List<Color> kAccentGradient = [
  Color(0xFF00B0FF),  // Start with accent
  Color(0xFF40C4FF),  // End with lighter accent
];

// Button and Interaction Colors
const Color kActiveButton = Color(0xFF1976D2);       // Button background
const Color kActiveButtonText = Colors.white;        // Button text
const Color kInactiveButton = Color(0xFFE0E0E0);     // Inactive button
const Color kInactiveButtonText = Color(0xFF9E9E9E); // Inactive button text

// Chat and Message Colors
const Color kChatBubbleSelf = Color(0xFFE3F2FD);    // Light blue for own messages
const Color kChatBubbleOther = Color(0xFFF5F5F5);   // Light gray for other's messages
const Color kChatTimestamp = Color(0xFF9E9E9E);     // Gray timestamp text

// Misc UI Colors
const Color kDivider = Color(0xFFE0E0E0);           // Divider lines
const Color kBorderColor = Color(0xFFE0E0E0);       // Border color
const Color kCardBackground = Colors.white;         // Card background
const Color kCardShadow = Color(0x1A000000);        // Card shadow

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({Key? key}) : super(key: key);

  @override
  _ExploreScreenState createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with SingleTickerProviderStateMixin {
  bool _isFabExpanded = false;
  late AnimationController _fabController;
  late Animation<double> _fabAnimation;
  final Map<String, bool> _likedPosts = {}; // Local cache for liked status
  final Map<String, bool> _bookmarkedPosts = {}; // Local cache for bookmark status
  String _selectedDomain = 'All'; // Default filter

  // Search related variables
  TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = '';
  Timer? _searchDebounce;

  // Refresh indicator key
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();

  // Add a scroll controller to maintain scroll position
  final ScrollController _scrollController = ScrollController();

  // Add a variable to store current posts to avoid rebuilding
  List<QueryDocumentSnapshot> _currentPosts = [];
  bool _isLoadingMorePosts = false;
  bool _hasMorePosts = true;
  int _postsPerPage = 10; // Number of posts to load at once
  DocumentSnapshot? _lastVisiblePost;

  // Add error state variables
  bool _hasError = false;
  String _errorMessage = '';

  // Add empty state tracking
  bool _isEmptyResults = false;

  // List of domains for filtering
  final List<String> _domains = [
    'All',
    'Full Stack Development',
    'Python Development',
    'Java Development',
    'AIML',
    'Data Science',
    'CyberSecurity',
    'Much More', // Consider making this more specific or dynamic
  ];

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fabAnimation =
        CurvedAnimation(parent: _fabController, curve: Curves.easeInOut);

    // Setup scroll listener for pagination
    _scrollController.addListener(_scrollListener);

    // Initial load of posts
    _loadInitialPosts();
  }

  // Scroll listener to detect when user reaches bottom
  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMorePosts &&
        _hasMorePosts) {
      _loadMorePosts();
    }
  }

  // Load initial posts
  Future<void> _loadInitialPosts() async {
    if (_currentPosts.isNotEmpty && !_isSearching) return; // Prevent duplicate loads unless searching

    setState(() {
      _isLoadingMorePosts = true;
      _hasError = false;
      _errorMessage = '';
      _isEmptyResults = false;
    });

    try {
      Query postsQuery;

      // If we're searching, apply improved search filter
      if (_searchQuery.isNotEmpty) {
        // Log the search query for debugging
        print("Searching for: '$_searchQuery'");

        try {
          // First fetch a reasonable number of posts for client-side filtering
          final QuerySnapshot allPosts = await FirebaseFirestore.instance
              .collection('posts')
              .orderBy('timestamp', descending: true)
              .limit(100) // Limit to a reasonable number for client-side filtering
              .get();

          print("Total posts fetched for search: ${allPosts.docs.length}");

          // Convert search query to lowercase for case-insensitive matching
          String searchLower = _searchQuery.toLowerCase();

          // Filter posts client-side for more flexible matching
          List<QueryDocumentSnapshot> matchingPosts = [];

          for (var doc in allPosts.docs) {
            try {
              Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

              // Get text fields and convert to lowercase strings, handling nulls safely
              String title = (data['title'] ?? '').toString().toLowerCase();
              String content = (data['content'] ?? '').toString().toLowerCase();
              String author = (data['author'] ?? '').toString().toLowerCase();
              String domain = (data['domain'] ?? '').toString().toLowerCase();

              // Check if search term appears in any of these fields
              bool matches = title.contains(searchLower) ||
                  content.contains(searchLower) ||
                  author.contains(searchLower) ||
                  domain.contains(searchLower);

              // Debug log for matches
              if (matches) {
                print("Match found: '${data['title']}' by ${data['author']}");
                matchingPosts.add(doc);
              }
            } catch (e) {
              print("Error processing document in search: $e");
              // Continue with next document
            }
          }

          print("Search results: ${matchingPosts.length} matches found");

          if (mounted) {
            setState(() {
              _currentPosts = matchingPosts;
              _isLoadingMorePosts = false;
              _hasMorePosts = false; // Don't try to load more for search results
              _isEmptyResults = matchingPosts.isEmpty;
            });
          }

          // Pre-fetch interaction statuses for found posts
          if (matchingPosts.isNotEmpty) {
            _batchFetchInteractionStatuses(matchingPosts);
          }
        } catch (e) {
          print("Error in client-side search: $e");

          // Fallback to original server-side search if client-side fails
          print("Falling back to server-side search");

          // First try exact match on title
          postsQuery = FirebaseFirestore.instance
              .collection('posts')
              .orderBy('timestamp', descending: true)
              .where('title', isGreaterThanOrEqualTo: _searchQuery)
              .where('title', isLessThanOrEqualTo: _searchQuery + '\uf8ff');

          final QuerySnapshot searchSnapshot = await postsQuery.limit(_postsPerPage).get();

          if (searchSnapshot.docs.isEmpty) {
            // If no exact title matches, try content
            postsQuery = FirebaseFirestore.instance
                .collection('posts')
                .orderBy('timestamp', descending: true)
                .where('content', isGreaterThanOrEqualTo: _searchQuery)
                .where('content', isLessThanOrEqualTo: _searchQuery + '\uf8ff');

            final QuerySnapshot contentSearchSnapshot = await postsQuery.limit(_postsPerPage).get();

            _handleQueryResults(contentSearchSnapshot);
          } else {
            _handleQueryResults(searchSnapshot);
          }
        }
      }
      // If we're filtering by domain
      else if (_selectedDomain != 'All') {
        // This query requires a composite index, use a try-catch to handle missing index
        try {
          // Try the query that needs an index
          postsQuery = FirebaseFirestore.instance
              .collection('posts')
              .where('domain', isEqualTo: _selectedDomain)
              .orderBy('timestamp', descending: true);

          final QuerySnapshot snapshot = await postsQuery
              .limit(_postsPerPage)
              .get();

          _handleQueryResults(snapshot);
        } catch (indexError) {
          print("Index error: $indexError");
          // Show a message to the user about the index
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('First-time setup: This filter requires a Firestore index. Using "All" posts for now.'),
              duration: Duration(seconds: 5),
            ),
          );

          // Fallback to the query without the domain filter
          postsQuery = FirebaseFirestore.instance
              .collection('posts')
              .orderBy('timestamp', descending: true);

          final QuerySnapshot snapshot = await postsQuery
              .limit(_postsPerPage)
              .get();

          _handleQueryResults(snapshot);

          // Update the selection to "All" since that's what we're actually showing
          setState(() {
            _selectedDomain = 'All';
          });
        }
      } else {
        // This query doesn't need a composite index
        postsQuery = FirebaseFirestore.instance
            .collection('posts')
            .orderBy('timestamp', descending: true);

        final QuerySnapshot snapshot = await postsQuery
            .limit(_postsPerPage)
            .get();

        _handleQueryResults(snapshot);
      }
    } catch (e) {
      print("Error loading initial posts: $e");
      setState(() {
        _isLoadingMorePosts = false;
        _hasError = true;
        _errorMessage = 'Failed to load posts. Please try again.';
      });
    }
  }

  void _handleQueryResults(QuerySnapshot snapshot) {
    if (snapshot.docs.isNotEmpty) {
      _lastVisiblePost = snapshot.docs.last;

      setState(() {
        _currentPosts = snapshot.docs;
        _isLoadingMorePosts = false;
        _hasMorePosts = snapshot.docs.length == _postsPerPage;
        _isEmptyResults = false;
      });

      // Pre-fetch interaction statuses for visible posts
      _batchFetchInteractionStatuses(snapshot.docs);
    } else {
      setState(() {
        _isLoadingMorePosts = false;
        _hasMorePosts = false;
        _isEmptyResults = true;
        _currentPosts = []; // Clear current posts if no results
      });
    }
  }

  // Load more posts when user scrolls to bottom
  void _loadMorePosts() async {
    if (_isLoadingMorePosts || !_hasMorePosts || _lastVisiblePost == null || _searchQuery.isNotEmpty) return;
    // Don't load more posts during search - implement separate pagination for search if needed

    setState(() {
      _isLoadingMorePosts = true;
    });

    try {
      Query postsQuery;

      if (_selectedDomain != 'All') {
        // This query requires a composite index, use a try-catch to handle missing index
        try {
          // Try the query that needs an index
          postsQuery = FirebaseFirestore.instance
              .collection('posts')
              .where('domain', isEqualTo: _selectedDomain)
              .orderBy('timestamp', descending: true);

          final QuerySnapshot snapshot = await postsQuery
              .startAfterDocument(_lastVisiblePost!)
              .limit(_postsPerPage)
              .get();

          _handleMoreQueryResults(snapshot);
        } catch (indexError) {
          print("Index error in loadMorePosts: $indexError");
          // For loadMore, it's better to just show an error than switch filter
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Filter requires a Firestore index. Please create it or use "All" posts.'),
              duration: Duration(seconds: 5),
              action: SnackBarAction(
                label: 'SWITCH TO ALL',
                onPressed: () {
                  setState(() {
                    _selectedDomain = 'All';
                    _resetAndRefreshPosts();
                  });
                },
              ),
            ),
          );
          // Don't auto-switch to "All" here - just stop loading more
          setState(() {
            _isLoadingMorePosts = false;
          });
        }
      } else {
        // This query doesn't need a composite index
        postsQuery = FirebaseFirestore.instance
            .collection('posts')
            .orderBy('timestamp', descending: true);

        final QuerySnapshot snapshot = await postsQuery
            .startAfterDocument(_lastVisiblePost!)
            .limit(_postsPerPage)
            .get();

        _handleMoreQueryResults(snapshot);
      }
    } catch (e) {
      print("Error loading more posts: $e");
      setState(() {
        _isLoadingMorePosts = false;
        // Show a snackbar instead of changing state to error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading more posts. Please try again.')),
        );
      });
    }
  }

  void _handleMoreQueryResults(QuerySnapshot snapshot) {
    if (snapshot.docs.isNotEmpty) {
      _lastVisiblePost = snapshot.docs.last;

      setState(() {
        _currentPosts.addAll(snapshot.docs);
        _isLoadingMorePosts = false;
        _hasMorePosts = snapshot.docs.length == _postsPerPage;
      });

      // Pre-fetch interaction statuses for newly loaded posts
      _batchFetchInteractionStatuses(snapshot.docs);
    } else {
      setState(() {
        _isLoadingMorePosts = false;
        _hasMorePosts = false;
      });
    }
  }

  // Reset and refresh posts for domain changes or manual refresh
  Future<void> _resetAndRefreshPosts() async {
    setState(() {
      _currentPosts = [];
      _lastVisiblePost = null;
      _hasMorePosts = true;
      _likedPosts.clear();
      _bookmarkedPosts.clear();
      _hasError = false;
      _errorMessage = '';
      _isEmptyResults = false;
    });

    return _loadInitialPosts();
  }

  // Handle search query changes with debounce
  void _onSearchChanged(String query) {
    if (_searchDebounce?.isActive ?? false) {
      _searchDebounce!.cancel();
    }

    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (query != _searchQuery) {
        setState(() {
          _searchQuery = query;
          _isSearching = query.isNotEmpty;
          // Reset pagination state for new search
          _currentPosts = [];
          _lastVisiblePost = null;
          _hasMorePosts = true;
        });

        _loadInitialPosts();
      }
    });
  }

  // Clear search and reset to normal view
  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _isSearching = false;
    });
    _resetAndRefreshPosts();
  }

  // Fetch interaction statuses in batch for visible posts
  void _batchFetchInteractionStatuses(List<QueryDocumentSnapshot> posts) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      List<Future> futures = [];

      for (var postDoc in posts) {
        final postId = postDoc.id;

        // Only fetch if not already in cache
        if (!_likedPosts.containsKey(postId)) {
          futures.add(
              FirebaseFirestore.instance
                  .collection('posts')
                  .doc(postId)
                  .collection('likes')
                  .doc(user.uid)
                  .get()
                  .then((likeDoc) {
                if (mounted) {
                  setState(() {
                    _likedPosts[postId] = likeDoc.exists;
                  });
                }
              })
          );
        }

        if (!_bookmarkedPosts.containsKey(postId)) {
          futures.add(
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('bookmarks')
                  .doc(postId)
                  .get()
                  .then((bookmarkDoc) {
                if (mounted) {
                  setState(() {
                    _bookmarkedPosts[postId] = bookmarkDoc.exists;
                  });
                }
              })
          );
        }
      }

      // Wait for all futures to complete
      await Future.wait(futures);
    } catch (e) {
      print("Error batch fetching interaction statuses: $e");
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _fabController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: kModernBackground,
      body: GestureDetector(
        // Add this gesture detector for horizontal swipes
        onHorizontalDragEnd: (details) {
          // Check if swipe was from left to right (positive velocity)
          if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
            _navigateToMessages();
          }
        },
        child: RefreshIndicator(
          key: _refreshIndicatorKey,
          color: kAppPrimary,
          backgroundColor: Colors.white,
          strokeWidth: 2.5,
          onRefresh: _resetAndRefreshPosts,
          child: SafeArea(
            child: Column(
              children: [
                // --- Top Bar ---
                _buildModernTopBar(context, user, screenWidth),

                // --- Domain Filter (Optional - could be moved or restyled) ---
                _buildModernDomainFilter(context),

                // --- Post List ---
                Expanded(
                  child: _buildPostList(context),
                ),
              ],
            ),
          ),
        ),
      ),
      // --- Floating Action Button ---
      floatingActionButton: _buildModernCreativeFab(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

// Add this helper method to navigate to messages
  void _navigateToMessages() {
    // Show feedback to the user for the swipe action
    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(Icons.swipe_right_alt, color: Colors.white),
          SizedBox(width: 10),
          Text('Navigating to Messages'),
        ],
      ),
      duration: Duration(milliseconds: 500),
      backgroundColor: kAppPrimary,
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);

    // Wait for snackbar to show briefly before navigating
    Future.delayed(Duration(milliseconds: 300), () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const MessagesScreen()),
      );
    });
  }

  // Build post list with cached posts to avoid rebuilding on likes
  Widget _buildPostList(BuildContext context) {
    // Show loading indicator if initial load
    if (_currentPosts.isEmpty && _isLoadingMorePosts) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(kAppPrimary),
              strokeWidth: 3.0,
            ).animate().fadeIn(duration: 500.ms),
            SizedBox(height: 16),
            Text(
              'Loading posts...',
              style: TextStyle(color: kModernTextSecondary, fontSize: 16),
            ).animate().fadeIn(duration: 700.ms),
          ],
        ),
      );
    }

    // Show error state
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: kErrorRed.withOpacity(0.8))
                .animate().fadeIn(duration: 500.ms),
            SizedBox(height: 16),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: kModernTextSecondary, fontSize: 16),
            ).animate().fadeIn(duration: 700.ms),
            SizedBox(height: 24),
            ElevatedButton.icon(
              icon: Icon(Icons.refresh),
              label: Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kAppPrimary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: _resetAndRefreshPosts,
            ).animate().fadeIn(duration: 900.ms).scale(begin: Offset(0.9, 0.9)),
          ],
        ),
      );
    }

    // Show empty state for search or filter
    if (_isEmptyResults) {
      return SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(), // Enable pull-to-refresh
        child: Container(
          height: MediaQuery.of(context).size.height * 0.7, // Make sure it's tall enough for pull refresh
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                    _isSearching ? Icons.search_off : Icons.inbox_outlined,
                    size: 64,
                    color: kModernTextSecondary.withOpacity(0.5)
                ).animate().fadeIn(duration: 500.ms),
                SizedBox(height: 24),
                Text(
                  _isSearching
                      ? 'No results found for "$_searchQuery"'
                      : 'No posts found for $_selectedDomain.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kModernTextSecondary, fontSize: 18, fontWeight: FontWeight.w500),
                ).animate().fadeIn(duration: 500.ms),
                SizedBox(height: 12),
                Text(
                  _isSearching
                      ? 'Try a different search term or browse all posts'
                      : 'Pull down to refresh or try a different filter',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kModernTextSecondary, fontSize: 14),
                ).animate().fadeIn(duration: 700.ms),
                if (_isSearching) ...[
                  SizedBox(height: 24),
                  OutlinedButton.icon(
                    icon: Icon(Icons.clear),
                    label: Text('Clear Search'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kAppPrimary,
                      side: BorderSide(color: kAppPrimary),
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: _clearSearch,
                  ).animate().fadeIn(duration: 900.ms),
                ],
              ],
            ).animate().fadeIn(duration: 500.ms).scale(begin: Offset(0.9, 0.9)),
          ),
        ),
      );
    }

    // Normal post list with posts
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(vertical: 8.0),
      itemCount: _currentPosts.length + (_isLoadingMorePosts || _hasMorePosts ? 1 : 0),
      physics: AlwaysScrollableScrollPhysics(), // Enable pull-to-refresh
      itemBuilder: (context, index) {
        // If we've reached the end of our cached posts
        if (index == _currentPosts.length) {
          // Show loading indicator or load more button
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 20.0),
            child: Center(
              child: _isLoadingMorePosts
                  ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 30,
                    width: 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      valueColor: AlwaysStoppedAnimation<Color>(kAppPrimary),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Loading more...',
                    style: TextStyle(color: kModernTextSecondary, fontSize: 12),
                  ),
                ],
              )
                  : _hasMorePosts
                  ? TextButton.icon(
                onPressed: _loadMorePosts,
                icon: Icon(Icons.refresh, size: 16),
                label: Text('Load more posts'),
                style: TextButton.styleFrom(
                  foregroundColor: kAppPrimary,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              )
                  : Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'No more posts to load',
                  style: TextStyle(color: kModernTextSecondary, fontSize: 12),
                ),
              ),
            ),
          );
        }

        var post = _currentPosts[index];
        try {
          var data = post.data() as Map<String, dynamic>;
          data['postId'] = post.id; // Crucial for interactions

          return _buildModernPostCard(
              context, data, index, MediaQuery.of(context).size.width);
        } catch (e) {
          print("Error processing post data at index $index: $e");
          print("Problematic Post ID: ${post.id}");
          return Card(
            color: Colors.red.shade100,
            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text("Error loading this post. ID: ${post.id}",
                  style: TextStyle(color: Colors.red.shade900)),
            ),
          );
        }
      },
    );
  }

  // --- Modern Top Bar Widget ---
  Widget _buildModernTopBar(BuildContext context, User? user, double screenWidth) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Row(
        children: [
          // Search Bar with functionality
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search posts...',
                hintStyle: TextStyle(color: kModernTextSecondary, fontSize: 15),
                prefixIcon: Icon(Icons.search, color: kModernIcon, size: 22),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: Icon(Icons.clear, color: kModernIcon, size: 18),
                  onPressed: _clearSearch,
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: Colors.grey.shade300, width: 1), // Subtle border
                ),
                enabledBorder: OutlineInputBorder( // Border when not focused
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
                ),
                focusedBorder: OutlineInputBorder( // Border when focused
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: kAppPrimary, width: 1.5), // Highlight with primary color
                ),
                filled: true,
                fillColor: kModernCard, // Use card background for fill
                contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                isDense: true,
              ),
              style: TextStyle(color: kModernTextPrimary, fontSize: 15),
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: (value) {
                // Set focus elsewhere to dismiss keyboard
                FocusScope.of(context).unfocus();
              },
            ),
          ),
          const SizedBox(width: 8),

          // Notification Icon
          _buildModernNotificationIcon(context, user),

          // Message Icon
          IconButton(
            icon: const Icon(Icons.send_outlined, // Instagram-like send icon
                color: kModernIcon, size: 26),
            tooltip: 'Messages',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const MessagesScreen()),
              );
            },
          ).animate().fadeIn(delay: 200.ms, duration: 500.ms),
        ],
      ),
    );
  }

  // --- Modern Notification Icon Widget ---
  Widget _buildModernNotificationIcon(BuildContext context, User? user){
    return Stack(
      alignment: Alignment.topRight,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_none_outlined, // Outlined version
              color: kModernIcon, size: 28), // Slightly larger
          tooltip: 'Notifications',
          onPressed: () => _showUnreadMessagesSummary(context), // Updated to call message summary
        ).animate().fadeIn(delay: 100.ms, duration: 500.ms),

        // Notification Badge Stream
        StreamBuilder<QuerySnapshot>(
          stream: user != null
              ? FirebaseFirestore.instance
              .collection('notifications')
              .where('userId', isEqualTo: user.uid)
              .where('read', isEqualTo: false)
              .limit(10) // Limit query for performance
              .snapshots()
              : null, // Return null stream if user is null
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const SizedBox.shrink(); // Don't show badge if no unread
            }
            int unreadCount = snapshot.data!.docs.length;
            return Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: EdgeInsets.all(2), // Minimal padding
                decoration: BoxDecoration(
                  color: kLikeRed, // Use vibrant red for badge
                  shape: BoxShape.circle,
                  border: Border.all(color: kModernBackground, width: 1.5), // Border against background
                ),
                constraints: BoxConstraints(
                  minWidth: 18,
                  minHeight: 18,
                ),
                child: Center(
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ).animate().scale(duration: 300.ms, curve: Curves.elasticOut),
            );
          },
        ),
      ],
    );
  }
  // --- Modern Domain Filter Dropdown Widget ---
  Widget _buildModernDomainFilter(BuildContext context) {
    // Don't show domain filter during search
    if (_isSearching) {
      return SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Container(
        height: 40, // Reduced height
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8), // Less rounded
          border: Border.all(color: Colors.grey.shade300), // Subtle border
          color: kModernCard, // White background
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _selectedDomain,
            icon: Icon(Icons.filter_list_alt, color: kModernIcon, size: 18), // Smaller icon
            isExpanded: true,
            elevation: 4, // Reduced elevation
            style: TextStyle(color: kModernTextPrimary, fontSize: 14),
            dropdownColor: kModernCard,
            onChanged: (String? newValue) {
              if (newValue != null && newValue != _selectedDomain) {
                if (newValue != 'All') {
                  // Show a warning if they're selecting a filter that might need an index
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('This filter may require a one-time Firestore index setup.'),
                      duration: Duration(seconds: 3),
                    ),
                  );
                }

                setState(() {
                  _selectedDomain = newValue;
                  // Use the new reset method
                  _resetAndRefreshPosts();
                  print("Selected Domain: $_selectedDomain");
                });
              }
            },
            items: _domains.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Row(
                  children: [
                    Icon(
                      _getIconForDomain(value),
                      color: kModernIcon.withOpacity(0.8),
                      size: 16, // Smaller icon
                    ),
                    const SizedBox(width: 8),
                    Text(value, overflow: TextOverflow.ellipsis),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // Helper to get icon based on domain name
  IconData _getIconForDomain(String domain) {
    switch (domain) {
      case 'All': return Icons.apps; // Changed icon
      case 'Full Stack Development': return Icons.web_asset; // Changed icon
      case 'Python Development': return Icons.code;
      case 'Java Development': return Icons.integration_instructions_outlined; // Changed icon
      case 'AIML': return Icons.psychology_outlined; // Changed icon
      case 'Data Science': return Icons.analytics_outlined; // Changed icon
      case 'CyberSecurity': return Icons.security_outlined; // Changed icon
      default: return Icons.category_outlined; // Changed icon
    }
  }

  // --- Modern Post Card Widget ---
  Widget _buildModernPostCard(BuildContext context,
      Map<String, dynamic> data, int index, double screenWidth) {
    final String postId = data['postId'] ?? 'error_id_${index}';
    final bool isLiked = _likedPosts[postId] ?? false;
    final bool isBookmarked = _bookmarkedPosts[postId] ?? false;

    // Highlight search results if searching
    Widget titleWidget;
    if (_isSearching && _searchQuery.isNotEmpty && data['title'] != null) {
      String title = data['title'].toString();
      if (title.toLowerCase().contains(_searchQuery.toLowerCase())) {
        // Create title with highlighted search term
        List<TextSpan> spans = [];
        int start = title.toLowerCase().indexOf(_searchQuery.toLowerCase());
        int end = start + _searchQuery.length;

        spans.add(TextSpan(
          text: title.substring(0, start),
          style: TextStyle(color: kModernTextPrimary, fontWeight: FontWeight.normal),
        ));

        spans.add(TextSpan(
          text: title.substring(start, end),
          style: TextStyle(
            color: kAppPrimary,
            fontWeight: FontWeight.bold,
            backgroundColor: kAppPrimary.withOpacity(0.1),
          ),
        ));

        spans.add(TextSpan(
          text: title.substring(end),
          style: TextStyle(color: kModernTextPrimary, fontWeight: FontWeight.normal),
        ));

        titleWidget = RichText(
          text: TextSpan(
            children: spans,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        );
      } else {
        titleWidget = Text(
          title,
          style: TextStyle(color: kModernTextPrimary, fontSize: 14),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        );
      }
    } else {
      titleWidget = data['title'] != null
          ? Text(
        data['title'].toString(),
        style: TextStyle(color: kModernTextPrimary, fontSize: 14),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      )
          : SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: kModernCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Card Header (Author Info) ---
          _buildModernPostCardHeader(context, data, screenWidth),

          // --- Post Content Preview ---
          GestureDetector(
            onTap: data['type'] != 'video'
                ? () {
              print('Post content tapped: ${data['title']} (ID: $postId)');
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HolographicPostView(data: data),
                ),
              );
            }
                : null,
            child: Container(
              width: double.infinity,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              color: Colors.grey.shade200,
              child: buildContentPreview(context, data, height: null),
            ),
          ),

          // --- Action Bar (Likes, Comments, Share, Bookmark) ---
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left Actions (Like, Comment, Share)
                Row(
                  children: [
                    // Like Button
                    _buildModernInteractiveButton(
                      icon: isLiked ? Icons.favorite : Icons.favorite_border,
                      countStream: FirebaseFirestore.instance
                          .collection('posts')
                          .doc(postId)
                          .collection('likes')
                          .snapshots(),
                      onTap: () => _likePost(context, data),
                      color: isLiked ? kLikeRed : kModernIcon,
                      tooltip: isLiked ? 'Unlike' : 'Like',
                      size: 26,
                    ),
                    SizedBox(width: 16),

                    // Comment Button
                    _buildModernInteractiveButton(
                      icon: Icons.chat_bubble_outline,
                      countStream: FirebaseFirestore.instance
                          .collection('posts')
                          .doc(postId)
                          .collection('comments')
                          .snapshots(),
                      onTap: () => _openCommentSection(context, data),
                      color: kModernIcon,
                      tooltip: 'Comment',
                      size: 24,
                    ),
                    SizedBox(width: 16),

                    // Share Button
                    _buildModernInteractiveButton(
                      icon: Icons.send_outlined,
                      onTap: () => _sharePost(context, data),
                      color: kModernIcon,
                      tooltip: 'Share',
                      showCount: false,
                      size: 24,
                    ),
                  ],
                ),

                // Right Actions (Bookmark)
                Row(
                  children: [
                    // Bookmark Button
                    _buildModernInteractiveButton(
                      icon: isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                      onTap: () => _bookmarkProject(context, data),
                      color: isBookmarked ? kAppPrimary : kModernIcon,
                      tooltip: isBookmarked ? 'Remove Bookmark' : 'Bookmark',
                      showCount: false,
                      size: 24,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // --- Like Count ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .doc(postId)
                  .collection('likes')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                  int likeCount = snapshot.data!.docs.length;
                  return GestureDetector(
                    onTap: () => _showLikesBottomSheet(context, postId),
                    child: Text(
                      '$likeCount like${likeCount != 1 ? 's' : ''}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: kModernTextPrimary,
                        fontSize: 14,
                      ),
                    ),
                  );
                }
                return SizedBox.shrink();
              },
            ),
          ),

          // --- Post Title & Description (Optional) ---
          if (data['title'] != null && data['title'].toString().isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['author'] ?? '',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: kModernTextPrimary,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(width: 4),
                  Expanded(child: titleWidget),
                ],
              ),
            ),

          // --- View Comments Link ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .doc(postId)
                  .collection('comments')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                  int commentCount = snapshot.data!.docs.length;
                  return InkWell(
                    onTap: () => _openCommentSection(context, data),
                    child: Text(
                      'View all $commentCount comment${commentCount != 1 ? 's' : ''}',
                      style: TextStyle(color: kModernTextSecondary, fontSize: 14),
                    ),
                  );
                }
                return InkWell(
                  onTap: () => _openCommentSection(context, data),
                  child: Text(
                    'Add a comment...',
                    style: TextStyle(color: kModernTextSecondary, fontSize: 14),
                  ),
                );
              },
            ),
          ),

          // --- Timestamp ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            child: Text(
              formatTimestamp(data['timestamp']),
              style: TextStyle(color: kModernTextSecondary, fontSize: 11),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: (index % 10 * 50).ms).slideY(begin: 0.1, duration: 300.ms, curve: Curves.easeOut);
  }

  // --- Modern Post Card Header Widget ---
  Widget _buildModernPostCardHeader(BuildContext context, Map<String, dynamic> data, double screenWidth) {
    final String userId = data['uid'] ?? '';
    final String authorName = data['author'] ?? 'Unknown User';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              // Navigate to user profile or start chat code (unchanged)
              final User? currentUser = FirebaseAuth.instance.currentUser;
              if (currentUser == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please log in to view profile or message')),
                );
                return;
              }
              if (userId.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Cannot interact with user: Invalid User ID')),
                );
                return;
              }
              if (userId == currentUser.uid) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("This is your own post.")),
                );
                return;
              }
              // Prioritize Chat for now
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    otherUserId: userId,
                    otherUserName: authorName,
                  ),
                ),
              );
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Profile Picture Story Ring (Instagram-like progress animation)
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    // Check if user has active stories
                    bool hasStories = false;
                    bool hasUnseenStories = false;

                    if (snapshot.hasData && snapshot.data!.exists) {
                      try {
                        final userData = snapshot.data!.data() as Map<String, dynamic>?;
                        hasStories = userData?['hasActiveStories'] == true;
                        hasUnseenStories = userData?['hasUnseenStories'] == true;
                      } catch (e) {
                        print("Error reading story status: $e");
                      }
                    }

                    if (hasStories) {
                      // Show gradient ring animation for users with stories
                      return Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: hasUnseenStories
                              ? LinearGradient(
                            colors: [
                              Colors.purple,
                              Colors.orange,
                              Colors.red,
                            ],
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                          )
                              : LinearGradient(
                            colors: [Colors.grey.shade400, Colors.grey.shade300],
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                          ),
                        ),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: Duration(seconds: 1),
                          builder: (context, value, child) {
                            return CircularProgressIndicator(
                              value: value,
                              strokeWidth: 2.5,
                              backgroundColor: Colors.transparent,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  hasUnseenStories ? Colors.transparent : Colors.grey.shade400
                              ),
                            );
                          },
                        ),
                      );
                    } else {
                      // No ring for users without stories
                      return SizedBox(width: 40, height: 40);
                    }
                  },
                ),

                // Actual Profile Picture
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey.shade300,
                  backgroundImage: (data['photoURL'] != null && data['photoURL'].toString().isNotEmpty)
                      ? NetworkImage(data['photoURL'])
                      : null,
                  child: (data['photoURL'] == null || data['photoURL'].toString().isEmpty)
                      ? Icon(Icons.person_outline, color: kModernIcon, size: 20)
                      : null,
                ).animate().fadeIn(duration: 400.ms),
              ],
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              authorName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: kModernTextPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // More Options Button (unchanged)
          IconButton(
            icon: const Icon(Icons.more_horiz, color: kModernIcon, size: 22),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(),
            tooltip: 'More options',
            onPressed: () {
              _showPostOptionsMenu(context, data);
            },
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    List<String> nameParts = name.split(' ').where((part) => part.isNotEmpty).toList();
    if (nameParts.length > 1) {
      return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
    } else if (name.isNotEmpty) {
      return name[0].toUpperCase();
    }
    return '?';
  }

  void _showLikesBottomSheet(BuildContext context, String postId) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kModernBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Header
                Container(
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: kModernCard,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    boxShadow: [
                      BoxShadow(
                        color: kModernShadow,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Liked by',
                        style: TextStyle(
                          color: kModernTextPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: kModernIcon),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                // Likes List
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('posts')
                        .doc(postId)
                        .collection('likes')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(kAppPrimary),
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        print('Error fetching likes: ${snapshot.error}');
                        return Center(
                          child: Text(
                            'Error loading likes',
                            style: TextStyle(color: kErrorRed),
                          ),
                        );
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Text(
                            'No likes yet',
                            style: TextStyle(color: kModernTextSecondary),
                          ),
                        );
                      }

                      final likeDocs = snapshot.data!.docs;

                      return ListView.builder(
                        controller: scrollController,
                        padding: EdgeInsets.symmetric(vertical: 8),
                        itemCount: likeDocs.length,
                        itemBuilder: (context, index) {
                          final userId = likeDocs[index].id;
                          return FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('studentprofile')
                                .doc(userId)
                                .get(),
                            builder: (context, userSnapshot) {
                              if (userSnapshot.connectionState == ConnectionState.waiting) {
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.grey.shade200,
                                    radius: 20,
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(kAppPrimary),
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  title: Text(
                                    'Loading...',
                                    style: TextStyle(color: kModernTextPrimary),
                                  ),
                                );
                              }
                              if (userSnapshot.hasError) {
                                print('Error fetching user $userId: ${userSnapshot.error}');
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.grey.shade200,
                                    radius: 20,
                                    child: Icon(Icons.person, color: Colors.grey),
                                  ),
                                  title: Text(
                                    'Error Loading User',
                                    style: TextStyle(color: kModernTextSecondary),
                                  ),
                                );
                              }

                              String displayName = 'User $userId';
                              String? imageUrl;
                              Map<String, dynamic>? userData;

                              if (userSnapshot.hasData && userSnapshot.data!.exists) {
                                userData = userSnapshot.data!.data() as Map<String, dynamic>;
                                print('Studentprofile data for $userId: $userData'); // Debug log
                                displayName = userData['displayName']?.toString() ??
                                    userData['username']?.toString() ??
                                    userData['name']?.toString() ??
                                    'User $userId';
                                imageUrl = userData['imageUrl']?.toString();
                              } else {
                                print('No studentprofile data found for userId: $userId');
                              }

                              // Fallback for current user via FirebaseAuth
                              try {
                                final user = FirebaseAuth.instance.currentUser;
                                if (user != null && user.uid == userId) {
                                  final authDisplayName = user.displayName;
                                  if (authDisplayName != null && authDisplayName.isNotEmpty) {
                                    displayName = authDisplayName;
                                    print('Using FirebaseAuth displayName for $userId: $displayName');
                                  }
                                }
                              } catch (e) {
                                print('Error fetching FirebaseAuth user: $e');
                              }

                              // Fallback to 'users' collection if studentprofile has no name
                              if (displayName == 'User $userId') {
                                return FutureBuilder<DocumentSnapshot>(
                                  future: FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(userId)
                                      .get(),
                                  builder: (context, usersSnapshot) {
                                    if (usersSnapshot.connectionState == ConnectionState.waiting) {
                                      return ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: Colors.grey.shade200,
                                          radius: 20,
                                          child: CircularProgressIndicator(
                                            valueColor: AlwaysStoppedAnimation<Color>(kAppPrimary),
                                            strokeWidth: 2,
                                          ),
                                        ),
                                        title: Text(
                                          'Loading...',
                                          style: TextStyle(color: kModernTextPrimary),
                                        ),
                                      );
                                    }
                                    if (usersSnapshot.hasData && usersSnapshot.data!.exists) {
                                      final usersData = usersSnapshot.data!.data() as Map<String, dynamic>;
                                      print('Users collection data for $userId: $usersData');
                                      displayName = usersData['displayName']?.toString() ??
                                          usersData['username']?.toString() ??
                                          usersData['name']?.toString() ??
                                          displayName;
                                    } else {
                                      print('No users collection data found for userId: $userId');
                                    }

                                    // Log final selected name
                                    print('Final selected displayName for $userId: $displayName');

                                    // Get initials for fallback
                                    final initials = _getInitials(displayName);

                                    // Determine if this is the current user
                                    final user = FirebaseAuth.instance.currentUser;
                                    final bool isCurrentUser = user != null && user.uid == userId;

                                    return ListTile(
                                      leading: GestureDetector(
                                        onTap: imageUrl != null && imageUrl.isNotEmpty
                                            ? () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => FullScreenImageView(imageUrl: imageUrl!),
                                            ),
                                          );
                                        }
                                            : null, // No tap action if imageUrl is null
                                        child: Container(
                                          height: 40,
                                          width: 40,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 2),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.15),
                                                blurRadius: 8,
                                                spreadRadius: 1,
                                                offset: Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: imageUrl != null && imageUrl.isNotEmpty
                                              ? CircleAvatar(
                                            backgroundColor: Colors.grey.shade200,
                                            backgroundImage: NetworkImage(imageUrl),
                                            onBackgroundImageError: (error, stackTrace) {
                                              print('Error loading image for $userId: $error');
                                            },
                                          )
                                              : CircleAvatar(
                                            backgroundColor: kAppPrimary,
                                            child: Text(
                                              initials,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      title: GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => ProfileScreen(
                                                username: displayName,
                                                userId: userId,
                                                isCurrentUser: isCurrentUser,
                                              ),
                                            ),
                                          );
                                        },
                                        child: Text(
                                          displayName,
                                          style: TextStyle(
                                            color: kModernTextPrimary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              }

                              // Log final selected name
                              print('Final selected displayName for $userId: $displayName');

                              // Get initials for fallback
                              final initials = _getInitials(displayName);

                              // Determine if this is the current user
                              final user = FirebaseAuth.instance.currentUser;
                              final bool isCurrentUser = user != null && user.uid == userId;

                              return ListTile(
                                leading: GestureDetector(
                                  onTap: imageUrl != null && imageUrl.isNotEmpty
                                      ? () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => FullScreenImageView(imageUrl: imageUrl!),
                                      ),
                                    );
                                  }
                                      : null, // No tap action if imageUrl is null
                                  child: Container(
                                    height: 40,
                                    width: 40,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.15),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: imageUrl != null && imageUrl.isNotEmpty
                                        ? CircleAvatar(
                                      backgroundColor: Colors.grey.shade200,
                                      backgroundImage: NetworkImage(imageUrl),
                                      onBackgroundImageError: (error, stackTrace) {
                                        print('Error loading image for $userId: $error');
                                      },
                                    )
                                        : CircleAvatar(
                                      backgroundColor: kAppPrimary,
                                      child: Text(
                                        initials,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                title: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ProfileScreen(
                                          username: displayName,
                                          userId: userId,
                                          isCurrentUser: isCurrentUser,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    displayName,
                                    style: TextStyle(
                                      color: kModernTextPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }


  Future<bool> _checkNetworkConnectivity({bool showFeedback = true}) async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(Duration(seconds: 5));
      bool hasConnection = result.isNotEmpty && result[0].rawAddress.isNotEmpty;

      if (!hasConnection && showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.signal_wifi_off, color: Colors.white),
                SizedBox(width: 10),
                Expanded(child: Text('No internet connection. Please check your network.')),
              ],
            ),
            action: SnackBarAction(
              label: 'RETRY',
              onPressed: () => _resetAndRefreshPosts(),
            ),
            duration: Duration(seconds: 5),
            backgroundColor: kErrorRed,
          ),
        );
      }

      return hasConnection;
    } on SocketException catch (_) {
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.signal_wifi_off, color: Colors.white),
                SizedBox(width: 10),
                Text('No internet connection'),
              ],
            ),
            action: SnackBarAction(
              label: 'RETRY',
              onPressed: () => _resetAndRefreshPosts(),
            ),
            duration: Duration(seconds: 5),
            backgroundColor: kErrorRed,
          ),
        );
      }
      return false;
    } on TimeoutException catch (_) {
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.timer_off, color: Colors.white),
                SizedBox(width: 10),
                Text('Connection timeout. Please try again.'),
              ],
            ),
            action: SnackBarAction(
              label: 'RETRY',
              onPressed: () => _resetAndRefreshPosts(),
            ),
            duration: Duration(seconds: 5),
            backgroundColor: kWarningYellow,
          ),
        );
      }
      return false;
    } catch (e) {
      print("Unexpected error checking connectivity: $e");
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Network error: ${e.toString().substring(0, min(50, e.toString().length))}...'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return false;
    }
  }

// Robust error handling for Firestore operations with auto-retry
  Future<T?> _safeFirestoreOperation<T>({
    required Future<T> Function() operation,
    required String operationName,
    bool showErrorToUser = true,
    int maxRetries = 2,
    bool requiresNetwork = true,
  }) async {
    int attempts = 0;

    // Check network first if required
    if (requiresNetwork) {
      bool hasNetwork = await _checkNetworkConnectivity(showFeedback: false);
      if (!hasNetwork) {
        if (showErrorToUser && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cannot $operationName: No internet connection'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return null;
      }
    }

    while (attempts <= maxRetries) {
      try {
        return await operation();
      } on FirebaseException catch (e) {
        attempts++;
        print("FirebaseException on $operationName (Attempt $attempts): ${e.code} - ${e.message}");

        // Handle specific Firebase errors
        if (e.code == 'permission-denied') {
          if (showErrorToUser && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('You don\'t have permission to $operationName'),
                backgroundColor: kErrorRed,
              ),
            );
          }
          return null; // Don't retry permission errors
        }
        else if (e.code == 'unavailable' && attempts <= maxRetries) {
          // Exponential backoff for retry
          await Future.delayed(Duration(milliseconds: 300 * attempts * attempts));
          continue; // Try again
        }

        // Show general error if reached max retries
        if (attempts > maxRetries && showErrorToUser && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: Could not $operationName. Please try again later.'),
              backgroundColor: kErrorRed,
            ),
          );
        }
      } catch (e) {
        print("Unexpected error on $operationName: $e");
        attempts++;

        if (attempts > maxRetries && showErrorToUser && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: Could not $operationName'),
              backgroundColor: kErrorRed,
            ),
          );
        }

        if (attempts <= maxRetries) {
          await Future.delayed(Duration(milliseconds: 300 * attempts));
          continue; // Try again
        }
      }
    }

    return null; // Return null if all retries failed
  }
  // --- Post Options Menu ---
  void _showPostOptionsMenu(BuildContext context, Map<String, dynamic> data) {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    final bool isOwnPost = currentUser != null && data['uid'] == currentUser.uid;

    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 5,
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              // Options specific to post owner
              if (isOwnPost) ...[
                _buildPostOptionTile(
                  icon: Icons.edit_outlined,
                  title: 'Edit Post',
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Navigate to edit post
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Edit post functionality coming soon')),
                    );
                  },
                ),
                _buildPostOptionTile(
                  icon: Icons.delete_outline,
                  title: 'Delete Post',
                  textColor: kErrorRed,
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDeletePost(context, data);
                  },
                ),
                Divider(height: 16, thickness: 0.5),
              ],

              // Common options
              _buildPostOptionTile(
                icon: Icons.bookmark_border,
                title: (_bookmarkedPosts[data['postId']] ?? false)
                    ? 'Remove from Bookmarks'
                    : 'Save to Bookmarks',
                onTap: () {
                  Navigator.pop(context);
                  _bookmarkProject(context, data);
                },
              ),
              _buildPostOptionTile(
                icon: Icons.ios_share_outlined,
                title: 'Share Post',
                onTap: () {
                  Navigator.pop(context);
                  _sharePost(context, data);
                },
              ),
              _buildPostOptionTile(
                icon: Icons.link,
                title: 'Copy Link',
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: "https://yourapp.com/post/${data['postId']}"));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Link copied to clipboard')),
                  );
                },
              ),

              // Report option (only for posts by others)
              if (!isOwnPost)
                _buildPostOptionTile(
                  icon: Icons.flag_outlined,
                  title: 'Report Post',
                  textColor: kErrorRed,
                  onTap: () {
                    Navigator.pop(context);
                    _showReportDialog(context, data);
                  },
                ),

              SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // Helper for building post option tiles
  Widget _buildPostOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: textColor ?? kModernIcon),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? kModernTextPrimary,
          fontSize: 16,
        ),
      ),
      onTap: onTap,
      dense: true,
      visualDensity: VisualDensity.compact,
    );
  }

  // Confirm delete post dialog
  void _confirmDeletePost(BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Post?'),
        content: Text('This action cannot be undone. Are you sure you want to delete this post?'),
        actions: [
          TextButton(
            child: Text('CANCEL'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text('DELETE', style: TextStyle(color: kErrorRed)),
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement delete post functionality
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Delete functionality coming soon')),
              );
            },
          ),
        ],
      ),
    );
  }

  // Show report dialog
  void _showReportDialog(BuildContext context, Map<String, dynamic> data) {
    final reasons = [
      'Inappropriate Content',
      'Spam',
      'Harassment',
      'False Information',
      'Intellectual Property Violation',
      'Other'
    ];

    String selectedReason = reasons.first;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Report Post'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Please select a reason:'),
              SizedBox(height: 12),
              DropdownButton<String>(
                value: selectedReason,
                isExpanded: true,
                items: reasons.map((reason) => DropdownMenuItem(
                  value: reason,
                  child: Text(reason),
                )).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => selectedReason = value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text('CANCEL'),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: Text('REPORT'),
              onPressed: () {
                Navigator.pop(context);
                // TODO: Implement report functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Thank you for your report. We\'ll review this post.'),
                    backgroundColor: kSuccessGreen,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
  // --- Modern Interactive Button Widget ---
  Widget _buildModernInteractiveButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
    String? tooltip,
    Stream<dynamic>? countStream, // Stream for real-time count
    int Function(dynamic)? countExtractor, // Function to extract count
    bool showCount = true, // Whether to display the count
    double size = 24.0, // Icon size
  }) {
    Widget buttonIcon = IconButton(
      icon: Icon(icon, color: color, size: size),
      onPressed: onTap,
      splashRadius: 24, // Adjust splash radius
      padding: EdgeInsets.all(6),
      constraints: BoxConstraints(),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
    );

    if (showCount && countStream != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          buttonIcon,
          SizedBox(width: 4), // Space between icon and count
          StreamBuilder<dynamic>(
            stream: countStream,
            builder: (context, snapshot) {
              // Show a subtle loading indicator if waiting for first count data
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return SizedBox(
                  width: 20,
                  height: 20,
                  child: Center(
                    child: SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        color: kModernTextSecondary.withOpacity(0.5),
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                );
              }

              int count = 0;
              if (snapshot.hasData) {
                try {
                  if (countExtractor != null) {
                    count = countExtractor(snapshot.data);
                  } else if (snapshot.data is QuerySnapshot) {
                    count = (snapshot.data as QuerySnapshot).docs.length;
                  }
                } catch (e) {
                  print("Error extracting count: $e");
                  count = 0;
                }
              }

              // Only display count if it's greater than 0
              if (count > 0) {
                return Text(
                  '$count',
                  style: TextStyle(color: kModernTextSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                );
              } else {
                return const SizedBox.shrink(); // Don't show '0'
              }
            },
          ),
        ],
      );
    } else {
      // Return only the icon button if count is not shown or stream is null
      return buttonIcon;
    }
  }

  // --- Modern Creative Floating Action Button ---
  Widget _buildModernCreativeFab(BuildContext context) {
    // Don't show FAB when searching
    if (_isSearching) {
      return SizedBox.shrink();
    }

    // Consider replacing with a simpler '+' FAB or integrating into bottom nav bar
    // Keeping the expanding FAB for now, but styled differently
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Expanded FAB options
        AnimatedOpacity(
          opacity: _isFabExpanded ? 1.0 : 0.0,
          duration: Duration(milliseconds: 200),
          child: IgnorePointer(
            ignoring: !_isFabExpanded,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Upload Post Action
                _buildModernMiniFab(
                  icon: Icons.add_photo_alternate_outlined,
                  label: 'Create Post',
                  onPressed: () {
                    _toggleFab();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UploadPostScreen(),
                      ),
                    );
                  },
                ),
                SizedBox(height: 12), // Increased spacing
                _buildModernMiniFab(
                  icon: Icons.edit_note_outlined, // Outlined icon
                  label: 'Write Article',
                  onPressed: () {
                    _toggleFab();
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Navigate to Article Editor (TODO)'))
                    );
                  },
                ),
              ],
            ).animate(target: _isFabExpanded ? 1.0 : 0.0).slideY(begin: 0.5, end: 0.0, duration: 250.ms, curve: Curves.easeOut).fadeIn(),
          ),
        ),

        // Main FAB
        SizedBox(height: 16), // Increased space
        FloatingActionButton(
          onPressed: _toggleFab,
          backgroundColor: kAppPrimary, // Use primary color
          heroTag: 'explore_fab_modern', // Ensure unique Hero tag
          child: AnimatedIcon(
            icon: AnimatedIcons.menu_close,
            progress: _fabAnimation,
            color: Colors.white,
            size: 28,
          ),
          elevation: 4, // Reduced elevation
          // shape: CircleBorder(), // Standard circular shape
        ).animate().scale(duration: 300.ms),
      ],
    );
  }

  // Helper for Modern Mini FABs
  Widget _buildModernMiniFab({required IconData icon, required String label, required VoidCallback onPressed}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5), // Adjusted padding
          decoration: BoxDecoration(
              color: kModernCard, // White background
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(color: kModernShadow.withOpacity(0.5), blurRadius: 3, offset: Offset(0, 1)) // Subtle shadow
              ]
          ),
          child: Text(label, style: TextStyle(fontSize: 12, color: kModernTextPrimary, fontWeight: FontWeight.w500)),
        ),
        SizedBox(width: 10),
        FloatingActionButton.small(
          onPressed: onPressed,
          backgroundColor: kModernCard, // White background for mini FAB
          foregroundColor: kAppPrimary, // Use primary color for icon
          heroTag: null,
          child: Icon(icon, size: 20),
          elevation: 2, // Reduced elevation
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ],
    );
  }

  // Toggle FAB expansion state
  void _toggleFab() {
    setState(() {
      _isFabExpanded = !_isFabExpanded;
      if (_isFabExpanded) {
        _fabController.forward();
      } else {
        _fabController.reverse();
      }
    });
  }

// --- Like/Unlike Post Logic with Fixed Implementation ---
  void _likePost(BuildContext context, Map<String, dynamic> data) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to like posts')),
      );
      return;
    }

    final postId = data['postId'] as String?;
    final postOwnerId = data['uid'] as String?;

    if (postId == null || postId.isEmpty) {
      print("Error: Cannot like post with null or empty postId.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Could not like post.')),
      );
      return;
    }

    final likeRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(user.uid);

    // Optimistically update the UI
    final bool currentlyLiked = _likedPosts[postId] ?? false;
    final bool newLikeState = !currentlyLiked;

    // Use minimal state update
    setState(() {
      _likedPosts[postId] = newLikeState;
    });

    // Show a subtle animation or feedback for the like action
    if (newLikeState) {
      _showHeartAnimation(context);
    }

    try {
      // First check network connectivity
      bool hasNetwork = await _checkNetworkConnectivity(showFeedback: false);
      if (!hasNetwork) {
        throw Exception("No internet connection");
      }

      // Get current like status
      DocumentSnapshot likeDoc = await likeRef.get();

      if (likeDoc.exists) {
        // User has already liked, so unlike
        await likeRef.delete();
        print("Post unliked: $postId by ${user.uid}");
      } else {
        // User hasn't liked, so like
        await likeRef.set({
          'userId': user.uid,
          'timestamp': FieldValue.serverTimestamp(),
        });
        print("Post liked: $postId by ${user.uid}");

        // Send "liked your post" notification
        if (postOwnerId != null && postOwnerId != user.uid) {
          final notificationService = NotificationService();
          await notificationService.createNotification(
            userId: postOwnerId,
            type: NotificationService.TYPE_LIKE,
            actorId: user.uid,
            actorName: user.displayName,
            actorPhotoURL: user.photoURL,
            postId: postId,
            postTitle: data['title'] ?? '',
            postImageURL: data['mediaUrl'],
          );
        }

        // Check for like milestones (e.g., 10, 50, 100 likes)
        final QuerySnapshot likesSnapshot = await FirebaseFirestore.instance
            .collection('posts')
            .doc(postId)
            .collection('likes')
            .get();
        final int likeCount = likesSnapshot.docs.length;

        // Define milestone thresholds
        const List<int> milestones = [10, 50, 100];
        for (int milestone in milestones) {
          if (likeCount == milestone) {
            final notificationService = NotificationService();
            await notificationService.createMilestoneNotification(
              userId: postOwnerId!,
              postId: postId,
              postTitle: data['title'] ?? '',
              likeCount: likeCount,
            );
            break; // Only send one milestone notification
          }
        }
      }
    } catch (e) {
      print("Error updating like status: $e");

      // Revert optimistic UI update on error
      if (mounted) {
        setState(() {
          _likedPosts[postId] = currentlyLiked;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update like status. Please try again.'),
            backgroundColor: kErrorRed,
          ),
        );
      }
    }
  }

  void _sendCommentNotification(Map<String, dynamic> data, String commentId) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final postId = data['postId'] as String?;
    final postOwnerId = data['uid'] as String?;

    if (postId == null || postOwnerId == null || postOwnerId == user.uid) return;

    final notificationService = NotificationService();
    await notificationService.createNotification(
      userId: postOwnerId,
      type: NotificationService.TYPE_COMMENT,
      actorId: user.uid,
      actorName: user.displayName,
      actorPhotoURL: user.photoURL,
      postId: postId,
      postTitle: data['title'] ?? '',
      postImageURL: data['mediaUrl'],
      commentId: commentId,
    );
  }

  void _showHeartAnimation(BuildContext context) {
    // Create the overlay entry
    late OverlayEntry overlay;

    // Define it with a reference to itself for removal
    overlay = OverlayEntry(
      builder: (context) => Positioned(
        left: 0,
        right: 0,
        top: 0,
        bottom: 0,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Center(
                child: Opacity(
                  opacity: value > 0.8 ? 2.0 - value * 2.0 : value, // Fade in and out
                  child: Transform.scale(
                    scale: value * 1.5,
                    child: Icon(
                      Icons.favorite,
                      color: kLikeRed.withOpacity(0.8),
                      size: 100,
                    ),
                  ),
                ),
              );
            },
            onEnd: () {
              // Remove overlay after animation completes
              try {
                overlay.remove();
              } catch (e) {
                print("Error removing overlay: $e");
              }
            },
          ),
        ),
      ),
    );

    try {
      // Add overlay to context
      Overlay.of(context).insert(overlay);

      // Set a backup timer to ensure overlay gets removed
      Future.delayed(Duration(milliseconds: 1000), () {
        try {
          overlay.remove();
        } catch (e) {
          // Already removed, ignore
        }
      });
    } catch (e) {
      print("Error showing heart animation: $e");
    }
  }

  // Separate method for sending notifications to avoid blocking UI
  Future<void> _sendLikeNotification(
      String postId, String postOwnerId, User user, Map<String, dynamic> data) async {
    try {
      // Check for recent notifications to avoid duplicates
      QuerySnapshot existingNotifs = await FirebaseFirestore.instance.collection('notifications')
          .where('userId', isEqualTo: postOwnerId)
          .where('actorId', isEqualTo: user.uid)
          .where('postId', isEqualTo: postId)
          .where('type', isEqualTo: 'like')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(DateTime.now().subtract(Duration(hours: 1))))
          .limit(1)
          .get();

      if (existingNotifs.docs.isEmpty) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': postOwnerId,
          'type': 'like',
          'postId': postId,
          'actorId': user.uid,
          'actorName': user.displayName ?? 'Someone',
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
          'postTitle': data['title'] ?? '',
        });
        print("Like notification sent to $postOwnerId for post $postId");
      } else {
        print("Like notification skipped (already sent recently) for post $postId");
      }
    } catch (e) {
      print("Error sending like notification: $e");
      // Don't affect the like operation if notification fails
    }
  }

  // --- Bookmark with Fixed Implementation ---
  void _bookmarkProject(BuildContext context, Map<String, dynamic> data) async {
    final User? user = FirebaseAuth.instance.currentUser;
    final String? postId = data['postId'];

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to bookmark posts')),
      );
      return;
    }
    if (postId == null || postId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Cannot bookmark post with invalid ID.')),
      );
      return;
    }

    final bookmarkRef = FirebaseFirestore.instance
        .collection('users') // Assuming user data is in 'users' collection
        .doc(user.uid)
        .collection('bookmarks')
        .doc(postId);

    // Optimistically update UI
    final bool currentlyBookmarked = _bookmarkedPosts[postId] ?? false;
    setState(() {
      _bookmarkedPosts[postId] = !currentlyBookmarked;
    });

    try {
      final String postTitle = data['title'] ?? 'this post'; // More descriptive message

      if (currentlyBookmarked) { // If it was bookmarked, delete it
        await bookmarkRef.delete();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed "$postTitle" from bookmarks!'),
            backgroundColor: kAppAccent,
          ),
        );
      } else { // If it wasn't bookmarked, add it
        await bookmarkRef.set({
          'postId': postId,
          'title': data['title'] ?? 'Untitled Post',
          'author': data['author'] ?? 'Unknown Author',
          'timestamp': FieldValue.serverTimestamp(), // Timestamp when bookmarked
          'previewImage': (data['type'] == 'image' && data['mediaUrl'] != null) ? data['mediaUrl'] : null,
          'type': data['type'] ?? 'text',
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bookmarked "$postTitle"!'),
            backgroundColor: kAppPrimary,
          ),
        );
      }
    } catch (e) {
      print("Error bookmarking post $postId: $e");
      // Revert optimistic UI update on error
      setState(() {
        _bookmarkedPosts[postId] = currentlyBookmarked;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating bookmarks. Please try again.')),
      );
    }
  }

  // --- Navigate to Comment Section ---
  void _openCommentSection(BuildContext context, Map<String, dynamic> data) {
    final postId = data['postId'] as String?;
    if (postId == null || postId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: Cannot open comments for invalid post ID.")),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommentScreen(postId: postId),
      ),
    );
  }

  // --- Navigate to Insights Screen ---
  void _showInsights(BuildContext context, Map<String, dynamic> data) {
    final postId = data['postId'] as String?;
    if (postId == null || postId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: Cannot show insights for invalid post ID.")),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InsightScreen(data: data), // Pass the whole data map
      ),
    );
  }

  // --- Share Post Logic with improved deep link handling ---
  Future<void> _sharePost(BuildContext context, Map<String, dynamic> data) async {
    final String postTitle = data['title'] ?? 'Check out this post!';
    final String postContent = data['content'] ?? '';
    final String? postMediaUrl = data['mediaUrl'] is String ? data['mediaUrl'] : null;
    final String postId = data['postId'] ?? '';

    try {
      // Show loading indicator
      final loadingOverlay = OverlayEntry(
        builder: (context) => Positioned(
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            color: Colors.black.withOpacity(0.3),
            child: Center(
              child: Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(kAppPrimary)),
                    SizedBox(height: 15),
                    Text('Preparing to share...', style: TextStyle(color: kModernTextPrimary)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      Overlay.of(context).insert(loadingOverlay);

      // Create a proper app link that works whether published or not
      String postLink;

      // DEVELOPMENT MODE - create a placeholder link until app is published
      if (!kReleaseMode) {
        // For testing only - create a fake dynamic link
        postLink = "https://yourapp.page.link/?link=https://yourapp.com/post/$postId&apn=com.yourapp.package&amv=1&isi=123456789&ibi=com.yourapp.ios";
        print("DEV MODE: Using placeholder dynamic link: $postLink");
      }
      // PRODUCTION MODE - generate a real Firebase Dynamic Link
      else {
        try {
          // This is the Firebase Dynamic Links implementation
          // You'll need to configure this with your actual Firebase details when published
          final DynamicLinkParameters parameters = DynamicLinkParameters(
            uriPrefix: 'https://yourapp.page.link', // Your actual Firebase Dynamic Links prefix
            link: Uri.parse('https://yourapp.com/post/$postId'),
            androidParameters: AndroidParameters(
              packageName: 'com.yourapp.package', // Your Android package name
              minimumVersion: 1,
            ),
            iosParameters: IOSParameters(
              bundleId: 'com.yourapp.ios', // Your iOS bundle ID
              minimumVersion: '1.0.0',
              appStoreId: '123456789', // Your App Store ID
            ),
            socialMetaTagParameters: SocialMetaTagParameters(
              title: postTitle,
              description: postContent.length > 100
                  ? postContent.substring(0, 97) + '...'
                  : postContent,
              imageUrl: postMediaUrl != null && postMediaUrl.isNotEmpty
                  ? Uri.parse(postMediaUrl)
                  : null,
            ),
          );

          final ShortDynamicLink shortLink = await FirebaseDynamicLinks.instance.buildShortLink(parameters);
          postLink = shortLink.shortUrl.toString();
          print("PROD MODE: Generated dynamic link: $postLink");
        } catch (e) {
          print("Error generating dynamic link: $e");
          // Fallback to a basic link if dynamic link generation fails
          postLink = "https://yourapp.com/post/$postId";
        }
      }

      // Remove loading overlay
      loadingOverlay.remove();

      // Create share text with the dynamic link
      String shareText = postTitle;
      if (postContent.isNotEmpty) {
        shareText += "\n\n${postContent.substring(0, postContent.length > 100 ? 100 : postContent.length)}${postContent.length > 100 ? '...' : ''}";
      }
      shareText += "\n\nView post: $postLink";

      // Handle media sharing similar to before
      XFile? sharedFile;

      if (!kIsWeb && postMediaUrl != null && postMediaUrl.isNotEmpty) {
        try {
          final directory = await getTemporaryDirectory();
          final String fileExtension = data['type'] == 'video' ? 'mp4' : 'jpg';
          final filePath = '${directory.path}/share_media.$fileExtension';
          final file = File(filePath);

          final response = await http.get(
            Uri.parse(postMediaUrl),
            headers: {'User-Agent': 'Mozilla/5.0'}, // Add user agent to avoid some server blocks
          ).timeout(Duration(seconds: 15));

          if (response.statusCode == 200) {
            await file.writeAsBytes(response.bodyBytes);
            sharedFile = XFile(file.path);
            print("Media downloaded successfully to ${file.path}");
          } else {
            print("Failed to download media: Status code ${response.statusCode}");
            // Show a toast/snackbar about media download failure but continue with text sharing
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not include media in share. Sharing text only.')),
            );
          }
        } catch (e) {
          print("Error downloading media for sharing: $e");
          // Continue with text-only sharing
        }
      }

      // Perform the share action
      if (sharedFile != null) {
        await Share.shareXFiles([sharedFile], text: shareText);
        print("Shared post $postId with media and dynamic link.");
      } else {
        await Share.share(shareText);
        print("Shared post $postId with text only and dynamic link.");
      }

      // Increment share count in Firestore with error handling
      if (postId.isNotEmpty) {
        try {
          await FirebaseFirestore.instance
              .collection('posts')
              .doc(postId)
              .update({
            'shares': FieldValue.increment(1),
          });
          print("Incremented share count for post $postId.");
        } catch (e) {
          print("Error incrementing share count: $e");
          // Don't display an error to the user if this fails
        }
      }

    } catch (e) {
      print('Error sharing post $postId: $e');
      // Remove loading overlay if still showing
      try {
        Overlay.of(context).dispose(); // Clean up any remaining overlays
      } catch (_) {}

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share post. Please try again.'),
          backgroundColor: kErrorRed,
        ),
      );
    }
  }


  // --- Show Unread Messages Summary Logic ---
  void _showUnreadMessagesSummary(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to view messages')),
      );
      return;
    }

    // Fetch unread message counts asynchronously
    Future<List<Map<String, dynamic>>> fetchUnreadSummaries() async {
      List<Map<String, dynamic>> summaries = [];
      final firestore = FirebaseFirestore.instance;

      try {
        // 1. Query chats involving the current user
        QuerySnapshot chatSnapshot = await firestore
            .collection('chats')
            .where('participants', arrayContains: user.uid)
            .get();

        // 2. For each chat, query unread messages
        for (var chatDoc in chatSnapshot.docs) {
          Map<String, dynamic> chatData = chatDoc.data() as Map<String, dynamic>? ?? {};
          String chatId = chatDoc.id;

          // Get participants and determine other user
          List<dynamic> participants = chatData['participants'] as List<dynamic>? ?? []; // Ensure it's List<dynamic>
          String otherUserId = participants.firstWhere((id) => id != user.uid, orElse: () => '') as String; // Cast result
          if (otherUserId.isEmpty) continue; // Skip if other user not found

          // Get last read timestamp for the current user
          Map<String, dynamic> lastReadTimestamps = chatData['lastReadTimestamp'] as Map<String, dynamic>? ?? {};
          Timestamp? lastReadTime = lastReadTimestamps[user.uid] as Timestamp?;

          // 3. Query messages collection for unread count
          Query messagesQuery = firestore
              .collection('chats')
              .doc(chatId)
              .collection('messages')
              .where('senderId', isEqualTo: otherUserId); // Messages sent by the other user

          // Add timestamp condition if lastReadTime exists
          if (lastReadTime != null) {
            messagesQuery = messagesQuery.where('timestamp', isGreaterThan: lastReadTime);
          }

          // Use count() aggregation query for efficiency
          AggregateQuerySnapshot unreadMessagesSnapshot = await messagesQuery.count().get();
          int unreadCount = unreadMessagesSnapshot.count ?? 0; // Use ?? 0 for safety

          // 4. Add to summary list if there are unread messages
          if (unreadCount > 0) {
            // Attempt to get other user's name (assuming it's stored or fetchable)
            String otherUserName = await _getOtherUserName(chatData, otherUserId); // Helper function

            summaries.add({
              'chatId': chatId,
              'otherUserId': otherUserId,
              'otherUserName': otherUserName,
              'unreadCount': unreadCount,
            });
          }
        }
      } catch (e) {
        print("Error fetching unread message summaries: $e");
        // Handle error appropriately, maybe return an empty list or throw
      }
      // Optional: Sort summaries by unread count or name
      summaries.sort((a, b) => b['unreadCount'].compareTo(a['unreadCount']));
      return summaries;
    }

    // Show the bottom sheet with a FutureBuilder
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5, minChildSize: 0.3, maxChildSize: 0.8, expand: false,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: kModernBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag Handle
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10))),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Text('Unread Messages', style: TextStyle(color: kModernTextPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
              ),
              Divider(height: 1, color: Colors.grey.shade300),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: fetchUnreadSummaries(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator(color: kAppPrimary));
                    }
                    if (snapshot.hasError) {
                      print("FutureBuilder Error: ${snapshot.error}");
                      return Center(child: Text('Error loading summaries.', style: TextStyle(color: Colors.red)));
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 30.0, horizontal: 15.0),
                          child: Text('No unread messages.', textAlign: TextAlign.center, style: TextStyle(color: kModernTextSecondary, fontSize: 16)),
                        ),
                      );
                    }

                    List<Map<String, dynamic>> summaries = snapshot.data!;
                    return ListView.separated(
                      controller: controller,
                      itemCount: summaries.length,
                      padding: EdgeInsets.zero,
                      separatorBuilder: (context, index) => Divider(height: 1, indent: 70, color: Colors.grey.shade200),
                      itemBuilder: (context, index) {
                        var summary = summaries[index];
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 22,
                            backgroundColor: kAppPrimary.withOpacity(0.1),
                            // TODO: Add user profile picture if available (fetch from userDoc in _getOtherUserName?)
                            child: Icon(Icons.person_outline, color: kAppPrimary, size: 20),
                          ),
                          title: Text(
                            summary['otherUserName'] ?? 'Unknown User',
                            style: TextStyle(color: kModernTextPrimary, fontWeight: FontWeight.w600),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${summary['unreadCount']} unread message${summary['unreadCount'] != 1 ? 's' : ''}',
                            style: TextStyle(color: kModernTextSecondary, fontSize: 13),
                          ),
                          trailing: Icon(Icons.chevron_right, color: kModernIcon),
                          onTap: () {
                            Navigator.pop(context); // Close bottom sheet
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatScreen(
                                  otherUserId: summary['otherUserId'],
                                  otherUserName: summary['otherUserName'] ?? 'Unknown User',
                                ),
                              ),
                            );
                          },
                          dense: true,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  // Helper function to get the other user's name
  // Tries to get from chatData first, then falls back to fetching from 'users' collection
  Future<String> _getOtherUserName(Map<String, dynamic> chatData, String otherUserId) async {
    // 1. Try getting from participantNames map if it exists
    Map<String, dynamic>? participantNames = chatData['participantNames'] as Map<String, dynamic>?;
    if (participantNames != null && participantNames.containsKey(otherUserId)) {
      // Ensure the value is actually a string before returning
      var name = participantNames[otherUserId];
      return name is String ? name : 'Unknown User';
    }

    // 2. Fallback: Fetch from 'users' collection (assuming structure)
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(otherUserId).get();
      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>? ?? {};
        // Adjust 'displayName' based on your actual field name in the users collection
        // Prioritize displayName, then name, then default
        var displayName = userData['displayName'];
        if (displayName is String && displayName.isNotEmpty) return displayName;
        var name = userData['name'];
        if (name is String && name.isNotEmpty) return name;
        return 'Unknown User'; // Default if fields are missing or not strings
      }
    } catch (e) {
      print("Error fetching user name for $otherUserId: $e");
    }

    return 'Unknown User'; // Default if not found or error occurs
  }

  // --- Notifications Bottom Sheet Logic ---
  void _showNotificationsBottomSheet(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to view notifications')),
      );
      return;
    }

    showModalBottomSheet( // Use BottomSheet for a more modern feel
      context: context,
      isScrollControlled: true, // Allow sheet to take more height
      backgroundColor: Colors.transparent, // Make background transparent
      builder: (context) => DraggableScrollableSheet( // Allow dragging and scrolling
        initialChildSize: 0.6, // Start at 60% height
        minChildSize: 0.3, // Min height
        maxChildSize: 0.9, // Max height
        expand: false,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
              color: kModernBackground, // Use modern background
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)) // Rounded top corners
          ),
          child: Column(
            children: [
              // Drag Handle
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Text(
                  'Notifications',
                  style: TextStyle(color: kModernTextPrimary, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              Divider(height: 1, color: Colors.grey.shade300),
              Expanded( // Make list scrollable
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('notifications')
                      .where('userId', isEqualTo: user.uid)
                      .orderBy('timestamp', descending: true)
                      .limit(50) // Fetch more notifications
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator(color: kAppPrimary));
                    }
                    if (snapshot.hasError) {
                      print("Error fetching notifications: ${snapshot.error}");
                      return Center(child: Text('Error loading notifications.', style: TextStyle(color: Colors.red)));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 30.0, horizontal: 15.0),
                          child: Text(
                            'You have no notifications yet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: kModernTextSecondary, fontSize: 16),
                          ),
                        ),
                      );
                    }

                    var notifications = snapshot.data!.docs;
                    return ListView.separated(
                      controller: controller, // Link controller for scrolling
                      itemCount: notifications.length,
                      padding: EdgeInsets.zero,
                      separatorBuilder: (context, index) => Divider(height: 1, indent: 70, color: Colors.grey.shade200), // Subtle separator
                      itemBuilder: (context, index) {
                        try {
                          var notification = notifications[index].data() as Map<String, dynamic>;
                          var notificationId = notifications[index].id;
                          String message = _getNotificationMessage(notification);
                          bool isRead = notification['read'] ?? false;

                          return ListTile(
                            leading: CircleAvatar(
                              radius: 22, // Slightly larger avatar
                              backgroundColor: isRead ? Colors.grey.shade200 : kAppPrimary.withOpacity(0.1),
                              child: Icon(
                                _getNotificationIcon(notification['type']),
                                size: 20,
                                color: isRead ? kModernIcon : kAppPrimary,
                              ),
                            ),
                            title: Text(
                              message,
                              style: TextStyle(
                                color: kModernTextPrimary,
                                fontSize: 14,
                                fontWeight: isRead ? FontWeight.normal : FontWeight.w600, // Bolder unread
                              ),
                              maxLines: 3, // Allow more lines
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              _formatNotificationTimestamp(notification['timestamp']),
                              style: TextStyle(color: kModernTextSecondary, fontSize: 11),
                            ),
                            onTap: () => _handleNotificationTap(
                                context, notification, notificationId, isBottomSheet: true), // Pass flag
                            dense: true,
                            tileColor: isRead ? null : kAppPrimary.withOpacity(0.03),
                          );
                        } catch (e) {
                          print("Error processing notification at index $index: $e");
                          return ListTile(title: Text("Error loading notification", style: TextStyle(color: Colors.red)));
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  // --- Notification Helper Functions ---
  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'like': return Icons.favorite_border; // Use border version
      case 'comment': return Icons.chat_bubble_outline; // Use border version
      case 'reply': return Icons.reply;
      case 'follow': return Icons.person_add_alt_1_outlined; // Use border version
      default: return Icons.notifications_none; // Use border version
    }
  }

  String _getNotificationMessage(Map<String, dynamic> notification) {
    String actorName = notification['actorName'] ?? 'Someone';
    String type = notification['type'] ?? '';
    String postTitle = notification['postTitle'] != null && notification['postTitle'].isNotEmpty
        ? '"${notification['postTitle']}"'
        : 'your post';

    switch (type) {
      case 'like': return '$actorName liked $postTitle.';
      case 'comment': return '$actorName commented on $postTitle.';
      case 'reply': return '$actorName replied to your comment on $postTitle.';
      case 'follow': return '$actorName started following you.';
      default: return '$actorName interacted with $postTitle.';
    }
  }

  String _formatNotificationTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      DateTime date = timestamp.toDate();
      // Consider using the timeago package for "2h ago", "3d ago" etc.
      // For now, keep the simple format
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 7) {
        return DateFormat('MMM d').format(date); // e.g., Mar 25
      } else if (difference.inDays >= 1) {
        return '${difference.inDays}d ago'; // e.g., 3d ago
      } else if (difference.inHours >= 1) {
        return '${difference.inHours}h ago'; // e.g., 5h ago
      } else if (difference.inMinutes >= 1) {
        return '${difference.inMinutes}m ago'; // e.g., 10m ago
      } else {
        return 'Just now';
      }
    }
    return 'Just now';
  }

  void _handleNotificationTap(BuildContext context,
      Map<String, dynamic> notification, String notificationId, {bool isBottomSheet = false}) async {
    final String? postId = notification['postId'] as String?;
    final String? type = notification['type'] as String?;
    final String? commentId = notification['commentId'] as String?;

    // Mark notification as read
    FirebaseFirestore.instance
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true}).catchError((e) {
      print("Error marking notification read: $e");
    });

    // Close the notification dialog/sheet first
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    // Navigate based on notification type
    if (postId != null && postId.isNotEmpty) {
      try {
        DocumentSnapshot postDoc = await FirebaseFirestore.instance
            .collection('posts')
            .doc(postId)
            .get();

        if (postDoc.exists) {
          var data = postDoc.data() as Map<String, dynamic>;
          data['postId'] = postId;

          // Navigate to post details or comment section
          if (type == 'comment' || type == 'reply') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CommentScreen(postId: postId),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => HolographicPostView(data: data),
              ),
            );
          }
        } else {
          print("Notification tap: Post $postId not found.");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('The related post may have been deleted.')),
          );
        }
      } catch (e) {
        print("Error fetching post $postId for notification: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error navigating to the post.')),
        );
      }
    } else if (type == 'follow') {
  // Navigate to the profile of the actor (notification['actorId'])
  final String? actorId = notification['actorId'] as String?;
  final String actorName = notification['actorName'] ?? 'Unknown User';
  if (actorId != null && actorId.isNotEmpty) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(
          userId: actorId,
          username: actorName,
          isCurrentUser: false, // Set this to false when viewing another user's profile
        ),
      ),
    );
  } else {
  ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text('Cannot view profile: User information missing')),
  );
  }
  }
  else {
  print("Notification tap: No valid action defined for type '$type' or missing postId.");
  }
}

// --- No Network Handler and Error Display ---
Widget _buildErrorWidget(String message, IconData icon, VoidCallback onRetry) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 70,
          color: kModernTextSecondary.withOpacity(0.7),
        ).animate().fadeIn(duration: 500.ms),
        SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: kModernTextSecondary,
            fontWeight: FontWeight.w500,
          ),
        ).animate().fadeIn(duration: 700.ms).slideY(begin: 0.2, end: 0),
        SizedBox(height: 24),
        ElevatedButton.icon(
          icon: Icon(Icons.refresh),
          label: Text('Try Again'),
          style: ElevatedButton.styleFrom(
            backgroundColor: kAppPrimary,
            foregroundColor: Colors.white,
            elevation: 2,
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          onPressed: onRetry,
        ).animate().fadeIn(duration: 900.ms).scale(delay: 300.ms),
      ],
    ),
  );
}

// --- Empty State Widget ---
Widget _buildEmptyStateWidget({
  required String title,
  required String subtitle,
  required IconData icon,
  String? buttonText,
  VoidCallback? onButtonPressed,
}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: kAppPrimary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 50,
              color: kAppPrimary,
            ),
          ).animate().fadeIn(duration: 600.ms),
          SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: kModernTextPrimary,
            ),
          ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.2, end: 0),
          SizedBox(height: 12),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: kModernTextSecondary,
            ),
          ).animate().fadeIn(duration: 1000.ms).slideY(begin: 0.1, end: 0),
          if (buttonText != null && onButtonPressed != null) ...[
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: onButtonPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: kAppPrimary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Text(buttonText),
            ).animate().fadeIn(duration: 1200.ms).scale(delay: 500.ms, begin: Offset(0.9, 0.9)),
          ],
        ],
      ),
    ),
  );
}

// --- Network Connectivity Check ---
Future<bool> _checkConnectivity() async {
  try {
    final result = await InternetAddress.lookup('google.com');
    return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
  } on SocketException catch (_) {
    return false;
  }
}

// --- Handle Network Error with Retry ---
Future<void> _handleNetworkError(BuildContext context, VoidCallback retry) async {
  bool isConnected = await _checkConnectivity();

  if (!isConnected) {
    if (mounted) {
      setState(() {
        _hasError = true;
        _errorMessage = 'No internet connection. Please check your network settings and try again.';
      });
    }
  } else {
    if (mounted) {
      retry();
    }
  }
}
}