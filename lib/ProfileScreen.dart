import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

// Import the new settings screen
import 'profile_settings_screen.dart';
// Import other necessary screens/utils
// Potentially needed if saved posts link to comments
import 'chat_screen.dart'; // Add this import for ChatScreen
import 'package:eduspark/ProfileScreen.dart'; // For navigating from saved posts

// App color palette
class AppColors {
  static const Color primaryBlue = Color(0xFF1976D2);
  static const Color lightBlue = Color(0xFF64B5F6);
  static const Color veryLightBlue = Color(0xFFE3F2FD);
  static const Color darkBlue = Color(0xFF0D47A1);
  static const Color accentBlue = Color(0xFF29B6F6);

  // Additional colors
  static const Color textPrimary = Color(0xFF263238);
  static const Color textSecondary = Color(0xFF607D8B);
  static const Color background = Color(0xFFF5F7FA);
  static const Color cardBackground = Colors.white;
  static const Color shadowColor = Color(0xFF000000);
  static const Color errorColor = Color(0xFFD32F2F);
  static const Color successColor = Color(0xFF388E3C);
}

class ProfileScreen extends StatefulWidget {
  final String username;
  final String? userId;
  final bool isCurrentUser;

  const ProfileScreen({
    Key? key,
    required this.username,
    this.userId,
    this.isCurrentUser = true,
  }) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic>? _profileData;
  String? _currentUserId;
  String? _viewedUserId;
  late TabController _tabController;

  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);

    _currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (_currentUserId == null) {
      print("Error: No user logged in.");
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    _viewedUserId = widget.isCurrentUser ? _currentUserId : widget.userId;

    if (_viewedUserId == null) {
      print("Error: No user ID to view profile.");
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    await _loadProfileData(_viewedUserId!);

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadProfileData(String userId) async {
    try {
      // Get current user data for fallback
      User? currentUser = FirebaseAuth.instance.currentUser;
      String initialName = widget.username;
      String? initialEmail =
          widget.isCurrentUser ? currentUser?.email : 'Not specified';
      String? initialPhotoURL =
          widget.isCurrentUser ? currentUser?.photoURL : null;

      // Set initial profile data with Firebase Auth fallback
      Map<String, dynamic> initialProfileData = {
        'fullName': initialName,
        'email': initialEmail ?? 'Not specified',
        'bio': 'Innovation Enthusiast',
        'imageUrl': initialPhotoURL,
        'phoneNumber': 'Not specified',
        'collegeName': 'Not specified',
        'department': 'Not specified',
        'year': 'Not specified',
        'primarySkill': 'Not specified',
        'careerGoal': 'Not specified',
        'portfolioLinks': [],
        'skills': [],
        'hasChangedName': false,
        'coverImageUrl': null,
      };

      if (mounted) {
        setState(() {
          _profileData = initialProfileData;
        });
      }

      // Try to load from studentprofile collection first
      final DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('studentprofile')
          .doc(userId)
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        print("✅ Profile loaded from studentprofile: ${data['fullName']}");

        if (!mounted) return;

        setState(() {
          _profileData = {
            'fullName': data['fullName'] ?? data['name'] ?? initialName,
            'email': data['email'] ?? initialEmail ?? 'Not specified',
            'bio': data['bio'] ?? 'Innovation Enthusiast',
            'imageUrl':
                data['imageUrl'] ?? data['profileImageUrl'] ?? initialPhotoURL,
            'phoneNumber': data['phoneNumber'] ?? 'Not specified',
            'collegeName':
                data['collegeName'] ?? data['college'] ?? 'Not specified',
            'department': data['department'] ?? 'Not specified',
            'year': data['year'] ?? 'Not specified',
            'primarySkill': data['primarySkill'] ?? 'Not specified',
            'careerGoal': data['careerGoal'] ?? 'Not specified',
            'portfolioLinks': data['portfolioLinks'] ?? [],
            'skills': data['skills'] ?? [],
            'hasChangedName': data['hasChangedName'] ?? false,
            'coverImageUrl': data['coverImageUrl'],
          };
        });
      } else {
        print(
            '⚠️ Profile document not found in studentprofile for userId: $userId');
        // Try to load from users collection as fallback
        try {
          final DocumentSnapshot userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();

          if (userDoc.exists && mounted) {
            Map<String, dynamic> userData =
                userDoc.data() as Map<String, dynamic>;
            print("📄 Found fallback data in users collection");

            setState(() {
              if (_profileData != null) {
                // Update with users collection data
                if (userData['fullName'] != null)
                  _profileData!['fullName'] = userData['fullName'];
                else if (userData['displayName'] != null)
                  _profileData!['fullName'] = userData['displayName'];
                else if (userData['name'] != null)
                  _profileData!['fullName'] = userData['name'];

                if (userData['photoURL'] != null)
                  _profileData!['imageUrl'] = userData['photoURL'];
                else if (userData['imageUrl'] != null)
                  _profileData!['imageUrl'] = userData['imageUrl'];
                else if (userData['profilePic'] != null)
                  _profileData!['imageUrl'] = userData['profilePic'];

                if (userData['bio'] != null)
                  _profileData!['bio'] = userData['bio'];
                if (userData['phoneNumber'] != null)
                  _profileData!['phoneNumber'] = userData['phoneNumber'];
                if (userData['college'] != null)
                  _profileData!['collegeName'] = userData['college'];
                if (userData['collegeName'] != null)
                  _profileData!['collegeName'] = userData['collegeName'];
                if (userData['department'] != null)
                  _profileData!['department'] = userData['department'];
                if (userData['year'] != null)
                  _profileData!['year'] = userData['year'];
                if (userData['email'] != null)
                  _profileData!['email'] = userData['email'];
              }
            });
          }
        } catch (e) {
          print('❌ Error checking users collection: $e');
        }
      }

      // Ensure profile data exists in studentprofile collection for current user
      if (widget.isCurrentUser && _profileData != null) {
        await _ensureProfileDataExists();
      }
    } catch (e) {
      print('❌ Error fetching profile for $userId: $e');
      if (mounted) {
        setState(() {
          _profileData = {
            'fullName': widget.username,
            'email': widget.isCurrentUser
                ? (FirebaseAuth.instance.currentUser?.email ??
                    'Error loading profile')
                : 'Not specified',
            'bio': 'Could not load details.',
            'imageUrl': null,
            'phoneNumber': 'Not specified',
            'collegeName': 'Not specified',
            'department': 'Not specified',
            'year': 'Not specified',
            'primarySkill': 'Not specified',
            'careerGoal': 'Not specified',
            'portfolioLinks': [],
            'skills': [],
            'hasChangedName': false,
            'coverImageUrl': null,
          };
        });
      }
    }
  }

  Future<void> _ensureProfileDataExists() async {
    if (_currentUserId == null || _profileData == null) return;

    try {
      Map<String, dynamic> dataToSave = Map.from(_profileData!);
      dataToSave['uid'] = _currentUserId;
      dataToSave['updatedAt'] = FieldValue.serverTimestamp();

      if (dataToSave.containsKey('fullName') &&
          dataToSave['fullName'] != null) {
        await FirebaseFirestore.instance
            .collection('studentprofile')
            .doc(_currentUserId)
            .set(dataToSave, SetOptions(merge: true));

        User? user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          if (user.displayName != _profileData!['fullName']) {
            await user.updateDisplayName(_profileData!['fullName']);
          }

          if (user.photoURL != _profileData!['imageUrl'] &&
              _profileData!['imageUrl'] != null) {
            await user.updatePhotoURL(_profileData!['imageUrl']);
          }
        }
        print("✅ Profile data ensured in studentprofile collection");
      }
    } catch (e) {
      print('❌ Error ensuring profile data exists: $e');
    }
  }

  Future<void> _selectProfilePicture() async {
    if (_currentUserId == null) {
      _showCustomSnackBar('You need to be logged in to change profile picture',
          isError: true);
      return;
    }

    final ImagePicker _picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowColor.withOpacity(0.1),
                blurRadius: 10,
                offset: Offset(0, -5),
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Change Profile Picture',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildImageSourceOption(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onTap: () async {
                      Navigator.of(context).pop();
                      await _getAndUploadImage(ImageSource.gallery);
                    },
                  ),
                  _buildImageSourceOption(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    onTap: () async {
                      Navigator.of(context).pop();
                      await _getAndUploadImage(ImageSource.camera);
                    },
                  ),
                ],
              ),
              SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Future<void> _selectAndUploadCoverPicture() async {
    if (_currentUserId == null) {
      _showCustomSnackBar('You need to be logged in to change cover picture',
          isError: true);
      return;
    }

    final ImagePicker _picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowColor.withOpacity(0.1),
                blurRadius: 10,
                offset: Offset(0, -5),
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Change Cover Picture',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildImageSourceOption(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onTap: () async {
                      Navigator.of(context).pop();
                      await _getAndUploadCoverImage(ImageSource.gallery);
                    },
                  ),
                  _buildImageSourceOption(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    onTap: () async {
                      Navigator.of(context).pop();
                      await _getAndUploadCoverImage(ImageSource.camera);
                    },
                  ),
                ],
              ),
              SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.veryLightBlue,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: AppColors.primaryBlue,
                size: 30,
              ),
            ),
            SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _getAndUploadImage(ImageSource source) async {
    try {
      setState(() => _isLoading = true);
      final XFile? pickedFile = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );

      if (pickedFile == null) {
        setState(() => _isLoading = false);
        return;
      }

      final File imageFile = File(pickedFile.path);
      final String fileName =
          'profile_${_currentUserId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef =
          FirebaseStorage.instance.ref().child('profile_pictures/$fileName');
      final UploadTask uploadTask = storageRef.putFile(imageFile);

      final TaskSnapshot taskSnapshot = await uploadTask;
      final String downloadUrl = await taskSnapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('studentprofile')
          .doc(_currentUserId)
          .update({
        'imageUrl': downloadUrl,
      });

      if (mounted) {
        setState(() {
          if (_profileData != null) {
            _profileData!['imageUrl'] = downloadUrl;
          }
          _isLoading = false;
        });
        _showCustomSnackBar('Profile picture updated successfully');
      }
    } catch (e) {
      print('Error uploading profile picture: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showCustomSnackBar('Error updating profile picture: $e',
            isError: true);
      }
    }
  }

  Future<void> _getAndUploadCoverImage(ImageSource source) async {
    try {
      setState(() => _isLoading = true);
      final XFile? pickedFile = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );

      if (pickedFile == null) {
        setState(() => _isLoading = false);
        return;
      }

      final File imageFile = File(pickedFile.path);
      final String fileName =
          'cover_${_currentUserId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef =
          FirebaseStorage.instance.ref().child('cover_pictures/$fileName');
      final UploadTask uploadTask = storageRef.putFile(imageFile);

      final TaskSnapshot taskSnapshot = await uploadTask;
      final String downloadUrl = await taskSnapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('studentprofile')
          .doc(_currentUserId)
          .update({
        'coverImageUrl': downloadUrl,
      });

      if (mounted) {
        setState(() {
          if (_profileData != null) {
            _profileData!['coverImageUrl'] = downloadUrl;
          }
          _isLoading = false;
        });
        _showCustomSnackBar('Cover picture updated successfully');
      }
    } catch (e) {
      print('Error uploading cover picture: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showCustomSnackBar('Error updating cover picture: $e', isError: true);
      }
    }
  }

  void _showCustomSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 24,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        duration: Duration(seconds: 3),
        backgroundColor: isError ? AppColors.errorColor : AppColors.primaryBlue,
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, double? height}) {
    return Container(
      height: height,
      margin: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.8),
            Colors.white.withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 0,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: child,
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    String? coverImageUrl = _profileData?['coverImageUrl'];

    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: AppColors.primaryBlue,
      leading: IconButton(
        icon: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.arrow_back, color: Colors.white, size: 20),
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        if (widget.isCurrentUser)
          IconButton(
            icon: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.refresh, color: Colors.white, size: 20),
            ),
            onPressed: _initializeData,
          ),
        IconButton(
          icon: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.isCurrentUser ? Icons.settings : Icons.more_vert,
              color: Colors.white,
              size: 20,
            ),
          ),
          onPressed: () {
            if (widget.isCurrentUser) {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const ProfileSettingsScreen()),
              );
            } else {
              _showUserOptions();
            }
          },
        ),
        SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Base cover image layer with GestureDetector
            GestureDetector(
              onTap: () {
                if (coverImageUrl != null && coverImageUrl.isNotEmpty) {
                  _showFullCoverImage(coverImageUrl);
                }
              },
              child: coverImageUrl != null && coverImageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: coverImageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          Container(color: Colors.grey[300]),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[300],
                        child: Icon(Icons.error, color: AppColors.errorColor),
                      ),
                    )
                  : Container(
                      color: Colors.grey[300],
                      child: Center(
                        child: Text(
                          'Add Cover Picture',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
            ),
            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.darkBlue.withOpacity(0.7),
                    AppColors.primaryBlue.withOpacity(0.3),
                  ],
                ),
              ),
            ),
            // Wave painter at the bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: CustomPaint(
                size: Size(MediaQuery.of(context).size.width, 40),
                painter: WavePainter(),
              ),
            ),
            // Camera icon for changing cover picture (for current user)
            if (widget.isCurrentUser)
              Positioned(
                bottom: 16,
                right: 16,
                child: GestureDetector(
                  onTap: _selectAndUploadCoverPicture,
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accentBlue,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadowColor.withOpacity(0.2),
                          blurRadius: 5,
                          spreadRadius: 0,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showFullCoverImage(String coverImageUrl) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: EdgeInsets.all(20),
          backgroundColor: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.topRight,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: coverImageUrl,
                      placeholder: (context, url) => Container(
                        color: Colors.black12,
                        child: Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primaryBlue),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.black12,
                        child: Center(
                          child: Icon(Icons.error, color: AppColors.errorColor),
                        ),
                      ),
                      imageBuilder: (context, imageProvider) => Container(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.7,
                          maxWidth: MediaQuery.of(context).size.width * 0.9,
                        ),
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: imageProvider,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileAvatar() {
    String? imageUrl = _profileData!['imageUrl'];

    return GestureDetector(
      onTap: () {
        if (imageUrl != null && imageUrl.isNotEmpty) {
          _showFullProfileImage(imageUrl);
        }
      },
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            height: 120,
            width: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowColor.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            padding: EdgeInsets.all(4),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.veryLightBlue,
                image: (imageUrl != null && imageUrl.isNotEmpty)
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(imageUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: (imageUrl == null || imageUrl.isEmpty)
                  ? Center(
                      child: Text(
                        _getInitials(),
                        style: TextStyle(
                          fontSize: 40,
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
          if (widget.isCurrentUser)
            Positioned(
              bottom: 0,
              right: 0,
              child: InkWell(
                onTap: _selectProfilePicture,
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accentBlue,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadowColor.withOpacity(0.2),
                        blurRadius: 5,
                        spreadRadius: 0,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
        ],
      )
          .animate()
          .fadeIn(duration: 500.ms)
          .scale(delay: 200.ms, begin: Offset(0.8, 0.8)),
    );
  }

  void _showFullProfileImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: EdgeInsets.all(20),
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.topRight,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    placeholder: (context, url) => Container(
                      color: Colors.black12,
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.primaryBlue),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.black12,
                      child: Center(
                        child: Icon(Icons.error, color: AppColors.errorColor),
                      ),
                    ),
                    imageBuilder: (context, imageProvider) => Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.7,
                      ),
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: imageProvider,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileInfo() {
    if (_profileData == null) return SizedBox();

    String displayName = _profileData!['fullName'] ?? widget.username;
    String bio = _profileData!['bio'] ?? 'Innovation Enthusiast';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Text(
            displayName,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.veryLightBlue,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _profileData!['department'] != 'Not specified'
                  ? _profileData!['department']
                  : 'Student',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.primaryBlue,
              ),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
          SizedBox(height: 16),
          Text(
            bio,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
        ],
      ),
    );
  }

  String _getInitials() {
    if (_profileData == null) return '?';
    String name = _profileData!['fullName'] ?? widget.username;
    List<String> nameParts =
        name.split(' ').where((part) => part.isNotEmpty).toList();
    if (nameParts.length > 1) {
      return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
    } else if (name.isNotEmpty) {
      return name[0].toUpperCase();
    }
    return '?';
  }

  Widget _buildTabBar() {
    return SliverToBoxAdapter(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowColor.withOpacity(0.05),
              blurRadius: 10,
              spreadRadius: 0,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryBlue,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          unselectedLabelStyle:
              TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
          indicator: BoxDecoration(
            color: AppColors.veryLightBlue,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.all(6),
          tabs: [
            Tab(
              text: 'About',
              icon: Icon(Icons.person_outline, size: 20),
              iconMargin: EdgeInsets.only(bottom: 4),
            ),
            Tab(
              text: 'Portfolio',
              icon: Icon(Icons.work_outline, size: 20),
              iconMargin: EdgeInsets.only(bottom: 4),
            ),
            Tab(
              text: 'Activities',
              icon: Icon(Icons.timeline, size: 20),
              iconMargin: EdgeInsets.only(bottom: 4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    if (_profileData == null) return SizedBox();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 16),
          _buildInfoItem(
            icon: Icons.email_outlined,
            iconColor: AppColors.accentBlue,
            label: 'Email',
            value: _profileData!['email'] ?? 'Not specified',
          ),
          _buildInfoItem(
            icon: Icons.phone_outlined,
            iconColor: Colors.green,
            label: 'Phone',
            value: _profileData!['phoneNumber'] ?? 'Not specified',
          ),
          _buildInfoItem(
            icon: Icons.school_outlined,
            iconColor: Colors.orange,
            label: 'College',
            value: _profileData!['collegeName'] ?? 'Not specified',
          ),
          _buildInfoItem(
            icon: Icons.calendar_today_outlined,
            iconColor: Colors.purple,
            label: 'Year',
            value: _profileData!['year'] ?? 'Not specified',
          ),
          _buildInfoItem(
            icon: Icons.work_outline,
            iconColor: Colors.brown,
            label: 'Department',
            value: _profileData!['department'] ?? 'Not specified',
          ),
          _buildInfoItem(
            icon: Icons.lightbulb_outline,
            iconColor: Colors.amber,
            label: 'Primary Skill',
            value: _profileData!['primarySkill'] ?? 'Not specified',
          ),
          _buildInfoItem(
            icon: Icons.flag_outlined,
            iconColor: AppColors.primaryBlue,
            label: 'Career Goal',
            value: _profileData!['careerGoal'] ?? 'Not specified',
          ),
          // Display skills if available
          if (_profileData!['skills'] != null &&
              (_profileData!['skills'] as List).isNotEmpty)
            _buildSkillsItem(),
          SizedBox(height: 24),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildSkillsItem() {
    List<dynamic> skills = _profileData!['skills'] ?? [];
    if (skills.isEmpty) return SizedBox();

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.psychology_outlined,
                    color: Colors.purple, size: 22),
              ),
              SizedBox(width: 16),
              Text(
                'Skills',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: skills
                .map((skill) => Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.veryLightBlue,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.primaryBlue.withOpacity(0.3)),
                      ),
                      child: Text(
                        skill.toString(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms, delay: 100.ms)
        .slideX(begin: 0.05, end: 0);
  }

  Widget _buildInfoItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    bool isNotSpecified = value == 'Not specified';

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isNotSpecified
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                    fontStyle:
                        isNotSpecified ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms, delay: 100.ms)
        .slideX(begin: 0.05, end: 0);
  }

  Widget _buildPortfolioSection() {
    if (_profileData == null) return SizedBox();
    List<dynamic> portfolioLinks = _profileData!['portfolioLinks'] ?? [];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Portfolio & Links',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              if (widget.isCurrentUser)
                IconButton(
                  onPressed: () {
                    if (_profileData != null && _currentUserId != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreateProfilePage(
                            FullName:
                                _profileData!['fullName'] ?? widget.username,
                          ),
                        ),
                      ).then((_) => _initializeData());
                    }
                  },
                  icon: Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.veryLightBlue,
                      shape: BoxShape.circle,
                    ),
                    child:
                        Icon(Icons.add, color: AppColors.primaryBlue, size: 18),
                  ),
                  tooltip: 'Add portfolio link',
                ),
            ],
          ),
          SizedBox(height: 16),
          if (portfolioLinks.isEmpty)
            _buildEmptyPortfolioPlaceholder()
          else
            Column(
              children: portfolioLinks
                  .map((link) => _buildPortfolioItem(link.toString()))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyPortfolioPlaceholder() {
    return Container(
      padding: EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.veryLightBlue,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.link_off,
              color: AppColors.primaryBlue,
              size: 40,
            ),
          ),
          SizedBox(height: 24),
          Text(
            widget.isCurrentUser
                ? 'No Portfolio Links Yet'
                : 'No Portfolio Links',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 12),
          Text(
            widget.isCurrentUser
                ? 'Add links to your GitHub, LinkedIn, and other portfolios to showcase your work.'
                : 'This user hasn\'t added any portfolio links yet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          if (widget.isCurrentUser) ...[
            SizedBox(height: 24),
            ElevatedButton.icon(
              icon: Icon(Icons.add),
              label: Text('Add Portfolio Link'),
              onPressed: () {
                if (_profileData != null && _currentUserId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreateProfilePage(
                        FullName: _profileData!['fullName'] ?? widget.username,
                      ),
                    ),
                  ).then((_) => _initializeData());
                }
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: AppColors.primaryBlue,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 500.ms);
  }

  Widget _buildPortfolioItem(String url) {
    IconData icon;
    String label;
    Color iconColor;

    if (url.contains('github.com')) {
      icon = Icons.code_rounded;
      label = 'GitHub';
      iconColor = Colors.deepPurple;
    } else if (url.contains('linkedin.com')) {
      icon = Icons.work_rounded;
      label = 'LinkedIn';
      iconColor = Colors.blue.shade700;
    } else if (url.contains('behance.net')) {
      icon = Icons.palette_outlined;
      label = 'Behance';
      iconColor = Colors.indigo;
    } else if (url.contains('dribbble.com')) {
      icon = Icons.sports_basketball_outlined;
      label = 'Dribbble';
      iconColor = Colors.pink.shade400;
    } else if (url.contains('medium.com')) {
      icon = Icons.article_outlined;
      label = 'Medium';
      iconColor = Colors.black87;
    } else if (url.contains('kaggle.com')) {
      icon = Icons.insights_outlined;
      label = 'Kaggle';
      iconColor = Colors.blue.shade600;
    } else {
      icon = Icons.link_rounded;
      label = 'Website';
      iconColor = AppColors.primaryBlue;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              try {
                final Uri uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  _showCustomSnackBar('Could not launch $url', isError: true);
                }
              } catch (e) {
                _showCustomSnackBar('Invalid URL: $url', isError: true);
              }
            },
            splashColor: AppColors.veryLightBlue,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconColor, size: 26),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          url,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.veryLightBlue,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.open_in_new_rounded,
                        color: AppColors.primaryBlue, size: 16),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms, delay: 150.ms)
        .slideX(begin: 0.1, end: 0);
  }

  Widget _buildActivitiesTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Activities',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 16),
          _buildActivityTimelinePlaceholder(),
        ],
      ),
    );
  }

  Widget _buildActivityTimelinePlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.veryLightBlue,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.pending_actions,
                    color: AppColors.primaryBlue,
                    size: 24,
                  ),
                ),
                SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Activity Timeline',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Coming in the next update',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: AppColors.veryLightBlue.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.timeline,
                      size: 80,
                      color: AppColors.primaryBlue.withOpacity(0.5),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'Activity tracking will be available soon!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 10),
                Text(
                  'Track your participation in challenges, projects, and collaborations. See your progress and contributions to the innovation ecosystem.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),
                OutlinedButton(
                  onPressed: () {
                    _showCustomSnackBar('Activity timeline coming soon!');
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryBlue,
                    side: BorderSide(color: AppColors.primaryBlue),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Text('Notify Me When Available'),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms);
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Text(
          'Options',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 16),
        if (widget.isCurrentUser)
          _buildActionButton(
            icon: Icons.edit_outlined,
            iconColor: AppColors.primaryBlue,
            title: 'Edit Profile',
            onTap: () {
              if (_profileData != null && _currentUserId != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateProfilePage(
                      FullName: _profileData!['fullName'] ?? widget.username,
                    ),
                  ),
                ).then((_) => _initializeData());
              }
            },
          ),
        if (widget.isCurrentUser) SizedBox(height: 12),
        if (!widget.isCurrentUser)
          _buildActionButton(
            icon: Icons.message_outlined,
            iconColor: AppColors.primaryBlue,
            title: 'Send Message',
            onTap: () {
              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    otherUserId: widget.userId!,
                    otherUserName: widget.username,
                  ),
                ),
              );
            },
          ),
        if (!widget.isCurrentUser) SizedBox(height: 12),
        _buildActionButton(
          icon: Icons.help_outline,
          iconColor: Colors.amber.shade700,
          title: 'Help & Support',
          onTap: () {
            _showCustomSnackBar('Help & Support (Coming Soon)');
          },
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withOpacity(0.05),
            blurRadius: 8,
            spreadRadius: 0,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: AppColors.veryLightBlue,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconColor, size: 24),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded,
                      color: Colors.grey.shade400, size: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 600.ms, delay: 200.ms);
  }

  void _showUserOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Profile Options',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 24),
              _buildOptionItem(
                icon: Icons.message_outlined,
                title: 'Send Message',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        otherUserId: widget.userId!,
                        otherUserName: widget.username,
                      ),
                    ),
                  );
                },
              ),
              Divider(
                  height: 1, thickness: 1, indent: 64, color: Colors.grey[200]),
              _buildOptionItem(
                icon: Icons.block_outlined,
                title: 'Block User',
                iconColor: AppColors.errorColor,
                textColor: AppColors.errorColor,
                onTap: () {
                  Navigator.pop(context);
                  _showBlockUserConfirmation();
                },
              ),
              SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOptionItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color iconColor = AppColors.primaryBlue,
    Color textColor = AppColors.textPrimary,
  }) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  void _showBlockUserConfirmation() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 8,
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.errorColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.block,
                    color: AppColors.errorColor,
                    size: 32,
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  'Block ${_profileData?['fullName'] ?? widget.username}?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                Text(
                  'They won\'t be able to message you or see your posts. You can unblock them later.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: BorderSide(color: Colors.grey[300]!),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text('Cancel'),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _blockUser();
                        },
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: AppColors.errorColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text('Block'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _blockUser() {
    if (_currentUserId == null || _viewedUserId == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
        ),
      ),
    );

    Future.delayed(Duration(seconds: 1), () {
      Navigator.pop(context);
      _showCustomSnackBar('User has been blocked');
      Navigator.pop(context);
    });
  }

  Widget _buildErrorScreen() {
    return Center(
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.all(24),
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowColor.withOpacity(0.1),
              blurRadius: 15,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.errorColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                color: AppColors.errorColor,
                size: 48,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Could Not Load Profile',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'We couldn\'t retrieve the profile data. Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 32),
            ElevatedButton.icon(
              icon: Icon(Icons.refresh),
              label: Text('Try Again'),
              onPressed: _initializeData,
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: AppColors.primaryBlue,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                      strokeWidth: 3,
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    "Loading profile...",
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : _profileData == null
              ? _buildErrorScreen()
              : Stack(
                  children: [
                    RefreshIndicator(
                      key: _refreshIndicatorKey,
                      onRefresh: _initializeData,
                      color: AppColors.primaryBlue,
                      child: CustomScrollView(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        slivers: [
                          _buildSliverAppBar(),
                          SliverToBoxAdapter(
                            child: Column(
                              children: [
                                SizedBox(height: 16),
                                _buildProfileAvatar(),
                                SizedBox(height: 24),
                                _buildProfileInfo(),
                                SizedBox(height: 24),
                              ],
                            ),
                          ),
                          _buildTabBar(),
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height: MediaQuery.of(context).size.height * 0.5,
                              child: TabBarView(
                                controller: _tabController,
                                physics: const BouncingScrollPhysics(),
                                children: [
                                  _buildInfoSection(),
                                  _buildPortfolioSection(),
                                  _buildActivitiesTab(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
      floatingActionButton: widget.isCurrentUser
          ? FloatingActionButton(
              onPressed: () {
                if (_profileData != null && _currentUserId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreateProfilePage(
                        FullName: _profileData!['fullName'] ?? widget.username,
                      ),
                    ),
                  ).then((_) => _initializeData());
                }
              },
              backgroundColor: AppColors.primaryBlue,
              elevation: 9,
              child: Icon(Icons.edit, color: Colors.white),
            )
          : null,
    );
  }
}

// Wave painter for the app bar
class WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final path = Path();

    path.moveTo(0, size.height * 0.7);
    path.quadraticBezierTo(size.width * 0.25, size.height * 0.5,
        size.width * 0.5, size.height * 0.7);
    path.quadraticBezierTo(
        size.width * 0.75, size.height * 0.9, size.width, size.height * 0.6);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);

    final paint2 = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    final path2 = Path();
    path2.moveTo(0, size.height * 0.8);
    path2.quadraticBezierTo(size.width * 0.3, size.height * 0.9,
        size.width * 0.55, size.height * 0.65);
    path2.quadraticBezierTo(
        size.width * 0.8, size.height * 0.4, size.width, size.height * 0.7);
    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();

    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Create Profile Page for editing profile
class CreateProfilePage extends StatefulWidget {
  final String FullName;

  const CreateProfilePage({Key? key, required this.FullName}) : super(key: key);

  @override
  State<CreateProfilePage> createState() => _CreateProfilePageState();
}

class _CreateProfilePageState extends State<CreateProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _bioController;
  late TextEditingController _skillsController;
  late TextEditingController _collegeController;
  late TextEditingController _yearController;
  late TextEditingController _departmentController;
  late TextEditingController _primarySkillController;
  late TextEditingController _careerGoalController;
  late TextEditingController _portfolioLinksController;
  late TextEditingController _phoneNumberController;

  bool _isLoading = false;
  bool _hasChangedName = false;
  String _originalName = '';
  File? _selectedImage;
  String? _currentImageUrl;

  final FocusNode _bioFocusNode = FocusNode();
  final FocusNode _careerGoalFocusNode = FocusNode();
  final FocusNode _portfolioLinksFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.FullName);
    _emailController = TextEditingController();
    _bioController = TextEditingController();
    _skillsController = TextEditingController();
    _collegeController = TextEditingController();
    _yearController = TextEditingController();
    _departmentController = TextEditingController();
    _primarySkillController = TextEditingController();
    _careerGoalController = TextEditingController();
    _portfolioLinksController = TextEditingController();
    _phoneNumberController = TextEditingController();

    _bioFocusNode.addListener(_onFocusChange);
    _careerGoalFocusNode.addListener(_onFocusChange);
    _portfolioLinksFocusNode.addListener(_onFocusChange);

    _loadProfileData();
  }

  void _onFocusChange() {
    Future.delayed(Duration(milliseconds: 300), () {
      if (_bioFocusNode.hasFocus ||
          _careerGoalFocusNode.hasFocus ||
          _portfolioLinksFocusNode.hasFocus) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    _skillsController.dispose();
    _collegeController.dispose();
    _yearController.dispose();
    _departmentController.dispose();
    _primarySkillController.dispose();
    _careerGoalController.dispose();
    _portfolioLinksController.dispose();
    _phoneNumberController.dispose();
    _bioFocusNode.dispose();
    _careerGoalFocusNode.dispose();
    _portfolioLinksFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    try {
      String? userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        final DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('studentprofile')
            .doc(userId)
            .get();

        if (!mounted) return;

        if (doc.exists) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          _nameController.text = data['fullName'] ?? widget.FullName;
          _emailController.text =
              data['email'] ?? FirebaseAuth.instance.currentUser?.email ?? '';
          _bioController.text = data['bio'] ?? '';
          _collegeController.text = data['collegeName'] ?? '';
          _yearController.text = data['year'] ?? '';
          _departmentController.text = data['department'] ?? '';
          _primarySkillController.text = data['primarySkill'] ?? '';
          _careerGoalController.text = data['careerGoal'] ?? '';
          _phoneNumberController.text = data['phoneNumber'] ?? '';
          _currentImageUrl = data['imageUrl'];

          setState(() {
            _hasChangedName = data['hasChangedName'] ?? false;
            _originalName = data['fullName'] ?? widget.FullName;
          });

          if (data['skills'] is List) {
            _skillsController.text = (data['skills'] as List).join(', ');
          } else {
            _skillsController.text = '';
          }

          if (data['portfolioLinks'] is List) {
            _portfolioLinksController.text =
                (data['portfolioLinks'] as List).join('\n');
          } else {
            _portfolioLinksController.text = '';
          }

          if (_hasChangedName && mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showSnackBar(
                'Note: You\'ve already changed your name once. Further name changes are not allowed.',
                isError: false,
                duration: Duration(seconds: 5),
              );
            });
          }
        } else {
          _emailController.text =
              FirebaseAuth.instance.currentUser?.email ?? '';
          setState(() {
            _hasChangedName = false;
            _originalName = widget.FullName;
          });
        }
      }
    } catch (e) {
      print('Error loading profile data for editing: $e');
      if (mounted) _showSnackBar('Error loading profile: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message,
      {bool isError = false, Duration? duration}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 24,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        duration: duration ?? Duration(seconds: 3),
        backgroundColor: isError ? AppColors.errorColor : AppColors.primaryBlue,
      ),
    );
  }

  Future<void> _selectProfilePicture() async {
    final ImagePicker _picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowColor.withOpacity(0.1),
                blurRadius: 10,
                offset: Offset(0, -5),
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Change Profile Picture',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildImageSourceOption(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onTap: () async {
                      Navigator.of(context).pop();
                      final XFile? image = await _picker.pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 1000,
                          maxHeight: 1000,
                          imageQuality: 85);
                      if (image != null) {
                        setState(() {
                          _selectedImage = File(image.path);
                        });
                      }
                    },
                  ),
                  _buildImageSourceOption(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    onTap: () async {
                      Navigator.of(context).pop();
                      final XFile? image = await _picker.pickImage(
                          source: ImageSource.camera,
                          maxWidth: 1000,
                          maxHeight: 1000,
                          imageQuality: 85);
                      if (image != null) {
                        setState(() {
                          _selectedImage = File(image.path);
                        });
                      }
                    },
                  ),
                ],
              ),
              SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.veryLightBlue,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: AppColors.primaryBlue,
                size: 30,
              ),
            ),
            SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _uploadProfilePicture() async {
    if (_selectedImage == null) return _currentImageUrl;

    try {
      String? userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return null;

      final String fileName =
          'profile_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef =
          FirebaseStorage.instance.ref().child('profile_pictures/$fileName');
      final UploadTask uploadTask = storageRef.putFile(_selectedImage!);
      final TaskSnapshot taskSnapshot = await uploadTask;
      final String downloadUrl = await taskSnapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      print('Error uploading profile picture: $e');
      if (mounted) {
        _showSnackBar('Error uploading profile picture: $e', isError: true);
      }
      return null;
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Please fix errors in the form', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      String? userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        if (_nameController.text.trim() != _originalName && _hasChangedName) {
          setState(() => _isLoading = false);
          _showSnackBar(
            'You can only change your name once for consistency.',
            isError: true,
            duration: Duration(seconds: 3),
          );
          return;
        }

        List<String> skills = _skillsController.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        List<String> portfolioLinks = _portfolioLinksController.text
            .split('\n')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();

        String? imageUrl = await _uploadProfilePicture();

        Map<String, dynamic> profileData = {
          'email': _emailController.text.trim(),
          'bio': _bioController.text.trim(),
          'collegeName': _collegeController.text.trim(),
          'year': _yearController.text.trim(),
          'department': _departmentController.text.trim(),
          'primarySkill': _primarySkillController.text.trim(),
          'careerGoal': _careerGoalController.text.trim(),
          'phoneNumber': _phoneNumberController.text.trim(),
          'skills': skills,
          'portfolioLinks': portfolioLinks,
          'updatedAt': FieldValue.serverTimestamp(),
          'uid': userId,
        };

        if (imageUrl != null) {
          profileData['imageUrl'] = imageUrl;
        }

        profileData['fullName'] = _nameController.text.trim();

        if (_nameController.text.trim() != _originalName) {
          profileData['hasChangedName'] = true;
        } else if (!_hasChangedName) {
          profileData['hasChangedName'] = false;
        }

        await FirebaseFirestore.instance
            .collection('studentprofile')
            .doc(userId)
            .set(profileData, SetOptions(merge: true));

        if (FirebaseAuth.instance.currentUser?.displayName !=
            _nameController.text.trim()) {
          await FirebaseAuth.instance.currentUser
              ?.updateDisplayName(_nameController.text.trim());
        }

        if (mounted) {
          _showSnackBar('Profile updated successfully');
          Navigator.pop(context);
        }
      }
    } catch (e) {
      print('Error saving profile: $e');
      if (mounted)
        _showSnackBar('Failed to update profile: ${e.toString()}',
            isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getInitials(String name) {
    List<String> nameParts =
        name.split(' ').where((part) => part.isNotEmpty).toList();
    if (nameParts.length > 1) {
      return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
    } else if (name.isNotEmpty) {
      return name[0].toUpperCase();
    }
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Edit Profile',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primaryBlue,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.arrow_back, color: Colors.white, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton.icon(
            icon: Icon(Icons.save_outlined, color: Colors.white),
            label: Text(
              'Save',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: _isLoading ? null : _saveProfile,
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
          SizedBox(width: 12),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryBlue))
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [AppColors.primaryBlue, AppColors.background],
                        ),
                      ),
                    ),
                    Transform.translate(
                      offset: Offset(0, -60),
                      child: Center(
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        AppColors.shadowColor.withOpacity(0.2),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              padding: EdgeInsets.all(4),
                              child: GestureDetector(
                                onTap: () {
                                  if (_selectedImage != null ||
                                      (_currentImageUrl != null &&
                                          _currentImageUrl!.isNotEmpty)) {
                                    _showFullImagePreview();
                                  } else {
                                    _selectProfilePicture();
                                  }
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.veryLightBlue,
                                    image: _selectedImage != null
                                        ? DecorationImage(
                                            image: FileImage(_selectedImage!),
                                            fit: BoxFit.cover,
                                          )
                                        : _currentImageUrl != null &&
                                                _currentImageUrl!.isNotEmpty
                                            ? DecorationImage(
                                                image:
                                                    CachedNetworkImageProvider(
                                                        _currentImageUrl!),
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                  ),
                                  child: (_selectedImage == null &&
                                          (_currentImageUrl == null ||
                                              _currentImageUrl!.isEmpty))
                                      ? Center(
                                          child: Text(
                                            _getInitials(_nameController.text),
                                            style: TextStyle(
                                              fontSize: 40,
                                              color: AppColors.primaryBlue,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: _selectProfilePicture,
                              child: Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.accentBlue,
                                  border:
                                      Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.shadowColor
                                          .withOpacity(0.2),
                                      blurRadius: 5,
                                      spreadRadius: 0,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Transform.translate(
                      offset: Offset(0, -40),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(
                                'Personal Information', Icons.person_outline),
                            SizedBox(height: 16),
                            _buildTextField(
                              controller: _nameController,
                              label: 'Full Name',
                              icon: Icons.person_outline,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Name cannot be empty';
                                }
                                if (value.length < 3) {
                                  return 'Name must be at least 3 characters';
                                }
                                if (value.trim() != _originalName &&
                                    _hasChangedName) {
                                  return 'You can only change your name once';
                                }
                                return null;
                              },
                              infoText: _hasChangedName
                                  ? 'You have already used your one-time name change.'
                                  : 'Note: You can only change your name once for consistency across posts.',
                              enabled: !_hasChangedName ||
                                  _nameController.text.trim() == _originalName,
                            ),
                            SizedBox(height: 16),
                            _buildTextField(
                              controller: _emailController,
                              label: 'Email Address',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              enabled: false,
                            ),
                            SizedBox(height: 16),
                            _buildTextField(
                              controller: _phoneNumberController,
                              label: 'Phone Number (Optional)',
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                            ),
                            SizedBox(height: 16),
                            _buildTextField(
                              controller: _bioController,
                              label: 'Bio',
                              icon: Icons.info_outline,
                              maxLines: 4,
                              hint: 'Tell others about yourself...',
                              focusNode: _bioFocusNode,
                            ),
                            SizedBox(height: 24),
                            _buildSectionHeader(
                                'Education', Icons.school_outlined),
                            SizedBox(height: 16),
                            _buildTextField(
                              controller: _collegeController,
                              label: 'College Name',
                              icon: Icons.school_outlined,
                            ),
                            SizedBox(height: 16),
                            _buildTextField(
                              controller: _yearController,
                              label: 'Year of Study',
                              icon: Icons.calendar_today_outlined,
                            ),
                            SizedBox(height: 16),
                            _buildTextField(
                              controller: _departmentController,
                              label: 'Department/Branch',
                              icon: Icons.work_outline,
                            ),
                            SizedBox(height: 24),
                            _buildSectionHeader(
                                'Skills & Goals', Icons.lightbulb_outline),
                            SizedBox(height: 16),
                            _buildTextField(
                              controller: _primarySkillController,
                              label: 'Primary Skill',
                              icon: Icons.lightbulb_outline,
                            ),
                            SizedBox(height: 16),
                            _buildTextField(
                              controller: _careerGoalController,
                              label: 'Career Goal',
                              icon: Icons.flag_outlined,
                              maxLines: 3,
                              focusNode: _careerGoalFocusNode,
                            ),
                            SizedBox(height: 16),
                            _buildTextField(
                              controller: _skillsController,
                              label: 'Skills (comma separated)',
                              icon: Icons.psychology_outlined,
                              hint: 'e.g., Flutter, Python, UI/UX',
                            ),
                            SizedBox(height: 24),
                            _buildSectionHeader(
                                'Portfolio Links', Icons.link_outlined),
                            SizedBox(height: 16),
                            _buildTextField(
                              controller: _portfolioLinksController,
                              label: 'Portfolio Links (one per line)',
                              icon: Icons.link_outlined,
                              maxLines: 5,
                              hint:
                                  'e.g., https://github.com/...\nhttps://linkedin.com/...',
                              focusNode: _portfolioLinksFocusNode,
                            ),
                            SizedBox(height: 30),
                            _buildSaveButton(),
                            SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  void _showFullImagePreview() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: EdgeInsets.all(20),
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.topRight,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _selectedImage != null
                      ? Image.file(
                          _selectedImage!,
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: MediaQuery.of(context).size.height * 0.6,
                        )
                      : CachedNetworkImage(
                          imageUrl: _currentImageUrl!,
                          placeholder: (context, url) => Container(
                            color: Colors.black12,
                            child: Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.primaryBlue),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.black12,
                            child: Center(
                              child: Icon(Icons.error,
                                  color: AppColors.errorColor),
                            ),
                          ),
                          imageBuilder: (context, imageProvider) => Container(
                            constraints: BoxConstraints(
                              maxHeight:
                                  MediaQuery.of(context).size.height * 0.7,
                            ),
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                image: imageProvider,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _selectProfilePicture();
                  },
                  icon: Icon(Icons.edit),
                  label: Text('Change'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: AppColors.primaryBlue,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          color: AppColors.primaryBlue,
          size: 24,
        ),
        SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _saveProfile,
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primaryBlue,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: EdgeInsets.symmetric(vertical: 16),
        elevation: 2,
      ),
      child: _isLoading
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Saving...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.save_outlined, size: 20),
                SizedBox(width: 12),
                Text(
                  'Save Profile',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
    String? hint,
    String? infoText,
    String? Function(String?)? validator,
    FocusNode? focusNode,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            filled: true,
            fillColor: enabled ? Colors.white : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.primaryBlue, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.errorColor),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.errorColor, width: 1.5),
            ),
            prefixIcon: Container(
              margin: EdgeInsets.symmetric(horizontal: 12),
              child: Icon(icon,
                  color: enabled ? AppColors.primaryBlue : Colors.grey),
            ),
            prefixIconConstraints: BoxConstraints(minWidth: 50, minHeight: 50),
            alignLabelWithHint: maxLines > 1,
            contentPadding:
                EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
            isDense: false,
            floatingLabelStyle: TextStyle(color: AppColors.primaryBlue),
          ),
          maxLines: maxLines,
          keyboardType: maxLines > 1 ? TextInputType.multiline : keyboardType,
          enabled: enabled,
          style: TextStyle(
            color: enabled ? AppColors.textPrimary : AppColors.textSecondary,
            fontSize: 16,
          ),
          validator: validator,
          textInputAction:
              maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
        ),
        if (infoText != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: _hasChangedName
                      ? AppColors.errorColor.withOpacity(0.8)
                      : AppColors.primaryBlue.withOpacity(0.8),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    infoText,
                    style: TextStyle(
                      fontSize: 12,
                      color: _hasChangedName
                          ? AppColors.errorColor.withOpacity(0.8)
                          : AppColors.primaryBlue.withOpacity(0.8),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
