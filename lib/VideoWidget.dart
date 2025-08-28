import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

// More subtle, transparent color palette
const Color transparentWhite = Color(0x99FFFFFF);
const Color transparentBlack = Color(0x55000000);
const Color glassEffect = Color(0x33FFFFFF);
const Color accentGlass = Color(0x44FFFFFF);

class VideoWidget extends StatefulWidget {
  final String? videoUrl;

  const VideoWidget({Key? key, required this.videoUrl}) : super(key: key);

  @override
  _VideoWidgetState createState() => _VideoWidgetState();
}

class _VideoWidgetState extends State<VideoWidget> with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  double _rotationAngle = 0.0;
  bool _isControlsVisible = true;
  bool _isLoading = true;
  bool _isFullScreen = false;
  bool _isBuffering = false; // New state variable to track buffering
  Timer? _controlsTimer;

  // For seeking indicator
  bool _showForwardIndicator = false;
  bool _showBackwardIndicator = false;
  Timer? _seekIndicatorTimer;

  // Animation controller for control fade in/out
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Setup animation controller for controls fade in/out
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);

    if (widget.videoUrl == null || widget.videoUrl!.isEmpty) {
      print("No video URL provided.");
      setState(() {
        _isLoading = false;
      });
      return;
    }

    print("Video URL: ${widget.videoUrl}");
    _initializeVideoPlayer();

    // Start with controls visible
    _animationController.value = 1.0;
    _startControlsTimer();
  }

  Future<void> _initializeVideoPlayer() async {
    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl!));

      await _controller!.initialize();

      print("Video player initialized successfully");
      setState(() {
        _isInitialized = true;
        _isLoading = false;
      });
      _controller!.play();

      // Listen to player value changes to update UI
      _controller!.addListener(_videoControllerListener);

    } catch (e) {
      print("Error setting up video player: $e");
      setState(() => _isLoading = false);
    }
  }

  void _videoControllerListener() {
    // Check for errors
    if (_controller!.value.hasError) {
      print("Video player error: ${_controller!.value.errorDescription}");
    }

    // Check for buffering status changes
    bool isCurrentlyBuffering = false;

    // If we have buffered regions but position is beyond the buffered part
    if (_controller!.value.buffered.isNotEmpty) {
      final Duration bufferedEnd = _controller!.value.buffered.last.end;
      // If current position is close to the buffer end and video is playing
      isCurrentlyBuffering = _controller!.value.isPlaying &&
          (_controller!.value.position.inMilliseconds > bufferedEnd.inMilliseconds - 1000);
    }

    // Additionally, the VideoPlayerValue directly has a isBuffering property in newer versions
    // So we can also check that
    if (_controller!.value.isBuffering != _isBuffering || isCurrentlyBuffering != _isBuffering) {
      setState(() {
        _isBuffering = _controller!.value.isBuffering || isCurrentlyBuffering;
      });
    }
  }

  void _togglePlayPause() {
    if (_controller == null) return;

    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
    });

    _showControls();
  }

  void _toggleControls() {
    if (_isControlsVisible) {
      _hideControls();
    } else {
      _showControls();
    }
  }

  void _showControls() {
    _cancelControlsTimer();

    setState(() {
      _isControlsVisible = true;
    });

    _animationController.forward();
    _startControlsTimer();
  }

  void _hideControls() {
    _cancelControlsTimer();

    setState(() {
      _isControlsVisible = false;
    });

    _animationController.reverse();
  }

  void _startControlsTimer() {
    _cancelControlsTimer();

    // Auto-hide controls after 3 seconds of inactivity
    if (_controller?.value.isPlaying ?? false) {
      _controlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _isControlsVisible) {
          _hideControls();
        }
      });
    }
  }

  void _cancelControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = null;
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });

    if (_isFullScreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }

    _showControls();
  }

  void _rotateVideo() {
    setState(() {
      _rotationAngle = (_rotationAngle + 90) % 360;
    });
    _showControls();
  }

  // Jump 10 seconds forward
  void _seekForward() {
    if (_controller == null) return;

    final newPosition = _controller!.value.position + const Duration(seconds: 10);
    if (newPosition < _controller!.value.duration) {
      _controller!.seekTo(newPosition);
    } else {
      _controller!.seekTo(_controller!.value.duration);
    }

    // Show seek indicator
    setState(() {
      _showForwardIndicator = true;
    });

    _clearSeekIndicatorTimer();
    _seekIndicatorTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _showForwardIndicator = false;
        });
      }
    });

    _showControls();
  }

  // Jump 10 seconds backward
  void _seekBackward() {
    if (_controller == null) return;

    final newPosition = _controller!.value.position - const Duration(seconds: 10);
    if (newPosition > Duration.zero) {
      _controller!.seekTo(newPosition);
    } else {
      _controller!.seekTo(Duration.zero);
    }

    // Show seek indicator
    setState(() {
      _showBackwardIndicator = true;
    });

    _clearSeekIndicatorTimer();
    _seekIndicatorTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _showBackwardIndicator = false;
        });
      }
    });

    _showControls();
  }

  void _clearSeekIndicatorTimer() {
    _seekIndicatorTimer?.cancel();
    _seekIndicatorTimer = null;
  }

  @override
  void dispose() {
    _cancelControlsTimer();
    _clearSeekIndicatorTimer();
    _controller?.removeListener(_videoControllerListener);
    _controller?.dispose();
    _animationController.dispose();

    // Reset system UI and orientation when widget is disposed
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Handle missing video URL
    if (widget.videoUrl == null || widget.videoUrl!.isEmpty) {
      return _buildErrorScreen("No video available");
    }

    // Build the main video player UI
    return WillPopScope(
      onWillPop: () async {
        // If in fullscreen, exit fullscreen first
        if (_isFullScreen) {
          _toggleFullScreen();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true, // Extend content behind appbar
        appBar: _isFullScreen
            ? null
            : AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: _isLoading
            ? _buildLoadingIndicator()
            : _buildVideoPlayer(),
      ),
    );
  }

  Widget _buildErrorScreen(String message) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Video Player"),
        backgroundColor: Colors.black.withOpacity(0.8),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 70, color: transparentWhite),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(color: Colors.white70, fontSize: 18),
            ),
          ],
        ),
      ),
      backgroundColor: Colors.black,
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(transparentWhite),
            strokeWidth: 3.0,
          ),
          const SizedBox(height: 20),
          const Text(
            "Loading video...",
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    return GestureDetector(
      onTap: _toggleControls,
      // Double tap for seek
      onDoubleTapDown: (details) {
        final screenWidth = MediaQuery.of(context).size.width;
        final tapPosition = details.globalPosition.dx;

        if (tapPosition < screenWidth / 2) {
          // Left side double tap - seek backward
          _seekBackward();
        } else {
          // Right side double tap - seek forward
          _seekForward();
        }
      },
      child: Stack(
        fit: StackFit.expand, // Use full space
        children: [
          // Video player
          Center(
            child: _isInitialized
                ? AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: Transform.rotate(
                angle: _rotationAngle * 3.14159 / 180,
                child: VideoPlayer(_controller!),
              ),
            )
                : const Text("Preparing video...", style: TextStyle(color: Colors.white)),
          ),

          // Buffering indicator
          if (_isBuffering)
            Center(
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: transparentBlack,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: glassEffect, width: 1),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Buffering...",
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),

          // Seek indicators
          if (_showForwardIndicator)
            Center(
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: transparentBlack,
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: glassEffect, width: 1),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.forward_10, color: transparentWhite, size: 50),
                    SizedBox(height: 4),
                    Text(
                      "+10s",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),

          if (_showBackwardIndicator)
            Center(
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: transparentBlack,
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: glassEffect, width: 1),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.replay_10, color: transparentWhite, size: 50),
                    SizedBox(height: 4),
                    Text(
                      "-10s",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),

          // Always visible time indicator
          Positioned(
            bottom: 10,
            right: 10,
            child: ValueListenableBuilder(
              valueListenable: _controller!,
              builder: (context, VideoPlayerValue value, child) {
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical:
                  5),
                  decoration: BoxDecoration(
                    color: transparentBlack,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: glassEffect.withOpacity(0.3), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "${_formatDuration(value.position)} / ${_formatDuration(value.duration)}",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Controls overlay
          _buildVideoControls(),
        ],
      ),
    );
  }

  Widget _buildVideoControls() {
    if (!_isInitialized) return const SizedBox.shrink();

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Stack(
        children: [
          // Semi-transparent background for better control visibility
          if (_isControlsVisible)
            Container(color: Colors.black.withOpacity(0.3)),

          // Center play/pause button
          if (_isControlsVisible)
            Center(
              child: Container(
                decoration: BoxDecoration(
                  color: transparentBlack,
                  shape: BoxShape.circle,
                  border: Border.all(color: glassEffect, width: 1.5),
                ),
                child: IconButton(
                  iconSize: 50,
                  icon: Icon(
                    _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                  ),
                  onPressed: _togglePlayPause,
                ),
              ),
            ),

          // Skip backward button
          if (_isControlsVisible)
            Positioned(
              left: 30,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: transparentBlack,
                    shape: BoxShape.circle,
                    border: Border.all(color: glassEffect, width: 1),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.replay_10, color: Colors.white),
                    onPressed: _seekBackward,
                    tooltip: '-10 seconds',
                  ),
                ),
              ),
            ),

          // Skip forward button
          if (_isControlsVisible)
            Positioned(
              right: 30,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: transparentBlack,
                    shape: BoxShape.circle,
                    border: Border.all(color: glassEffect, width: 1),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.forward_10, color: Colors.white),
                    onPressed: _seekForward,
                    tooltip: '+10 seconds',
                  ),
                ),
              ),
            ),

          // Bottom controls bar
          if (_isControlsVisible)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Progress and timestamp
                    _buildProgressBar(),

                    const SizedBox(height: 8),

                    // Control buttons row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Current time position
                        ValueListenableBuilder(
                          valueListenable: _controller!,
                          builder: (context, VideoPlayerValue value, child) {
                            return Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: transparentBlack,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _formatDuration(value.position),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            );
                          },
                        ),

                        // Rotation button
                        Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: transparentBlack,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.screen_rotation, color: Colors.white, size: 22),
                            onPressed: _rotateVideo,
                            tooltip: 'Rotate',
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(minWidth: 40, minHeight: 40),
                          ),
                        ),

                        // Total duration
                        ValueListenableBuilder(
                          valueListenable: _controller!,
                          builder: (context, VideoPlayerValue value, child) {
                            return Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: transparentBlack,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _formatDuration(value.duration),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),

                    // Add extra bottom padding in fullscreen mode
                    if (_isFullScreen) const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

          // Top controls bar with only fullscreen button
          if (_isControlsVisible)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                  ),
                ),
                child: SafeArea(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back button
                      Container(
                        decoration: BoxDecoration(
                          color: transparentBlack,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: glassEffect, width: 1),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () {
                            if (_isFullScreen) {
                              _toggleFullScreen();
                            } else {
                              Navigator.pop(context);
                            }
                          },
                          tooltip: 'Back',
                        ),
                      ),

                      // Fullscreen toggle button
                      Container(
                        decoration: BoxDecoration(
                          color: transparentBlack,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: glassEffect, width: 1),
                        ),
                        child: IconButton(
                          icon: Icon(
                            _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                            color: Colors.white,
                          ),
                          onPressed: _toggleFullScreen,
                          tooltip: _isFullScreen ? 'Exit fullscreen' : 'Fullscreen',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return ValueListenableBuilder(
      valueListenable: _controller!,
      builder: (context, VideoPlayerValue value, child) {
        // Calculate buffered percentage
        double bufferedPercentage = 0.0;
        if (value.buffered.isNotEmpty) {
          final Duration bufferedEnd = value.buffered.last.end;
          bufferedPercentage = bufferedEnd.inMilliseconds /
              value.duration.inMilliseconds;
        }

        return Column(
          children: [
            // Custom progress bar with buffering indicator
            Container(
              height: 8,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Stack(
                children: [
                  // Buffered progress
                  FractionallySizedBox(
                    widthFactor: bufferedPercentage.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  // Playback progress
                  FractionallySizedBox(
                    widthFactor: value.duration.inMilliseconds > 0
                        ? (value.position.inMilliseconds / value.duration.inMilliseconds)
                        .clamp(0.0, 1.0)
                        : 0.0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Slider for seeking
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 0, // Hide the actual track
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape: RoundSliderOverlayShape(overlayRadius: 16),
                thumbColor: Colors.white,
                overlayColor: Colors.white.withOpacity(0.3),
                trackShape: CustomTrackShape(), // Custom track shape with zero height
              ),
              child: Slider(
                min: 0.0,
                max: value.duration.inMilliseconds.toDouble(),
                value: value.position.inMilliseconds.toDouble().clamp(
                    0,
                    value.duration.inMilliseconds.toDouble()
                ),
                onChanged: (newValue) {
                  final position = Duration(milliseconds: newValue.round());
                  _controller!.seekTo(position);
                  _showControls(); // Reset control visibility timer on seek
                },
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = duration.inHours > 0 ? "${twoDigits(duration.inHours)}:" : "";
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours$minutes:$seconds";
  }
}

// Custom track shape to make the slider overlay the progress bar
class CustomTrackShape extends RoundedRectSliderTrackShape {
  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double trackHeight = sliderTheme.trackHeight ?? 0;
    final double trackLeft = offset.dx;
    final double trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final double trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }
}