import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Added for tracking first login
import 'signup.dart';
import 'forgot_password.dart';

// Particle Class for Confetti Snow
class Particle {
  double x, y, size, speed, drift;
  Color color;
  final math.Random random;

  Particle(this.random)
      : x = random.nextDouble(),
        y = random.nextDouble() * -1,
        size = random.nextDouble() * 2 + 1,
        speed = random.nextDouble() * 0.5 + 0.5,
        drift = (random.nextDouble() - 0.5) * 0.2,
        color = Colors.lightBlue.shade300.withOpacity(random.nextDouble() * 0.5 + 0.5);

  void update() {
    y += speed * 0.005;
    x += drift * 0.005;
    if (y > 1) {
      y = random.nextDouble() * -0.2;
      x = random.nextDouble();
      drift = (random.nextDouble() - 0.5) * 0.2;
    }
    if (x > 1 || x < 0) {
      x = random.nextDouble();
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

// New Progress Bar Screen
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  _LoadingScreenState createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _progressAnimation = Tween<double>(begin: 0, end: 1).animate(_controller)
      ..addListener(() {
        setState(() {});
      });
    _controller.forward().then((_) async {
      // After loading, go to student details and mark first login as false
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isFirstLogin', false);
      Navigator.pushReplacementNamed(context, '/student_details');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Color(0xFFE6F3FF)],
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Your Learning Adventure Begins...🌟",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4A90E2),
                    letterSpacing: 0.3,
                  ),
                ).animate().fadeIn(duration: 1000.ms).slideY(begin: -0.5),
                const SizedBox(height: 40),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final maxWidth = constraints.maxWidth;
                      final segmentCount = 10;
                      final segmentWidth = (maxWidth - (segmentCount - 1) * 4) / segmentCount;
                      final filledSegments = (segmentCount * _progressAnimation.value).floor();

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(segmentCount, (index) {
                          return Row(
                            children: [
                              Container(
                                width: segmentWidth,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: index < filledSegments
                                      ? Color(0xFF4A90E2)
                                      : Color(0xFFDEEFFF),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              if (index < segmentCount - 1) SizedBox(width: 4),
                            ],
                          );
                        }),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "${(_progressAnimation.value * 100).toInt()}%",
                  style: TextStyle(
                    fontSize: 20,
                    color: Color(0xFF4A90E2),
                    fontWeight: FontWeight.bold,
                  ),
                ).animate().fadeIn(duration: 800.ms),
                const SizedBox(height: 8),
                Text(
                  "Loading Knowledge...",
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF8EB8E5),
                    fontWeight: FontWeight.w500,
                  ),
                ).animate().fadeIn(duration: 800.ms),
              ],
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: ParticlePainter(
                List.generate(50, (_) => Particle(math.Random())),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool isLoading = false;
  bool _isPasswordVisible = false;
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
    _controller.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> signInWithEmail() async {
    setState(() => isLoading = true);
    try {
      await _auth.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      _showSuccessDialog();
    } on FirebaseAuthException catch (e) {
      _showErrorDialog(e.message ?? "Login failed");
    }
    setState(() => isLoading = false);
  }

  void _showSuccessDialog() async {
    // Check if it's the first login
    final prefs = await SharedPreferences.getInstance();
    bool isFirstLogin = prefs.getBool('isFirstLogin') ?? true;

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
                    "Your Knowledge Journey Continues 🚀 ",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ).animate().fadeIn(delay: 400.ms),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Close the dialog
                      if (isFirstLogin) {
                        // First login: go to LoadingScreen, then StudentDetails
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const LoadingScreen()),
                        );
                      } else {
                        // Subsequent login: go straight to home page
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          "/home_page",
                              (route) => false,
                        );
                      }
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
                      "Let’s Go! ⚡",
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
          Center(
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
                                      "Unlock Your Learning Journey",
                                      style: TextStyle(
                                        fontSize: MediaQuery.of(context).size.width > 600 ? 16 : 14,
                                        color: Colors.blue.shade800,
                                      ),
                                    ).animate().fadeIn(delay: 300.ms),
                                    const SizedBox(height: 32),
                                    _buildTextField(
                                      controller: emailController,
                                      hintText: "Email",
                                      icon: Icons.email,
                                    ).animate().slideX(delay: 400.ms),
                                    const SizedBox(height: 16),
                                    _buildTextField(
                                      controller: passwordController,
                                      hintText: "Password",
                                      icon: Icons.lock,
                                      isPassword: true,
                                    ).animate().slideX(delay: 500.ms),
                                    const SizedBox(height: 16),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
                                          );
                                        },
                                        child: Text(
                                          "Forgot Password?",
                                          style: TextStyle(color: Colors.blue.shade900),
                                        ),
                                      ),
                                    ).animate().fadeIn(delay: 600.ms),
                                    const SizedBox(height: 24),
                                    SizedBox(
                                      width: double.infinity,
                                      child: FloatingActionButton.extended(
                                        onPressed: isLoading ? null : signInWithEmail,
                                        backgroundColor: Colors.white,
                                        foregroundColor: Colors.blue.shade900,
                                        elevation: 4,
                                        label: isLoading
                                            ? CircularProgressIndicator(color: Colors.blue.shade900)
                                            : const Text(
                                          "Sign In",
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        extendedPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                      ),
                                    ).animate().scale(delay: 700.ms),
                                    const SizedBox(height: 24),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          "New here? ",
                                          style: TextStyle(color: Colors.blue.shade800),
                                        ),
                                        GestureDetector(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (context) => const SignUpScreen()),
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
                                              "Create Account",
                                              style: TextStyle(
                                                color: Colors.blue.shade900,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ).animate().scale(duration: 300.ms, curve: Curves.easeInOut),
                                          ),
                                        ).animate().fadeIn(delay: 800.ms),
                                      ],
                                    ),
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
          ),
        ],
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