import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'Researchmaster.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'ResearchmasterTrending.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';


// Enhanced Color Palette
const Color primaryBlue = Color(0xFF1976D2);
const Color lightBlue = Color(0xFF64B5F6);
const Color veryLightBlue = Color(0xFFE3F2FD);
const Color darkBlue = Color(0xFF0D47A1);
const Color accentBlue = Color(0xFF29B6F6);
const Color shadowColor = Color(0x1A000000);

class ResearchTool {
  final String title;
  final IconData icon;
  final Color color;
  final String description;
  final String originalTitle;  // The original service name (for internal reference)

  ResearchTool({
    required this.title,
    required this.icon,
    required this.color,
    required this.description,
    required this.originalTitle,
  });
}

class ToolDetailsPage extends StatefulWidget {
  final ResearchTool tool;

  const ToolDetailsPage({
    Key? key,
    required this.tool,
  }) : super(key: key);

  @override
  State<ToolDetailsPage> createState() => _ToolDetailsPageState();
}

class _ToolDetailsPageState extends State<ToolDetailsPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final detailsController = TextEditingController();
  bool agreedToTerms = false;
  late AnimationController _animationController;
  late ScrollController _scrollController;
  bool _isScrolled = false;

  // Banner Ad related variables
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  // Ad Unit IDs
  final String testBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  final String prodBannerAdUnitId = 'ca-app-pub-9136866657796541/3776722778';

  String get _adUnitId => kDebugMode ? testBannerAdUnitId : prodBannerAdUnitId;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);

    // Initialize the Mobile Ads SDK
    _initGoogleMobileAds();

    // Load a banner ad
    _loadBannerAd();

    // Set system UI overlay style
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
  }

  Future<void> _initGoogleMobileAds() async {
    await MobileAds.instance.initialize();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: _adUnitId,
      size: AdSize.banner,
      request: AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          print('Banner ad loaded successfully!');
          setState(() {
            _isAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          print('Banner ad failed to load: ${error.message}');
          ad.dispose();
          _bannerAd = null;

          // Retry loading after a delay
          Future.delayed(Duration(minutes: 1), _loadBannerAd);
        },
      ),
    );
    _bannerAd?.load();
  }


  void _scrollListener() {
    if (_scrollController.offset > 80 && !_isScrolled) {
      setState(() {
        _isScrolled = true;
      });
    } else if (_scrollController.offset <= 80 && _isScrolled) {
      setState(() {
        _isScrolled = false;
      });
    }
  }


  // Function to save booking to Firestore
  Future<void> _saveBookingToFirestore({
    required String name,
    required String email,
    required String phone,
    required String details,
    required String serviceName,
  }) async {
    try {
      // Generate a reference number for the booking
      final String referenceNumber = 'RM-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}-${Random().nextInt(1000).toString().padLeft(3, '0')}';

      // Get Firestore instance
      final FirebaseFirestore firestore = FirebaseFirestore.instance;

      // Save booking data to 'Researchmasterbookings' collection
      await firestore.collection('Researchmasterbookings').add({
        'name': name,
        'email': email,
        'phone': phone,
        'details': details,
        'serviceName': serviceName,
        'referenceNumber': referenceNumber,
        'status': 'pending',
        'created': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
        'callbackScheduled': false,
      });

      print('Booking saved to Firestore successfully');
    } catch (error) {
      print('Error saving booking to Firestore: $error');
      // You might want to handle the error appropriately, perhaps by showing a different UI
      // or retrying the operation
    }
  }


  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    detailsController.dispose();
    _animationController.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Enhanced App Bar with trending icon
          SliverAppBar(
            expandedHeight: 250.0,
            floating: false,
            pinned: true,
            backgroundColor: _isScrolled ? widget.tool.color : Colors.transparent,
            elevation: _isScrolled ? 4 : 0,
            stretch: true,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _isScrolled ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.tool.title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  shadows: _isScrolled ? [] : [
                    Shadow(
                      blurRadius: 10.0,
                      color: Colors.black.withOpacity(0.5),
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              stretchModes: const [
                StretchMode.zoomBackground,
                StretchMode.blurBackground,
              ],
              background: Hero(
                tag: 'tool_${widget.tool.title}',
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Enhanced background with animated gradient
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                          colors: [
                            widget.tool.color,
                            widget.tool.color.withOpacity(0.7),
                            widget.tool.color.withOpacity(0.5),
                          ],
                        ),
                      ),
                    ),
                    // Animated pattern overlay
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.06, end: 0.10),
                      duration: const Duration(seconds: 5),
                      curve: Curves.easeInOut,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Image.network(
                            '/api/placeholder/800/600',
                            fit: BoxFit.cover,
                          ),
                        );
                      },
                    ),
                    // Enhanced gradient overlay with depth
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.4),
                          ],
                          stops: const [0.6, 1.0],
                        ),
                      ),
                    ),
                    // Stylish background particles (simulated with containers)
                    ...List.generate(10, (index) {
                      final random = index * 0.1;
                      return Positioned(
                        top: 50 + (index * 20 * random),
                        right: 30 + (index * 25 * (1 - random)),
                        child: Opacity(
                          opacity: 0.1 + (random * 0.1),
                          child: Container(
                            height: 10 + (random * 15),
                            width: 10 + (random * 15),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      );
                    }),
                    // Content with enhanced styling
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Spacer(),
                          // Glowing effect for the icon
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.1),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Icon(
                              widget.tool.icon,
                              size: 60,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Enhanced description container with animation
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0.8, end: 1.0),
                            duration: const Duration(seconds: 2),
                            curve: Curves.easeInOut,
                            builder: (context, value, child) {
                              return Transform.scale(
                                scale: value,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 10
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    widget.tool.description,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.3,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              );
                            },
                          ),
                          const Spacer(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              // Trending Topics Navigation Button with badge
              Stack(
                children: [
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _isScrolled
                            ? Colors.white.withOpacity(0.2)
                            : Colors.white.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.trending_up_rounded),
                    ),
                    tooltip: 'Trending Topics',
                    onPressed: () {
                      // Navigate to Trending Topics page
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => TrendingPage(),
                        ),
                      );
                    },
                  ),
                  // Notification badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 1.5,
                        ),
                      ),
                      child: const Text(
                        '!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
            ],  // Closing bracket for actions array
          ),  // Closing bracket for SliverAppBar

// Content section continues here
// Next part of your CustomScrollView slivers array would go here

    // Content
    SliverToBoxAdapter(
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    // Quick stats cards with animations
    Padding(
    padding: const EdgeInsets.all(16.0),
    child: Row(
    children: [
    _buildStatCard('Success Rate', '98%', Icons.thumb_up_outlined)
        .animate().fadeIn(delay: 100.ms, duration: 400.ms).moveY(begin: 20, end: 0),
    const SizedBox(width: 16),
    _buildStatCard('Clients', '200+', Icons.people_outline)
        .animate().fadeIn(delay: 200.ms, duration: 400.ms).moveY(begin: 20, end: 0),
    const SizedBox(width: 16),
    _buildStatCard('Avg. Rating', '4.9/5', Icons.star_outline)
        .animate().fadeIn(delay: 300.ms, duration: 400.ms).moveY(begin: 20, end: 0),
    ],
    ),
    ),

    // About this service
    _buildInfoCard(
    title: 'About This Service',
    icon: Icons.info_outline,
    child: _buildAboutService(widget.tool.originalTitle),
    ).animate().fadeIn(delay: 400.ms, duration: 400.ms).moveY(begin: 20, end: 0),

    // Our guidelines
    _buildInfoCard(
    title: 'Our Guidelines',
    icon: Icons.verified_outlined,
    child: _buildGuidelines(widget.tool.originalTitle),
    ).animate().fadeIn(delay: 500.ms, duration: 400.ms).moveY(begin: 20, end: 0),



    // Book a call form
    Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
    decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
    BoxShadow(
    color: shadowColor,
    blurRadius: 15,
    offset: const Offset(0, 5),
    ),
    ],
    ),
    child: Form(
    key: _formKey,
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    // Form header with gradient
    Container(
    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
    decoration: BoxDecoration(
    gradient: LinearGradient(
    colors: [primaryBlue, accentBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    ),
    borderRadius: const BorderRadius.only(
    topLeft: Radius.circular(20),
    topRight: Radius.circular(20),
    ),
    ),
    child: Row(
    children: [
    Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
    color: Colors.white.withOpacity(0.2),
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
    BoxShadow(
    color: Colors.black.withOpacity(0.1),
    blurRadius: 5,
    offset: const Offset(0, 2),
    ),
    ],
    ),
    child: const Icon(
    Icons.phone_callback_outlined,
    color: Colors.white,
    size: 30,
    ),
    ),
    const SizedBox(width: 16),
    Expanded(
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    const Text(
    'Book a Free Consultation Call',
    style: TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    ),
    ),
    const SizedBox(height: 6),
    Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
    color: Colors.white.withOpacity(0.2),
    borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
    const Icon(
    Icons.access_time_filled,
    color: Colors.white,
    size: 14,
    ),
    const SizedBox(width: 4),
    Text(
    'Response within 24 hours',
    style: TextStyle(
    color: Colors.white.withOpacity(0.9),
    fontSize: 12,
    fontWeight: FontWeight.w500,
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

    // Form fields
    Padding(
    padding: const EdgeInsets.all(20.0),
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    // Name field
    _buildFormField(
    controller: nameController,
    icon: Icons.person_outline,
    label: 'Full Name',
    validator: (value) {
    if (value == null || value.isEmpty) {
    return 'Please enter your name';
    }
    return null;
    },
    ),
    const SizedBox(height: 20),

    // Email field
    _buildFormField(
    controller: emailController,
    icon: Icons.email_outlined,
    label: 'Email Address',
    keyboardType: TextInputType.emailAddress,
    validator: (value) {
    if (value == null || value.isEmpty) {
    return 'Please enter your email';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Please enter a valid email';
    }
    return null;
    },
    ),
      const SizedBox(height: 20),

      // Phone field
      _buildFormField(
        controller: phoneController,
        icon: Icons.phone_outlined,
        label: 'Phone Number',
        keyboardType: TextInputType.phone,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter your phone number';
          }
          return null;
        },
      ),
      const SizedBox(height: 20),

      // Project details field with animated expansion
      _buildFormField(
        controller: detailsController,
        icon: Icons.description_outlined,
        label: 'Project Details',
        maxLines: 4,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please provide some details';
          }
          return null;
        },
      ),
      const SizedBox(height: 24),

      // Terms checkbox with enhanced styling
      Theme(
        data: Theme.of(context).copyWith(
          checkboxTheme: CheckboxThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            fillColor: MaterialStateProperty.resolveWith<Color>((states) {
              if (states.contains(MaterialState.selected)) {
                return primaryBlue;
              }
              return Colors.white;
            }),
            side: const BorderSide(width: 1.5, color: Colors.grey),
          ),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: agreedToTerms ? veryLightBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: agreedToTerms ? primaryBlue.withOpacity(0.5) : Colors.grey.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: CheckboxListTile(
            title: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                children: [
                  const TextSpan(text: 'I agree to the '),
                  TextSpan(
                    text: 'terms and conditions',
                    style: TextStyle(
                      color: primaryBlue,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
            value: agreedToTerms,
            onChanged: (value) {
              setState(() {
                agreedToTerms = value ?? false;
              });
            },
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
          ),
        ),
      ),
      const SizedBox(height: 32),

      // Submit button with animation
      TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 800),
        builder: (context, value, child) {
          return Transform.scale(
            scale: 0.9 + (0.1 * value),
            child: Opacity(
              opacity: value,
              child: SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate() && agreedToTerms) {
                      _showBookingConfirmation(context);
                    } else if (!agreedToTerms) {
                      _showSnackBar(
                        context: context,
                        message: 'Please agree to the terms and conditions',
                        isError: true,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: primaryBlue.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Book Your Call',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ],
    ),
    ),
    ],
    ),
    ),
    ).animate().fadeIn(delay: 700.ms, duration: 500.ms).slideY(begin: 0.2, end: 0),
    ],
    ),
    ),
    ],
        ),
      // Floating action button to scroll to the booking form
      floatingActionButton: AnimatedOpacity(
        opacity: _isScrolled ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: FloatingActionButton.extended(
          onPressed: () {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOut,
            );
          },
          backgroundColor: primaryBlue,
          label: const Text('Book Now'),
          icon: const Icon(Icons.calendar_today_outlined),
        ),
      ),
    );
  }

  // Enhanced card builder with shadow and border
  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: Colors.grey.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header with gradient
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryBlue.withOpacity(0.05),
                  veryLightBlue.withOpacity(0.2),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: primaryBlue, size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: darkBlue,
                  ),
                ),
              ],
            ),
          ),
          // Card content
          Padding(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        decoration: BoxDecoration(
          color: veryLightBlue,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: shadowColor.withOpacity(0.5),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(
            color: primaryBlue.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: primaryBlue, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: darkBlue,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required IconData icon,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    required String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Container(
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: veryLightBlue,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              bottomLeft: Radius.circular(12),
              topRight: Radius.circular(0),
              bottomRight: Radius.circular(0),
            ),
          ),
          child: Icon(icon, color: primaryBlue, size: 22),
        ),
        labelStyle: TextStyle(color: Colors.grey.shade600),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade300, width: 1.5),
        ),
        filled: true,
        fillColor: Colors.grey.withOpacity(0.05),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      style: const TextStyle(fontSize: 16),
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      cursorColor: primaryBlue,
    );
  }


  Widget _buildAboutService(String originalTitle) {
    // Customize this based on each service with better styling
    switch (originalTitle) {
      case 'Patent Writing':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text(
                'Patent Documentation Support',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: darkBlue,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildFeatureItem(
                'Structure your patent professionally with a clear, comprehensive framework'),
            _buildFeatureItem(
                'Develop detailed technical descriptions using industry-specific terminology'),
            _buildFeatureItem(
                'Create professional diagrams and illustrations that explain technical aspects'),
            _buildFeatureItem(
                'Meet international patent filing standards and requirements'),
            _buildFeatureItem(
                'Receive guidance from experienced patent documentation specialists'),
          ],
        );
      case 'SCI Paper Writing':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text(
                'Scientific Manuscript Development',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: darkBlue,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildFeatureItem(
                'Conduct comprehensive literature reviews to support your research'),
            _buildFeatureItem(
                'Structure your paper according to SCI journal standards with proper sections'),
            _buildFeatureItem(
                'Ensure technical accuracy with precise data analysis and methodology'),
            _buildFeatureItem(
                'Enhance readability and clarity through professional scientific editing'),
            _buildFeatureItem(
                'Optimize for high impact factor journals by refining research presentation'),
          ],
        );
      case 'Thesis Writing':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text(
                'Academic Document Development',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: darkBlue,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildFeatureItem(
                'Structure your research into a comprehensive academic document'),
            _buildFeatureItem(
                'Develop detailed literature reviews highlighting relevant research'),
            _buildFeatureItem(
                'Present your methodology with proper academic rigor and clarity'),
            _buildFeatureItem(
                'Analyze findings with appropriate depth and scholarly context'),
            _buildFeatureItem(
                'Format according to specific institutional requirements and standards'),
          ],
        );
      case 'Book Chapter Writing':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text(
                'Comprehensive Book Chapter Development',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: darkBlue,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildFeatureItem('We will provide book chapter for you'),
            _buildFeatureItem(
                'Develop detailed literature reviews highlighting relevant research'),
            _buildFeatureItem(
                'Present your methodology with proper academic rigor and clarity'),
            _buildFeatureItem(
                'Analyze findings with appropriate depth and scholarly context'),
            _buildFeatureItem(
                'Format according to specific institutional requirements and standards'),
          ],
        );
      case 'Business Pitch Making':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text(
                'Effective Business Pitch Creation',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: darkBlue,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildFeatureItem(
                'Develop a compelling and structured pitch to showcase your business idea effectively'),
            _buildFeatureItem(
                'Highlight key aspects such as problem statement, solution, market potential, and revenue model'),
            _buildFeatureItem(
                'Create engaging presentation slides with visually appealing graphics and concise content'),
            _buildFeatureItem(
                'Refine your pitch with storytelling techniques to capture investor interest'),
            _buildFeatureItem(
                'Ensure clarity, confidence, and persuasion for successful business communication'),
          ],
        );
      case 'Project Report Making':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text(
                'Professional Project Report Documentation',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: darkBlue,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildFeatureItem(
                'Structure your project report with a clear introduction, objectives, methodology, and conclusion'),
            _buildFeatureItem(
                'Provide detailed documentation of research, data collection, and findings'),
            _buildFeatureItem(
                'Ensure clarity and coherence with proper formatting and citations'),
            _buildFeatureItem(
                'Incorporate tables, graphs, and images to enhance report presentation'),
            _buildFeatureItem(
                'Meet academic or industrial standards for professional project reporting'),
          ],
        );
      case 'Project Video Making':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text(
                'Engaging Project Video Production',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: darkBlue,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildFeatureItem(
                'Create engaging and high-quality video presentations to showcase project ideas'),
            _buildFeatureItem(
                'Use visuals, animations, and voice overs to explain project concepts effectively'),
            _buildFeatureItem(
                'Structure the video with an introduction, problem statement, solution, and impact'),
            _buildFeatureItem(
                'Optimize the video with proper editing, transitions, and background music'),
            _buildFeatureItem(
                'Ensure clarity, professionalism, and storytelling for better audience engagement'),
          ],
        );

      case 'BE Projects Making':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text(
                'Entire BE Project Pack',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: darkBlue,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildFeatureItem(
                'Create engaging and high-quality video presentations to showcase project ideas'),
            _buildFeatureItem(
                'Use visuals, animations, and voice overs to explain project concepts effectively'),
            _buildFeatureItem(
                'Structure the video with an introduction, problem statement, solution, and impact'),
            _buildFeatureItem(
                'Optimize the video with proper editing, transitions, and background music'),
            _buildFeatureItem(
                'Ensure clarity, professionalism, and storytelling for better audience engagement'),
          ],
        );
      case 'ME Projects Making':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text(
                'Entire BE Project Pack',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: darkBlue,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildFeatureItem(
                'Create engaging and high-quality video presentations to showcase project ideas'),
            _buildFeatureItem(
                'Use visuals, animations, and voice overs to explain project concepts effectively'),
            _buildFeatureItem(
                'Structure the video with an introduction, problem statement, solution, and impact'),
            _buildFeatureItem(
                'Optimize the video with proper editing, transitions, and background music'),
            _buildFeatureItem(
                'Ensure clarity, professionalism, and storytelling for better audience engagement'),
          ],
        );
      case 'ML Coding':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text(
                'Entire BE Project Pack',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: darkBlue,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildFeatureItem(
                'Create engaging and high-quality video presentations to showcase project ideas'),
            _buildFeatureItem(
                'Use visuals, animations, and voice overs to explain project concepts effectively'),
            _buildFeatureItem(
                'Structure the video with an introduction, problem statement, solution, and impact'),
            _buildFeatureItem(
                'Optimize the video with proper editing, transitions, and background music'),
            _buildFeatureItem(
                'Ensure clarity, professionalism, and storytelling for better audience engagement'),
          ],
        );



      case 'Plagiarism Reduction':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text(
                'Advanced Plagiarism Reduction Techniques',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: darkBlue,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildFeatureItem(
                'Rephrase and rewrite content while maintaining original meaning'),
            _buildFeatureItem(
                'Use proper citations and references to avoid plagiarism issues'),
            _buildFeatureItem(
                'Implement advanced paraphrasing techniques to enhance originality'),
            _buildFeatureItem(
                'Improve sentence structure and word choice for better readability'),
            _buildFeatureItem(
                'Ensure compliance with plagiarism-checking tools and academic integrity standards'),
          ],
        );

    // Add more cases for other services
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text(
                'Professional Research Support',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: darkBlue,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildFeatureItem(
                'Structure your content professionally with expert guidance'),
            _buildFeatureItem(
                'Ensure adherence to industry standards and best practices'),
            _buildFeatureItem(
                'Enhance quality and clarity through collaborative refinement'),
            _buildFeatureItem(
                'Meet deadlines with efficient project management and support'),
            _buildFeatureItem(
                'Receive personalized feedback from subject matter experts'),
          ],
        );
    }
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            height: 20,
            width: 20,
            decoration: BoxDecoration(
              color: primaryBlue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                Icons.check,
                size: 12,
                color: primaryBlue,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade800,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidelines(String originalTitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGuidelineItem(
          'Collaborative Support',
          'We provide expert guidance while you maintain your involvement',
          Icons.handshake_outlined,
        ),
        _buildGuidelineItem(
          'Full Content Ownership',
          'You retain 100% ownership of all intellectual property',
          Icons.copyright_outlined,
        ),
        _buildGuidelineItem(
          'Academic Integrity',
          'Our support aligns with educational and research standards',
          Icons.school_outlined,
        ),
        _buildGuidelineItem(
          'Complete Confidentiality',
          'Your data and research details are protected by strict privacy protocols',
          Icons.security_outlined,
        ),
        _buildGuidelineItem(
          'Iterative Feedback Process',
          'We work with you through multiple rounds of refinement',
          Icons.refresh_outlined,
        ),
      ],
    );
  }

  Widget _buildGuidelineItem(String title, String subtitle, IconData iconData) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              iconData,
              color: primaryBlue,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  void _showSnackBar({
    required BuildContext context,
    required String message,
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'DISMISS',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  void _showBookingConfirmation(BuildContext context) async {
    // First save the booking data to Firestore
    await _saveBookingToFirestore(
      name: nameController.text,
      email: emailController.text,
      phone: phoneController.text,
      details: detailsController.text,
      serviceName: widget.tool.originalTitle,
    );

    // Then show the confirmation dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: SingleChildScrollView(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Animated success icon
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 800),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.check_circle,
                          color: Colors.green.shade600,
                          size: 60,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Confirmation title
                Center(
                  child: Text(
                    'Booking Confirmed!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: darkBlue,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),

                // Confirmation message
                Text(
                  'Thank you for booking a consultation call. Our expert will contact you soon.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),

                // Booking details card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: veryLightBlue,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: shadowColor,
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: primaryBlue.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Details title
                      Text(
                        'Booking Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: darkBlue,
                        ),
                      ),
                      const Divider(height: 20),

                      // User details
                      _buildDetailRow(Icons.person, 'Name', nameController.text),
                      const SizedBox(height: 10),
                      _buildDetailRow(Icons.email, 'Email', emailController.text),
                      const SizedBox(height: 10),
                      _buildDetailRow(Icons.phone, 'Phone', phoneController.text),
                      const SizedBox(height: 10),

                      // Callback timing
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 18,
                            color: primaryBlue,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Callback Time:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: primaryBlue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'Within 24 hours',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: primaryBlue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Processing indicator
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: primaryBlue.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.sync,
                              color: primaryBlue,
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Processing your request',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Animated progress indicator
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: 1),
                        duration: const Duration(seconds: 2),
                        builder: (context, value, child) {
                          return Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: FractionallySizedBox(
                              widthFactor: value,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [primaryBlue, accentBlue],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Close button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shadowColor: primaryBlue.withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: primaryBlue,
        ),
        const SizedBox(width: 12),
        Text(
          '$label:',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: darkBlue,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

}

// Extension method for smooth scrolling
extension ScrollExtension on ScrollController {
  Future<void> animateToSmoothly(
      double offset, {
        Duration duration = const Duration(milliseconds: 500),
        Curve curve = Curves.easeInOut,
      }) async {
    await animateTo(
      offset.clamp(0.0, position.maxScrollExtent),
      duration: duration,
      curve: curve,
    );
  }
}