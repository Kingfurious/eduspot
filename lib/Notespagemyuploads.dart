import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pdf_viewer_screen.dart';

class MyUploadsScreen extends StatefulWidget {
  @override
  _MyUploadsScreenState createState() => _MyUploadsScreenState();
}

class _MyUploadsScreenState extends State<MyUploadsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Sky blue color palette
  final Color primaryBlue = Color(0xFF1E88E5);
  final Color lightBlue = Color(0xFFBBDEFB);
  final Color darkBlue = Color(0xFF0D47A1);
  final Color accentBlue = Color(0xFF64B5F6);

  String? _userId;
  bool _isLoading = true;
  List<QueryDocumentSnapshot>? _userNotes;
  bool _hasError = false;
  bool _isDeleting = false; // Track deletion state

  // Stats summary
  int _totalViews = 0;
  int _totalLikes = 0;
  int _totalNotes = 0;
  double _averageRating = 0.0;

  @override
  void initState() {
    super.initState();
    _getUserId();
  }

  Future<void> _getUserId() async {
    try {
      // First try to get from Firebase Auth
      User? user = _auth.currentUser;
      if (user != null) {
        setState(() {
          _userId = user.uid;
        });
      } else {
        // Try to get from SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        setState(() {
          _userId = prefs.getString('userId');
        });
      }

      if (_userId != null) {
        _loadUserNotes();
      } else {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    } catch (e) {
      print('Error getting user ID: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _loadUserNotes() async {
    try {
      // Remove the orderBy to avoid needing a composite index
      final notesSnapshot = await _firestore
          .collection('notes')
          .where('userId', isEqualTo: _userId)
          .get();

      // Sort the results in memory instead
      final sortedDocs = notesSnapshot.docs;
      sortedDocs.sort((a, b) {
        final aData = a.data() as Map<String, dynamic>;
        final bData = b.data() as Map<String, dynamic>;

        final aTimestamp = aData['createdAt'] as Timestamp?;
        final bTimestamp = bData['createdAt'] as Timestamp?;

        if (aTimestamp == null) return 1;  // null values come last
        if (bTimestamp == null) return -1;

        // Sort in descending order (newest first)
        return bTimestamp.compareTo(aTimestamp);
      });

      setState(() {
        _userNotes = sortedDocs;
        _totalNotes = sortedDocs.length;

        // Calculate summary stats
        _totalViews = 0;
        _totalLikes = 0;
        double totalRatingPoints = 0;
        int notesWithRating = 0;

        for (var note in sortedDocs) {
          final data = note.data() as Map<String, dynamic>;
          _totalViews += (data['views'] as int?) ?? 0;
          _totalLikes += (data['likes'] as int?) ?? 0;

          if ((data['rating'] as double?) != null && (data['rating'] as double?) != 0.0) {
            totalRatingPoints += (data['rating'] as double?) ?? 0.0;
            notesWithRating++;
          }
        }

        _averageRating = notesWithRating > 0 ? totalRatingPoints / notesWithRating : 0.0;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading user notes: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  // New method to delete a note
  Future<void> _deleteNote(String noteId) async {
    try {
      setState(() {
        _isDeleting = true;
      });

      // Delete the note from Firestore
      await _firestore.collection('notes').doc(noteId).delete();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Note deleted successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Reload the notes to update the UI
      _loadUserNotes();
    } catch (e) {
      print('Error deleting note: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete note. Please try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {
        _isDeleting = false;
      });
    }
  }

  // Show confirmation dialog before deleting
  void _showDeleteConfirmation(String noteId, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red),
            SizedBox(width: 10),
            Text('Delete Note', style: TextStyle(color: Colors.red)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "$title"? This action cannot be undone.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('CANCEL'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteNote(noteId);
            },
            child: Text('DELETE'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Uploads',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: primaryBlue,
        elevation: 0,
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
        child: _isLoading || _isDeleting
            ? Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              if (_isDeleting)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Text(
                    'Deleting note...',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
            ],
          ),
        )
            : _hasError
            ? _buildErrorState()
            : _userNotes == null || _userNotes!.isEmpty
            ? _buildEmptyState()
            : _buildContent(),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.white),
          SizedBox(height: 16),
          Text(
            'Unable to load your notes',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _isLoading = true;
                _hasError = false;
              });
              _getUserId();
            },
            icon: Icon(Icons.refresh),
            label: Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: primaryBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.upload_file, size: 64, color: Colors.white),
          SizedBox(height: 16),
          Text(
            'You haven\'t uploaded any notes yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Upload your first note to see it here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to Upload tab in main screen
              Navigator.pop(context);
              // You'll need to handle this navigation in your main screen
            },
            icon: Icon(Icons.add),
            label: Text('Upload Note'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: primaryBlue,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return CustomScrollView(
      slivers: [
        // Stats summary
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: _buildStatsSummary(),
          ),
        ),

        // Notes section title
        SliverToBoxAdapter(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
            padding: EdgeInsets.fromLTRB(16, 24, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Notes',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: darkBlue,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Manage and track your uploaded notes',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: 16),
              ],
            ),
          ),
        ),

        // Notes list
        SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, index) {
              if (index >= _userNotes!.length) {
                return null;
              }
              final note = _userNotes![index];
              final noteData = note.data() as Map<String, dynamic>;

              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: _buildNoteItem(
                  noteId: note.id,
                  noteData: noteData,
                  onTap: () => _navigateToNoteViewer(context, note.id, noteData),
                  onDelete: () => _showDeleteConfirmation(
                      note.id,
                      noteData['title'] ?? 'Untitled'
                  ),
                ),
              );
            },
            childCount: _userNotes!.length,
          ),
        ),

        // Bottom padding
        SliverToBoxAdapter(
          child: SizedBox(height: 20),
        ),
      ],
    );
  }

  Widget _buildStatsSummary() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: primaryBlue),
                SizedBox(width: 8),
                Text(
                  'Your Stats Summary',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: darkBlue,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard(
                  icon: Icons.upload_file,
                  value: '$_totalNotes',
                  label: 'Notes',
                  iconColor: primaryBlue,
                ),
                _buildStatCard(
                  icon: Icons.remove_red_eye,
                  value: NumberFormat.compact().format(_totalViews),
                  label: 'Views',
                  iconColor: Colors.blue.shade700,
                ),
                _buildStatCard(
                  icon: Icons.auto_awesome,
                  value: NumberFormat.compact().format(_totalLikes),
                  label: 'Inspiring',
                  iconColor: Colors.purple,
                ),
                _buildStatCard(
                  icon: Icons.lightbulb,
                  value: _averageRating.toStringAsFixed(1),
                  label: 'Avg Rating',
                  iconColor: Colors.amber,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color iconColor,
  }) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: iconColor.withOpacity(0.2),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.grey.shade800,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildNoteItem({
    required String noteId,
    required Map<String, dynamic> noteData,
    required VoidCallback onTap,
    required VoidCallback onDelete,
  }) {
    final timestamp = noteData['createdAt'] as Timestamp?;
    final date = timestamp != null
        ? DateFormat('MMM d, yyyy').format(timestamp.toDate())
        : 'Unknown date';

    final views = noteData['views'] as int? ?? 0;
    final likes = noteData['likes'] as int? ?? 0;
    final dislikes = noteData['dislikes'] as int? ?? 0;
    final rating = (noteData['rating'] ?? 0.0).toDouble();
    final ratingCount = noteData['ratingCount'] ?? 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title and date
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: accentBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.description, color: accentBlue),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          noteData['title'] ?? 'Untitled',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          date,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Action buttons
                  Row(
                    children: [
                      // Delete button
                      Container(
                        height: 32,
                        width: 32,
                        margin: EdgeInsets.only(right: 8),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                          onPressed: onDelete,
                          icon: Icon(Icons.delete_outline, color: Colors.red),
                          tooltip: 'Delete note',
                        ),
                      ),
                      // View button
                      Container(
                        height: 32,
                        child: ElevatedButton(
                          onPressed: onTap,
                          child: Text('View'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              SizedBox(height: 16),
              Divider(height: 1),
              SizedBox(height: 12),

              // Stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNoteStat(Icons.remove_red_eye, '${NumberFormat.compact().format(views)} Views', Colors.blue),
                  _buildNoteStat(Icons.auto_awesome, '${NumberFormat.compact().format(likes)} Inspiring', Colors.purple),
                  _buildNoteStat(Icons.psychology, '${NumberFormat.compact().format(dislikes)} Questions', Colors.amber.shade700),
                  _buildNoteStat(
                    Icons.star,
                    '${rating.toStringAsFixed(1)} (${ratingCount})',
                    rating > 0 ? Colors.amber : Colors.grey,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoteStat(IconData icon, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
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