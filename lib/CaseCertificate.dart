import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class CertificatePage extends StatefulWidget {
  final String caseStudyId;
  final String userId;
  final String problemTitle;
  final String problemDescription;
  final String skills;
  final String domain;
  final String outcome;

  const CertificatePage({
    required this.caseStudyId,
    required this.userId,
    required this.problemTitle,
    required this.problemDescription,
    required this.skills,
    required this.domain,
    required this.outcome,
  });

  @override
  _CertificatePageState createState() => _CertificatePageState();
}

class _CertificatePageState extends State<CertificatePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  late Razorpay _razorpay;
  bool isLoading = false;
  bool isCertificateGenerated = false;
  bool showDetailsExpanded = false;
  String? certificateId;

  // Add price related variables
  int certificatePrice = 500; // Default price in INR
  bool isPriceFetched = false;

  // Define color palette to match previous screens
  final Color primaryBlue = Color(0xFF1976D2);
  final Color lightBlue = Color(0xFF64B5F6);
  final Color veryLightBlue = Color(0xFFE3F2FD);
  final Color darkBlue = Color(0xFF0D47A1);
  final Color accentBlue = Color(0xFF29B6F6);

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _loadUserData();
    _checkExistingCertificate();
    _fetchCertificatePrice(); // Add this line to fetch the price
  }

  // Add this method to fetch certificate price from Firestore
  Future<void> _fetchCertificatePrice() async {
    try {
      var priceDoc = await FirebaseFirestore.instance
          .collection('certificate_price')
          .doc('current') // Assuming you store the current price in a document called 'current'
          .get();

      if (priceDoc.exists && priceDoc.data() != null) {
        setState(() {
          // Get the price from Firestore and convert to integer
          certificatePrice = priceDoc.data()!['price'] ?? 500;
          isPriceFetched = true;
        });
      }
    } catch (e) {
      print('Error fetching certificate price: $e');
      // Keep using the default price if there's an error
    }
  }

  Future<void> _loadUserData() async {
    var user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        var profile = await FirebaseFirestore.instance
            .collection('studentprofile')
            .doc(widget.userId)
            .get();
        if (profile.exists) {
          setState(() {
            _nameController.text = profile.data()?['fullName'] ?? '';
            _mobileController.text = profile.data()?['phoneNumber'] ?? '';
            _emailController.text = user.email ?? '';
          });
        }
      } catch (e) {
        print('Error loading user data: $e');
      }
    }
  }

  Future<void> _checkExistingCertificate() async {
    setState(() => isLoading = true);

    try {
      var certificateDoc = await FirebaseFirestore.instance
          .collection('case_studies_certificates')
          .doc(widget.userId + '_' + widget.caseStudyId)
          .get();

      if (certificateDoc.exists &&
          certificateDoc.data()?['paymentStatus'] == 'success') {
        setState(() {
          isCertificateGenerated = true;
          certificateId = certificateDoc.id;
        });
      }
    } catch (e) {
      print('Error checking certificate: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _openCheckout() async {
    if (!_formKey.currentState!.validate()) return;

    var options = {
      'key': 'rzp_live_yP3PuDH5boPpyU', // Replace with your Razorpay Key
      'amount': certificatePrice * 100, // Amount in paise (converting INR to paise)
      'name': 'Case Study Certificate',
      'description': 'Payment for Certificate: ${widget.problemTitle}',
      'prefill': {
        'contact': _mobileController.text,
        'email': _emailController.text,
        'name': _nameController.text,
      },
      'external': {
        'wallets': ['paytm']
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error initiating payment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    setState(() => isLoading = true);

    try {
      // Generate a unique certificate ID if needed
      final docId = widget.userId + '_' + widget.caseStudyId;

      await FirebaseFirestore.instance
          .collection('case_studies_certificates')
          .doc(docId)
          .set({
        'userId': widget.userId,
        'caseStudyId': widget.caseStudyId,
        'name': _nameController.text,
        'email': _emailController.text,
        'mobileNumber': _mobileController.text,
        'paymentStatus': 'success',
        'paymentId': response.paymentId,
        'problemTitle': widget.problemTitle,
        'problemDescription': widget.problemDescription,
        'domain': widget.domain,
        'skills': widget.skills,
        'outcome': widget.outcome,
        'timestamp': FieldValue.serverTimestamp(),
        'certificateNumber': 'CERT-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
        'certificateStatus': 'pending_verification', // New status field
        'scheduledMeetingTime': null, // Will be set after scheduling
      });

      setState(() {
        isCertificateGenerated = true;
        certificateId = docId;
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment successful! We\'ll contact you to schedule a verification meeting.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing payment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) async {
    setState(() => isLoading = false);

    try {
      await FirebaseFirestore.instance
          .collection('case_studies_certificates')
          .doc(widget.userId + '_' + widget.caseStudyId)
          .set({
        'userId': widget.userId,
        'caseStudyId': widget.caseStudyId,
        'name': _nameController.text,
        'email': _emailController.text,
        'mobileNumber': _mobileController.text,
        'paymentStatus': 'failed',
        'errorCode': response.code.toString(),
        'errorMessage': response.message,
        'problemTitle': widget.problemTitle,
        'problemDescription': widget.problemDescription,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error recording failed payment: $e');
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment failed: ${response.message}'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('External wallet selected: ${response.walletName}'),
        backgroundColor: primaryBlue,
      ),
    );
  }

  void _toggleShowDetails() {
    setState(() {
      showDetailsExpanded = !showDetailsExpanded;
    });
  }

  void _showScheduleMeetingInfo() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.calendar_month, color: primaryBlue),
              SizedBox(width: 10),
              Text('Verification Meeting', style: TextStyle(color: darkBlue)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What to Expect:',
                  style: TextStyle(fontWeight: FontWeight.bold, color: darkBlue),
                ),
                SizedBox(height: 8),
                Text('• A 15-20 minute video call with one of our mentors'),
                Text('• Discussion about your case study solutions'),
                Text('• Verification of your understanding of key concepts'),
                Text('• Opportunity to ask questions about the domain'),
                SizedBox(height: 16),
                Text(
                  'Next Steps:',
                  style: TextStyle(fontWeight: FontWeight.bold, color: darkBlue),
                ),
                SizedBox(height: 8),
                Text('1. We\'ll contact you within 24-48 hours at ${_emailController.text}'),
                Text('2. You\'ll select a convenient time slot for the meeting'),
                Text('3. After successful verification, we\'ll mail your certificate to your address'),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: veryLightBlue,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: lightBlue),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: primaryBlue, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Please ensure you\'re familiar with all aspects of your case study solution before the meeting.',
                          style: TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: primaryBlue,
              ),
              child: Text('OK, GOT IT'),
            ),
          ],
          backgroundColor: Colors.white,
          elevation: 4,
        );
      },
    );
  }

  @override
  void dispose() {
    _razorpay.clear();
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Theme(
      data: Theme.of(context).copyWith(
        primaryColor: primaryBlue,
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: primaryBlue,
          secondary: accentBlue,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: primaryBlue,
          elevation: 0,
        ),
        scaffoldBackgroundColor: Colors.grey[50],
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            isCertificateGenerated ? 'Certificate Status' : 'Certificate Registration',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(15),
              bottomRight: Radius.circular(15),
            ),
          ),
        ),
        body: isLoading
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
              ),
              SizedBox(height: 16),
              Text(
                'Processing your request...',
                style: TextStyle(
                  color: darkBlue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        )
            : isCertificateGenerated
            ? _buildCertificateStatusView(screenSize)
            : _buildRegistrationForm(screenSize),
      ),
    );
  }

  Widget _buildCertificateStatusView(Size screenSize) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Card
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [darkBlue, primaryBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  Icons.pending_actions,
                  color: Colors.white,
                  size: 48,
                ),
                SizedBox(height: 16),
                Text(
                  'Certificate In Progress',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Your payment was successful. We\'re now scheduling your verification meeting.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'ID: CERT-${certificateId?.substring(0, 8) ?? '00000000'}',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 24),

          // Certificate Preview
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Certificate Preview',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: darkBlue,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: veryLightBlue,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: lightBlue),
                        ),
                        child: Text(
                          'SAMPLE',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Divider(color: lightBlue),
                  SizedBox(height: 16),

                  // Certificate content
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: primaryBlue, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: Offset(0, 2),
                        ),
                      ],
                      image: DecorationImage(
                        image: AssetImage('assets/certificate_bg.png'), // You'll need to add this asset
                        fit: BoxFit.cover,
                        opacity: 0.1,
                      ),
                    ),
                    child: Column(
                      children: [
                        // Header
                        Text(
                          'CERTIFICATE OF COMPLETION',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: darkBlue,
                          ),
                        ),
                        SizedBox(height: 8),

                        // Body
                        Text(
                          'This is to certify that',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          _nameController.text,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'has successfully completed the case study:',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 6),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: accentBlue, width: 2),
                            ),
                          ),
                          child: Text(
                            widget.problemTitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        SizedBox(height: 16),

                        // Domain & Skills
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildCertificateBadge('Domain', widget.domain),
                            _buildCertificateBadge('Skills',
                                widget.skills.split(',').length > 1
                                    ? '${widget.skills.split(',')[0]} +${widget.skills.split(',').length - 1}'
                                    : widget.skills),
                          ],
                        ),

                        SizedBox(height: 12),
                        Text(
                          'with ${widget.outcome}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontStyle: FontStyle.italic,
                            color: Colors.green.shade700,
                            fontSize: 14,
                          ),
                        ),

                        SizedBox(height: 16),
                        Divider(color: lightBlue),
                        SizedBox(height: 16),

                        // Footer
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Date:',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                                Text(
                                  DateTime.now().toString().substring(0, 10),
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                            Image.asset(
                              'assets/signature.png', // You'll need to add this asset
                              height: 40,
                              width: 100,
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Cert ID:',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                                Text(
                                  'PENDING',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.orange[700],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 24),

          // Next Steps
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next Steps',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: darkBlue,
                    ),
                  ),
                  SizedBox(height: 16),

                  _buildNextStepItem(
                    1,
                    'Schedule Verification',
                    'We\'ll contact you within 24-48 hours to schedule your verification meeting.',
                    Icons.calendar_month,
                    Colors.blue,
                  ),

                  _buildNextStepItem(
                    2,
                    'Attend Online Meeting',
                    'Meet with our mentor to verify your understanding and discuss your solution.',
                    Icons.video_call,
                    Colors.green,
                  ),

                  _buildNextStepItem(
                    3,
                    'Receive Certificate',
                    'Upon successful verification, we\'ll send your certificate to your registered address.',
                    Icons.verified,
                    Colors.purple,
                  ),

                  SizedBox(height: 16),
                  OutlinedButton.icon(
                    icon: Icon(Icons.info_outline),
                    label: Text('Meeting Details'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryBlue,
                      side: BorderSide(color: primaryBlue),
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _showScheduleMeetingInfo,
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 24),

          // Contact Info
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: veryLightBlue,
            elevation: 2,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.support_agent, color: primaryBlue),
                      SizedBox(width: 8),
                      Text(
                        'Need Help?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: darkBlue,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text('If you have any questions about the verification process, please contact our support team:'),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.email, size: 16, color: darkBlue),
                      SizedBox(width: 8),
                      Text('support@example.com', style: TextStyle(color: primaryBlue)),
                    ],
                  ),
                  SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.phone, size: 16, color: darkBlue),
                      SizedBox(width: 8),
                      Text('+91 98765 43210', style: TextStyle(color: primaryBlue)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextStepItem(int number, String title, String description, IconData icon, Color color) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: color,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrationForm(Size screenSize) {
    return Padding(
        padding: const EdgeInsets.all(16.0),
    child: Form(
    key: _formKey,
    child: SingleChildScrollView(
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    // Success Banner
    Container(
    width: double.infinity,
    padding: EdgeInsets.all(16),
    decoration: BoxDecoration(
    color: Colors.green[50],
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: Colors.green[300]!),
    ),
    child: Row(
    children: [
    Icon(Icons.check_circle, color: Colors.green, size: 32),
    SizedBox(width: 16),
    Expanded(
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Text(
    'Congratulations!',
    style: TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: Colors.green[800],
    ),
    ),
    SizedBox(height: 4),
    Text(
    'You have successfully completed all levels of this case study.',
    style: TextStyle(
    color: Colors.green[800],
    ),
    ),
    ],
    ),
    ),
    ],
    ),
    ),

    SizedBox(height: 24),

    // Certificate Preview
    Card(
    shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
    ),
    elevation: 4,
    child: Column(
    children: [
    Container(
    width: double.infinity,
    padding: EdgeInsets.all(16),
    decoration: BoxDecoration(
    color: darkBlue,
    borderRadius: BorderRadius.only(
    topLeft: Radius.circular(16),
    topRight: Radius.circular(16),
    ),
    ),
    child: Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
    Icon(Icons.workspace_premium, color: Colors.white),
    SizedBox(width: 8),
    Text(
    'Certificate Preview',
    style: TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    ),
    ),
    ],
    ),
    ),
    Padding(
    padding: EdgeInsets.all(16),
    child: Container(
    width: double.infinity,
    padding: EdgeInsets.all(20),
    decoration: BoxDecoration(
    gradient: LinearGradient(
    colors: [Colors.white, veryLightBlue],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    ),
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: primaryBlue, width: 2),
    ),
    child: Column(
    children: [
    // Certificate content
    Text(
    'CERTIFICATE OF COMPLETION',
    style: TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: darkBlue,
    ),
    ),
    Divider(color: accentBlue),
    SizedBox(height: 12),
    Text(
    'This is to certify that',
    style: TextStyle(fontStyle: FontStyle.italic),
    ),
    SizedBox(height: 8),
    Container(
    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
    BoxShadow(
    color: Colors.grey.withOpacity(0.2),
    spreadRadius: 1,
    blurRadius: 2,
    offset: Offset(0, 1),
    ),
    ],
    ),
    child: Text(
    _nameController.text.isNotEmpty ? _nameController.text : '[Your Name]',
    style: TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: darkBlue,
    ),
    ),
    ),
      SizedBox(height: 8),
      Text(
        widget.problemTitle,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: darkBlue,
        ),
      ),
      SizedBox(height: 16),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildCertificateBadge('Domain', widget.domain),
          _buildCertificateBadge(
              'Skills',
              widget.skills.split(',').length > 1
                  ? '${widget.skills.split(',')[0]} +${widget.skills.split(',').length - 1}'
                  : widget.skills
          ),
        ],
      ),
      SizedBox(height: 12),
      Text(
        'with ${widget.outcome}',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          fontStyle: FontStyle.italic,
          color: Colors.green.shade700,
        ),
      ),
    ],
    ),
    ),
    ),
      Padding(
        padding: EdgeInsets.only(bottom: 16, left: 16, right: 16),
        child: InkWell(
          onTap: _toggleShowDetails,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: veryLightBlue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  showDetailsExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: primaryBlue,
                ),
                SizedBox(width: 8),
                Text(
                  showDetailsExpanded ? 'Hide Details' : 'View Details',
                  style: TextStyle(
                    color: primaryBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      if (showDetailsExpanded)
        Padding(
          padding: EdgeInsets.only(bottom: 16, left: 16, right: 16),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: veryLightBlue.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: lightBlue),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Certification Process:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: darkBlue,
                  ),
                ),
                SizedBox(height: 8),
                _buildProcessStep(
                    '1. Registration',
                    'Complete this form and make the payment.'
                ),
                _buildProcessStep(
                    '2. Verification Meeting',
                    'Our mentor will conduct a video meeting to verify your understanding.'
                ),
                _buildProcessStep(
                    '3. Certificate Delivery',
                    'After successful verification, we will send your certificate by mail.'
                ),
                SizedBox(height: 12),
                Divider(color: lightBlue),
                SizedBox(height: 12),
                Text(
                  'Certificate Benefits:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: darkBlue,
                  ),
                ),
                SizedBox(height: 8),
                _buildBenefitItem('Industry-recognized certification'),
                _buildBenefitItem('Verification by professional mentors'),
                _buildBenefitItem('Digital and physical certificate copies'),
                _buildBenefitItem('Add to your LinkedIn profile and resume'),
              ],
            ),
          ),
        ),
    ],
    ),
    ),

      SizedBox(height: 24),

      // Form Title
      Text(
        'Enter your details to receive your certificate:',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: darkBlue,
        ),
      ),
      SizedBox(height: 16),

      // Input Fields
      TextFormField(
        controller: _nameController,
        decoration: InputDecoration(
          labelText: 'Full Name',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          prefixIcon: Icon(Icons.person, color: primaryBlue),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: primaryBlue, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
        ),
        onChanged: (value) {
          // Force a rebuild to update the preview
          setState(() {});
        },
        validator: (value) =>
        value!.isEmpty ? 'Name is required' : null,
      ),
      SizedBox(height: 16),
      TextFormField(
        controller: _mobileController,
        decoration: InputDecoration(
          labelText: 'Mobile Number',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          prefixIcon: Icon(Icons.phone, color: primaryBlue),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: primaryBlue, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
        ),
        keyboardType: TextInputType.phone,
        validator: (value) => value!.isEmpty || value.length < 10
            ? 'Valid mobile number is required'
            : null,
      ),
      SizedBox(height: 16),
      TextFormField(
        controller: _emailController,
        decoration: InputDecoration(
          labelText: 'Email',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          prefixIcon: Icon(Icons.email, color: primaryBlue),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: primaryBlue, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
        ),
        keyboardType: TextInputType.emailAddress,
        validator: (value) => value!.isEmpty || !value.contains('@')
            ? 'Valid email is required'
            : null,
      ),
      SizedBox(height: 24),

      // Important Notice
      Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange[300]!),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange[700]),
                SizedBox(width: 8),
                Text(
                  'Important Information',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[800],
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'After payment, we will conduct an online meeting with a mentor to verify your understanding of the case study. Upon successful verification, we will send your certificate to your registered address.',
              style: TextStyle(color: Colors.orange[800]),
            ),
          ],
        ),
      ),

      SizedBox(height: 24),

      // Payment Button

      ElevatedButton.icon(
        icon: Icon(Icons.payment),
        label: Text('Pay ₹${certificatePrice} for Certificate'),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          minimumSize: Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 2,
        ),
        onPressed: _openCheckout,
      ),
      SizedBox(height: 16),
      // Payment Button
      isPriceFetched
          ? ElevatedButton.icon(
        icon: Icon(Icons.payment),
        label: Text('Pay ₹${certificatePrice} for Certificate'),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          minimumSize: Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 2,
        ),
        onPressed: _openCheckout,
      )
          : ElevatedButton.icon(
        icon: Icon(Icons.hourglass_empty),
        label: Text('Loading price...'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey[400],
          foregroundColor: Colors.white,
          minimumSize: Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 1,
        ),
        onPressed: null, // Disabled until price is fetched
      ),

      // Terms & Conditions
      Row(
        children: [
          Icon(Icons.check_circle_outline, size: 16, color: Colors.grey[600]),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'By proceeding with payment, you agree to our terms and conditions for certification.',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    ],
    ),
    ),
    ),
    );
  }

  Widget _buildCertificateBadge(String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: veryLightBlue,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: lightBlue),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: primaryBlue,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: darkBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessStep(String title, String description) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.arrow_right, color: primaryBlue, size: 20),
          SizedBox(width: 4),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: darkBlue,
                      fontSize: 14,
                    ),
                  ),
                  TextSpan(
                    text: description,
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.check, color: Colors.green, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(text),
          ),
        ],
      ),
    );
  }
}