import 'package:eduspark/UploadProjectForm.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';

class CertificateRequestPage extends StatefulWidget {
  final String projectId;

  const CertificateRequestPage({super.key, required this.projectId});

  @override
  State<CertificateRequestPage> createState() => _CertificateRequestPageState();
}

class _CertificateRequestPageState extends State<CertificateRequestPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late Razorpay _razorpay;
  bool _isPaymentSuccessful = false;
  bool _isPromoCodeApplied = false;
  String? _verificationStatus;
  File? _proofFile;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _promoCodeController = TextEditingController();
  String? _validPromoCode;
  int _certificatePrice = 99; // Default price
  int _discountedPrice = 99; // Default discounted price
  bool _isLoading = true;
  bool _applyingPromo = false;

  // Progress tracking
  int _currentStep = 0;
  final List<String> _steps = ['Submit Details', 'Payment', 'Verification', 'Certificate'];

  @override
  void initState() {
    super.initState();
    _setupRazorpay();
    _fetchCertificatePrice().then((_) {
      _fetchPromoCode().then((_) {
        _checkVerificationStatus();
      });
    });
  }

  void _setupRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  Future<void> _fetchCertificatePrice() async {
    try {
      final priceDoc = await FirebaseFirestore.instance
          .collection('certificate_price')
          .doc('current')
          .get();

      if (priceDoc.exists && priceDoc.data()!.containsKey('price')) {
        setState(() {
          _certificatePrice = priceDoc.data()!['price'];
          _discountedPrice = _certificatePrice; // Initialize with full price
          print("Certificate price loaded from Firebase: $_certificatePrice");
        });
      } else {
        print("Price document doesn't exist or missing 'price' field, using default: $_certificatePrice");
      }
    } catch (e) {
      print("Error fetching certificate price: $e");
      // Keep default price if fetch fails
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchPromoCode() async {
    try {
      final promoDoc = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('promo_codes')
          .get();

      if (promoDoc.exists) {
        setState(() {
          // Print what we got from Firestore for debugging
          print("Fetched promo code from Firestore: ${promoDoc.data()?['certificate_promo']}");
          _validPromoCode = promoDoc.data()?['certificate_promo'] ?? "GOKUL08";
        });
      } else {
        print("Promo code document doesn't exist, using default");
        _validPromoCode = "GOKUL08";
      }
    } catch (e) {
      print("Error fetching promo code: $e");
      // Fallback to default if fetch fails
      _validPromoCode = "GOKUL08";
    }

    // Debug what we have
    print("Valid promo code set to: $_validPromoCode");
  }

  Future<void> _checkVerificationStatus() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('user_answers')
            .doc(user.uid)
            .collection('completed')
            .doc(widget.projectId)
            .get();

        if (doc.exists) {
          // Log the entire document data for debugging
          print("Retrieved document data: ${doc.data()}");

          // Extract all relevant data
          final Map<String, dynamic> data = doc.data() ?? {};
          final String status = data['status']?.toString() ?? 'pending';

          // IMPORTANT: Check for paymentId to determine if payment is actually complete
          final bool hasPayment = data['paymentId'] != null;

          // Check for promo code separately from payment
          final bool hasPromoCode = data['promoCodeApplied'] != null;
          final int? storedDiscountedPrice = data['discountedPrice'] != null ? data['discountedPrice'] as int : null;
          final int? storedOriginalPrice = data['originalPrice'] != null ? data['originalPrice'] as int : null;

          setState(() {
            // Set verification status
            _verificationStatus = status;

            // Set payment status - ONLY based on paymentId presence
            _isPaymentSuccessful = hasPayment;

            // Set promo code status separately
            _isPromoCodeApplied = hasPromoCode;

            // Set prices - ensure we use the stored values if available
            if (storedOriginalPrice != null) {
              _certificatePrice = storedOriginalPrice;
              print("Using stored original price: $_certificatePrice");
            }

            if (storedDiscountedPrice != null && _isPromoCodeApplied) {
              _discountedPrice = storedDiscountedPrice;
              print("Using stored discounted price: $_discountedPrice");
            } else if (storedOriginalPrice != null) {
              // If no discount found but original price exists, use that
              _discountedPrice = storedOriginalPrice;
            }

            // Pre-fill form fields if they exist
            if (data['name'] != null) {
              _nameController.text = data['name'];
            }
            if (data['phoneNumber'] != null) {
              _phoneController.text = data['phoneNumber'];
            }

            // Set promo code if stored
            if (data['promoCodeApplied'] != null) {
              _promoCodeController.text = data['promoCodeApplied'];
            }

            // Set current step based on status
            if (_isPaymentSuccessful) {
              _currentStep = 1;
            }
            if (status == 'pending_manual') {
              _currentStep = 2;
            }
            if (status == 'approved') {
              _currentStep = 3;
            }
          });

          // Detailed logging for debugging
          print("Verification status: $_verificationStatus");
          print("Payment successful: $_isPaymentSuccessful");
          print("Promo applied: $_isPromoCodeApplied");
          print("Certificate price: $_certificatePrice");
          print("Discounted price: $_discountedPrice");
          print("Current step: $_currentStep");
        } else {
          print("No document found for this project ID: ${widget.projectId}");
        }
      } catch (e) {
        print("Error retrieving verification status: $e");
      }
    } else {
      print("No user is currently logged in");
    }
  }

  void _openCheckout() async {
    // First check if payment is already completed to avoid double payments
    if (_isPaymentSuccessful) {
      _showAnimatedDialog(
        title: 'Payment Already Completed',
        message: 'You have already made a payment for this certificate. Please proceed to the next step.',
        icon: Icons.check_circle,
        iconColor: Colors.green,
      );
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      _showAnimatedDialog(
        title: 'Authentication Required',
        message: 'Please log in to continue with the certificate request process.',
        icon: Icons.account_circle,
        iconColor: Colors.blue,
      );
      return;
    }

    if (_nameController.text.isEmpty || _phoneController.text.isEmpty) {
      _showAnimatedDialog(
        title: 'Missing Information',
        message: 'Please provide your full name and phone number to proceed with payment.',
        icon: Icons.info_outline,
        iconColor: Colors.orange,
      );
      return;
    }

    // Update user details in Firestore first to make sure they're saved
    // even if the user doesn't complete payment
    try {
      await FirebaseFirestore.instance
          .collection('user_answers')
          .doc(user.uid)
          .collection('completed')
          .doc(widget.projectId)
          .set({
        'name': _nameController.text,
        'phoneNumber': _phoneController.text,
        'email': user.email,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print("✅ User details updated in Firestore");
    } catch (e) {
      print("⚠️ Error updating user details: $e");
      // Continue anyway since this is not critical
    }

    // Double check the price is correctly set
    int finalPrice = _isPromoCodeApplied ? _discountedPrice : _certificatePrice;

    // Amount in paise (100 paise = ₹1)
    final amountInPaise = finalPrice * 100;

    // Debug information - IMPORTANT FOR TROUBLESHOOTING
    print("⚡️ OPENING RAZORPAY CHECKOUT");
    print("💰 Certificate price: $_certificatePrice");
    print("💰 Discounted price: $_discountedPrice");
    print("💰 Is promo applied: $_isPromoCodeApplied");
    print("💰 Final price being used: $finalPrice");
    print("💰 Amount in paise: $amountInPaise");

    var options = {
      'key': 'rzp_live_yP3PuDH5boPpyU',
      'amount': amountInPaise,
      'name': 'EduSpark Certificate',
      'description': _isPromoCodeApplied
          ? 'Certificate Payment (50% Discount Applied)'
          : 'Certificate Payment',
      'prefill': {
        'contact': _phoneController.text,
        'email': user.email ?? 'user@eduspark.com',
        'name': _nameController.text,
      },
      'theme': {
        'color': '#6366F1', // Updated to match Indigo-500
      },
    };

    try {
      print("🚀 Launching Razorpay with options: $options");
      _razorpay.open(options);
    } catch (e) {
      print("❌ Razorpay Error: $e");
      _showAnimatedDialog(
        title: 'Payment Error',
        message: 'Unable to open payment gateway. Please try again later.',
        icon: Icons.error_outline,
        iconColor: Colors.red,
      );
    }
  }

  Future<void> _verifyPromoCode() async {
    // Get the entered code
    final enteredCode = _promoCodeController.text.trim();

    // Show visual feedback
    setState(() => _applyingPromo = true);

    print("⚡️ VERIFYING PROMO CODE: '$enteredCode'");
    print("⚡️ Valid code from database: '$_validPromoCode'");

    try {
      // Basic validation
      if (enteredCode.isEmpty) {
        _showSnackBar('Please enter a promo code');
        setState(() => _applyingPromo = false);
        return;
      }

      // Check if promo is already applied
      if (_isPromoCodeApplied) {
        setState(() => _applyingPromo = false);
        _showAnimatedDialog(
          title: 'Promo Already Applied',
          message: 'You have already applied a promo code. The discount of 50% has been applied to your certificate.',
          icon: Icons.info_outline,
          iconColor: Colors.blue,
        );
        return;
      }

      // Check if the code matches (ignoring case)
      if (enteredCode.toUpperCase() == _validPromoCode?.toUpperCase()) {
        // Calculate 50% discount
        final originalPrice = _certificatePrice;
        final newPrice = (originalPrice * 0.5).round();

        print("✅ PROMO CODE VERIFIED SUCCESSFULLY!");
        print("💰 Original price: $originalPrice");
        print("💰 New price (50% off): $newPrice");

        // Apply the discount immediately
        setState(() {
          _isPromoCodeApplied = true;
          _discountedPrice = newPrice;
          _applyingPromo = false;
        });

        // Store this in Firestore for tracking
        final user = _auth.currentUser;
        if (user != null) {
          try {
            await FirebaseFirestore.instance
                .collection('user_answers')
                .doc(user.uid)
                .collection('completed')
                .doc(widget.projectId)
                .set({
              'promoCodeApplied': enteredCode,
              'originalPrice': originalPrice,
              'discountedPrice': newPrice,
              'discountAppliedAt': FieldValue.serverTimestamp(),
              // Include all important fields to ensure data consistency
              'isDiscounted': true,
              'discountPercentage': 50,
            }, SetOptions(merge: true));

            print("✅ Promo code details stored successfully in Firestore");
          } catch (e) {
            print("❌ Error storing promo code details: $e");
            // Even if Firestore update fails, we keep the UI updated
          }
        }

        _showAnimatedDialog(
          title: 'Promo Code Applied!',
          message: 'Congratulations! 50% discount has been applied to your certificate. New price: ₹$newPrice',
          icon: Icons.local_offer,
          iconColor: Colors.green,
          showConfetti: true,
        );
      } else {
        print("❌ INVALID PROMO CODE: Does not match valid code");
        setState(() => _applyingPromo = false);
        _showAnimatedDialog(
          title: 'Invalid Promo Code',
          message: 'The promo code you entered is not valid. Please check and try again.',
          icon: Icons.error_outline,
          iconColor: Colors.red,
        );
      }
    } catch (e) {
      print("⚠️ Error verifying promo code: $e");
      setState(() => _applyingPromo = false);
      _showAnimatedDialog(
        title: 'Error',
        message: 'Something went wrong while verifying your promo code. Please try again later.',
        icon: Icons.warning,
        iconColor: Colors.orange,
      );
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    print("✅ Payment successful! ID: ${response.paymentId}");
    setState(() {
      _isPaymentSuccessful = true;
      _currentStep = 1; // Update progress
    });
    _storePaymentDetails(response.paymentId!);
    _showAnimatedDialog(
      title: 'Payment Successful!',
      message: 'Your payment has been processed successfully. We will contact you soon for verification.',
      icon: Icons.check_circle,
      iconColor: Colors.green,
      showConfetti: true,
    );
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    print("❌ Payment Error: ${response.code} - ${response.message}");
    _showAnimatedDialog(
      title: 'Payment Failed',
      message: 'Your payment could not be processed. Please try again.',
      icon: Icons.error_outline,
      iconColor: Colors.red,
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    print("💳 External wallet selected: ${response.walletName}");
    _showSnackBar('External Wallet: ${response.walletName}');
  }

  Future<void> _storePaymentDetails(String paymentId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // First, get the latest project details
      final projectDoc = await FirebaseFirestore.instance.collection('projects').doc(widget.projectId).get();
      final projectTitle = projectDoc.data()?['title'] as String? ?? 'Untitled';

      // Prepare payment data with all critical fields
      final Map<String, dynamic> paymentData = {
        'paymentId': paymentId,
        'name': _nameController.text,
        'phoneNumber': _phoneController.text,
        'email': user.email,
        'projectTitle': projectTitle,
        'originalPrice': _certificatePrice,
        'paidAmount': _discountedPrice,
        'isDiscounted': _isPromoCodeApplied,
        'discountPercentage': _isPromoCodeApplied ? 50 : 0,
        'status': 'pending',
        'paymentTimestamp': FieldValue.serverTimestamp(),
      };

      // If promo code was applied, ensure those details are saved too
      if (_isPromoCodeApplied) {
        paymentData['promoCodeApplied'] = _promoCodeController.text.isEmpty ? "APPLIED" : _promoCodeController.text;
        paymentData['discountedPrice'] = _discountedPrice;
      }

      // Detailed logging for debugging
      print("💾 Storing payment details to Firestore:");
      print(paymentData);

      // Store all payment details in Firestore for tracking
      await FirebaseFirestore.instance
          .collection('user_answers')
          .doc(user.uid)
          .collection('completed')
          .doc(widget.projectId)
          .set(paymentData, SetOptions(merge: true));

      print("✅ Payment details stored in Firestore successfully");

      // Also notify admin via email about the payment
      final String paymentMessage = "Payment completed. Amount: ₹$_discountedPrice" +
          (_isPromoCodeApplied ? " (with 50% discount from original price ₹$_certificatePrice)" : "");

      await _sendVerificationRequestEmail(
          _nameController.text,
          user.email ?? 'unknown@example.com',
          _phoneController.text,
          projectTitle,
          paymentMessage
      );

      // Double-check that the data was stored correctly by retrieving it
      _checkVerificationStatus();
    } catch (e) {
      print("⚠️ Error storing payment details: $e");
      // Handle error appropriately - consider showing a message to the user
    }
  }

  Future<void> _pickProofFile() async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'h5', 'pth', 'csv', 'pdf', 'jpg', 'png']
    );

    if (result != null) {
      setState(() => _proofFile = File(result.files.single.path!));
      print("📁 File selected: ${result.files.single.path!}");
    }
  }

  Future<void> _submitProof() async {
    // First check if already submitted
    if (_verificationStatus == 'pending_manual' || _verificationStatus == 'approved') {
      _showAnimatedDialog(
        title: 'Already Submitted',
        message: 'You have already submitted your proof and it is currently under review or approved.',
        icon: Icons.info_outline,
        iconColor: Colors.blue,
      );
      return;
    }

    final user = _auth.currentUser;
    if (user == null || _proofFile == null) {
      _showAnimatedDialog(
        title: 'Missing File',
        message: 'Please upload a proof file to continue with the verification process.',
        icon: Icons.file_upload_off,
        iconColor: Colors.orange,
      );
      return;
    }

    // Show loading indicator
    _showLoadingDialog('Uploading proof file...');

    try {
      final userName = _nameController.text.trim();
      final userEmail = user.email ?? 'unknown@example.com';
      final phoneNumber = _phoneController.text.trim();

      final projectDoc = await FirebaseFirestore.instance.collection('projects').doc(widget.projectId).get();
      final projectTitle = projectDoc.data()?['title'] as String? ?? 'Untitled';

      // Generate a unique filename with timestamp to avoid cache issues
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExtension = _proofFile!.path.split('.').last;
      final fileName = 'proof_${timestamp}.$fileExtension';

      // Upload file to Firebase Storage
      final ref = FirebaseStorage.instance.ref().child('user_files/${user.uid}/${widget.projectId}/$fileName');
      await ref.putFile(_proofFile!);
      final proofUrl = await ref.getDownloadURL();
      print("📤 File uploaded to Firebase Storage: $proofUrl");

      // Prepare proof submission data
      final Map<String, dynamic> proofData = {
        'name': userName,
        'email': userEmail,
        'phoneNumber': phoneNumber,
        'projectTitle': projectTitle,
        'proofUrl': proofUrl,
        'proofFileName': fileName,
        'proofFileType': fileExtension,
        'status': 'pending_manual',
        'proofSubmittedAt': FieldValue.serverTimestamp(),
      };

      // Ensure we preserve payment and discount information
      if (_isPaymentSuccessful) {
        proofData['paidAmount'] = _discountedPrice;
      }

      if (_isPromoCodeApplied) {
        proofData['isDiscounted'] = true;
        proofData['discountedPrice'] = _discountedPrice;
        proofData['originalPrice'] = _certificatePrice;
      }

      // Store submission details in Firestore
      await FirebaseFirestore.instance
          .collection('user_answers')
          .doc(user.uid)
          .collection('completed')
          .doc(widget.projectId)
          .set(proofData, SetOptions(merge: true));

      // Notify admin about the proof submission
      await _sendVerificationRequestEmail(
          userName,
          userEmail,
          phoneNumber,
          projectTitle,
          "Proof file submitted: $proofUrl\nPayment status: " +
              (_isPaymentSuccessful ? "Paid (₹$_discountedPrice)" : "Not paid yet")
      );

      // Pop loading dialog
      Navigator.of(context).pop();

      setState(() {
        _verificationStatus = 'pending_manual';
        _currentStep = 2; // Update progress
      });

      _showAnimatedDialog(
        title: 'Proof Submitted',
        message: 'Your proof has been submitted successfully! Our team will review it and contact you for the verification meeting.',
        icon: Icons.check_circle,
        iconColor: Colors.green,
      );

      // Refresh data to ensure everything is in sync
      _checkVerificationStatus();
    } catch (e) {
      print("❌ Error submitting proof: $e");
      // Pop loading dialog
      Navigator.of(context).pop();
      _showAnimatedDialog(
        title: 'Upload Failed',
        message: 'Error submitting proof: $e',
        icon: Icons.error_outline,
        iconColor: Colors.red,
      );
    }
  }

  Future<void> _sendVerificationRequestEmail(String userName, String userEmail, String phoneNumber, String projectTitle, String proofUrl) async {
    const adminEmail = 'vijaygokul120@gmail.com';
    final url = Uri.parse('https://your-server.com/send-email'); // Replace with your server endpoint

    try {
      final response = await http.post(url, body: {
        'to': adminEmail,
        'subject': 'Certificate Verification Request for $projectTitle',
        'body': '''
          Student Name: $userName
          Email: $userEmail
          Phone Number: $phoneNumber
          Project Title: $projectTitle
          Project ID: ${widget.projectId}
          Proof URL: $proofUrl
          Payment Amount: ₹$_discountedPrice${_isPromoCodeApplied ? ' (50% discount applied)' : ''}
          Status: Pending manual verification
        ''',
      });

      print("📧 Notification email sent to admin. Status: ${response.statusCode}");
    } catch (e) {
      print("⚠️ Could not send email notification: $e");
      // We don't want to fail the whole process if just the email fails
    }
  }

  void _showAnimatedDialog({
    required String title,
    required String message,
    required IconData icon,
    required Color iconColor,
    bool showConfetti = false,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Column(
            children: [
              if (showConfetti)
                SizedBox(
                  height: 100,
                  width: 100,
                  child: Lottie.network(
                    'https://assets5.lottiefiles.com/packages/lf20_KOxP1cAf5z.json',
                    repeat: false,
                  ),
                ),
              Icon(icon, size: 48, color: iconColor),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          actions: [
            Container(
              width: double.infinity,
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: iconColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message, {int duration = 3}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: duration),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: EdgeInsets.all(8),
        action: message.contains('Error') ? SnackBarAction(
          label: 'OK',
          onPressed: () {},
        ) : null,
      ),
    );
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 100,
                width: 100,
                child: Lottie.network(
                  'https://assets9.lottiefiles.com/packages/lf20_x62chJ.json',
                  repeat: true,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProgressStepper() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Certificate Process',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(_steps.length, (index) {
              final isActive = index <= _currentStep;
              final isCompleted = index < _currentStep;

              return Expanded(
                child: Row(
                  children: [
                    // Circle indicator
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isActive ? Colors.indigo : Colors.grey.shade300,
                        shape: BoxShape.circle,
                        boxShadow: isActive ? [
                          BoxShadow(
                            color: Colors.indigo.withOpacity(0.3),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          )
                        ] : null,
                      ),
                      child: Center(
                        child: isCompleted
                            ? Icon(Icons.check, color: Colors.white, size: 18)
                            : Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    // Line connector (except for the last item)
                    if (index < _steps.length - 1)
                      Expanded(
                        child: Container(
                          height: 3,
                          color: index < _currentStep
                              ? Colors.indigo
                              : Colors.grey.shade300,
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          // Step labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _steps.asMap().entries.map((entry) {
              final index = entry.key;
              final label = entry.value;
              final isActive = index <= _currentStep;

              return Expanded(
                child: Text(
                  label,
                  textAlign: index == 0 ? TextAlign.start :
                  index == _steps.length - 1 ? TextAlign.end : TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: isActive ? Colors.indigo : Colors.grey,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoCodeSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.indigo.shade50, Colors.purple.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.discount_rounded, color: Colors.indigo),
                SizedBox(width: 8),
                Text(
                  "Apply Promo Code",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.indigo.shade800,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),
            Text(
              "Enter a valid promo code to get a discount on your certificate",
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
            ),
            SizedBox(height: 16),
            if (_isPromoCodeApplied)
              Container(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade300, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Promo Code Applied!",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                            ),
                          ),
                          Text(
                            "Your 50% discount has been applied to the final price",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _promoCodeController,
                        decoration: InputDecoration(
                          hintText: 'Enter promo code',
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.indigo, width: 2),
                          ),
                          prefixIcon: Icon(Icons.redeem, color: Colors.indigo),
                        ),
                        style: TextStyle(fontSize: 16),
                        textCapitalization: TextCapitalization.characters,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _applyingPromo ? null : _verifyPromoCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      padding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      minimumSize: Size(100, 48),
                    ),
                    child: _applyingPromo
                        ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : Text('Apply', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceDisplay() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Certificate Price",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "₹",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _isPromoCodeApplied ? Colors.green.shade700 : Colors.indigo.shade700,
                ),
              ),
              _isPromoCodeApplied
                  ? Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "$_certificatePrice",
                    style: TextStyle(
                      fontSize: 24,
                      decoration: TextDecoration.lineThrough,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    "$_discountedPrice",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              )
                  : Text(
                "$_certificatePrice",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo.shade700,
                ),
              ),
              SizedBox(width: 8),
              if (_isPromoCodeApplied)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    "50% OFF",
                    style: TextStyle(
                      color: Colors.green.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            _isPromoCodeApplied
                ? "Discount applied! Original price was ₹$_certificatePrice"
                : "Get your professional certificate for your completed project",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          if (_isPaymentSuccessful)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 18, color: Colors.green),
                  SizedBox(width: 8),
                  Text(
                    "Payment completed",
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCertificationInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.school, color: Colors.indigo, size: 28),
              SizedBox(width: 12),
              Text(
                "Certification Process",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo.shade800,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildProcessStep(
            number: "1",
            title: "Complete Payment",
            description: "Pay the certification fee or apply a valid promo code to proceed",
            isActive: _currentStep >= 0,
          ),
          _buildProcessStep(
            number: "2",
            title: "Expert Evaluation",
            description: "Our experts will review your project and schedule a verification meeting",
            isActive: _currentStep >= 1,
          ),
          _buildProcessStep(
            number: "3",
            title: "Verification Meeting",
            description: "Attend a meeting with our experts to verify your project and knowledge",
            isActive: _currentStep >= 2,
          ),
          _buildProcessStep(
            number: "4",
            title: "Receive Certificate",
            description: "Get your digital certificate via email after successful verification",
            isActive: _currentStep >= 3,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildProcessStep({
    required String number,
    required String title,
    required String description,
    required bool isActive,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Step number circle
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isActive ? Colors.indigo : Colors.grey.shade400,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        // Vertical line connector
        if (!isLast)
          Padding(
            padding: const EdgeInsets.only(left: 13.5),
            child: SizedBox(
              width: 1,
              height: 40,
              child: Container(
                color: isActive ? Colors.indigo : Colors.grey.shade300,
              ),
            ),
          ),
        if (isLast)
          SizedBox(width: 14.5),
        // Step content
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: 12.0, bottom: isLast ? 0 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.indigo.shade800 : Colors.grey.shade700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: isActive ? Colors.indigo.shade700 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('projects').doc(widget.projectId).get(),
      builder: (context, projectSnapshot) {
        if (!projectSnapshot.hasData || _isLoading) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 100,
                    width: 100,
                    child: Lottie.network(
                      'https://assets9.lottiefiles.com/packages/lf20_x62chJ.json',
                      repeat: true,
                    ),
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Loading Certificate Information...',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          );
        }

        final projectData = projectSnapshot.data!.data() as Map<String, dynamic>? ?? {};
        final projectTitle = projectData['title'] ?? 'Untitled';

        return Scaffold(
          appBar: AppBar(
            title: const Text('Certificate Request'),
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with project info
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Container(
                        padding: EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            colors: [Colors.indigo.shade600, Colors.indigo.shade800],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.workspace_premium,
                                    size: 36,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Get Certified',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: 16,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        projectTitle,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 20),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.email,
                                    size: 16,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    user?.email ?? 'Not logged in',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 20),

                    // Progress stepper
                    _buildProgressStepper(),

                    // Personal information section
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Your Information",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            SizedBox(height: 16),
                            TextField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: 'Full Name',
                                hintText: 'Enter your full name',
                                prefixIcon: Icon(Icons.person, color: Colors.indigo),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: Colors.grey.shade200),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: Colors.indigo, width: 2),
                                ),
                              ),
                            ),
                            SizedBox(height: 16),
                            TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                labelText: 'Phone Number',
                                hintText: 'Enter your phone number',
                                prefixIcon: Icon(Icons.phone, color: Colors.indigo),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: Colors.grey.shade200),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: Colors.indigo, width: 2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 20),

                    // Price and Payment section
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Payment Details",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            SizedBox(height: 16),
                            _buildPriceDisplay(),
                            SizedBox(height: 16),
                            _buildPromoCodeSection(),
                            SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton.icon(
                                onPressed: _isPaymentSuccessful ? null : _openCheckout,
                                icon: Icon(Icons.payment, size: 24),
                                label: _isPromoCodeApplied
                                    ? RichText(
                                  text: TextSpan(
                                    style: TextStyle(fontSize: 18, color: Colors.white),
                                    children: [
                                      TextSpan(text: 'Pay '),
                                      TextSpan(
                                        text: '₹$_discountedPrice',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      TextSpan(text: ' for Certificate'),
                                    ],
                                  ),
                                )
                                    : Text(
                                  'Pay ₹$_certificatePrice for Certificate',
                                  style: TextStyle(fontSize: 18),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isPaymentSuccessful ? Colors.green : Colors.indigo,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: EdgeInsets.symmetric(vertical: 14),
                                  elevation: 3,
                                ),
                              ),
                            ),
                            if (_isPaymentSuccessful)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                                    SizedBox(width: 8),
                                    Text(
                                      'Payment completed successfully',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 20),

                    // Certification Process Information
                    _buildCertificationInfo(),

                    SizedBox(height: 20),

                    // Status or Proof upload section based on current status
                    if (_isPaymentSuccessful && _verificationStatus == 'pending') ...[
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Upload Project Proof",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                "Please upload a file to verify your project completion. This will help our experts evaluate your work.",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              SizedBox(height: 16),
                              Container(
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                    width: 1,

                                  ),
                                ),
                                child: _proofFile == null
                                    ? InkWell(
                                  onTap: _pickProofFile,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.indigo.shade50,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.cloud_upload,
                                          size: 40,
                                          color: Colors.indigo,
                                        ),
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        'Click to upload your proof file',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.indigo,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Supported formats: JSON, H5, PTH, CSV, PDF, JPG, PNG',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                    : Column(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.indigo.shade50,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.indigo.shade100,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.insert_drive_file,
                                              color: Colors.indigo,
                                            ),
                                          ),
                                          SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _proofFile!.path.split('/').last,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.indigo.shade800,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                SizedBox(height: 4),
                                                Text(
                                                  'File selected successfully',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.close, color: Colors.red),
                                            onPressed: () => setState(() => _proofFile = null),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(height: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 50,
                                      child: ElevatedButton.icon(
                                        onPressed: _submitProof,
                                        icon: Icon(Icons.upload_file),
                                        label: Text('Submit Proof File'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.indigo,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
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
                    ] else if (_verificationStatus == 'pending_manual') ...[
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              SizedBox(
                                height: 100,
                                width: 100,
                                child: Lottie.network(
                                  'https://assets9.lottiefiles.com/packages/lf20_kseho6rf.json',
                                  repeat: true,
                                ),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Verification In Progress',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Our experts are reviewing your submission. We will contact you soon with details for the verification meeting.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              SizedBox(height: 16),
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.orange.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline, color: Colors.orange),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'You will receive an email with meeting details within 2-3 business days',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.orange.shade800,
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
                    ] else if (_verificationStatus == 'approved') ...[
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              SizedBox(
                                height: 120,
                                width: 120,
                                child: Lottie.network(
                                  'https://assets2.lottiefiles.com/packages/lf20_jAW1Sz.json',
                                  repeat: false,
                                ),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Certificate Approved!',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Congratulations! Your certificate has been approved and sent to your email.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: () {},
                                icon: Icon(Icons.download),
                                label: Text('Download Certificate'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.green.shade700,
                                  side: BorderSide(color: Colors.green.shade300),
                                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else if (_verificationStatus == 'rejected') ...[
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Colors.red,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Verification Not Passed',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade700,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Unfortunately, your verification did not pass. Please check your email for detailed feedback or contact our support team.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              SizedBox(height: 16),
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline, color: Colors.red),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'You can try again by submitting a new proof or contacting support for assistance',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.red.shade800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        // Reset status to try again
                                        setState(() {
                                          _verificationStatus = 'pending';
                                          _isPaymentSuccessful = true;
                                          _currentStep = 1;
                                        });
                                      },
                                      icon: Icon(Icons.refresh),
                                      label: Text('Try Again'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.indigo,
                                        side: BorderSide(color: Colors.indigo.shade300),
                                        padding: EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {},
                                      icon: Icon(Icons.contact_support),
                                      label: Text('Contact Support'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.indigo,
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    SizedBox(height: 20),

                    // Support contact section
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.support_agent, color: Colors.indigo),
                                SizedBox(width: 8),
                                Text(
                                  "Need Help?",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              "If you have any questions or need assistance with your certificate request, please contact our support team.",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: () {},
                              icon: Icon(Icons.email),
                              label: Text('Email Support'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.indigo,
                                side: BorderSide(color: Colors.indigo.shade300),
                                padding: EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _razorpay.clear();
    _nameController.dispose();
    _phoneController.dispose();
    _promoCodeController.dispose();
    super.dispose();
  }
}