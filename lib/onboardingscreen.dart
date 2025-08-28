import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class OnboardingScreen extends StatefulWidget {
  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  int _currentPage = 0;
  late AnimationController _animationController;
  late Animation<Color?> _backgroundAnimation;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    _animationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _backgroundAnimation = ColorTween(
      begin: Colors.lightBlue.shade100, // Lighter sky blue
      end: Colors.white, // White
    ).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pushReplacementNamed(context, "/login");
    }
  }

  void _skip() {
    Navigator.pushReplacementNamed(context, "/login");
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _backgroundAnimation,
      builder: (context, child) {
        return Scaffold(
          body: Stack(
            children: [
              // Radial Gradient Background with Wave Pattern
              Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.0,
                    colors: [
                      _backgroundAnimation.value ?? Colors.lightBlue.shade100,
                      Colors.white,
                    ],
                  ),
                ),
                child: CustomPaint(
                  painter: WaveBackgroundPainter(_animationController.value),
                  size: Size.infinite,
                ),
              ),
              // 3D Flip PageView
              PageView.builder(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: 3,
                itemBuilder: (context, index) {
                  return AnimatedBuilder(
                    animation: _pageController,
                    builder: (context, child) {
                      double value = 0;
                      if (_pageController.position.haveDimensions) {
                        value = index - _pageController.page!;
                        value = value.clamp(-1, 1);
                      }
                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001) // Perspective
                          ..rotateY(math.pi * value),
                        child: Opacity(
                          opacity: (1 - value.abs()).clamp(0.5, 1.0),
                          child: OnboardingPage(
                            image: index == 0
                                ? "assets/first.jpg"
                                : index == 1
                                ? "assets/sec.jpg"
                                : "assets/success.jpg",
                            title: index == 0
                                ? "Welcome to EduSpark"
                                : index == 1
                                ? "Stay Organized"
                                : "Achieve More",
                            subtitle: index == 0
                                ? "Manage tasks with ease and efficiency"
                                : index == 1
                                ? "Track your progress in a smarter way"
                                : "Boost productivity with AI-powered tools",
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              // Dots Navigation
              Positioned(
                bottom: 100,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    3,
                        (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == index ? 18 : 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _currentPage == index ? Colors.blue.shade900 : Colors.blue.shade300,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          if (_currentPage == index)
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Glassmorphism Buttons
              if (_currentPage > 0)
                Positioned(
                  bottom: 30,
                  left: 30,
                  child: _buildGlassButton("Back", _previousPage),
                ),
              Positioned(
                bottom: 30,
                right: 30,
                child: _currentPage == 2
                    ? _buildGlassButton("Get Started", _nextPage, isHighlighted: true)
                    : _buildGlassButton("Next", _nextPage),
              ),
              Positioned(
                top: 50,
                right: 30,
                child: _buildGlassButton("Skip", _skip),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGlassButton(String text, VoidCallback onPressed, {bool isHighlighted = false}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: isHighlighted ? Colors.blue.shade900.withOpacity(0.8) : Colors.white.withOpacity(0.2),
            shadowColor: isHighlighted ? Colors.blue.shade900.withOpacity(0.5) : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
              side: isHighlighted ? const BorderSide(color: Colors.white, width: 2) : BorderSide.none,
            ),
            elevation: isHighlighted ? 8 : 0,
          ),
          child: Text(
            text,
            style: TextStyle(
              color: isHighlighted ? Colors.white : Colors.blue.shade900,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardingPage extends StatelessWidget {
  final String image;
  final String title;
  final String subtitle;

  const OnboardingPage({
    required this.image,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              image,
              height: MediaQuery.of(context).size.height * 0.4,
              width: double.infinity,
              fit: BoxFit.cover,
            ).animate().fadeIn(duration: 600.ms),
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.05),
          Text(
            title,
            style: TextStyle(
              fontSize: MediaQuery.of(context).size.width > 600 ? 28 : 24,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade900, // Darker blue for contrast
              shadows: const [Shadow(blurRadius: 5, color: Colors.black45)],
            ),
          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: MediaQuery.of(context).size.width > 600 ? 18 : 16,
              color: Colors.blue.shade800, // Slightly lighter for subtitle
              fontWeight: FontWeight.w400,
            ),
          ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),
        ],
      ),
    );
  }
}

// Custom Painter for Wave Background
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
        size.height * 0.8 + 20 * math.sin((x / size.width * 2 * math.pi) + animationValue * 2 * math.pi),
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