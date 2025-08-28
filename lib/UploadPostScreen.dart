import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Color palette - matching chat screen with enhanced modern feel
const Color primaryBlue = Color(0xFF1976D2);
const Color lightBlue = Color(0xFF64B5F6);
const Color veryLightBlue = Color(0xFFE3F2FD);
const Color darkBlue = Color(0xFF0D47A1);
const Color accentBlue = Color(0xFF2196F3); // Slightly adjusted for modern look
const Color surfaceColor = Colors.white;
const Color shadowColor = Color(0x1A000000);
const Color backgroundGrey = Color(0xFFF5F7FA); // New light background color

class UploadPostScreen extends StatefulWidget {
  const UploadPostScreen({Key? key}) : super(key: key);

  @override
  State<UploadPostScreen> createState() => _UploadPostScreenState();
}

class _UploadPostScreenState extends State<UploadPostScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _insightsController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  File? _videoFile;
  String _postType = 'text';
  String _selectedDomain = 'Full Stack Development'; // Default domain
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // User profile data
  String _userName = '';
  String _userImageUrl = '';
  bool _loadingUserData = true;

  // Reference to hold dialog context and setState for updating progress
  BuildContext? _progressDialogContext;
  StateSetter? _progressDialogSetState;

  // List of IT domains with icons
  final List<Map<String, dynamic>> _domains = [
    {'name': 'Full Stack Development', 'icon': Icons.web_asset_rounded},
    {'name': 'Python Development', 'icon': Icons.code_rounded},
    {'name': 'Java Development', 'icon': Icons.coffee_rounded},
    {'name': 'AIML', 'icon': Icons.psychology_rounded},
    {'name': 'Data Science', 'icon': Icons.analytics_rounded},
    {'name': 'CyberSecurity', 'icon': Icons.security_rounded},
    {'name': 'Much More', 'icon': Icons.more_horiz_rounded},
  ];

  @override
  void initState() {
    super.initState();

    // Setup animations
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeInOut,
        )
    );

    _animationController.forward();

    // Load user data
    _loadUserData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _insightsController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _loadingUserData = true;
    });

    final user = _auth.currentUser;
    if (user != null) {
      try {
        // First, try to get basic data from Firebase Auth
        String initialUserName = user.displayName ?? '';
        String initialPhotoURL = user.photoURL ?? '';

        // Set initial values from Firebase Auth if available
        if (initialUserName.isNotEmpty || initialPhotoURL.isNotEmpty) {
          setState(() {
            _userName = initialUserName;
            _userImageUrl = initialPhotoURL;
          });
        }

        print("Initial Auth data - name: $initialUserName, photoURL: $initialPhotoURL");

        // Then try to get complete data from Firestore
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('studentprofile')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

          print("Found user data in studentprofile: ${userData['fullName']}");

          // Check if we actually have values in the data
          String fullName = userData['fullName'] ?? '';
          String imageUrl = userData['imageUrl'] ?? '';

          // Only update if we got valid data from Firestore
          setState(() {
            if (fullName.isNotEmpty) _userName = fullName;
            if (imageUrl.isNotEmpty) _userImageUrl = imageUrl;
          });
        } else {
          print("No document found in studentprofile for user ${user.uid}");

          // If no document in studentprofile, check if we have data in 'users' collection as fallback
          try {
            DocumentSnapshot userDoc2 = await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();

            if (userDoc2.exists) {
              Map<String, dynamic> userData = userDoc2.data() as Map<String, dynamic>;
              print("Found user data in users collection");

              // Check for name in various possible field names
              String fullName = userData['fullName'] ?? userData['displayName'] ?? userData['name'] ?? '';
              String imageUrl = userData['imageUrl'] ?? userData['photoURL'] ?? userData['profilePic'] ?? '';

              // Only update if we got valid data
              setState(() {
                if (fullName.isNotEmpty) _userName = fullName;
                if (imageUrl.isNotEmpty) _userImageUrl = imageUrl;
              });
            }
          } catch (e) {
            print("Error checking users collection: $e");
          }
        }
      } catch (e) {
        print("Error fetching user data: $e");
      } finally {
        // Always ensure we have at least a basic name for the user
        setState(() {
          // If still no name, use email or 'Anonymous'
          if (_userName.isEmpty) {
            _userName = user.email?.split('@')[0] ?? 'Anonymous';
          }
          _loadingUserData = false;
        });

        // Show welcome dialog after data is loaded
        if (mounted) {
          _showWelcomeDialog();
        }
      }
    } else {
      setState(() {
        _loadingUserData = false;
        _userName = 'Anonymous';
      });
    }
  }

  Future<void> _showWelcomeDialog() async {
    // Only show dialog if we have a user name
    if (_userName.isEmpty) {
      print("Not showing welcome dialog because username is empty");
      return;
    }

    print("Showing welcome dialog for $_userName");

    await Future.delayed(Duration(milliseconds: 500)); // Small delay for better UX

    if (!mounted) return; // Check if widget is still mounted

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: surfaceColor,
        elevation: 8,
        title: Column(
          children: [
            // User profile image
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: accentBlue, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: shadowColor.withOpacity(0.2),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: _userImageUrl.isNotEmpty
                    ? CachedNetworkImage(
                  imageUrl: _userImageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: lightBlue.withOpacity(0.3),
                    child: Icon(Icons.person, color: primaryBlue, size: 40),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: lightBlue.withOpacity(0.3),
                    child: Icon(Icons.person, color: primaryBlue, size: 40),
                  ),
                )
                    : Container(
                  color: lightBlue.withOpacity(0.3),
                  child: Icon(Icons.person, color: primaryBlue, size: 40),
                ),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Welcome, $_userName!',
              style: GoogleFonts.poppins(
                color: darkBlue,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              'Ready to create your next post?',
              style: TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.normal,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Text(
          'Share your knowledge and projects with the community. Your contributions make a difference!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16,
            height: 1.5,
          ),
        ),
        actions: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentBlue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              child: Text(
                'Let\'s Start',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: surfaceColor,
        elevation: 8,
        title: Column(
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: Colors.red[600]),
            SizedBox(height: 16),
            Text(
              'Oops!',
              style: GoogleFonts.poppins(
                color: Colors.red[700],
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16,
            height: 1.5,
          ),
        ),
        actions: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: primaryBlue,
                padding: EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: primaryBlue, width: 1),
                ),
              ),
              child: Text(
                'Got it',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    // Show a bottom sheet for image source selection
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Select Image Source',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: darkBlue,
              ),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _imageSourceOption(
                  icon: Icons.camera_alt_rounded,
                  title: 'Camera',
                  onTap: () async {
                    Navigator.pop(context);
                    final pickedFile = await _picker.pickImage(source: ImageSource.camera);
                    if (pickedFile != null) {
                      setState(() {
                        _imageFile = File(pickedFile.path);
                        _postType = 'image';
                        _videoFile = null;
                      });
                    }
                  },
                ),
                _imageSourceOption(
                  icon: Icons.photo_library_rounded,
                  title: 'Gallery',
                  onTap: () async {
                    Navigator.pop(context);
                    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
                    if (pickedFile != null) {
                      setState(() {
                        _imageFile = File(pickedFile.path);
                        _postType = 'image';
                        _videoFile = null;
                      });
                    }
                  },
                ),
              ],
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _imageSourceOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 120,
        padding: EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: veryLightBlue,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: shadowColor.withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: primaryBlue, size: 36),
            SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                color: darkBlue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickVideo() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Select Video Source',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: darkBlue,
              ),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _imageSourceOption(
                  icon: Icons.videocam_rounded,
                  title: 'Camera',
                  onTap: () async {
                    Navigator.pop(context);
                    final pickedFile = await _picker.pickVideo(source: ImageSource.camera);
                    if (pickedFile != null) {
                      setState(() {
                        _videoFile = File(pickedFile.path);
                        _postType = 'video';
                        _imageFile = null;
                      });
                    }
                  },
                ),
                _imageSourceOption(
                  icon: Icons.video_library_rounded,
                  title: 'Gallery',
                  onTap: () async {
                    Navigator.pop(context);
                    final pickedFile = await _picker.pickVideo(source: ImageSource.gallery);
                    if (pickedFile != null) {
                      setState(() {
                        _videoFile = File(pickedFile.path);
                        _postType = 'video';
                        _imageFile = null;
                      });
                    }
                  },
                ),
              ],
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showUploadProgressDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        _progressDialogContext = dialogContext;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            _progressDialogSetState = setStateDialog;
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              backgroundColor: surfaceColor,
              elevation: 8,
              contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              title: Column(
                children: [
                  _uploadProgress < 1.0
                      ? Container(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      value: _uploadProgress,
                      strokeWidth: 6,
                      valueColor: AlwaysStoppedAnimation<Color>(accentBlue),
                      backgroundColor: veryLightBlue,
                    ),
                  )
                      : Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle,
                      color: Colors.green[700],
                      size: 60,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    _uploadProgress < 1.0 ? 'Uploading...' : 'Success!',
                    style: GoogleFonts.poppins(
                      color: _uploadProgress < 1.0 ? darkBlue : Colors.green[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_uploadProgress < 1.0) ...[
                    LinearPercentIndicator(
                      animation: true,
                      lineHeight: 8.0,
                      animateFromLastPercent: true,
                      percent: _uploadProgress,
                      backgroundColor: veryLightBlue,
                      progressColor: accentBlue,
                      barRadius: Radius.circular(4),
                      padding: EdgeInsets.symmetric(horizontal: 0),
                    ),
                    SizedBox(height: 16),
                    Text(
                      '${(_uploadProgress * 100).toInt()}% complete',
                      style: TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ] else
                    Text(
                      'Your post has been uploaded successfully!',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
              actions: _uploadProgress >= 1.0
                  ? [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close dialog
                      Navigator.of(context).pop(); // Return to previous screen after upload
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                    child: Text(
                      'Done',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ]
                  : null,
            );
          },
        );
      },
    );
  }

  // Method to update progress in dialog
  void _updateProgressDialog(double progress) {
    setState(() {
      _uploadProgress = progress;
    });

    // Also update the dialog if it exists
    if (_progressDialogSetState != null) {
      _progressDialogSetState!(() {
        _uploadProgress = progress;
      });
    }
  }

  Future<void> _uploadPost() async {
    if (_titleController.text.isEmpty) {
      _showErrorDialog('Title cannot be empty');
      return;
    }
    if ((_postType == 'text' || _postType == 'code') && _contentController.text.isEmpty) {
      _showErrorDialog('Content cannot be empty for text/code posts');
      return;
    }
    if ((_postType == 'image' && _imageFile == null) || (_postType == 'video' && _videoFile == null)) {
      _showErrorDialog('Please select a media file for $_postType post');
      return;
    }

    final user = _auth.currentUser;
    if (user != null) {
      setState(() {
        _isUploading = true;
        _uploadProgress = 0.0;
      });

      _showUploadProgressDialog();

      try {
        String? mediaUrl;

        // For tracking upload progress
        if (_postType == 'image' && _imageFile != null) {
          mediaUrl = await _uploadFileWithProgress(_imageFile!);
        } else if (_postType == 'video' && _videoFile != null) {
          mediaUrl = await _uploadFileWithProgress(_videoFile!);
        } else {
          // Simulate progress for text posts
          for (var i = 1; i <= 10; i++) {
            await Future.delayed(Duration(milliseconds: 300));
            _updateProgressDialog(i / 10);
          }
        }

        // Get the most accurate and complete user profile data
        String authorName = _userName;
        String photoURL = _userImageUrl;
        String department = '';
        String college = '';
        String year = '';

        // First try studentprofile collection
        try {
          DocumentSnapshot userDoc = await FirebaseFirestore.instance
              .collection('studentprofile')
              .doc(user.uid)
              .get();

          if (userDoc.exists) {
            Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

            // Update with data from studentprofile
            authorName = userData['fullName'] ?? authorName;
            photoURL = userData['imageUrl'] ?? photoURL;
            department = userData['department'] ?? '';
            college = userData['collegeName'] ?? '';
            year = userData['year'] ?? '';

            print('Using profile data from studentprofile collection');
          } else {
            // Try users collection as fallback
            try {
              DocumentSnapshot userDoc2 = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get();

              if (userDoc2.exists) {
                Map<String, dynamic> userData = userDoc2.data() as Map<String, dynamic>;

                // Try various field names
                if (userData['fullName'] != null) authorName = userData['fullName'];
                else if (userData['displayName'] != null) authorName = userData['displayName'];
                else if (userData['name'] != null) authorName = userData['name'];

                if (userData['imageUrl'] != null) photoURL = userData['imageUrl'];
                else if (userData['photoURL'] != null) photoURL = userData['photoURL'];
                else if (userData['profilePic'] != null) photoURL = userData['profilePic'];

                if (userData['department'] != null) department = userData['department'];
                if (userData['college'] != null) college = userData['college'];
                else if (userData['collegeName'] != null) college = userData['collegeName'];
                if (userData['year'] != null) year = userData['year'];

                print('Using profile data from users collection');
              }
            } catch (e) {
              print('Error checking users collection: $e');
            }
          }
        } catch (e) {
          print('Error fetching user profile data: $e');
        }

        // Final fallback - use Firebase Auth data
        if (authorName.isEmpty) {
          authorName = user.displayName ?? user.email?.split('@')[0] ?? 'Anonymous';
        }
        if (photoURL.isEmpty) {
          photoURL = user.photoURL ?? '';
        }

        print('Using author: $authorName');
        print('Using photoURL: $photoURL');

        final postId = FirebaseFirestore.instance.collection('posts').doc().id;

        await FirebaseFirestore.instance.collection('posts').doc(postId).set({
          'postId': postId,
          'title': _titleController.text,
          'content': _contentController.text,
          'author': authorName,
          'uid': user.uid,
          'photoURL': photoURL,
          'timestamp': FieldValue.serverTimestamp(),
          'type': _postType,
          'mediaUrl': mediaUrl,
          'insights': _insightsController.text,
          'likes': 0,
          'likedBy': [],
          'shares': 0,
          'domain': _selectedDomain,
          // Add additional profile info if available
          'department': department,
          'college': college,
          'year': year,
        });

        print('Post created successfully with ID: $postId');

        // Ensure this data is saved to studentprofile collection for consistency
        _ensureUserProfileDataExists(authorName, photoURL, department, college, year);

        // Update both main state and dialog state
        setState(() {
          _isUploading = false;
        });

        // Update progress to 100% in dialog
        _updateProgressDialog(1.0);

        // Add haptic feedback on success
        HapticFeedback.mediumImpact();

      } catch (e) {
        setState(() {
          _isUploading = false;
        });

        // Close progress dialog if it's open
        if (_progressDialogContext != null) {
          Navigator.of(_progressDialogContext!).pop();
        }

        // Show error dialog
        _showErrorDialog('Error uploading post: ${e.toString()}');
      }
    } else {
      _showErrorDialog('You must be logged in to post');
    }
  }

// Helper method to ensure profile data consistency
  Future<void> _ensureUserProfileDataExists(String name, String photoURL, String department, String college, String year) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return;

      // Get existing doc, if any
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('studentprofile')
          .doc(user.uid)
          .get();

      Map<String, dynamic> dataToSave = {
        'uid': user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Only add non-empty fields
      if (name.isNotEmpty) dataToSave['fullName'] = name;
      if (photoURL.isNotEmpty) dataToSave['imageUrl'] = photoURL;
      if (department.isNotEmpty) dataToSave['department'] = department;
      if (college.isNotEmpty) dataToSave['collegeName'] = college;
      if (year.isNotEmpty) dataToSave['year'] = year;

      // Keep existing email if available
      if (doc.exists) {
        Map<String, dynamic> existingData = doc.data() as Map<String, dynamic>;
        if (!dataToSave.containsKey('email') && existingData.containsKey('email')) {
          dataToSave['email'] = existingData['email'];
        }
      } else if (user.email != null && user.email!.isNotEmpty) {
        dataToSave['email'] = user.email;
      }

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('studentprofile')
          .doc(user.uid)
          .set(dataToSave, SetOptions(merge: true));

      print('Saved profile data to studentprofile collection for consistency');

      // Also update Firebase Auth profile if needed
      if (user.displayName != name && name.isNotEmpty) {
        await user.updateDisplayName(name);
      }
      if (user.photoURL != photoURL && photoURL.isNotEmpty) {
        await user.updatePhotoURL(photoURL);
      }
    } catch (e) {
      print('Error ensuring profile data exists: $e');
    }
  }


  Future<String> _uploadFileWithProgress(File file) async {
    final storageRef = FirebaseStorage.instance.ref().child('posts/${DateTime.now().toIso8601String()}');

    final uploadTask = storageRef.putFile(file);

    uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
      double progress = snapshot.bytesTransferred / snapshot.totalBytes;
      _updateProgressDialog(progress);
    });

    await uploadTask;
    return await storageRef.getDownloadURL();
  }

  @override
  Widget build(BuildContext context) {
    // Set status bar color
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: backgroundGrey,
      appBar: AppBar(
        backgroundColor: primaryBlue,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Create New Post',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline_rounded, color: Colors.white),
            onPressed: () {
              _showTips();
            },
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(24),
          ),
        ),
      ),
      body: _loadingUserData
          ? Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
        ),
      )
          : SafeArea(
        child: Stack(
          children: [
            ListView(
              physics: BouncingScrollPhysics(),
              padding: EdgeInsets.all(16),
              children: [
                SizedBox(height: 8),
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Post Type + Domain Combined Card
                      _buildMaterialCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Post Type Section
                            _buildHeaderRow(
                              icon: Icons.category_rounded,
                              title: 'Post Type',
                            ),
                            SizedBox(height: 8),
                            _buildPostTypeSelector(),

                            Divider(color: veryLightBlue, thickness: 1, height: 32),

                            // Domain Section
                            _buildHeaderRow(
                              icon: Icons.business_rounded,
                              title: 'Domain Category',
                            ),
                            SizedBox(height: 8),
                            _buildDomainSelector(),
                          ],
                        ),
                      ),

                      SizedBox(height: 16),

                      // Post Details Card
                      _buildMaterialCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeaderRow(
                              icon: Icons.description_rounded,
                              title: 'Post Details',
                            ),
                            SizedBox(height: 16),

                            _buildTextField(
                              controller: _titleController,
                              labelText: 'Title',
                              hintText: 'Enter a catchy title for your post',
                              prefixIcon: Icons.title_rounded,
                            ),

                            SizedBox(height: 16),

                            if (_postType == 'text' || _postType == 'code')
                              _buildTextField(
                                controller: _contentController,
                                labelText: _postType == 'code' ? 'Code' : 'Content',
                                hintText: _postType == 'code'
                                    ? 'Paste your code here'
                                    : 'Write your post content here',
                                prefixIcon: _postType == 'code' ? Icons.code_rounded : Icons.text_fields_rounded,
                                maxLines: 6,
                              ),

                            if (_postType == 'image') ...[
                              const SizedBox(height: 16),
                              _buildMediaPreview(
                                title: 'Image',
                                icon: Icons.image_rounded,
                                onTap: _pickImage,
                                mediaSelected: _imageFile != null,
                                mediaPreview: _imageFile != null
                                    ? ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.file(
                                    _imageFile!,
                                    height: 200,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                )
                                    : null,
                              ),
                            ],

                            if (_postType == 'video') ...[
                              const SizedBox(height: 16),
                              _buildMediaPreview(
                                title: 'Video',
                                icon: Icons.video_file_rounded,
                                onTap: _pickVideo,
                                mediaSelected: _videoFile != null,
                                mediaPreview: _videoFile != null
                                    ? Container(
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: veryLightBlue,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: accentBlue.withOpacity(0.5)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: accentBlue.withOpacity(0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.play_arrow_rounded,
                                            color: accentBlue, size: 30),
                                      ),
                                      SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Video selected',
                                              style: TextStyle(
                                                color: darkBlue,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 16,
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              'Ready to upload',
                                              style: TextStyle(
                                                color: Colors.black54,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                    : null,
                              ),
                            ],

                            const SizedBox(height: 16),

                            _buildTextField(
                              controller: _insightsController,
                              labelText: 'Project Insights',
                              hintText: 'Add step-by-step instructions and resource links...',
                              prefixIcon: Icons.lightbulb_outline_rounded,
                              maxLines: 6,
                            ),
                          ],
                        ),
                      ),

                      // User information card
                      SizedBox(height: 16),
                      _buildMaterialCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeaderRow(
                              icon: Icons.person_rounded,
                              title: 'Post Author',
                            ),
                            SizedBox(height: 16),
                            Row(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: accentBlue.withOpacity(0.5), width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: shadowColor.withOpacity(0.1),
                                        blurRadius: 8,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(30),
                                    child: _userImageUrl.isNotEmpty
                                        ? CachedNetworkImage(
                                      imageUrl: _userImageUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        color: lightBlue.withOpacity(0.3),
                                        child: Icon(Icons.person, color: primaryBlue, size: 30),
                                      ),
                                      errorWidget: (context, url, error) => Container(
                                        color: lightBlue.withOpacity(0.3),
                                        child: Icon(Icons.person, color: primaryBlue, size: 30),
                                      ),
                                    )
                                        : Container(
                                      color: lightBlue.withOpacity(0.3),
                                      child: Icon(Icons.person, color: primaryBlue, size: 30),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _userName.isNotEmpty ? _userName : 'Anonymous',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: darkBlue,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Your posts help others learn and grow',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
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

                      SizedBox(height: 100), // Space for floating button
                    ],
                  ),
                ),
              ],
            ),

            // Floating action button at the bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  boxShadow: [
                    BoxShadow(
                      color: shadowColor.withOpacity(0.1),
                      blurRadius: 10,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: ElevatedButton(
                    onPressed: _isUploading ? null : _uploadPost,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentBlue,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[300],
                      disabledForegroundColor: Colors.grey[500],
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _isUploading
                            ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                            : Icon(Icons.cloud_upload_rounded, size: 24),
                        SizedBox(width: 12),
                        Text(
                          _isUploading ? 'Uploading...' : 'Publish Post',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTips() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.symmetric(vertical: 12),
              width: double.infinity,
              alignment: Alignment.center,
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryBlue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.tips_and_updates_rounded, color: primaryBlue, size: 24),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Tips for a Great Post',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: darkBlue,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1),
            Expanded(
              child: ListView(
                padding: EdgeInsets.all(20),
                physics: BouncingScrollPhysics(),
                children: [
                  _buildTipItem(
                    icon: Icons.title_rounded,
                    title: 'Craft a Clear Title',
                    description: 'Your title should be concise and descriptive. Its the first thing others will see.',
                  ),
                  _buildTipItem(
                    icon: Icons.format_align_left_rounded,
                    title: 'Structured Content',
                    description: 'Organize your content with clear sections. Use paragraphs to improve readability.',
                  ),
                  _buildTipItem(
                    icon: Icons.image_rounded,
                    title: 'Quality Media',
                    description: 'If including images or videos, ensure they are clear and relevant to your content.',
                  ),
                  _buildTipItem(
                    icon: Icons.code_rounded,
                    title: 'Format Code Properly',
                    description: 'When posting code, include comments and ensure proper indentation.',
                  ),
                  _buildTipItem(
                    icon: Icons.lightbulb_outline_rounded,
                    title: 'Add Valuable Insights',
                    description: 'Share your learning process, challenges faced, and resources that helped you.',
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Got it',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: veryLightBlue.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: primaryBlue, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: darkBlue,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: child,
      ),
    );
  }

  Widget _buildHeaderRow({
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: primaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: primaryBlue, size: 20),
        ),
        SizedBox(width: 12),
        Text(
          title,
          style: GoogleFonts.poppins(
            color: darkBlue,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildPostTypeSelector() {
    return Container(
      height: 70,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: BouncingScrollPhysics(),
        children: [
          _buildPostTypeOption(
            title: 'Text',
            icon: Icons.text_fields_rounded,
            isSelected: _postType == 'text',
            onTap: () {
              setState(() {
                _postType = 'text';
                _imageFile = null;
                _videoFile = null;
              });
              HapticFeedback.lightImpact();
            },
          ),
          _buildPostTypeOption(
            title: 'Code',
            icon: Icons.code_rounded,
            isSelected: _postType == 'code',
            onTap: () {
              setState(() {
                _postType = 'code';
                _imageFile = null;
                _videoFile = null;
              });
              HapticFeedback.lightImpact();
            },
          ),
          _buildPostTypeOption(
            title: 'Image',
            icon: Icons.image_rounded,
            isSelected: _postType == 'image',
            onTap: () {
              setState(() {
                _postType = 'image';
                _videoFile = null;
              });
              _pickImage();
              HapticFeedback.lightImpact();
            },
          ),
          _buildPostTypeOption(
            title: 'Video',
            icon: Icons.video_library_rounded,
            isSelected: _postType == 'video',
            onTap: () {
              setState(() {
                _postType = 'video';
                _imageFile = null;
              });
              _pickVideo();
              HapticFeedback.lightImpact();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPostTypeOption({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        margin: EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isSelected ? primaryBlue : veryLightBlue,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.transparent : lightBlue.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : primaryBlue,
              size: 24,
            ),
            SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : darkBlue,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDomainSelector() {
    return Container(
      height: 110, // Increased height to prevent overflow
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: BouncingScrollPhysics(),
        children: _domains.map((domain) {
          bool isSelected = _selectedDomain == domain['name'];
          return _buildDomainOption(
            title: domain['name'],
            icon: domain['icon'],
            isSelected: isSelected,
            onTap: () {
              setState(() {
                _selectedDomain = domain['name'];
              });
              HapticFeedback.lightImpact();
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDomainOption({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 110, // Slightly reduced width
        margin: EdgeInsets.only(right: 12),
        padding: EdgeInsets.all(10), // Reduced padding
        decoration: BoxDecoration(
          color: isSelected ? accentBlue.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? accentBlue : Colors.grey.withOpacity(0.2),
            width: isSelected ? 2 : 1, // Thinner border for non-selected
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min, // Added to prevent overflow
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? accentBlue.withOpacity(0.2) : veryLightBlue,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? accentBlue : primaryBlue,
                size: 22, // Slightly smaller icon
              ),
            ),
            SizedBox(height: 8),
            Flexible( // Wrapped in Flexible to prevent overflow
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? darkBlue : Colors.black87,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 12, // Slightly smaller font
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    String? hintText,
    IconData? prefixIcon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(fontSize: 16),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: primaryBlue) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: lightBlue),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primaryBlue, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
        ),
        filled: true,
        fillColor: veryLightBlue.withOpacity(0.3),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: TextStyle(
          color: darkBlue,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: TextStyle(
          color: Colors.grey[400],
          fontWeight: FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildMediaPreview({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    required bool mediaSelected,
    Widget? mediaPreview,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: mediaSelected ? accentBlue.withOpacity(0.1) : veryLightBlue,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: mediaSelected ? accentBlue : lightBlue.withOpacity(0.5),
                width: mediaSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: mediaSelected ? accentBlue.withOpacity(0.2) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: mediaSelected ? accentBlue : primaryBlue,
                    size: 24,
                  ),
                ),
                SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mediaSelected ? 'Change $title' : 'Select $title',
                      style: TextStyle(
                        color: mediaSelected ? accentBlue : primaryBlue,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      mediaSelected ? '$title selected' : 'Tap to browse files',
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: mediaSelected ? Colors.green[50] : Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    mediaSelected ? Icons.check_circle : Icons.add_circle_outline,
                    color: mediaSelected ? Colors.green[600] : primaryBlue,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (mediaSelected && mediaPreview != null) ...[
          SizedBox(height: 16),
          Stack(
            alignment: Alignment.topRight,
            children: [
              mediaPreview,
              if (_postType == 'image')
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _imageFile = null;
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close, color: Colors.white, size: 18),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}