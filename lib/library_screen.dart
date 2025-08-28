import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'pdf_viewer_screen.dart';
import 'upload_notes_screen.dart';
import 'leaderboard_screen.dart';
import 'Notespagemyuploads.dart';

class LibraryScreen extends StatefulWidget {
  @override
  _LibraryScreenState createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  int _currentIndex = 0;
  TabController? _tabController;
  bool _isSearchVisible = false;

  // Sky blue color palette
  final Color primaryBlue = Color(0xFF1E88E5);
  final Color lightBlue = Color(0xFFBBDEFB);
  final Color darkBlue = Color(0xFF0D47A1);
  final Color accentBlue = Color(0xFF64B5F6);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController!.addListener(() {
      setState(() {
        _currentIndex = _tabController!.index;
      });
    });
  }

  void _navigateToMyUploads() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => MyUploadsScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          var begin = Offset(0.0, 1.0);
          var end = Offset.zero;
          var curve = Curves.easeInOutCubic;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_tabController == null) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: !_isSearchVisible
            ? Text(
          'Handwritten Notes',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        )
            : null,
        backgroundColor: primaryBlue,
        elevation: 0,
        actions: [
          // Search toggle
          if (!_isSearchVisible)
            IconButton(
              icon: Icon(Icons.search),
              onPressed: () {
                setState(() {
                  _isSearchVisible = true;
                });
              },
            ),
          // Search field when visible
          if (_isSearchVisible)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: 16.0, right: 8.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search notes...',
                    hintStyle: TextStyle(color: Colors.white70),
                    border: InputBorder.none,
                    suffixIcon: IconButton(
                      icon: Icon(Icons.clear, color: Colors.white),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                        });
                      },
                    ),
                  ),
                  style: TextStyle(color: Colors.white),
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
              ),
            ),
          // Close search button
          if (_isSearchVisible)
            IconButton(
              icon: Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isSearchVisible = false;
                  _searchController.clear();
                });
              },
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: [
            Tab(
              icon: Icon(Icons.library_books),
              text: 'Library',
            ),
            Tab(
              icon: Icon(Icons.leaderboard),
              text: 'Leaderboard',
            ),
            Tab(
              icon: Icon(Icons.upload_file),
              text: 'Upload',
            ),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [primaryBlue, Colors.white],
            stops: [0.0, 0.2],
          ),
        ),
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildLibraryContent(),
            LeaderboardScreen(),
            UploadNoteScreen(),
          ],
        ),
      ),
    );
  }

  Widget _buildLibraryContent() {
    return Stack(
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('notes')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(accentBlue),
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                    SizedBox(height: 16),
                    Text(
                      'Error loading notes',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.note_alt_outlined, size: 48, color: accentBlue),
                    SizedBox(height: 16),
                    Text(
                      'No notes available',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Upload your first note to get started!',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        _tabController?.animateTo(2); // Navigate to Upload tab
                      },
                      icon: Icon(Icons.add),
                      label: Text('Upload Note'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            var notes = snapshot.data!.docs;

            // Apply search filter if text is entered
            if (_searchController.text.isNotEmpty) {
              final searchTerm = _searchController.text.toLowerCase();
              notes = notes.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final title = (data['title'] ?? '').toString().toLowerCase();
                final description = (data['description'] ?? '').toString().toLowerCase();
                final userName = (data['userName'] ?? '').toString().toLowerCase();

                return title.contains(searchTerm) ||
                    description.contains(searchTerm) ||
                    userName.contains(searchTerm);
              }).toList();
            }

            if (notes.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
                    SizedBox(height: 16),
                    Text(
                      'No matching notes found',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: notes.length,
              itemBuilder: (context, index) {
                final note = notes[index];
                final noteData = note.data() as Map<String, dynamic>;

                return EnhancedNoteCard(
                  noteId: note.id,
                  noteData: noteData,
                  onTap: () => _navigateToNoteViewer(context, note.id, noteData),
                  primaryColor: primaryBlue,
                  accentColor: accentBlue,
                );
              },
            );
          },
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: AnimatedContainer(
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryBlue, darkBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: primaryBlue.withOpacity(0.3),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _navigateToMyUploads,
                borderRadius: BorderRadius.circular(30),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.folder_special,
                        color: Colors.white,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'My Uploads',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _navigateToNoteViewer(BuildContext context, String noteId, Map<String, dynamic> noteData) async {
    // Show interstitial ad before viewing the note
    InterstitialAd? interstitialAd;
    final String interstitialAdUnitId = 'ca-app-pub-9136866657796541/8468111985';

    await InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          interstitialAd = ad;
          interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NoteViewerScreen(
                    noteId: noteId,
                    noteData: noteData,
                  ),
                ),
              );
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NoteViewerScreen(
                    noteId: noteId,
                    noteData: noteData,
                  ),
                ),
              );
            },
          );
          interstitialAd!.show();
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('InterstitialAd failed to load: $error');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NoteViewerScreen(
                noteId: noteId,
                noteData: noteData,
              ),
            ),
          );
        },
      ),
    );
  }
}

class EnhancedNoteCard extends StatelessWidget {
  final String noteId;
  final Map<String, dynamic> noteData;
  final VoidCallback onTap;
  final Color primaryColor;
  final Color accentColor;

  const EnhancedNoteCard({
    Key? key,
    required this.noteId,
    required this.noteData,
    required this.onTap,
    required this.primaryColor,
    required this.accentColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final timestamp = noteData['createdAt'] as Timestamp?;
    final date = timestamp != null
        ? DateFormat('MMM d, yyyy').format(timestamp.toDate())
        : 'Unknown date';

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: primaryColor,
                width: 4,
              ),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, date),
                SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.description,
                        color: accentColor,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            noteData['title'] ?? 'Untitled',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            noteData['description'] ?? 'No description',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Divider(),
                SizedBox(height: 8),
                _buildStatsBar(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String date) {
    // Get user name and first letter for avatar
    final userName = noteData['userName'] ?? 'Unknown user';
    final firstLetter = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: noteData['userImageUrl'] != null && noteData['userImageUrl'].toString().isNotEmpty
              ? Colors.grey[300]
              : primaryColor,
          backgroundImage: noteData['userImageUrl'] != null && noteData['userImageUrl'].toString().isNotEmpty
              ? CachedNetworkImageProvider(noteData['userImageUrl'])
              : null,
          child: noteData['userImageUrl'] == null || noteData['userImageUrl'].toString().isEmpty
              ? Text(
            firstLetter,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          )
              : null,
        ),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                userName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              Text(
                date,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        // Use a compact button to avoid overflow
        Container(
          height: 30,
          child: ElevatedButton.icon(
            onPressed: onTap,
            icon: Icon(Icons.visibility, size: 12),
            label: Text('View', style: TextStyle(fontSize: 10)),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsBar(BuildContext context) {
    final rating = (noteData['rating'] ?? 0.0).toDouble();
    final ratingCount = noteData['ratingCount'] ?? 0;

    // Create a scrollable row for smaller screens
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Views with eye icon
          _buildStatItem(Icons.remove_red_eye, '${noteData['views'] ?? 0}', 'Views'),
          SizedBox(width: 8),

          // Replace Likes and Dislikes with new metrics
          _buildStatItem(Icons.auto_awesome, '${noteData['likes'] ?? 0}', 'Inspiring'),
          SizedBox(width: 8),
          _buildStatItem(Icons.psychology, '${noteData['dislikes'] ?? 0}', 'Questions'),
          SizedBox(width: 8),

          // Rating with bulb icons instead of stars
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: rating > 0 ? accentColor.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb,
                  size: 14,
                  color: rating > 0 ? Colors.amber : Colors.grey,
                ),
                SizedBox(width: 4),
                Text(
                  '${rating.toStringAsFixed(1)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: rating > 0 ? Colors.amber.shade800 : Colors.grey,
                  ),
                ),
                SizedBox(width: 2),
                Text(
                  '($ratingCount)',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String count, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min, // Keep row as small as possible
        children: [
          Icon(
            icon,
            size: 14,
            color: Colors.grey[600],
          ),
          SizedBox(width: 4),
          Text(
            count,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}