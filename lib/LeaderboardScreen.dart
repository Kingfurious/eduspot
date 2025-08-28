import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ProfileScreen.dart';
import 'ProfileScreen.dart';



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
  static const Color currentUserHighlight = Color(0xFFFFF9C4);
}

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({Key? key}) : super(key: key);

  @override
  _LeaderboardPageState createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  final int pageSize = 20;
  DocumentSnapshot? lastDoc;
  List<DocumentSnapshot> users = [];
  bool isLoading = false;
  bool hasMore = true;

  Future<void> _loadUsers({bool reset = false}) async {
    if (isLoading || !hasMore) return;
    setState(() => isLoading = true);

    if (reset) {
      users.clear();
      lastDoc = null;
      hasMore = true;
    }

    Query query = FirebaseFirestore.instance
        .collection('users')
        .orderBy('innovationScore', descending: true)
        .limit(pageSize);
    if (lastDoc != null) query = query.startAfterDocument(lastDoc!);

    final snapshot = await query.get();
    setState(() {
      users.addAll(snapshot.docs);
      lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      hasMore = snapshot.docs.length == pageSize;
      isLoading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<String?> _getProfileImageUrl(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('studentprofile')
          .doc(userId)
          .get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        return userData['imageUrl'] as String?;
      }
      print('No studentprofile found for userId: $userId');
      return null;
    } catch (e) {
      print('Error fetching profile image for user $userId: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.background, AppColors.veryLightBlue],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadUsers(reset: true);
          },
          color: AppColors.primaryBlue,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollEndNotification &&
                  notification.metrics.extentAfter < 100 &&
                  hasMore &&
                  !isLoading) {
                _loadUsers();
              }
              return false;
            },
            child: users.isEmpty && !isLoading
                ? const Center(
              child: Text(
                'No users found',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: users.length + (hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == users.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                      ),
                    ),
                  );
                }

                final userData = users[index].data() as Map<String, dynamic>;
                final userId = users[index].id;
                final displayName = userData['fullName'] ?? userData['name'] ?? 'Unknown User';
                final innovationScore = userData['innovationScore']?.toString() ?? '0';
                final isCurrentUser = userId == currentUser?.uid;

                return FutureBuilder<String?>(
                  future: _getProfileImageUrl(userId),
                  builder: (context, imageSnapshot) {
                    final imageUrl = imageSnapshot.data ?? '';
                    return _buildLeaderboardCard(
                      context,
                      rank: index + 1,
                      displayName: displayName,
                      innovationScore: innovationScore,
                      imageUrl: imageUrl,
                      isCurrentUser: isCurrentUser,
                      userId: userId,
                      userData: userData,
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboardCard(
      BuildContext context, {
        required int rank,
        required String displayName,
        required String innovationScore,
        required String imageUrl,
        required bool isCurrentUser,
        required String userId,
        required Map<String, dynamic> userData,
      }) {
    final lastActive = userData['lastActive'] is Timestamp
        ? (userData['lastActive'] as Timestamp).toDate()
        : null;
    final isRecentlyActive = lastActive != null && DateTime.now().difference(lastActive).inDays < 7;

    return GestureDetector(
      onTap: () {
        print('Navigating to profile for userId: $userId');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UserProfileDetailsPage(
              userId: userId,
              userData: userData,
            ),
          ),
        );
      },
      child: Card(
        elevation: 3,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isCurrentUser ? const BorderSide(color: AppColors.primaryBlue, width: 2) : BorderSide.none,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isCurrentUser ? AppColors.currentUserHighlight : AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowColor.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(2, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              radius: 30,
              backgroundColor: AppColors.primaryBlue.withOpacity(0.2),
              child: imageUrl.isNotEmpty
                  ? ClipOval(
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                  ),
                  errorWidget: (context, url, error) => Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ),
              )
                  : Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '#$rank',
                    style: const TextStyle(
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      fontStyle: isCurrentUser ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Innovation Score: $innovationScore',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (isRecentlyActive)
                  Text(
                    'Recently Active',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.successColor,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class UserProfileDetailsPage extends StatelessWidget {
  final String userId;
  final Map<String, dynamic> userData;

  const UserProfileDetailsPage({Key? key, required this.userId, required this.userData}) : super(key: key);

  @override
  Widget build(context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Details'),
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.background, AppColors.veryLightBlue],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('studentprofile').doc(userId).get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                ),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error loading profile: ${snapshot.error}',
                  style: TextStyle(
                    color: AppColors.errorColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }

            // Extract basic user data from users collection
            final displayName = userData['fullName'] ?? userData['name'] ?? 'Unknown User';
            final innovationScore = userData['innovationScore']?.toString() ?? '0';
            final email = userData['email'] ?? 'N/A';

            // Initialize profile data variables
            String imageUrl = '';
            String careerGoal = '';
            String collegeName = '';
            String department = '';
            String phoneNumber = '';
            String primarySkill = '';
            String year = '';
            String createdAt = userData['created_at'] is Timestamp
                ? (userData['created_at'] as Timestamp).toDate().toString()
                : '';
            List<String> portfolioLinks = [];

            bool hasProfile = false;
            if (snapshot.hasData && snapshot.data!.exists) {
              hasProfile = true;
              final profileData = snapshot.data!.data() as Map<String, dynamic>;
              imageUrl = profileData['imageUrl'] ?? '';
              careerGoal = profileData['careerGoal'] ?? '';
              collegeName = profileData['collegeName'] ?? '';
              department = profileData['department'] ?? '';
              phoneNumber = profileData['phoneNumber'] ?? '';
              primarySkill = profileData['primarySkill'] ?? '';
              year = profileData['year'] ?? '';
              createdAt = profileData['createdAt'] is Timestamp
                  ? (profileData['createdAt'] as Timestamp).toDate().toString()
                  : createdAt;
              portfolioLinks = List<String>.from(profileData['portfolioLinks'] ?? []);
            } else {
              print('No studentprofile document found for userId: $userId');
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: AppColors.primaryBlue.withOpacity(0.2),
                    child: imageUrl.isNotEmpty
                        ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                        ),
                        errorWidget: (context, url, error) => Text(
                          displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 48,
                          ),
                        ),
                      ),
                    )
                        : Text(
                      displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 48,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    email,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildProfileField('Innovation Score', innovationScore),
                          if (hasProfile) ...[
                            if (careerGoal.isNotEmpty) _buildProfileField('Career Goal', careerGoal),
                            if (collegeName.isNotEmpty) _buildProfileField('College', collegeName),
                            if (department.isNotEmpty) _buildProfileField('Department', department),
                            if (primarySkill.isNotEmpty) _buildProfileField('Primary Skill', primarySkill),
                            if (year.isNotEmpty) _buildProfileField('Year', year),
                            if (phoneNumber.isNotEmpty) _buildProfileField('Phone Number', phoneNumber),
                            if (createdAt.isNotEmpty) _buildProfileField('Joined', createdAt),
                            if (portfolioLinks.isNotEmpty) ...[
                              const Text(
                                'Portfolio Links',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...portfolioLinks.map((link) => _buildPortfolioLink(context, link)),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (!hasProfile)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        'Full details loading is hidden',
                        style: TextStyle(
                          color: AppColors.errorColor,
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProfileScreen(username: userId),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'View Full Profile',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProfileField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolioLink(BuildContext context, String link) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () async {
          final url = Uri.parse(link.startsWith('http') ? link : 'https://$link');
          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Cannot open $link')),
            );
          }
        },
        child: Text(
          link,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.primaryBlue,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}