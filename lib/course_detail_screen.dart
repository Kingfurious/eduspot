// screens/course_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/course.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

class CourseDetailScreen extends StatefulWidget {
  final Course course;

  CourseDetailScreen({required this.course});

  @override
  _CourseDetailScreenState createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> with SingleTickerProviderStateMixin {
  late Razorpay _razorpay;
  final _formKey = GlobalKey<FormState>();
  String name = '';
  String email = '';
  String phone = '';
  bool _isLoading = false;
  bool _isRegistered = false;

  // For tab controller
  late TabController _tabController;
  final List<String> _tabs = ['Overview', 'Syllabus', 'Instructor', 'Reviews'];

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    _tabController = TabController(length: _tabs.length, vsync: this);
    _checkIfAlreadyRegistered();
  }

  Future<void> _checkIfAlreadyRegistered() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        print("Checking if user is enrolled in course: ${widget.course.id}");
        print("User email: ${user.email}");

        final querySnapshot = await FirebaseFirestore.instance
            .collection('Registrations')
            .where('courseId', isEqualTo: widget.course.id)
            .where('userEmail', isEqualTo: user.email)
            .where('paymentStatus', isEqualTo: 'completed')
            .limit(1)
            .get();

        print("Query executed. Found documents: ${querySnapshot.docs.length}");

        if (querySnapshot.docs.isNotEmpty) {
          print("User is enrolled! Registration data: ${querySnapshot.docs.first.data()}");
        } else {
          print("User is not enrolled in this course");
        }

        setState(() {
          _isRegistered = querySnapshot.docs.isNotEmpty;
          _isLoading = false;

          // Pre-fill form with user data if available
          name = user.displayName ?? '';
          email = user.email ?? '';
        });
      } catch (e) {
        print('Error checking registration: $e');
        setState(() {
          _isLoading = false;
        });
      }


      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('Registrations')
            .where('courseId', isEqualTo: widget.course.id)
            .where('userEmail', isEqualTo: user.email)
            .where('paymentStatus', isEqualTo: 'completed')
            .limit(1)
            .get();

        setState(() {
          _isRegistered = querySnapshot.docs.isNotEmpty;
          _isLoading = false;

          // Pre-fill form with user data if available
          name = user.displayName ?? '';
          email = user.email ?? '';
        });
      } catch (e) {
        print('Error checking registration: $e');
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    setState(() {
      _isLoading = true;
    });

    _saveRegistration(response.paymentId!);

    _showSuccessDialog(response.paymentId!);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment Failed: ${response.message ?? "Unknown error"}'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('External Wallet Selected: ${response.walletName}'),
      ),
    );
  }

  Future<void> _saveRegistration(String paymentId) async {
    try {
      await FirebaseFirestore.instance.collection('Registrations').add({
        'courseId': widget.course.id,
        'courseName': widget.course.name,
        'coursePrice': widget.course.coursePrice,
        'userName': name,
        'userEmail': email,
        'userPhone': phone,
        'paymentId': paymentId,
        'paymentStatus': 'completed',
        'registrationDate': FieldValue.serverTimestamp(),
      });

      // Update enrolledStudents count in the course document
      final courseRef = FirebaseFirestore.instance.collection('Courses').doc(widget.course.id);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(courseRef);
        if (!snapshot.exists) {
          throw Exception("Course does not exist!");
        }

        final currentEnrolled = snapshot.data()?['enrolledStudents'] ?? 0;
        transaction.update(courseRef, {'enrolledStudents': currentEnrolled + 1});
      });

      setState(() {
        _isRegistered = true;
        _isLoading = false;
      });
    } catch (e) {
      print('Error saving registration: $e');
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error completing registration. Please contact support.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _openCheckout() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    _formKey.currentState!.save();

    // Convert course price to paise (assuming the price is in INR)
    int priceInPaise;
    try {
      priceInPaise = (double.parse(widget.course.coursePrice ?? '0') * 100).round();
    } catch (e) {
      priceInPaise = 0;
      print('Error parsing course price: $e');
    }

    var options = {
      'key': 'rzp_live_yP3PuDH5boPpyU',
      'amount': priceInPaise,
      'name': widget.course.name ?? 'Course Registration',
      'description': widget.course.description ?? 'Course Registration Payment',
      'prefill': {
        'contact': phone,
        'email': email,
        'name': name,
      },
      'theme': {
        'color': '#6366F1', // Indigo color
      },
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      print('Error opening Razorpay: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening payment gateway. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSuccessDialog(String paymentId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Success animation with checkmark
                Container(
                  height: 100,
                  width: 100,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.check_circle,
                      color: Colors.green.shade600,
                      size: 70,
                    ),
                  ),
                ),
                SizedBox(height: 24),

                // Success message
                Text(
                  'Registration Successful!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),

                // Course name
                Text(
                  widget.course.name ?? 'This Course',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 24),

                // Payment details with custom styling
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Payment ID:',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            paymentId,
                            style: TextStyle(
                              color: Colors.grey.shade900,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Amount:',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '₹${widget.course.coursePrice ?? "0"}',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 20),

                // Contact information with icon
                Container(
                  padding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue.shade700,
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'We will contact you through the email and mobile number you provided during registration',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 24),

                // Button with gradient and shadow
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.3),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }



  // Add this new method for the enhanced loading indicator
  Widget _buildLoadingIndicator() {
    return Center(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Course icon with animation
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.school,
                  size: 50,
                  color: Colors.indigo,
                ),
              ),
            ),
            SizedBox(height: 32),

            // Course name
            Text(
              "Loading ${widget.course.name ?? 'Course'}",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.indigo.shade800,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),

            // Loading message
            Text(
              "Please wait while we load the course details...",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 40),

            // Custom progress indicator
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: Duration(seconds: 3),
              builder: (context, value, child) {
                return Column(
                  children: [
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: value,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo),
                        minHeight: 10,
                      ),
                    ),
                    SizedBox(height: 8),

                    // Progress text
                    Text(
                      "${(value * 100).toInt()}%",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),

                    // Dynamic loading message
                    SizedBox(height: 16),
                    Text(
                      _getLoadingMessage(value),
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Helper method for dynamic loading messages
  String _getLoadingMessage(double progress) {
    if (progress < 0.3) {
      return "Getting course details...";
    } else if (progress < 0.6) {
      return "Checking enrollment status...";
    } else if (progress < 0.9) {
      return "Preparing course materials...";
    } else {
      return "Almost ready!";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? _buildLoadingIndicator()
          : CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildPriceAndEnrollSection(),
                _buildTabBar(),
              ],
            ),
          ),
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildSyllabusTab(),
                _buildInstructorTab(),
                _buildReviewsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
  bool _isCourseFinished() {
    if (widget.course.endDate == null) return false;

    try {
      // Parse the end date (assuming format is like "4.5.2025" or similar)
      // You might need to adjust this parsing based on your actual date format
      final dateParts = widget.course.endDate!.split('.');
      if (dateParts.length != 3) return false;

      final day = int.tryParse(dateParts[0]) ?? 1;
      final month = int.tryParse(dateParts[1]) ?? 1;
      final year = int.tryParse(dateParts[2]) ?? 2025;

      final endDate = DateTime(year, month, day);
      final now = DateTime.now();

      return now.isAfter(endDate);
    } catch (e) {
      print('Error parsing course end date: $e');
      return false;
    }
  }

  Future<void> _deleteCourseDocument() async {
    try {
      // Show confirmation dialog first
      final shouldDelete = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Delete Course?'),
          content: Text('This course has ended. Do you want to remove it from your enrolled courses?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('KEEP'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('DELETE'),
            ),
          ],
        ),
      ) ?? false;

      if (!shouldDelete) return;

      // Show loading
      setState(() => _isLoading = true);

      // Delete from Registrations collection
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('Registrations')
            .where('courseId', isEqualTo: widget.course.id)
            .where('userEmail', isEqualTo: user.email)
            .get();

        // Delete all matching registration documents
        for (var doc in querySnapshot.docs) {
          await doc.reference.delete();
          print('Deleted registration document: ${doc.id}');
        }
      }

      setState(() {
        _isLoading = false;
        _isRegistered = false;
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Course has been removed from your enrollments'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back to course list
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error deleting course: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing course: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  Widget _buildSliverAppBar() {
    // Extract direct image URL if it's a Google Images URL
    String imageUrl = widget.course.imageUrl ?? '';
    if (imageUrl.contains('imgurl=')) {
      try {
        // Extract the imgurl parameter from Google Images URL
        final urlParamStart = imageUrl.indexOf('imgurl=') + 7; // 7 is length of 'imgurl='
        final urlParamEnd = imageUrl.indexOf('&', urlParamStart);
        if (urlParamEnd > urlParamStart) {
          final encodedUrl = imageUrl.substring(urlParamStart, urlParamEnd);
          // Decode the URL (it's URL encoded in the Google link)
          imageUrl = Uri.decodeFull(encodedUrl);
        }
      } catch (e) {
        print('Error extracting image URL: $e');
        // Fallback to the original URL if extraction fails
      }
    }

    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          widget.course.name ?? 'Course Details',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black45, blurRadius: 10)],
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Course image with improved handling
            imageUrl.startsWith('data:image')
                ? Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: MemoryImage(
                    base64Decode(imageUrl.split(',')[1]),
                  ),
                  fit: BoxFit.cover,
                ),
              ),
            )
                : Image.network(
              imageUrl.isNotEmpty ? imageUrl : 'https://via.placeholder.com/800x400?text=No+Image',
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: Colors.indigo.shade100,
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                          (loadingProgress.expectedTotalBytes ?? 1)
                          : null,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo),
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                print('Error loading image: $error');
                return Container(
                  color: Colors.indigo.shade200,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.indigo.shade600,
                          size: 48,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Image not available',
                          style: TextStyle(
                            color: Colors.indigo.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceAndEnrollSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '₹${widget.course.coursePrice ?? 'Free'}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
                  SizedBox(width: 4),
                  Text(
                    widget.course.duration ?? 'Duration not specified',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ],
          ),
          Spacer(),
          _isRegistered
              ? Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Enrolled',
                      style: TextStyle(
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isCourseFinished())
                Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: TextButton.icon(
                    onPressed: _deleteCourseDocument,
                    icon: Icon(Icons.delete, color: Colors.red),
                    label: Text('Remove Course', style: TextStyle(color: Colors.red)),
                  ),
                ),
            ],
          )
              : ElevatedButton(
            onPressed: _showRegistrationForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Enroll Now',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.indigo,
        unselectedLabelColor: Colors.grey.shade600,
        indicatorColor: Colors.indigo,
        tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Course description
          Text(
            'Description',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            widget.course.description ?? 'No description available',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade800,
              height: 1.5,
            ),
          ),

          SizedBox(height: 24),

          // Course details
          Text(
            'Course Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),

          _buildDetailRow(Icons.calendar_today, 'Start Date', widget.course.startDate ?? 'Not specified'),
          _buildDetailRow(Icons.calendar_today, 'End Date', widget.course.endDate ?? 'Not specified'),
          _buildDetailRow(Icons.speed, 'Level', widget.course.level ?? 'Not specified'),
          _buildDetailRow(Icons.school, 'Prerequisites', widget.course.prerequisites ?? 'None'),

          SizedBox(height: 24),

          // What you'll learn section
          Text(
            'What You\'ll Learn',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),

          if (widget.course.syllabus.isNotEmpty)
            ...widget.course.syllabus.take(4).map((item) =>
                Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item,
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                )
            ).toList()
          else
            Text(
              'No syllabus information available',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),

          if (widget.course.syllabus.length > 4)
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: TextButton.icon(
                onPressed: () {
                  _tabController.animateTo(1); // Switch to Syllabus tab
                },
                icon: Icon(Icons.arrow_forward),
                label: Text('See full syllabus'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.indigo,
                ),
              ),
            ),

          SizedBox(height: 24),

          // Tags section
          if (widget.course.tags.isNotEmpty) ...[
            Text(
              'Tags',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.course.tags.map((tag) =>
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.indigo.shade200),
                    ),
                    child: Text(
                      tag.trim(),
                      style: TextStyle(
                        color: Colors.indigo.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
              ).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.indigo),
          SizedBox(width: 8),
          Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyllabusTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Course Syllabus',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),

          if (widget.course.syllabus.isNotEmpty)
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: widget.course.syllabus.length,
              itemBuilder: (context, index) {
                return Card(
                  margin: EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.indigo,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            widget.course.syllabus[index],
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            )
          else
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.book_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No syllabus information available',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInstructorTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Instructor profile section
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundImage: NetworkImage(
                  widget.course.teacherImage ?? 'https://via.placeholder.com/80x80?text=Instructor',
                ),
                onBackgroundImageError: (exception, stackTrace) {
                  print('Error loading instructor image: $exception');
                },
                backgroundColor: Colors.grey.shade300,
                child: widget.course.teacherImage == null
                    ? Icon(Icons.person, size: 40, color: Colors.grey.shade700)
                    : null,
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.course.teacherName ?? 'Unknown Instructor',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    if (widget.course.teacherEmail != null) ...[
                      Row(
                        children: [
                          Icon(Icons.email, size: 16, color: Colors.grey.shade600),
                          SizedBox(width: 4),
                          Text(
                            widget.course.teacherEmail!,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                    ],
                    if (widget.course.teacherContact != null && widget.course.teacherContact!.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(Icons.phone, size: 16, color: Colors.grey.shade600),
                          SizedBox(width: 4),
                          Text(
                            widget.course.teacherContact!,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 24),

          // Instructor bio
          Text(
            'About the Instructor',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            widget.course.teacherBio ?? 'No instructor bio available',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade800,
              height: 1.5,
            ),
          ),

          // Add courses by this instructor section here
          SizedBox(height: 24),

          Text(
            'Other Courses by this Instructor',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),

          // This would ideally fetch from Firestore, but for now we'll just show a placeholder
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey.shade700),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Courses by this instructor will appear here',
                    style: TextStyle(
                      color: Colors.grey.shade700,
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

  Widget _buildReviewsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rating summary
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  // Large rating display
                  Column(
                    children: [
                      Text(
                        widget.course.rating?.toString() ?? 'N/A',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo.shade800,
                        ),
                      ),
                      Row(
                        children: List.generate(5, (index) {
                          final rating = widget.course.rating ?? 0;
                          return Icon(
                            index < rating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 16,
                          );
                        }),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${widget.course.enrolledStudents ?? 0} students',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: 24),
                  // Rating bars (would be populated from actual review data)
                  Expanded(
                    child: Column(
                      children: [
                        _buildRatingBar(5, 0.7),
                        SizedBox(height: 4),
                        _buildRatingBar(4, 0.2),
                        SizedBox(height: 4),
                        _buildRatingBar(3, 0.05),
                        SizedBox(height: 4),
                        _buildRatingBar(2, 0.03),
                        SizedBox(height: 4),
                        _buildRatingBar(1, 0.02),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 24),

          // Student reviews section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_isRegistered)
                TextButton.icon(
                  onPressed: () {
                    // This would open a review form
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Review feature coming soon!'))
                    );
                  },
                  icon: Icon(Icons.rate_review),
                  label: Text('Add Review'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.indigo,
                  ),
                ),
            ],
          ),

          SizedBox(height: 16),


        ],
      ),
    );
  }

  Widget _buildRatingBar(int stars, double percentage) {
    return Row(
      children: [
        Text(
          '$stars',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
          ),
        ),
        SizedBox(width: 4),
        Icon(Icons.star, size: 14, color: Colors.amber),
        SizedBox(width: 8),
        Expanded(
          child: LinearProgressIndicator(
            value: percentage,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        SizedBox(width: 8),
        Text(
          '${(percentage * 100).toInt()}%',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildMockReview({
    required String name,
    required String date,
    required int rating,
    required String comment,
  }) {
    return Card(
        margin: EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
        padding: EdgeInsets.all(16),
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      CircleAvatar(
        radius: 20,
        backgroundColor: Colors.indigo.shade100,
        child: Text(
          name.substring(0, 1),
          style: TextStyle(
            color: Colors.indigo.shade800,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Row(
              children: [
                Text(
                  date,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
                SizedBox(width: 8),
                ...List.generate(5, (index) {
                  return Icon(
                    index < rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 14,
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    ],
    ),
      SizedBox(height: 12),
      Text(
        comment,
        style: TextStyle(
          fontSize: 16,
          color: Colors.grey.shade800,
        ),
      ),
    ],
    ),
        ),
    );
  }

  void _showRegistrationForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Course Registration',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo.shade800,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Text(
                  'Course: ${widget.course.name}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Price: ₹${widget.course.coursePrice}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.green.shade700,
                  ),
                ),
                SizedBox(height: 24),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        initialValue: name,
                        decoration: InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your name';
                          }
                          return null;
                        },
                        onSaved: (value) => name = value!,
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        initialValue: email,
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
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
                        onSaved: (value) => email = value!,
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        initialValue: phone,
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          prefixIcon: Icon(Icons.phone),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your phone number';
                          }
                          if (value.length < 10) {
                            return 'Please enter a valid phone number';
                          }
                          return null;
                        },
                        onSaved: (value) => phone = value!,
                      ),
                      SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _openCheckout();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Proceed to Payment',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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

  @override
  void dispose() {
    _razorpay.clear();
    _tabController.dispose();
    super.dispose();
  }
}