import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';

// Enhanced Color Palette
const Color primaryBlue = Color(0xFF1976D2);
const Color lightBlue = Color(0xFF64B5F6);
const Color veryLightBlue = Color(0xFFE3F2FD);
const Color darkBlue = Color(0xFF0D47A1);
const Color accentBlue = Color(0xFF29B6F6);
const Color shadowColor = Color(0x1A000000);

class TrendingTopic {
  final String numberOfProjects;
  final String title;
  final double trendPercentage;
  final String color;
  final String description;
  final String icon;
  final bool isNew;
  final DateTime timestamp;
  final String views;

  TrendingTopic({
    required this.numberOfProjects,
    required this.title,
    required this.trendPercentage,
    required this.color,
    required this.description,
    required this.icon,
    required this.isNew,
    required this.timestamp,
    required this.views,
  });

  factory TrendingTopic.fromFirestore(Map<String, dynamic> data) {
    return TrendingTopic(
      numberOfProjects: data['numberOfProjects'] ?? '0',
      title: data['title'] ?? '',
      trendPercentage: (data['trendPercentage'] as num?)?.toDouble() ?? 0.0,
      color: data['color'] ?? '#000000',
      description: data['description'] ?? '',
      icon: data['icon'] ?? 'default_icon',
      isNew: data['isNew'] ?? false,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      views: data['views'] ?? '0',
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primaryColor: primaryBlue,
        scaffoldBackgroundColor: Colors.grey.shade100,
        fontFamily: 'Roboto',
        appBarTheme: AppBarTheme(
          backgroundColor: primaryBlue,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        cardTheme: CardTheme(
          elevation: 4,
          shadowColor: shadowColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      home: TrendingPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class TrendingPage extends StatefulWidget {
  @override
  _TrendingPageState createState() => _TrendingPageState();
}

class _TrendingPageState extends State<TrendingPage> with WidgetsBindingObserver {
  final CollectionReference trendingCollection =
  FirebaseFirestore.instance.collection('Trending');

  // App Open Ad related variables
  AppOpenAd? _appOpenAd;
  bool _isShowingAd = false;

  // Banner Ads related variables
  BannerAd? _topBannerAd;
  BannerAd? _bottomBannerAd;
  bool _isTopBannerAdLoaded = false;
  bool _isBottomBannerAdLoaded = false;

  // Ad Unit IDs
  final String testAppOpenAdUnitId = 'ca-app-pub-3940256099942544/3419835294';
  final String prodAppOpenAdUnitId = 'ca-app-pub-9136866657796541/9573475369';
  final String testBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  final String prodBannerAdUnitId = 'ca-app-pub-9136866657796541/3776722778';

  String get _appOpenAdUnitId => kDebugMode ? testAppOpenAdUnitId : prodAppOpenAdUnitId;
  String get _bannerAdUnitId => kDebugMode ? testBannerAdUnitId : prodBannerAdUnitId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAppOpenAd();
    _loadTopBannerAd();
    _loadBottomBannerAd();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _appOpenAd?.dispose();
    _topBannerAd?.dispose();
    _bottomBannerAd?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Show app open ad when app is foregrounded
    if (state == AppLifecycleState.resumed) {
      _showAppOpenAdIfAvailable();
    }
  }

  void _loadAppOpenAd() {
    AppOpenAd.load(
      adUnitId: _appOpenAdUnitId,
      request: AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          print('AppOpenAd loaded successfully');
          _appOpenAd = ad;
          _showAppOpenAdIfAvailable();
        },
        onAdFailedToLoad: (error) {
          print('AppOpenAd failed to load: $error');
          // Handle the error or retry loading after delay
          Future.delayed(Duration(minutes: 1), _loadAppOpenAd);
        },
      ),
    );
  }

  void _loadTopBannerAd() {
    _topBannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      size: AdSize.banner,
      request: AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          print('Top Banner ad loaded successfully!');
          setState(() {
            _isTopBannerAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          print('Top Banner ad failed to load: ${error.message}');
          ad.dispose();
          _topBannerAd = null;

          // Retry loading after a delay
          Future.delayed(Duration(minutes: 1), _loadTopBannerAd);
        },
      ),
    );
    _topBannerAd?.load();
  }

  void _loadBottomBannerAd() {
    _bottomBannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      size: AdSize.banner,
      request: AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          print('Bottom Banner ad loaded successfully!');
          setState(() {
            _isBottomBannerAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          print('Bottom Banner ad failed to load: ${error.message}');
          ad.dispose();
          _bottomBannerAd = null;

          // Retry loading after a delay
          Future.delayed(Duration(minutes: 1), _loadBottomBannerAd);
        },
      ),
    );
    _bottomBannerAd?.load();
  }

  void _showAppOpenAdIfAvailable() {
    if (_appOpenAd == null || _isShowingAd) {
      return;
    }

    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _isShowingAd = true;
        print('AppOpenAd showed full screen content');
      },
      onAdDismissedFullScreenContent: (ad) {
        _isShowingAd = false;
        ad.dispose();
        print('AppOpenAd dismissed - loading new ad');
        _loadAppOpenAd(); // Load a new ad for next time
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _isShowingAd = false;
        ad.dispose();
        print('AppOpenAd failed to show: $error');
        _loadAppOpenAd(); // Load a new ad for next time
      },
    );

    _appOpenAd!.show();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [darkBlue, primaryBlue],
            ),
          ),
        ),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        centerTitle: true,
        title: Text(
          "Trending Now",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22.0,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: Column(
        children: [
          // Top Banner Ad Container
          if (_isTopBannerAdLoaded && _topBannerAd != null)
            Container(
              alignment: Alignment.center,
              width: _topBannerAd!.size.width.toDouble(),
              height: _topBannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _topBannerAd!),
            ),

          // Trending topics list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: trendingCollection.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _buildErrorState(snapshot.error.toString());
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingState();
                }

                final trendingTopics = snapshot.data!.docs
                    .map((doc) => TrendingTopic.fromFirestore(doc.data() as Map<String, dynamic>))
                    .toList();

                if (trendingTopics.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
                  itemCount: trendingTopics.length,
                  itemBuilder: (context, index) {
                    final topic = trendingTopics[index];
                    return _buildTrendingCard(context, topic, index);
                  },
                );
              },
            ),
          ),

          // Bottom Banner Ad Container
          // Bottom Banner Ad Container - Added additional properties to ensure visibility
          if (_isBottomBannerAdLoaded && _bottomBannerAd != null)
            Container(
              alignment: Alignment.center,
              width: MediaQuery.of(context).size.width, // Use full width
              height: 60, // Fixed height that's enough for the banner
              color: Colors.white, // Background color to make it visible
              child: AdWidget(ad: _bottomBannerAd!),
            ),
        ],
      ),
      // No floating action button
    );
  }

  Widget _buildTrendingCard(BuildContext context, TrendingTopic topic, int index) {
    final Color topicColor = Color(int.parse(topic.color.replaceFirst('#', '0xff')));
    final bool isHighTrend = topic.trendPercentage > 15;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          // Navigate to topic detail
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Opening ${topic.title} details'),
              backgroundColor: primaryBlue,
              duration: Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Trending position with gradient background
            Container(
              width: 36,
              height: 36,
              margin: EdgeInsets.only(right: 16, top: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [darkBlue, primaryBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: primaryBlue.withOpacity(0.3),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  "#${index + 1}",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),

            // Content column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row with topic info
                  Row(
                    children: [
                      // Icon in circle
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: topicColor.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getIcon(topic.icon),
                          color: topicColor,
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 10),

                      // Title
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    topic.title,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                SizedBox(width: 6),
                                if (topic.isNew)
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: primaryBlue,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      "NEW",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            Text(
                              _timeAgo(topic.timestamp),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 8),

                  // Description
                  Padding(
                    padding: EdgeInsets.only(left: 38),
                    child: Text(
                      topic.description,
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  SizedBox(height: 10),

                  // Stats row
                  Padding(
                    padding: EdgeInsets.only(left: 38),
                    child: Row(
                      children: [
                        _buildSimpleStat(
                          Icons.trending_up,
                          "${topic.trendPercentage.toStringAsFixed(1)}%",
                          isHighTrend ? Colors.green.shade700 : Colors.orange.shade800,
                        ),
                        SizedBox(width: 16),
                        _buildSimpleStat(
                          Icons.remove_red_eye_outlined,
                          _formatNumber(topic.views),
                          Colors.grey.shade700,
                        ),
                        SizedBox(width: 16),
                        _buildSimpleStat(
                          Icons.folder_outlined,
                          topic.numberOfProjects,
                          Colors.grey.shade700,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 12),

                  // Divider
                  Divider(height: 1, color: Colors.grey.shade300),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleStat(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatNumber(String number) {
    // Format number like Twitter (e.g. 1.5K, 2.3M)
    int num = int.tryParse(number) ?? 0;
    if (num > 999999) {
      return "${(num / 1000000).toStringAsFixed(1)}M";
    } else if (num > 999) {
      return "${(num / 1000).toStringAsFixed(1)}K";
    } else {
      return number;
    }
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 44,
            color: Colors.grey.shade400,
          ),
          SizedBox(height: 16),
          Text(
            "Couldn't load trends",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Text(
              "Try again later",
              style: TextStyle(color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 24),
          GestureDetector(
            onTap: () {},
            child: Text(
              "Refresh",
              style: TextStyle(
                color: primaryBlue,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 30,
            width: 30,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
            ),
          ),
          SizedBox(height: 12),
          Text(
            "Loading trends",
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.tag,
            size: 48,
            color: Colors.grey.shade400,
          ),
          SizedBox(height: 16),
          Text(
            "No trending topics",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Text(
              "When topics become popular, you'll find them here.",
              style: TextStyle(color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIcon(String iconName) {
    switch (iconName) {
      case 'engineering':
        return Icons.engineering;
      case 'code':
        return Icons.code;
      case 'design':
        return Icons.design_services;
      case 'business':
        return Icons.business;
      case 'science':
        return Icons.science;
      case 'education':
        return Icons.school;
      case 'health':
        return Icons.health_and_safety;
      case 'finance':
        return Icons.attach_money;
      default:
        return Icons.trending_up;
    }
  }

  String _timeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 7) {
      return DateFormat('MMM d').format(timestamp);
    } else if (difference.inDays > 0) {
      return "${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago";
    } else if (difference.inHours > 0) {
      return "${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago";
    } else if (difference.inMinutes > 0) {
      return "${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago";
    } else {
      return "Just now";
    }
  }
}