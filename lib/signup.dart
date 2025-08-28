import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' show Random;
import 'login_screen.dart';
import 'terms_of_service_screen.dart';
import 'privacy_policy_screen.dart';

// Particle Class for Snow-like Confetti
class Particle {
  double x, y, size, speed, drift;
  Color color;
  final math.Random random;

  Particle(this.random)
      : x = random.nextDouble(),
        y = random.nextDouble() * -1, // Start above the screen
        size = random.nextDouble() * 2 + 1, // Smaller size for snow
        speed = random.nextDouble() * 0.5 + 0.5, // Slower speed (0.5 to 1)
        drift = (random.nextDouble() - 0.5) * 0.2, // Reduced drift for gentler motion
        color = Colors.lightBlue.shade300.withOpacity(random.nextDouble() * 0.5 + 0.5); // Light blue snow

  void update() {
    y += speed * 0.005; // Slower falling rate
    x += drift * 0.005; // Slower horizontal drift
    if (y > 1) {
      y = random.nextDouble() * -0.2; // Reset to just above the screen
      x = random.nextDouble(); // Random x position
      drift = (random.nextDouble() - 0.5) * 0.2; // Reset drift
    }
    if (x > 1 || x < 0) {
      x = random.nextDouble(); // Keep within bounds
    }
  }
}

// Particle Painter
class ParticlePainter extends CustomPainter {
  final List<Particle> particles;

  ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      particle.update();
      final paint = Paint()..color = particle.color;
      canvas.drawCircle(
        Offset(particle.x * size.width, particle.y * size.height),
        particle.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Wave Painter for Card Bottom
class WavePainter extends CustomPainter {
  final double animationValue;

  WavePainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.lightBlue.shade200.withOpacity(0.5);
    final path = Path();

    path.moveTo(0, size.height * 0.7);
    for (double x = 0; x <= size.width; x++) {
      path.lineTo(
        x,
        size.height * 0.7 +
            20 * math.sin((x / size.width * 2 * math.pi) + animationValue * 2 * math.pi),
      );
    }
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Wave Background Painter
class WaveBackgroundPainter extends CustomPainter {
  final double animationValue;

  WaveBackgroundPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.lightBlue.shade200.withOpacity(0.3);
    final path = Path();

    path.moveTo(0, size.height * 0.8);
    for (double x = 0; x <= size.width; x++) {
      path.lineTo(
        x,
        size.height * 0.8 +
            20 * math.sin((x / size.width * 2 * math.pi) + animationValue * 2 * math.pi),
      );
    }
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> with SingleTickerProviderStateMixin {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool isLoading = false;
  bool agreeToTerms = false;
  bool _isPasswordVisible = false;
  Timer? _verificationTimer;
  late AnimationController _controller;
  final math.Random _random = math.Random();
  final List<Particle> _particles = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    for (int i = 0; i < 100; i++) {
      _particles.add(Particle(_random));
    }
  }

  @override
  void dispose() {
    _verificationTimer?.cancel();
    _controller.dispose();
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // Password validation function
  bool isValidPassword(String password) {
    final RegExp regex = RegExp(r'^(?=.*[A-Z])(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{6,}$');
    return regex.hasMatch(password);
  }

  Future<void> signUp() async {
    if (!agreeToTerms) {
      _showErrorDialog("You must agree to the Terms of Service and Privacy Policy.");
      return;
    }

    if (nameController.text.isEmpty ||
        emailController.text.isEmpty ||
        passwordController.text.isEmpty) {
      _showErrorDialog("All fields are required.");
      return;
    }

    if (!isValidPassword(passwordController.text)) {
      _showErrorDialog("Password must be at least 6 characters, include one uppercase letter, and one special character.");
      return;
    }

    setState(() => isLoading = true);

    try {
      UserCredential userCredential =
      await _auth.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      await userCredential.user!.sendEmailVerification();

      await _firestore.collection("users").doc(userCredential.user!.uid).set({
        "name": nameController.text.trim(),
        "email": emailController.text.trim(),
        "created_at": Timestamp.now(),
        "email_verified": false,
      });

      _showEmailVerificationDialog(userCredential.user!);
    } on FirebaseAuthException catch (e) {
      _showErrorDialog(e.message ?? "Sign-up failed");
    }

    setState(() => isLoading = false);
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => Center(
        child: SingleChildScrollView(
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red.shade600, Colors.orange.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    child: Icon(
                      Icons.error_outline,
                      size: 60,
                      color: Colors.red.shade700,
                    ).animate().shake(duration: 600.ms),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Oops!",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ).animate().fadeIn(delay: 300.ms),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ).animate().fadeIn(delay: 400.ms),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    ),
                    child: const Text(
                      "Try Again",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ).animate().slideY(delay: 500.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSuccessView(User user) {
    _verificationTimer?.cancel();
    _firestore.collection("users").doc(user.uid).update({
      "email_verified": true,
    });
    setState(() {
      _currentView = _buildSuccessView();
    });
    HapticFeedback.mediumImpact();
  }

  Widget _buildSuccessView() {
    return Stack(
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            size: MediaQuery.of(context).size,
            painter: ParticlePainter(_particles),
          ),
        ),
        Center(
          child: SingleChildScrollView(
            child: Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.8,
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade600, Colors.teal.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          child: Icon(
                            Icons.check_circle,
                            size: 60,
                            color: Colors.green.shade700,
                          ).animate().scale(duration: 600.ms).then().rotate(),
                        ),
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _SuccessParticlePainter(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Success!",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ).animate().fadeIn(delay: 300.ms),
                    const SizedBox(height: 10),
                    const Text(
                      "Your account is now active and ready to use.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ).animate().fadeIn(delay: 400.ms),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.green.shade700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                      ),
                      child: const Text(
                        "Continue to Login",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ).animate().slideY(delay: 500.ms),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showEmailVerificationDialog(User user) {
    _startVerificationCheck(user);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: Center(
          child: SingleChildScrollView(
            child: Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.8,
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade600, Colors.lightBlue.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.email_outlined,
                        size: 60,
                        color: Colors.blue.shade700,
                      ).animate().shake(duration: 600.ms),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "Verify Your Email",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ).animate().fadeIn(delay: 300.ms),
                    const SizedBox(height: 10),
                    const Text(
                      "We've sent a verification email to your inbox. Please check your email and click the verification link.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ).animate().fadeIn(delay: 400.ms),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          try {
                            await user.sendEmailVerification();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Verification email sent again. Please check your inbox."),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Failed to send verification email. Please try again later."),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.blue.shade700,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                        ),
                        child: const Text(
                          "Resend Verification Email",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ).animate().slideY(delay: 500.ms),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text(
                        "I'll verify later",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _startVerificationCheck(User user) {
    _verificationTimer?.cancel();
    _verificationTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      await user.reload();
      User? refreshedUser = _auth.currentUser;
      if (refreshedUser != null && refreshedUser.emailVerified) {
        timer.cancel();
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        _showSuccessView(refreshedUser);
      }
    });
  }

  Widget? _currentView;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.0,
                colors: [
                  Colors.lightBlue.shade100,
                  Colors.white,
                ],
              ),
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => CustomPaint(
                painter: WaveBackgroundPainter(_controller.value),
                size: Size.infinite,
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: _buildCornerGradient(radius: 100, alignment: Alignment.topLeft),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: _buildCornerGradient(radius: 100, alignment: Alignment.bottomRight),
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(
              size: MediaQuery.of(context).size,
              painter: ParticlePainter(_particles),
            ),
          ),
          _currentView ?? _buildSignUpForm(),
        ],
      ),
    );
  }

  Widget _buildSignUpForm() {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.05),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, 5 * math.sin(_controller.value * 2 * math.pi)),
                child: Container(
                  width: MediaQuery.of(context).size.width > 600
                      ? 400
                      : MediaQuery.of(context).size.width * 0.9,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.lightBlue.shade200.withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 5,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.lightBlue.shade300,
                                ),
                                child: const Icon(
                                  Icons.school,
                                  size: 60,
                                  color: Colors.white,
                                ),
                              ).animate().scale(duration: 600.ms),
                              const SizedBox(height: 32),
                              Text(
                                "EduConnect",
                                style: TextStyle(
                                  fontSize: MediaQuery.of(context).size.width > 600 ? 32 : 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                ),
                              ).animate().fadeIn(delay: 200.ms),
                              const SizedBox(height: 8),
                              Text(
                                "Create Your Account",
                                style: TextStyle(
                                  fontSize: MediaQuery.of(context).size.width > 600 ? 16 : 14,
                                  color: Colors.blue.shade800,
                                ),
                              ).animate().fadeIn(delay: 300.ms),
                              const SizedBox(height: 32),
                              _buildTextField(
                                controller: nameController,
                                hintText: "Full Name",
                                icon: Icons.person,
                              ).animate().slideX(delay: 400.ms),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: emailController,
                                hintText: "Email",
                                icon: Icons.email,
                              ).animate().slideX(delay: 500.ms),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: passwordController,
                                hintText: "Password",
                                icon: Icons.lock,
                                isPassword: true,
                              ).animate().slideX(delay: 600.ms),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Checkbox(
                                    value: agreeToTerms,
                                    onChanged: (bool? value) {
                                      setState(() {
                                        agreeToTerms = value ?? false;
                                      });
                                    },
                                  ),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.blue.shade800,
                                        ),
                                        children: [
                                          const TextSpan(text: "I agree to the "),
                                          WidgetSpan(
                                            child: GestureDetector(
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                      builder: (context) => const TermsOfServiceScreen()),
                                                );
                                              },
                                              child: Text(
                                                "Terms of Service",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.blue.shade900,
                                                  decoration: TextDecoration.underline,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const TextSpan(text: " and "),
                                          WidgetSpan(
                                            child: GestureDetector(
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                      builder: (context) => const PrivacyPolicyScreen()),
                                                );
                                              },
                                              child: Text(
                                                "Privacy Policy",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.blue.shade900,
                                                  decoration: TextDecoration.underline,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ).animate().fadeIn(delay: 700.ms),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: FloatingActionButton.extended(
                                  onPressed: (isLoading ||
                                      !agreeToTerms ||
                                      nameController.text.isEmpty ||
                                      emailController.text.isEmpty ||
                                      passwordController.text.isEmpty)
                                      ? null
                                      : signUp,
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.blue.shade900,
                                  elevation: 4,
                                  label: isLoading
                                      ? CircularProgressIndicator(color: Colors.blue.shade900)
                                      : const Text(
                                    "Sign Up",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  extendedPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                ),
                              ).animate().scale(delay: 800.ms),
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Already have an account? ",
                                    style: TextStyle(color: Colors.blue.shade800),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade900.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.blue.shade900, width: 1),
                                      ),
                                      child: Text(
                                        "Sign In",
                                        style: TextStyle(
                                          color: Colors.blue.shade900,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ).animate().scale(duration: 300.ms, curve: Curves.easeInOut),
                                    ),
                                  ),
                                ],
                              ).animate().fadeIn(delay: 900.ms),
                              const SizedBox(height: 50),
                            ],
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: SizedBox(
                            height: 100,
                            child: CustomPaint(
                              painter: WavePainter(_controller.value),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.lightBlue.shade100.withOpacity(0.3),
            offset: const Offset(2, 2),
            blurRadius: 5,
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword && !_isPasswordVisible,
        style: TextStyle(color: Colors.blue.shade900),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.blue.shade400),
          prefixIcon: Icon(icon, color: Colors.blue.shade700),
          suffixIcon: isPassword
              ? IconButton(
            icon: Icon(
              _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
              color: Colors.blue.shade700,
            ),
            onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
          )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildCornerGradient({required double radius, required Alignment alignment}) {
    return Container(
      width: radius,
      height: radius,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: alignment,
          radius: 0.5,
          colors: [
            Colors.lightBlue.shade300.withOpacity(0.6),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

// Success Particle Painter for Dialog Animation
class _SuccessParticlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.5);
    final random = math.Random();
    for (int i = 0; i < 20; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      canvas.drawCircle(Offset(x, y), random.nextDouble() * 3 + 1, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}