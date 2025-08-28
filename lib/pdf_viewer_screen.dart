import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:math' as math;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';

class NoteViewerScreen extends StatefulWidget {
  final String noteId;
  final Map<String, dynamic> noteData;

  const NoteViewerScreen({
    Key? key,
    required this.noteId,
    required this.noteData,
  }) : super(key: key);

  @override
  _NoteViewerScreenState createState() => _NoteViewerScreenState();
}

class _NoteViewerScreenState extends State<NoteViewerScreen> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  double _userRating = 0;

  // Track user interactions
  bool _hasInspirationMarked = false;  // Replaced "liked"
  bool _hasQuestionMarked = false;    // Replaced "disliked"
  bool _hasRated = false;
  String? _userId;

  // PDF viewer related variables
  String? localPdfPath;
  bool isPdfLoading = true;
  int currentPage = 0;
  int totalPages = 0;
  bool pdfReady = false;
  double _downloadProgress = 0.0;

  // Animation controller for loading animation
  late AnimationController _progressAnimationController;

  // Modern color scheme
  final Color primaryColor = Color(0xFF4361EE);
  final Color secondaryColor = Color(0xFF3A0CA3);
  final Color accentColor = Color(0xFF4CC9F0);
  final Color lightColor = Color(0xFFF8F9FA);
  final Color darkColor = Color(0xFF212529);
  final Color errorColor = Color(0xFFE63946);
  final Color successColor = Color(0xFF06D6A0);

  @override
  void initState() {
    super.initState();
    _progressAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    )..repeat();

    _loadBannerAd();
    _incrementViews();
    _loadPdfFromUrl(widget.noteData['fileUrl']);
    _getUserId();
    _loadInteractionState();
  }

  @override
  void dispose() {
    _progressAnimationController.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  Future<void> _getUserId() async {
    // First try to get from Firebase Auth
    User? user = _auth.currentUser;
    if (user != null) {
      _userId = user.uid;
    } else {
      // Try to get from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getString('userId');
    }
  }

  Future<void> _loadInteractionState() async {
    await _getUserId();

    if (_userId == null) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _hasInspirationMarked = prefs.getBool('${widget.noteId}_${_userId}_inspired') ?? false;
      _hasQuestionMarked = prefs.getBool('${widget.noteId}_${_userId}_question') ?? false;
      _hasRated = prefs.getBool('${widget.noteId}_${_userId}_rated') ?? false;
    });

    // Also check Firestore for interaction records
    try {
      final interactionDoc = await _firestore
          .collection('note_interactions')
          .doc('${widget.noteId}_$_userId')
          .get();

      if (interactionDoc.exists) {
        final data = interactionDoc.data() as Map<String, dynamic>;
        setState(() {
          _hasInspirationMarked = data['inspired'] ?? _hasInspirationMarked;
          _hasQuestionMarked = data['question'] ?? _hasQuestionMarked;
          _hasRated = data['rated'] ?? _hasRated;
        });
      }
    } catch (e) {
      print('Error loading interaction state: $e');
    }
  }

  Future<void> _saveInteractionState(String type) async {
    if (_userId == null) {
      await _getUserId();
      if (_userId == null) {
        _showSnackBar(
          'Unable to record your interaction. Please sign in.',
          Colors.red.shade700,
          Icons.error_outline,
        );
        return;
      }
    }

    final prefs = await SharedPreferences.getInstance();

    switch (type) {
      case 'inspired':
        await prefs.setBool('${widget.noteId}_${_userId}_inspired', true);
        if (_hasQuestionMarked) {
          await prefs.setBool('${widget.noteId}_${_userId}_question', false);
          // Remove question mark if user changes to inspiration
          await _firestore.collection('notes').doc(widget.noteId).update({
            'dislikes': FieldValue.increment(-1),
          });
        }
        setState(() {
          _hasInspirationMarked = true;
          _hasQuestionMarked = false;
        });
        break;
      case 'question':
        await prefs.setBool('${widget.noteId}_${_userId}_question', true);
        if (_hasInspirationMarked) {
          await prefs.setBool('${widget.noteId}_${_userId}_inspired', false);
          // Remove inspiration mark if user changes to question
          await _firestore.collection('notes').doc(widget.noteId).update({
            'likes': FieldValue.increment(-1),
          });
        }
        setState(() {
          _hasQuestionMarked = true;
          _hasInspirationMarked = false;
        });
        break;
      case 'rate':
        await prefs.setBool('${widget.noteId}_${_userId}_rated', true);
        setState(() {
          _hasRated = true;
        });
        break;
    }

    // Also save to Firestore for better tracking
    try {
      await _firestore
          .collection('note_interactions')
          .doc('${widget.noteId}_$_userId')
          .set({
        'userId': _userId,
        'noteId': widget.noteId,
        'inspired': _hasInspirationMarked,
        'question': _hasQuestionMarked,
        'rated': _hasRated,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error saving interaction state to Firestore: $e');
    }
  }

  Future<void> _loadPdfFromUrl(String url) async {
    setState(() {
      isPdfLoading = true;
      _downloadProgress = 0.0;
    });

    try {
      // Create a client that will track download progress
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);

      final contentLength = response.contentLength ?? 0;
      final bytes = <int>[];

      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        final downloadedLength = bytes.length;
        setState(() {
          _downloadProgress = contentLength > 0
              ? downloadedLength / contentLength
              : 0.0;
        });
      }

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/document.pdf');

      await file.writeAsBytes(bytes, flush: true);

      setState(() {
        localPdfPath = file.path;
        isPdfLoading = false;
        pdfReady = true;
      });
    } catch (e) {
      setState(() {
        isPdfLoading = false;
      });
      _showSnackBar(
        'Error loading PDF: $e',
        errorColor,
        Icons.error_outline,
      );
    }
  }

  void _loadBannerAd() {
    final String bannerAdUnitId = 'ca-app-pub-9136866657796541/6897947810';

    _bannerAd = BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          print('Ad failed to load: $error');
          ad.dispose();
        },
      ),
    )..load();
  }

  Future<void> _incrementViews() async {
    // We only want to increment view count once per session
    final prefs = await SharedPreferences.getInstance();
    final hasViewed = prefs.getBool('${widget.noteId}_viewed') ?? false;

    if (!hasViewed) {
      await _firestore.collection('notes').doc(widget.noteId).update({
        'views': FieldValue.increment(1),
      });

      await prefs.setBool('${widget.noteId}_viewed', true);
    }
  }

  void _markAsInspiring() async {
    if (_hasInspirationMarked) {
      _showSnackBar(
        'You already marked this note as inspiring',
        Colors.purple,
        Icons.auto_awesome,
      );
      return;
    }

    await _firestore.collection('notes').doc(widget.noteId).update({
      'likes': FieldValue.increment(1),
    });

    await _saveInteractionState('inspired');

    _showSnackBar(
      'You marked this note as inspiring!',
      Colors.purple,
      Icons.auto_awesome,
    );
  }

  void _markAsQuestionable() async {
    if (_hasQuestionMarked) {
      _showSnackBar(
        'You already marked this note as questionable',
        Colors.amber.shade700,
        Icons.psychology,
      );
      return;
    }

    await _firestore.collection('notes').doc(widget.noteId).update({
      'dislikes': FieldValue.increment(1),
    });

    await _saveInteractionState('question');

    _showSnackBar(
      'You marked this note as questionable',
      Colors.amber.shade700,
      Icons.psychology,
    );
  }

  void _rateNote() async {
    if (_hasRated) {
      _showSnackBar(
        'You have already rated this note',
        Colors.grey.shade700,
        Icons.info_outline,
      );
      return;
    }

    if (_userRating > 0) {
      // Get current rating data
      DocumentSnapshot doc = await _firestore.collection('notes').doc(widget.noteId).get();
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

      double currentRating = (data['rating'] ?? 0.0).toDouble();
      int ratingCount = (data['ratingCount'] ?? 0);

      // Calculate new average rating
      double totalRating = currentRating * ratingCount;
      totalRating += _userRating;
      ratingCount++;
      double newRating = totalRating / ratingCount;

      await _firestore.collection('notes').doc(widget.noteId).update({
        'rating': newRating,
        'ratingCount': ratingCount,
      });

      await _saveInteractionState('rate');

      _showSnackBar(
        'Your rating has been recorded. Thank you!',
        successColor,
        Icons.emoji_events,
      );
    } else {
      _showSnackBar(
        'Please select a rating before submitting',
        Colors.orange,
        Icons.warning_amber_rounded,
      );
    }
  }

  void _showSnackBar(String message, Color color, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: EdgeInsets.all(8),
        duration: Duration(seconds: 3),
        elevation: 6,
      ),
    );
  }

  void _shareNote() {
    // Show a bottom sheet with sharing options
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.share, color: primaryColor),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Share this note',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: darkColor,
                        ),
                      ),
                      Text(
                        widget.noteData['title'] ?? 'Handwritten Note',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),

            // Social sharing options
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildShareOption(
                  color: Color(0xFF25D366),
                  icon: Icons.message,
                  label: 'WhatsApp',
                  onTap: () => _shareToApp('whatsapp'),
                ),
                _buildShareOption(
                  color: Color(0xFF0088CC),
                  icon: Icons.send,
                  label: 'Telegram',
                  onTap: () => _shareToApp('telegram'),
                ),
                _buildShareOption(
                  color: Color(0xFF833AB4),
                  icon: Icons.camera_alt,
                  label: 'Instagram',
                  onTap: () => _shareToApp('instagram'),
                ),
                _buildShareOption(
                  color: Colors.blue,
                  icon: Icons.link,
                  label: 'Copy Link',
                  onTap: () => _copyLink(),
                ),
              ],
            ),

            SizedBox(height: 20),

            // General share button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _shareWithSharePlus();
                },
                icon: Icon(Icons.share),
                label: Text('Share with other apps'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
              ),
            ),

            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption({
    required Color color,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _shareToApp(String app) {
    Navigator.pop(context); // Close bottom sheet

    final String title = widget.noteData['title'] ?? 'Handwritten Note';
    final String desc = widget.noteData['description'] ?? '';
    final String url = 'https://yourdomain.com/notes/${widget.noteId}';

    String message = '📝 $title\n\n$desc\n\nView note: $url';

    Share.share(message, subject: 'Check out this note: $title');

    // Show confirmation
    _showSnackBar(
      'Sharing via $app...',
      primaryColor,
      Icons.share,
    );
  }

  void _shareWithSharePlus() {
    final String title = widget.noteData['title'] ?? 'Handwritten Note';
    final String desc = widget.noteData['description'] ?? '';
    final String url = 'https://yourdomain.com/notes/${widget.noteId}';

    String message = '📝 $title\n\n$desc\n\nView note: $url';

    Share.share(message, subject: 'Check out this note: $title');
  }

  void _copyLink() {
    Navigator.pop(context); // Close bottom sheet

    final String url = 'https://yourdomain.com/notes/${widget.noteId}';
    Clipboard.setData(ClipboardData(text: url));

    _showSnackBar(
      'Link copied to clipboard',
      successColor,
      Icons.check_circle,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.noteData['title'] ?? 'View Note',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.share),
            onPressed: _shareNote,
            tooltip: 'Share this note',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildPdfView(),
          ),
          _buildInteractionBar(),
          _buildRatingSection(),
          if (_isAdLoaded)
            Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
              ),
              child: AdWidget(ad: _bannerAd!),
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
            ),
        ],
      ),
    );
  }

  Widget _buildInteractionBar() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildInteractionButton(
            icon: Icons.auto_awesome,
            label: 'Inspiring',
            active: _hasInspirationMarked,
            activeColor: Colors.purple,
            onPressed: _markAsInspiring,
          ),
          _buildInteractionButton(
            icon: Icons.psychology,
            label: 'Questionable',
            active: _hasQuestionMarked,
            activeColor: Colors.amber.shade700,
            onPressed: _markAsQuestionable,
          ),
          _buildInteractionButton(
            icon: Icons.remove_red_eye,
            label: '${widget.noteData['views'] ?? 0}',
            active: false,
            activeColor: Colors.grey,
            onPressed: null,
          ),
        ],
      ),
    );
  }

  Widget _buildInteractionButton({
    required IconData icon,
    required String label,
    required bool active,
    required Color activeColor,
    required VoidCallback? onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: active ? activeColor.withOpacity(0.1) : Colors.grey.shade50,
            border: Border.all(
              color: active ? activeColor.withOpacity(0.5) : Colors.grey.shade200,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: active ? activeColor : Colors.grey.shade600,
                size: 20,
              ),
              SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: active ? activeColor : Colors.grey.shade700,
                  fontWeight: active ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPdfView() {
    if (isPdfLoading) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Custom animated loading indicator
              _buildLoadingAnimation(),
              SizedBox(height: 30),

              // Document info
              Text(
                widget.noteData['title'] ?? 'View Note',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: darkColor,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'by ${widget.noteData['userName'] ?? 'Anonymous'}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              SizedBox(height: 40),

              // Progress bar
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Downloading PDF',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: darkColor,
                          ),
                        ),
                        Text(
                          '${(_downloadProgress * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Stack(
                        children: [
                          AnimatedContainer(
                            duration: Duration(milliseconds: 200),
                            width: MediaQuery.of(context).size.width * 0.8 * _downloadProgress,
                            height: 6,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [primaryColor, accentColor],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } else if (!pdfReady || localPdfPath == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: errorColor),
            SizedBox(height: 16),
            Text(
              'Failed to load PDF',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: darkColor,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Please try again or contact support',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _loadPdfFromUrl(widget.noteData['fileUrl']),
              icon: Icon(Icons.refresh),
              label: Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    } else {
      return Stack(
        children: [
          PDFView(
            filePath: localPdfPath!,
            enableSwipe: true,
            swipeHorizontal: false,
            autoSpacing: true,
            pageFling: true,
            pageSnap: true,
            defaultPage: currentPage,
            fitPolicy: FitPolicy.WIDTH,
            preventLinkNavigation: false,
            onRender: (_pages) {
              setState(() {
                totalPages = _pages!;
                pdfReady = true;
              });
            },
            onError: (error) {
              _showSnackBar(
                'Error loading PDF: $error',
                errorColor,
                Icons.error_outline,
              );
            },
            onPageError: (page, error) {
              _showSnackBar(
                'Error on page $page: $error',
                errorColor,
                Icons.error_outline,
              );
            },
            onViewCreated: (PDFViewController pdfViewController) {
              // You can use the controller for operations like jumping to a specific page
            },
            onPageChanged: (int? page, int? total) {
              if (page != null && total != null) {
                setState(() {
                  currentPage = page;
                  totalPages = total;
                });
              }
            },
          ),
          // Modern page indicator
          totalPages > 0
              ? Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.insert_drive_file_outlined,
                      color: Colors.white,
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Page ${currentPage + 1} of $totalPages',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
              : Container(),
        ],
      );
    }
  }

  Widget _buildLoadingAnimation() {
    return AnimatedBuilder(
      animation: _progressAnimationController,
      builder: (context, child) {
        return Container(
          width: 100,
          height: 100,
          child: CustomPaint(
            painter: LoadingPainter(
              _progressAnimationController.value,
              primaryColor: primaryColor,
              secondaryColor: accentColor,
            ),
          ),
        );
      },
    );
  }

  Widget _buildRatingSection() {
    return Container(
        padding: EdgeInsets.all(16),
    decoration: BoxDecoration(
    color: Colors.white,
    boxShadow: [
    BoxShadow(
    color: Colors.black.withOpacity(0.05),
    blurRadius: 5,
    offset: Offset(0, -1),
    ),
    ],
    ),
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Text(
    _hasRated
    ? 'You have already rated this note'
        : 'How insightful was this note?',
    style: TextStyle(
    fontWeight: FontWeight.bold,
    color: _hasRated ? Colors.grey.shade600 : darkColor,
    fontSize: 15,
    ),
    ),
    SizedBox(height: 10),
    Row(
    children: [
    Expanded(
    child: RatingBar.builder(
    initialRating: 0,
    minRating: 1,
    direction: Axis.horizontal,
    allowHalfRating: true,
    itemCount: 5,
    itemSize: 24,
    unratedColor: Colors.grey.shade300,
      ignoreGestures: _hasRated,
      itemBuilder: (context, _) => Icon(
        Icons.lightbulb,
        color: _hasRated ? Colors.grey.shade400 : Colors.amber,
      ),
      onRatingUpdate: (rating) {
        if (!_hasRated) {
          setState(() {
            _userRating = rating;
          });

          // Add haptic feedback
          HapticFeedback.lightImpact();
        }
      },
    ),
    ),
      SizedBox(width: 12),
      ElevatedButton(
        onPressed: _hasRated ? null : _rateNote,
        style: ElevatedButton.styleFrom(
          backgroundColor: _hasRated ? Colors.grey.shade300 : primaryColor,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: _hasRated ? 0 : 2,
        ),
        child: Text(
          'Submit',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    ],
    ),
    ],
    ),
    );
  }
}

// Custom loading animation painter
class LoadingPainter extends CustomPainter {
  final double animationValue;
  final Color primaryColor;
  final Color secondaryColor;

  LoadingPainter(
      this.animationValue, {
        required this.primaryColor,
        required this.secondaryColor,
      });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw background circle
    final backgroundPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0;

    canvas.drawCircle(center, radius - 5, backgroundPaint);

    // Draw animated arc
    final arcPaint = Paint()
      ..shader = SweepGradient(
        colors: [primaryColor, secondaryColor],
        startAngle: 0.0,
        endAngle: 2 * math.pi,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5.0;

    final startAngle = -math.pi / 2; // Start from the top (negative PI/2)
    final sweepAngle = 2 * math.pi * animationValue; // Full circle times animation progress

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 5),
      startAngle,
      sweepAngle,
      false,
      arcPaint,
    );

    // Draw small circles at the end of the arc
    final double arcEndX = center.dx + (radius - 5) * math.cos(startAngle + sweepAngle);
    final double arcEndY = center.dy + (radius - 5) * math.sin(startAngle + sweepAngle);

    final circlePaint = Paint()
      ..color = secondaryColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(arcEndX, arcEndY), 5, circlePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}