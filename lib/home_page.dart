import 'package:eduspark/Applymentor.dart';
import 'package:eduspark/Courseform.dart';
import 'package:eduspark/ExploreJobsPage.dart';
import 'package:eduspark/Models/Course.dart';
import 'package:eduspark/Researchmaster.dart';
import 'package:eduspark/course_detail_screen.dart';
import 'package:eduspark/jobs_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'LeaderboardScreen.dart';
import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'MentorPage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:eduspark/CoursesScreen.dart';
import 'package:eduspark/ExploreScreen.dart';
import 'package:eduspark/ProfileScreen.dart';
import 'package:eduspark/MyTeamScreen.dart';
import 'package:eduspark/projectsscreen.dart';
import 'package:eduspark/AskHelpScreen.dart';
import 'package:eduspark/LearnScreen.dart';
import 'package:eduspark/StartupPage.dart';
import 'package:eduspark/UploadProjectScreen.dart';
import 'package:eduspark/UploadProjectForm.dart';
import 'package:eduspark/Studymodepage.dart';
import 'Course_list_screen.dart';
import 'Learnscreenhome.dart';
import 'innovation_score_service.dart';
import 'dart:ui';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // Added for connectivity check

// App Colors
class AppColors {
  static const Color primaryBlue = Color(0xFF1976D2);
  static const Color lightBlue = Color(0xFF64B5F6);
  static const Color veryLightBlue = Color(0xFFE3F2FD);
  static const Color darkBlue = Color(0xFF0D47A1);
  static const Color accentBlue = Color(0xFF29B6F6);
  static const Color textPrimary = Color(0xFF263238);
  static const Color textSecondary = Color(0xFF607D8B);
  static const Color background = Color(0xFFF5F7FA);
  static const Color cardBackground = Colors.white;
  static const Color shadowColor = Color(0xFF000000);
  static const Color errorColor = Color(0xFFD32F2F);
  static const Color successColor = Color(0xFF388E3C);
  static const Color gradientStart = Color(0xFF2196F3);
  static const Color gradientEnd = Color(0xFF1976D2);
  static const Color watercolorLight = Color(0xFFBBDEFB);
  static const Color watercolorDark = Color(0xFF42A5F5);
  // Colors for grid items
  static const Color gridColor1 = Color(0xFFFF8A80); // Coral
  static const Color gridColor2 = Color(0xFF80D8FF); // Sky Blue
  static const Color gridColor3 = Color(0xFFFFD180); // Amber
  static const Color gridColor4 = Color(0xFFFF6F61); // Coral Red
  static const Color gridColor5 = Color(0xFFB388FF); // Purple
  static const Color gridColor6 = Color(0xFFFF80AB); // Pink
  static const Color gridColor7 = Color(0xFF4CAF50); // Forest Green
  static const Color gridColor8 = Color(0xFFFFD740); // Yellow
  static const Color gridColor9 = Color(0xFF82B1FF); // Light Blue
  // Glass effect colors
  static const Color glassBackground = Color(0x80FFFFFF);
  static const Color glassBorder = Color(0x33FFFFFF);
}

void main() {
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Innovation Dashboard',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Poppins',
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryBlue,
          primary: AppColors.primaryBlue,
          secondary: AppColors.accentBlue,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: AppColors.textPrimary),
          bodyMedium: TextStyle(color: AppColors.textSecondary),
          headlineSmall: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      home: const DashboardScreen(username: 'John Doe'),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  final String username;
  const DashboardScreen({Key? key, required this.username}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.background, AppColors.veryLightBlue],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          IndexedStack(
            index: _selectedIndex,
            children: [
              HomeScreen(username: widget.username),
              const ProjectsPagetwo(),
              CoursesListScreen(),
              const ExploreScreen(),
              const UploadProjectScreenForm(),
            ],
          ),
        ],
      ),
      bottomNavigationBar: _buildGlassBottomNavigation(),
    );
  }

  Widget _buildGlassBottomNavigation() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 70,
            decoration: BoxDecoration(
              color: AppColors.glassBackground,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.glassBorder, width: 1),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowColor.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(Icons.home_rounded, 'Home', 0),
                _buildNavItem(Icons.book_rounded, 'Courses', 1),
                _buildNavItem(Icons.explore_rounded, 'Explore', 2),
                _buildNavItem(Icons.rocket_launch_rounded, 'Projects', 3),
                _buildNavItem(Icons.cloud_upload_rounded, 'Upload', 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primaryBlue : AppColors.textSecondary,
              size: 28,
            ),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: TextStyle(
                color: isSelected ? AppColors.primaryBlue : AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final String username;
  const HomeScreen({Key? key, required this.username}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late String greeting;
  late String formattedDate;
  String? _profileImageUrl;
  bool _isLoadingProfile = true;
  bool _isMessageBarVisible = true;
  bool _showSkipButton = false;
  bool _isOffline = false;
  bool _hasShownAd = false; // Track if ad has been shown
  Timer? _skipTimer;
  String? _lastShownAdId; // Track which ad was last shown

  // Recommended courses data
  final List<Map<String, dynamic>> recommendedCourses = [
    {'name': 'Python', 'code': 'PY', 'color': AppColors.gridColor1},
    {'name': 'Java', 'code': 'JV', 'color': AppColors.gridColor3},
    {'name': 'Flutter', 'code': 'FLT', 'color': AppColors.gridColor8},
    {'name': 'Web Development', 'code': 'WEB', 'color': AppColors.gridColor7},
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _isMessageBarVisible = true;
    _showSkipButton = false;
    _hasShownAd = false;
    _startSkipTimer();

    _setGreetingAndDate();
    _loadUserProfile();
    _animationController.forward();
  }

  void _startSkipTimer() {
    _skipTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _isMessageBarVisible && !_hasShownAd) {
        setState(() {
          _showSkipButton = true;
        });
      }
    });
  }

  // Improved skip functionality
  void _skipAd() {
    _skipTimer?.cancel();
    setState(() {
      _isMessageBarVisible = false;
      _hasShownAd = true;
      _showSkipButton = false;
    });
    Navigator.of(context).pop(); // Close the ad dialog
  }

  // Improved ad click functionality
  void _handleAdClick(Map<String, dynamic> adData) async {
    final url = Uri.parse(adData['cta_url']);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('ad_clicks').add({
          'user_id': user.uid,
          'ad_id': adData['id'],
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    }

    // Close ad after click
    setState(() {
      _isMessageBarVisible = false;
      _hasShownAd = true;
      _showSkipButton = false;
    });
    Navigator.of(context).pop();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoadingProfile = true;
      _isOffline = false;
    });

    // Check connectivity
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      if (mounted) {
        setState(() {
          _isOffline = true;
          _isLoadingProfile = false;
        });
      }
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('studentprofile')
            .doc(currentUser.uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          if (mounted) {
            setState(() {
              _profileImageUrl = userData['imageUrl'] ?? currentUser.photoURL;
              _isLoadingProfile = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _profileImageUrl = currentUser.photoURL;
              _isLoadingProfile = false;
            });
          }
        }
      } catch (e) {
        print("Error loading user profile: $e");
        if (mounted) {
          setState(() {
            _profileImageUrl = currentUser.photoURL;
            _isLoadingProfile = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
    }
  }

  void _setGreetingAndDate() {
    final now = DateTime.now();
    final dateFormatter = DateFormat('EEEE, d MMMM yyyy');
    formattedDate = dateFormatter.format(now);
    final hour = now.hour;
    greeting = hour < 12 ? 'Good Morning' : hour < 17 ? 'Good Afternoon' : 'Good Evening';
  }

  @override
  void dispose() {
    _animationController.dispose();
    _skipTimer?.cancel();
    super.dispose();
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

  Future<String> _getDownloadUrl(String gsUrl) async {
    try {
      final ref = FirebaseStorage.instance.refFromURL(gsUrl);
      final downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error fetching download URL: $e');
      return '';
    }
  }

  // Updated _showFullScreenAd method with proper skip functionality
  void _showFullScreenAd(Map<String, dynamic> adData, BuildContext context) {
    // Don't show ad if already shown or dismissed
    if (_hasShownAd || !_isMessageBarVisible) return;

    // Don't show same ad again
    if (_lastShownAdId == adData['id']) return;

    _lastShownAdId = adData['id'];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return WillPopScope(
          onWillPop: () async => false, // Prevent back button
          child: Dialog(
            insetPadding: EdgeInsets.zero,
            backgroundColor: Colors.transparent,
            child: FutureBuilder<String>(
              future: _getDownloadUrl(adData['image_url']),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Loading ad...',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                  // Auto-dismiss if ad fails to load
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _skipAd();
                  });
                  return SizedBox.shrink();
                }

                return Stack(
                  children: [
                    // Full screen image
                    Positioned.fill(
                      child: Image.network(
                        snapshot.data!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          // Auto-dismiss if image fails to load
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _skipAd();
                          });
                          return Container(
                            color: Colors.grey,
                            child: const Center(
                              child: Icon(
                                Icons.broken_image,
                                color: Colors.white,
                                size: 48,
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Skip button in top-right corner
                    Positioned(
                      top: 40,
                      right: 20,
                      child: _showSkipButton
                          ? GestureDetector(
                        onTap: _skipAd,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(color: Colors.white.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 18,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Skip',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                          : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Skip in 5s',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Ad content at bottom
                    Positioned(
                      bottom: 40,
                      left: 20,
                      right: 20,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withOpacity(0.7),
                                  Colors.black.withOpacity(0.9),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withOpacity(0.2)),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  adData['title'] ?? 'Special Offer',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  adData['subtitle'] ?? 'Don\'t miss out!',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // CTA Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => _handleAdClick(adData),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryBlue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                elevation: 8,
                              ),
                              child: Text(
                                adData['cta_text'] ?? 'Learn More',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildScoreCard() {
    return StreamBuilder<int>(
      stream: InnovationScoreService().innovationScoreStream,
      builder: (context, snapshot) {
        final int innovationScore = snapshot.data ?? 0;
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.gradientStart.withOpacity(0.9), AppColors.gradientEnd.withOpacity(0.9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowColor.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.star_rounded,
                    color: Colors.yellow,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: CircularProgressIndicator(
                          value: innovationScore / 100,
                          strokeWidth: 8,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 500),
                        child: Text(
                          '$innovationScore',
                          key: ValueKey<int>(innovationScore),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  CustomPaint(
                    size: const Size(24, 24),
                    painter: SparklePainter(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Innovation Score',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                snapshot.connectionState == ConnectionState.waiting
                    ? 'Calculating your score...'
                    : snapshot.hasError
                    ? 'Error loading score'
                    : 'Your creative impact',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecommendedCourseCard(Map<String, dynamic> course) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>  LearnHomePage(),
          ),
        );
      },
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowColor.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [course['color'], course['color'].withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Text(
                course['code'],
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                course['name'],
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridItem({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowColor.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(4, 4),
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.5),
              blurRadius: 8,
              offset: const Offset(-4, -4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            splashColor: color.withOpacity(0.2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [color, color.withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final displayName = currentUser?.displayName ?? widget.username;

    return SafeArea(
      child: Stack(
          children: [
          AbsorbPointer(
          absorbing: _isMessageBarVisible && !_hasShownAd,
          child: BackdropFilter(
          filter: ImageFilter.blur(
          sigmaX: (_isMessageBarVisible && !_hasShownAd) ? 5.0 : 0.0,
      sigmaY: (_isMessageBarVisible && !_hasShownAd) ? 5.0 : 0.0,
    ),
    child: SingleChildScrollView(
    physics: const BouncingScrollPhysics(),
    child: Padding(
    padding: const EdgeInsets.all(20.0),
    child: FadeTransition(
    opacity: _fadeAnimation,
    child: SlideTransition(
    position: _slideAnimation,
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
    Expanded(
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Text(
    greeting,
    style: TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    ),
    ),
    const SizedBox(height: 4),
    Text(
    displayName,
    style: const TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.primaryBlue,
    ),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    ),
    const SizedBox(height: 8),
    Text(
    formattedDate,
    style: const TextStyle(
    fontSize: 14,
    color: AppColors.textSecondary,
    ),
    ),
    ],
    ),
    ),
    Column(
    children: [
    GestureDetector(
    onTap: () {
    Navigator.push(
    context,
    MaterialPageRoute(
    builder: (context) => ProfileScreen(username: displayName),
    ),
    ).then((_) => _loadUserProfile());
    },
    child: Hero(
    tag: 'profilePicture',
    child: Container(
    height: 56,
    width: 56,
    decoration: BoxDecoration(
    shape: BoxShape.circle,
    border: Border.all(color: AppColors.accentBlue, width: 2),
    boxShadow: [
    BoxShadow(
    color: AppColors.shadowColor.withOpacity(0.1),
    blurRadius: 8,
    offset: const Offset(0, 2),
    ),
    ],
    ),
    child: _isOffline
    ? CircleAvatar(
    backgroundColor: Colors.grey.shade400,
    child: Text(
    _getInitials(displayName),
    style: const TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.bold,
    fontSize: 20,
    ),
    ),
    )
        : _isLoadingProfile
    ? CircleAvatar(
    backgroundColor: Colors.grey.shade200,
    child: Text(
    _getInitials(displayName),
    style: const TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.bold,
    fontSize: 20,
    ),
    ),
    )
        : _profileImageUrl != null && _profileImageUrl!.isNotEmpty
    ? CircleAvatar(
    backgroundColor: Colors.grey.shade200,
    backgroundImage: NetworkImage(_profileImageUrl!),
    )
        : CircleAvatar(
    backgroundColor: AppColors.primaryBlue,
    child: Text(
    _getInitials(displayName),
    style: const TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.bold,
    fontSize: 20,
    ),
    ),
    ),
    ),
    ),
    ),
    if (_isLoadingProfile && !_isOffline)
    const SizedBox(
    width: 56,
    child: LinearProgressIndicator(
    backgroundColor: Colors.grey,
    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
    ),
    ),
    if (_isOffline)
    const Padding(
    padding: EdgeInsets.only(top: 8),
    child: Text(
    'No internet connection.\nPlease check your network.',
    style: TextStyle(
    color: AppColors.errorColor,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    ),
    textAlign: TextAlign.center,
    ),
    ),
    ],
    ),
    ],
    ),
    const SizedBox(height: 28),
    _buildScoreCard(),
    const SizedBox(height: 28),
    Text(
    'Recommended Courses',
    style: Theme.of(context).textTheme.headlineSmall,
    ),
    const SizedBox(height: 16),
    SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    physics: const BouncingScrollPhysics(),
    child: Row(
    children: recommendedCourses
        .map((course) => _buildRecommendedCourseCard(course))
        .toList(),
    ),
    ),
    const SizedBox(height: 28),
    Text(
    'Learning Resources',
    style: Theme.of(context).textTheme.headlineSmall,
    ),
    const SizedBox(height: 16),
    GridView.count(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    crossAxisCount: 3,
    childAspectRatio: 0.85,
    crossAxisSpacing: 16,
    mainAxisSpacing: 16,
    children: [
    _buildGridItem(
    title: 'Courses',
    icon: Icons.school_rounded,
    color: AppColors.gridColor1,
    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CoursesListScreen())),
    ),
    _buildGridItem(
    title: 'C Submission',
    icon: Icons.assignment_turned_in_rounded,
    color: AppColors.gridColor2,
    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CourseForm())),
    ),
    _buildGridItem(
    title: 'Learn',
    icon: Icons.menu_book_rounded,
    color: AppColors.gridColor3,
    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => LearnHomePage())),
    ),
    _buildGridItem(
    title: 'Jobs Upload',
    icon: Icons.work_rounded,
    color: AppColors.gridColor4,
    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const JobsPage())),
    ),
    _buildGridItem(
    title: 'Explore Jobs',
    icon: Icons.search_rounded,
    color: AppColors.gridColor5,
    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ExploreJobsPage())),
    ),
    _buildGridItem(
    title: 'Upload Project',
    icon: Icons.cloud_upload_rounded,
    color: AppColors.gridColor6,
    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => UploadProjectScreen())),
    ),
    _buildGridItem(
    title: 'Mentors',
    icon: Icons.person_pin_rounded,
    color: AppColors.gridColor7,
    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MentorPage())),
    ),
      _buildGridItem(
        title: 'Startup',
        icon: Icons.rocket_launch_rounded,
        color: AppColors.gridColor7,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ExerciseForm())),
      ),
      _buildGridItem(
        title: 'Ask Help',
        icon: Icons.help_outline_rounded,
        color: AppColors.gridColor8,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => FocusLockScreen())),
      ),
      _buildGridItem(
        title: 'Master',
        icon: Icons.psychology_rounded,
        color: AppColors.gridColor9,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => Researchmaster())),
      ),
      _buildGridItem(
        title: 'Leaderboard',
        icon: Icons.leaderboard_rounded,
        color: AppColors.gridColor9,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LeaderboardPage())),
      ),
    ],
    ),
      const SizedBox(height: 80),
    ],
    ),
    ),
    ),
    ),
    ),
          ),
          ),

            // FIXED: Ad StreamBuilder with proper state management
            if (_isMessageBarVisible && !_hasShownAd)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('ads')
                    .orderBy('priority')
                    .limit(1)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox.shrink();
                  }
                  if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    // No ads available, hide the message bar
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && _isMessageBarVisible && !_hasShownAd) {
                        setState(() {
                          _isMessageBarVisible = false;
                          _hasShownAd = true;
                        });
                      }
                    });
                    return const SizedBox.shrink();
                  }

                  final ad = snapshot.data!.docs.first;
                  final adData = {'id': ad.id, ...ad.data() as Map<String, dynamic>};

                  // Only show ad once
                  if (!_hasShownAd && _lastShownAdId != adData['id']) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && _isMessageBarVisible && !_hasShownAd) {
                        _showFullScreenAd(adData, context);
                      }
                    });
                  }

                  return const SizedBox.shrink();
                },
              ),
          ],
      ),
    );
  }
}

// SparklePainter class remains the same
class SparklePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.yellow
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    const radius = 5.0;

    final path = Path();
    const pi = 3.14159;
    for (int i = 0; i < 8; i++) {
      final angle = (i * 45.0) * (pi / 180);
      final length = i % 2 == 0 ? radius : radius / 2;
      final x = center.dx + length * math.cos(angle);
      final y = center.dy + length * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// CreateProfilePage class remains the same
class CreateProfilePage extends StatefulWidget {
  final String FullName;
  const CreateProfilePage({Key? key, required this.FullName}) : super(key: key);

  @override
  State<CreateProfilePage> createState() => _CreateProfilePageState();
}

class _CreateProfilePageState extends State<CreateProfilePage> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.FullName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.gradientStart, AppColors.gradientEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 64,
                    backgroundColor: AppColors.primaryBlue,
                    child: Text(
                      widget.FullName.isNotEmpty ? widget.FullName[0].toUpperCase() : '',
                      style: const TextStyle(
                        fontSize: 48,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadowColor.withOpacity(0.1),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(Icons.camera_alt, color: AppColors.primaryBlue),
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: Icon(Icons.person, color: AppColors.primaryBlue),
                  filled: true,
                  fillColor: AppColors.veryLightBlue,
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: Icon(Icons.email, color: AppColors.primaryBlue),
                  filled: true,
                  fillColor: AppColors.veryLightBlue,
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Bio',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: Icon(Icons.info, color: AppColors.primaryBlue),
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: AppColors.veryLightBlue,
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
                  ),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Skills (comma separated)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: Icon(Icons.psychology, color: AppColors.primaryBlue),
                  filled: true,
                  fillColor: AppColors.veryLightBlue,
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 3,
                    shadowColor: AppColors.shadowColor.withOpacity(0.3),
                  ),
                  child: const Text(
                    'Save Profile',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}