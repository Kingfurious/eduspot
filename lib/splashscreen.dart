import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:math' show Random;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  double _opacity = 0.0;
  Timer? _navigationTimer;
  final List<ParticleModel> particles = [];
  final List<WaveModel> waves = [];
  final int _numParticles = 30;
  final Random _random = Random();

  // Controllers for various animations
  late final AnimationController _scaleController;
  late final AnimationController _rotateController;
  late final AnimationController _particleController;
  late final AnimationController _waveController;
  late final AnimationController _pulseController;
  late final AnimationController _slideController;
  late final AnimationController _logoRevealController;
  late final AnimationController _backgroundShiftController;

  // Animations
  late final Animation<double> _slideAnimation;
  late final Animation<Color?> _backgroundColorAnimation;
  late final Animation<double> _logoRevealAnimation;

  // For 3D rotation effect
  double _rotationX = 0;
  double _rotationY = 0;

  @override
  void initState() {
    super.initState();

    // Hide status bar
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    // Initialize animation controllers with more variation
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _logoRevealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..forward();

    _backgroundShiftController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat(reverse: true);

    // Setup complex animations
    _slideAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    );

    _logoRevealAnimation = CurvedAnimation(
      parent: _logoRevealController,
      curve: Curves.easeOutBack,
    );

    _backgroundColorAnimation = ColorTween(
      begin: Colors.blue.shade700,
      end: Colors.blue.shade500,
    ).animate(_backgroundShiftController);

    // Generate particles and waves
    for (int i = 0; i < _numParticles; i++) {
      particles.add(ParticleModel(
        sizeVariation: _random.nextDouble() * 0.5 + 0.5,
        speedFactor: _random.nextDouble() * 0.7 + 0.3,
      ));
    }

    for (int i = 0; i < 4; i++) {
      waves.add(WaveModel(
          offset: i * 1.5,
          amplitude: 15 + _random.nextDouble() * 10,
          frequency: 25 + _random.nextDouble() * 10
      ));
    }

    // Fade in content
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _opacity = 1.0;
      });
    });

    // Start the navigation timer
    _navigationTimer = Timer(const Duration(seconds: 4), _navigateBasedOnAuthState);

    // Simulate device motion for subtle 3D effect
    _simulateDeviceMotion();
  }

  // Simulate device motion for a subtle 3D effect
  void _simulateDeviceMotion() {
    Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (mounted) {
        setState(() {
          // Create subtle random movements
          _rotationX = math.sin(_backgroundShiftController.value * math.pi * 2) * 0.03;
          _rotationY = math.cos(_backgroundShiftController.value * math.pi * 2) * 0.03;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    // Restore system UI when leaving splash screen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom]);

    _navigationTimer?.cancel();
    _scaleController.dispose();
    _rotateController.dispose();
    _particleController.dispose();
    _waveController.dispose();
    _pulseController.dispose();
    _slideController.dispose();
    _logoRevealController.dispose();
    _backgroundShiftController.dispose();
    super.dispose();
  }

  // Updated navigation logic based on auth state
  void _navigateBasedOnAuthState() {
    if (mounted) {
      final User? user = FirebaseAuth.instance.currentUser;

      // Create an animation to fade out the screen before navigation
      AnimationController fadeOutController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      );

      Animation<double> fadeOutAnimation = Tween<double>(
        begin: 1.0,
        end: 0.0,
      ).animate(CurvedAnimation(
        parent: fadeOutController,
        curve: Curves.easeOut,
      ));

      fadeOutController.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          if (user != null) {
            // User is logged in, go straight to home page
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/home_page',
                  (route) => false, // Remove all previous routes
            );
          } else {
            // User is not logged in, go to welcome screen
            Navigator.pushReplacementNamed(context, '/welcome');
          }
          fadeOutController.dispose();
        }
      });

      // Start the fade out animation
      fadeOutController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        child: AnimatedBuilder(
          animation: _backgroundColorAnimation,
          builder: (context, child) {
            return Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _backgroundColorAnimation.value ?? Colors.blue.shade600,
                    Colors.blue.shade300,
                    Colors.white,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.7, 1.0],
                ),
              ),
              child: child,
            );
          },
          child: Stack(
            children: [
              // Animated background particles (stars/glitters)
              ...particles.map((particle) => AnimatedBuilder(
                animation: _particleController,
                builder: (context, child) {
                  return Positioned(
                    left: particle.x * size.width,
                    top: (particle.y * size.height +
                        _particleController.value * particle.speed) %
                        size.height,
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: 0.1 + (_pulseController.value * 0.15 * particle.sizeVariation),
                          child: Container(
                            width: particle.size * (1 + _pulseController.value * 0.4) * particle.sizeVariation,
                            height: particle.size * (1 + _pulseController.value * 0.4) * particle.sizeVariation,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.4),
                                  blurRadius: 5,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              )),

              // Animated waves with improved appearance
              ...waves.map((wave) => AnimatedBuilder(
                animation: _waveController,
                builder: (context, child) {
                  return Positioned(
                    top: size.height * 0.65 + wave.offset * 18,
                    left: -size.width * 0.2,
                    child: CustomPaint(
                      painter: WavePainter(
                        animation: _waveController.value,
                        opacity: 0.12,
                        offset: wave.offset,
                        amplitude: wave.amplitude,
                        frequency: wave.frequency,
                      ),
                      size: Size(size.width * 1.4, 100),
                    ),
                  );
                },
              )              ),

              // Main content - LOGO ONLY
              Center(
                child: Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001) // perspective
                    ..rotateX(_rotationX)
                    ..rotateY(_rotationY),
                  alignment: Alignment.center,
                  child: ScaleTransition(
                    scale: _logoRevealAnimation,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_scaleController, _rotateController, _pulseController]),
                      builder: (context, child) {
                        return Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.3 + _pulseController.value * 0.2),
                                blurRadius: 25,
                                spreadRadius: 8,
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Outer glowing ring
                              Container(
                                width: 180, // Slightly larger logo for more emphasis
                                height: 180,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      Colors.white.withOpacity(0.7),
                                      Colors.white.withOpacity(0.0),
                                    ],
                                    stops: const [0.7, 1.0],
                                  ),
                                ),
                              ),

                              // Rotating elements around the icon
                              ...List.generate(8, (index) {
                                final angle = index * (math.pi / 4);
                                return Transform.rotate(
                                  angle: _rotateController.value * 2 * math.pi + angle,
                                  child: Transform.translate(
                                    offset: Offset(
                                      math.cos(angle) * (85 + _pulseController.value * 5),
                                      math.sin(angle) * (85 + _pulseController.value * 5),
                                    ),
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.7),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.white.withOpacity(0.5),
                                            blurRadius: 5,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),

                              // Main icon with transform and shimmer
                              Transform.rotate(
                                angle: _rotateController.value * math.pi * 2,
                                child: Transform.scale(
                                  scale: 1.0 + (_scaleController.value * 0.15),
                                  child: Container(
                                    width: 140, // Larger main icon
                                    height: 140,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.blue.shade600,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.blue.shade300.withOpacity(0.5),
                                          blurRadius: 10,
                                          spreadRadius: 5,
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Shimmer.fromColors(
                                        baseColor: Colors.white,
                                        highlightColor: Colors.blue.shade100,
                                        child: const Icon(
                                          Icons.menu_book,
                                          size: 85, // Larger icon size
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ParticleModel {
  final double x;
  final double y;
  final double size;
  final double speed;
  final double sizeVariation;
  final double speedFactor;

  ParticleModel({
    double? sizeVariation,
    double? speedFactor,
  }) : x = Random().nextDouble(),
        y = Random().nextDouble(),
        size = Random().nextDouble() * 3 + 1,
        speed = Random().nextDouble() * 15 + 5,
        sizeVariation = sizeVariation ?? 1.0,
        speedFactor = speedFactor ?? 1.0;
}

class WaveModel {
  final double offset;
  final double amplitude;
  final double frequency;

  WaveModel({
    required this.offset,
    this.amplitude = 20.0,
    this.frequency = 30.0,
  });
}

class WavePainter extends CustomPainter {
  final double animation;
  final double opacity;
  final double offset;
  final double amplitude;
  final double frequency;

  WavePainter({
    required this.animation,
    required this.opacity,
    required this.offset,
    this.amplitude = 20.0,
    this.frequency = 30.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(opacity)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height / 2);

    for (double i = 0; i < size.width; i++) {
      path.lineTo(
        i,
        size.height / 2 + math.sin((i / frequency) + (animation * 2 * math.pi) + offset) * amplitude,
      );
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(WavePainter oldDelegate) => true;
}