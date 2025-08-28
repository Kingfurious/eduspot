import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'pdf_viewer_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  @override
  _LeaderboardScreenState createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sky blue color palette
  final Color primaryBlue = Color(0xFF1E88E5);
  final Color lightBlue = Color(0xFFBBDEFB);
  final Color darkBlue = Color(0xFF0D47A1);
  final Color accentBlue = Color(0xFF64B5F6);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [primaryBlue, Colors.white],
            stops: [0.0, 0.3],
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('notes')
              .orderBy('views', descending: true)
              .limit(20)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Text('Error loading leaderboard',
                    style: TextStyle(color: Colors.white)
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Text('No notes available yet',
                    style: TextStyle(color: Colors.white)
                ),
              );
            }

            final notes = snapshot.data!.docs;

            // Get top 3 for podium
            final topNotes = notes.length > 3
                ? notes.sublist(0, 3)
                : notes;

            // Get top 10 for bar chart (excluding top 3)
            final topTenNotes = notes.length > 3
                ? (notes.length > 10
                ? notes.sublist(3, 10)
                : notes.sublist(3))
                : <QueryDocumentSnapshot<Object?>>[];

            return CustomScrollView(
              slivers: [
                // Header section (non-scrollable part)
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      _buildLeaderboardHeader(),
                      // Top 3 Podium
                      _buildTopThreePodium(topNotes),
                    ],
                  ),
                ),

                // White container with rounded top corners
                SliverToBoxAdapter(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 20, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Section title
                          Text(
                            'Top 10 Most Viewed Notes',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: darkBlue,
                            ),
                          ),
                          SizedBox(height: 16),

                          // Bar chart for top 10
                          if (topTenNotes.isNotEmpty)
                            Container(
                              height: 220,
                              child: _buildBarChart(topTenNotes),
                            ),

                          SizedBox(height: 20),

                          // Detailed list title
                          Text(
                            'Detailed Rankings',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: darkBlue,
                            ),
                          ),
                          SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ),

                // Detailed rankings list (scrollable)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      if (index >= (notes.length > 10 ? 10 : notes.length)) {
                        return null;
                      }
                      final note = notes[index];
                      final noteData = note.data() as Map<String, dynamic>;

                      return Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: _buildDetailedItem(
                          noteId: note.id,
                          noteData: noteData,
                          rank: index + 1,
                          onTap: () => _navigateToNoteViewer(context, note.id, noteData),
                        ),
                      );
                    },
                    childCount: notes.length > 10 ? 10 : notes.length,
                  ),
                ),

                // Add padding at the bottom
                SliverToBoxAdapter(
                  child: SizedBox(height: 16),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLeaderboardHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.emoji_events, color: Colors.white, size: 32),
              SizedBox(width: 12),
              Text(
                'Top Notes Leaderboard',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Most viewed handwritten notes',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopThreePodium(List<QueryDocumentSnapshot<Object?>> topNotes) {
    // Handle case with fewer than 3 notes
    final hasFirst = topNotes.length >= 1;
    final hasSecond = topNotes.length >= 2;
    final hasThird = topNotes.length >= 3;

    // Get note data
    final firstNote = hasFirst ? topNotes[0].data() as Map<String, dynamic> : null;
    final secondNote = hasSecond ? topNotes[1].data() as Map<String, dynamic> : null;
    final thirdNote = hasThird ? topNotes[2].data() as Map<String, dynamic> : null;

    return Container(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd Place
          if (hasSecond)
            _buildPodiumPlace(
              rank: 2,
              noteData: secondNote!,
              noteId: topNotes[1].id,
              height: 160,
              color: Colors.grey.shade300,
              labelColor: Colors.grey.shade800,
            ),

          // 1st Place
          if (hasFirst)
            _buildPodiumPlace(
              rank: 1,
              noteData: firstNote!,
              noteId: topNotes[0].id,
              height: 180,
              color: Color(0xFFFFD700), // Gold color
              labelColor: Colors.brown.shade800,
              showCrown: true,
            ),

          // 3rd Place
          if (hasThird)
            _buildPodiumPlace(
              rank: 3,
              noteData: thirdNote!,
              noteId: topNotes[2].id,
              height: 140,
              color: Color(0xFFCD7F32), // Bronze color
              labelColor: Colors.brown.shade600,
            ),
        ],
      ),
    );
  }
  Widget _buildPodiumPlace({
    required int rank,
    required Map<String, dynamic> noteData,
    required String noteId,
    required double height,
    required Color color,
    required Color labelColor,
    bool showCrown = false,
  }) {
    final viewsText = noteData['views'] != null ?
    NumberFormat.compact().format(noteData['views']) : '0';

    // Get user name and first letter for avatar
    final userName = noteData['userName'] ?? 'Unknown';
    final firstLetter = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: () => _navigateToNoteViewer(context, noteId, noteData),
        child: Column(
          children: [
            // Crown for 1st place
            if (showCrown)
              Icon(Icons.workspace_premium, color: Colors.amber, size: 24),

            // User avatar
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: rank == 1 ? 30 : 24,
                    backgroundColor: noteData['userImageUrl'] != null &&
                        noteData['userImageUrl'].toString().isNotEmpty
                        ? Colors.grey.shade200
                        : color,
                    backgroundImage: noteData['userImageUrl'] != null &&
                        noteData['userImageUrl'].toString().isNotEmpty
                        ? CachedNetworkImageProvider(noteData['userImageUrl'])
                        : null,
                    child: noteData['userImageUrl'] == null ||
                        noteData['userImageUrl'].toString().isEmpty
                        ? Text(
                      firstLetter,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: rank == 1 ? 24 : 20,
                      ),
                    )
                        : null,
                  ),
                ),

                // Rank badge
                Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    '#$rank',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),

            // Rest of the widget stays the same
            SizedBox(height: 8),

            Container(
              width: 90,
              child: Text(
                userName,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.white,
                ),
              ),
            ),

            SizedBox(height: 5),

            Container(
              width: 90,
              child: Text(
                noteData['title'] ?? 'Untitled',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                ),
              ),
            ),

            SizedBox(height: 8),

            // Podium
            Container(
              width: 80,
              height: height,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.remove_red_eye, color: labelColor),
                    SizedBox(height: 4),
                    Text(
                      viewsText,
                      style: TextStyle(
                        color: labelColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Views',
                      style: TextStyle(
                        color: labelColor,
                        fontSize: 12,
                      ),
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

// Update for the bar chart avatar
  Widget _buildBarChart(List<QueryDocumentSnapshot<Object?>> topNotes) {
    // Find maximum views to scale the bars
    int maxViews = 0;
    for (var note in topNotes) {
      final data = note.data() as Map<String, dynamic>;
      final views = data['views'] as int? ?? 0;
      if (views > maxViews) maxViews = views;
    }

    // If no views, set a default max
    if (maxViews == 0) maxViews = 100;

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: topNotes.length,
      itemBuilder: (context, index) {
        final noteData = topNotes[index].data() as Map<String, dynamic>;
        final views = noteData['views'] as int? ?? 0;
        final rank = index + 4; // Since these are ranks 4-10

        // Calculate height percentage
        final double heightPercentage = views / maxViews;

        // Get user name and first letter for avatar
        final userName = noteData['userName'] ?? 'Unknown';
        final firstLetter = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

        return InkWell(
          onTap: () => _navigateToNoteViewer(context, topNotes[index].id, noteData),
          child: Container(
            width: 70,
            margin: EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // We can add a small avatar here above the bar
                CircleAvatar(
                  radius: 12,
                  backgroundColor: noteData['userImageUrl'] != null &&
                      noteData['userImageUrl'].toString().isNotEmpty
                      ? Colors.grey.shade200
                      : primaryBlue,
                  backgroundImage: noteData['userImageUrl'] != null &&
                      noteData['userImageUrl'].toString().isNotEmpty
                      ? CachedNetworkImageProvider(noteData['userImageUrl'])
                      : null,
                  child: noteData['userImageUrl'] == null ||
                      noteData['userImageUrl'].toString().isEmpty
                      ? Text(
                    firstLetter,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  )
                      : null,
                ),
                SizedBox(height: 4),
                Text(
                  '${NumberFormat.compact().format(views)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: primaryBlue,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 4),
                Container(
                  width: 45,
                  height: 100 * heightPercentage,
                  decoration: BoxDecoration(
                    color: accentBlue,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [primaryBlue, accentBlue],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    shape: BoxShape.circle,
                    border: Border.all(color: primaryBlue),
                  ),
                  child: Text(
                    '#$rank',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: primaryBlue,
                    ),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  userName,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  Widget _buildDetailedItem({
    required String noteId,
    required Map<String, dynamic> noteData,
    required int rank,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            children: [
              // Top row with rank, user info and view count
              Row(
                children: [
                  // Rank number with medal for top 3
                  _buildRankBadge(rank),

                  SizedBox(width: 12),

                  // User avatar
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: noteData['userImageUrl'] != null &&
                        noteData['userImageUrl'].toString().isNotEmpty
                        ? CachedNetworkImageProvider(noteData['userImageUrl'])
                        : null,
                    child: noteData['userImageUrl'] == null ||
                        noteData['userImageUrl'].toString().isEmpty
                        ? Icon(Icons.person, size: 16, color: Colors.grey.shade500)
                        : null,
                  ),

                  SizedBox(width: 12),

                  // Title and user name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          noteData['title'] ?? 'Untitled',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          noteData['userName'] ?? 'Unknown user',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Views count
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.visibility, size: 14, color: primaryBlue),
                        SizedBox(width: 4),
                        Text(
                          '${NumberFormat.compact().format(noteData['views'] ?? 0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: primaryBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Divider
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1),
              ),

              // Expanded metrics row (Likes, Dislikes, etc.)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMetricItem(
                    icon: Icons.auto_awesome,
                    value: '${noteData['likes'] ?? 0}',
                    label: 'Inspiring',
                    color: Colors.purple,
                  ),
                  _buildMetricItem(
                    icon: Icons.psychology,
                    value: '${noteData['dislikes'] ?? 0}',
                    label: 'Questions',
                    color: Colors.amber.shade700,
                  ),
                  _buildMetricItem(
                    icon: Icons.lightbulb,
                    value: '${(noteData['rating'] ?? 0.0).toStringAsFixed(1)}',
                    label: 'Rating (${noteData['ratingCount'] ?? 0})',
                    color: Colors.amber,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRankBadge(int rank) {
    IconData? medalIcon;
    Color backgroundColor;
    Color iconColor;

    if (rank == 1) {
      medalIcon = Icons.looks_one;
      backgroundColor = Color(0xFFFFD700).withOpacity(0.2); // Gold
      iconColor = Color(0xFFFFD700);
    } else if (rank == 2) {
      medalIcon = Icons.looks_two;
      backgroundColor = Colors.grey.shade300.withOpacity(0.3); // Silver
      iconColor = Colors.grey.shade500;
    } else if (rank == 3) {
      medalIcon = Icons.looks_3;
      backgroundColor = Color(0xFFCD7F32).withOpacity(0.2); // Bronze
      iconColor = Color(0xFFCD7F32);
    } else {
      backgroundColor = primaryBlue.withOpacity(0.1);
      iconColor = primaryBlue;
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: medalIcon != null
            ? Icon(medalIcon, size: 20, color: iconColor)
            : Text(
          '$rank',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: iconColor,
          ),
        ),
      ),
    );
  }

  Widget _buildMetricItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
              ),
            ),
          ],
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