import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UploadNoteScreen extends StatefulWidget {
  @override
  _UploadNoteScreenState createState() => _UploadNoteScreenState();
}

class _UploadNoteScreenState extends State<UploadNoteScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String? _userEmail;
  String? _userName;
  String? _userId;
  File? _selectedFile;
  String? _fileName;
  bool _isUploading = false;
  bool _isLoading = true;
  bool _nameIsEditable = true;

  // Progress tracking variables
  double _uploadProgress = 0.0;
  bool _showUploadDialog = false;

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
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get user ID
      final user = _auth.currentUser;
      if (user != null) {
        _userId = user.uid;
        _userEmail = user.email;
      } else {
        // If no authenticated user, use stored userId from SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        _userId = prefs.getString('userId') ?? '';
      }

      if (_userId != null && _userId!.isNotEmpty) {
        // Check if user has already set their name
        final prefs = await SharedPreferences.getInstance();
        _userName = prefs.getString('userName');

        if (_userName != null && _userName!.isNotEmpty) {
          _nameController.text = _userName!;
          _nameIsEditable = false;
        }

        // Also check Firestore for existing notes with this user ID to get the name
        if (_userName == null || _userName!.isEmpty) {
          final noteSnapshot = await _firestore
              .collection('notes')
              .where('userId', isEqualTo: _userId)
              .limit(1)
              .get();

          if (noteSnapshot.docs.isNotEmpty) {
            final noteData = noteSnapshot.docs.first.data();
            if (noteData['userName'] != null && noteData['userName']
                .toString()
                .isNotEmpty) {
              _userName = noteData['userName'];
              _nameController.text = _userName!;
              _nameIsEditable = false;

              // Save to SharedPreferences
              await prefs.setString('userName', _userName!);
            }
          }
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [lightColor, Color(0xFFE7F0FE)],
        ),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              SizedBox(height: 24),
              _buildUserInfoSection(),
              SizedBox(height: 24),
              _buildNoteDetailsSection(),
              SizedBox(height: 24),
              _buildFilePickerSection(),
              SizedBox(height: 32),
              _buildUploadButton(),

              // Upload Progress Dialog
              if (_showUploadDialog)
                _buildUploadProgressDialog(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.cloud_upload, color: Colors.white, size: 28),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Share Your Notes',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Help others learn from your handwritten notes',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfoSection() {
    return Container(
      padding: EdgeInsets.all(0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: lightColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.person, color: primaryColor),
                SizedBox(width: 10),
                Text(
                  'Your Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: darkColor,
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, thickness: 1, color: Colors.grey.shade100),

          // Form fields
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User email display (not editable)
                if (_userEmail != null)
                  _buildInfoDisplay(
                    icon: Icons.email_outlined,
                    title: 'Email',
                    value: _userEmail!,
                  ),

                SizedBox(height: 16),

                // Name field (editable only once)
                _buildModernTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  icon: Icons.person_outline,
                  hint: 'Enter your full name',
                  enabled: _nameIsEditable,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),

                if (!_nameIsEditable)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, left: 8.0),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 14,
                            color: Colors.grey.shade600),
                        SizedBox(width: 6),
                        Text(
                          'Your name cannot be changed',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
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
    );
  }

  Widget _buildNoteDetailsSection() {
    return Container(
      padding: EdgeInsets.all(0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: lightColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.note_alt, color: primaryColor),
                SizedBox(width: 10),
                Text(
                  'Note Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: darkColor,
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, thickness: 1, color: Colors.grey.shade100),

          // Form fields
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildModernTextField(
                  controller: _titleController,
                  label: 'Title',
                  icon: Icons.title,
                  hint: 'Enter a descriptive title',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                _buildModernTextField(
                  controller: _descriptionController,
                  label: 'Description',
                  icon: Icons.description_outlined,
                  hint: 'What is this note about?',
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a description';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilePickerSection() {
    return Container(
      padding: EdgeInsets.all(0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: lightColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.file_copy_outlined, color: primaryColor),
                SizedBox(width: 10),
                Text(
                  'Note File',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: darkColor,
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, thickness: 1, color: Colors.grey.shade100),

          // File selection
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Selected file display
                if (_fileName != null)
                  Container(
                    margin: EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: primaryColor.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // File header with delete button
                        Padding(
                          padding: EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.picture_as_pdf,
                                    color: Colors.red.shade700, size: 20),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Selected File',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      _fileName!,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: darkColor,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                    Icons.delete_outline, color: errorColor),
                                onPressed: () {
                                  setState(() {
                                    _selectedFile = null;
                                    _fileName = null;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),

                        // File type indicator
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(12),
                              bottomRight: Radius.circular(12),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'PDF Document',
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // File picker button
                Center(
                  child: _fileName == null
                      ? _buildFileDragArea()
                      : TextButton.icon(
                    onPressed: _pickFile,
                    icon: Icon(Icons.change_circle_outlined),
                    label: Text('Change File'),
                    style: TextButton.styleFrom(
                      foregroundColor: primaryColor,
                      padding: EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileDragArea() {
    return InkWell(
      onTap: _pickFile,
      child: Container(
        padding: EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: lightColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey.shade300,
            width: 2,

          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.cloud_upload_outlined,
              size: 48,
              color: primaryColor,
            ),
            SizedBox(height: 16),
            Text(
              'Tap to select PDF file',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: darkColor,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Share your handwritten notes as PDF',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isUploading ? null : _uploadNote,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: Colors.grey.shade300,
        ),
        child: _isUploading
            ? Row(
          mainAxisSize: MainAxisSize.min,
          // Fix overflow by setting mainAxisSize to min
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 2,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Uploading...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        )
            : Row(
          mainAxisSize: MainAxisSize.min,
          // Fix overflow by setting mainAxisSize to min
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_upload_outlined),
            SizedBox(width: 8),
            Text(
              'Upload Note',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadProgressDialog() {
    return Container(
      margin: EdgeInsets.only(top: 32),
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.15),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress indicator with percentage in center
          Stack(
            alignment: Alignment.center,
            children: [
              // Circular progress indicator
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: _uploadProgress / 100,
                  strokeWidth: 8,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _uploadProgress < 30 ? primaryColor.withOpacity(0.7) :
                    _uploadProgress < 70 ? primaryColor :
                    successColor,
                  ),
                ),
              ),
              // Percentage text
              Column(
                children: [
                  Text(
                    '${_uploadProgress.round()}%',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: darkColor,
                    ),
                  ),
                  Text(
                    'Uploading',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),

          SizedBox(height: 32),

          // Upload status message
          Text(
            _getUploadStatusMessage(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: darkColor,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 8),

          Text(
            'Please keep the app open during upload',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 24),

          // Progress steps
          _buildProgressSteps(),
        ],
      ),
    );
  }

  Widget _buildProgressSteps() {
    return Column(
      children: [
        _buildProgressStep(
          title: 'Preparing files',
          isCompleted: _uploadProgress >= 20,
          isActive: _uploadProgress < 20,
        ),
        _buildProgressStep(
          title: 'Uploading to Library',
          isCompleted: _uploadProgress >= 85,
          isActive: _uploadProgress >= 20 && _uploadProgress < 85,
        ),
        _buildProgressStep(
          title: 'Finalizing',
          isCompleted: _uploadProgress >= 100,
          isActive: _uploadProgress >= 85 && _uploadProgress < 100,
        ),
      ],
    );
  }

  Widget _buildProgressStep({
    required String title,
    required bool isCompleted,
    required bool isActive,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // Status icon
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: isCompleted ? successColor :
              isActive ? primaryColor : Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                isCompleted ? Icons.check : isActive
                    ? Icons.hourglass_top
                    : Icons.circle,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),

          SizedBox(width: 16),

          // Step title
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isActive || isCompleted ? FontWeight.bold : FontWeight
                  .normal,
              color: isActive ? primaryColor :
              isCompleted ? darkColor : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoDisplay({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: lightColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey.shade600, size: 18),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: darkColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    int maxLines = 1,
    bool enabled = true,
    required String? Function(String?) validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: darkColor,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          enabled: enabled,
          validator: validator,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400),
            prefixIcon: Icon(icon, color: primaryColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryColor, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: errorColor),
            ),
            filled: true,
            fillColor: enabled ? Colors.white : Colors.grey.shade100,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            suffixIcon: !enabled
                ? Icon(Icons.lock_outline, color: Colors.grey.shade400)
                : null,
          ),
          style: TextStyle(
            color: enabled ? darkColor : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  String _getUploadStatusMessage() {
    if (_uploadProgress < 20) {
      return "Preparing your document for upload";
    } else if (_uploadProgress < 85) {
      return "Uploading your notes to the cloud";
    } else if (_uploadProgress < 100) {
      return "Almost done! Finalizing your upload";
    } else {
      return "Upload complete!";
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
        _fileName = result.files.single.name;
      });
    }
  }

  Future<void> _uploadNote() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedFile == null) {
        _showErrorSnackBar('Please select a PDF file');
        return;
      }

      _formKey.currentState!.save();
      setState(() {
        _isUploading = true;
        _showUploadDialog = true;
        _uploadProgress = 0.0;
      });

      try {
        if (_userId == null || _userId!.isEmpty) {
          final user = _auth.currentUser;
          if (user != null) {
            _userId = user.uid;
          } else {
            final prefs = await SharedPreferences.getInstance();
            _userId = prefs.getString('userId');
            if (_userId == null || _userId!.isEmpty) {
              throw Exception('User ID not found');
            }
          }
        }

        // Simulate initial processing
        await _simulateProgress(0, 15);

        // Save user name to SharedPreferences if it's the first time
        if (_nameIsEditable) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userName', _nameController.text);
          setState(() {
            _userName = _nameController.text;
            _nameIsEditable = false;
          });
        }

        // Simulate preparation
        await _simulateProgress(15, 20);

        // Upload file to Firebase Storage with progress tracking
        final fileName = 'notes/${_userId}_${DateTime
            .now()
            .millisecondsSinceEpoch}.pdf';
        final storageRef = _storage.ref().child(fileName);

        final uploadTask = storageRef.putFile(_selectedFile!);

        // Track real upload progress
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          final progress = (snapshot.bytesTransferred / snapshot.totalBytes) *
              65;
          setState(() {
            _uploadProgress = 20 +
                progress; // 20% was already simulated, the upload is 65% of the process
          });
        });

        await uploadTask;
        final fileUrl = await storageRef.getDownloadURL();

        // Simulate database operations
        await _simulateProgress(85, 100);

        // Create note document in Firestore
        await _firestore.collection('notes').add({
          'title': _titleController.text,
          'description': _descriptionController.text,
          'fileUrl': fileUrl,
          'userId': _userId,
          'userName': _nameController.text,
          'userImageUrl': '', // Add profile image functionality later if needed
          'likes': 0,
          'dislikes': 0,
          'views': 0,
          'rating': 0.0,
          'ratingCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Keep dialog visible for a moment at 100%
        await Future.delayed(Duration(milliseconds: 800));

        // Clear form
        _titleController.clear();
        _descriptionController.clear();
        setState(() {
          _selectedFile = null;
          _fileName = null;
          _showUploadDialog = false;
        });

        // Show success message
        _showSuccessDialog();
      } catch (e) {
        print('Error uploading note: $e');
        setState(() {
          _showUploadDialog = false;
        });
        _showErrorSnackBar('Error uploading note: ${e.toString()}');
      } finally {
        if (mounted) {
          setState(() {
            _isUploading = false;
          });
        }
      }
    }
  }

  // Helper method to simulate progress steps
  Future<void> _simulateProgress(double from, double to) async {
    final steps = 5;
    final increment = (to - from) / steps;
    for (int i = 0; i < steps; i++) {
      await Future.delayed(Duration(milliseconds: 150)); // Simulate work
      setState(() {
        _uploadProgress = from + (increment * (i + 1));
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: EdgeInsets.all(16),
        elevation: 4,
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: TweenAnimationBuilder(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 500),
              curve: Curves.easeOutBack,
              builder: (context, double value, child) {
                return Transform.scale(
                  scale: value,
                  child: child,
                );
              },
              child: Container(
                width: MediaQuery
                    .of(context)
                    .size
                    .width * 0.85, // Set max width
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Success checkmark with animation
                    TweenAnimationBuilder(
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      duration: Duration(milliseconds: 800),
                      curve: Curves.elasticOut,
                      builder: (context, double value, child) {
                        return Transform.scale(
                          scale: value,
                          child: child,
                        );
                      },
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: successColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_circle,
                          color: successColor,
                          size: 60,
                        ),
                      ),
                    ),

                    SizedBox(height: 24),

                    Text(
                      'Upload Successful!',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: darkColor,
                      ),
                    ),

                    SizedBox(height: 16),

                    Text(
                      'Your note has been successfully uploaded and is now available in the library.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade700,
                      ),
                    ),

                    SizedBox(height: 24),

                    // Animated progress bar
                    TweenAnimationBuilder(
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      duration: Duration(milliseconds: 1000),
                      curve: Curves.easeOut,
                      builder: (context, double value, child) {
                        return Column(
                          children: [
                            // Rounded progress bar
                            Container(
                              height: 6,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    height: 6,
                                    width: MediaQuery
                                        .of(context)
                                        .size
                                        .width * 0.7 * value,
                                    // Responsive width
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [primaryColor, successColor],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: 8),

                            // Status text
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Upload Status',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                Text(
                                  'Complete',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: successColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),

                    SizedBox(height: 24),

                    // Action buttons with animation
                    TweenAnimationBuilder(
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      duration: Duration(milliseconds: 600),
                      curve: Curves.easeOutQuad,
                      builder: (context, double value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1 - value)),
                            child: child,
                          ),
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Wrap buttons with Flexible widgets
                          Flexible(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: primaryColor,
                                side: BorderSide(color: primaryColor),
                                padding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('View My Uploads'),
                              ),
                            ),
                          ),
                          SizedBox(width: 12), // Reduced from 16
                          Flexible(
                            child: ElevatedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: successColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text('Done'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

// Alternative approach - using Wrap instead of Row for buttons
  void _showSuccessDialogWithWrap() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: TweenAnimationBuilder(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 500),
              curve: Curves.easeOutBack,
              builder: (context, double value, child) {
                return Transform.scale(
                  scale: value,
                  child: child,
                );
              },
              child: Container(
                width: MediaQuery
                    .of(context)
                    .size
                    .width * 0.85,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Same content as before...

                    // Instead of Row, use Wrap for the buttons
                    TweenAnimationBuilder(
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      duration: Duration(milliseconds: 600),
                      curve: Curves.easeOutQuad,
                      builder: (context, double value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1 - value)),
                            child: child,
                          ),
                        );
                      },
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primaryColor,
                              side: BorderSide(color: primaryColor),
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text('View My Uploads'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: successColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text('Done'),
                          ),
                        ],
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