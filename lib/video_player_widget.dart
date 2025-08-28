// START OF FILE screens/messaging/widgets/video_player_screen.dart

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'app_colors.dart'; // Import colors if needed

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  const VideoPlayerScreen({Key? key, required this.videoUrl}) : super(key: key);

  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  Future<void>? _initializeVideoPlayerFuture; // Future for initialization
  bool _showControls = true; // Show controls initially

  @override
  void initState() {
    super.initState();
    print("Initializing video player for URL: ${widget.videoUrl}");
    // Create and store the VideoPlayerController.
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));

    // Initialize the controller and store the Future for later use.
    _initializeVideoPlayerFuture = _controller.initialize().then((_) {
      // Ensure the first frame is shown after the video is initialized.
      if (mounted) {
        setState(() {});
        print("Video player initialized.");
        _controller.play(); // Start playing automatically
        _controller.setLooping(true); // Optional: Loop the video
      }
    }).catchError((error) {
      print("Error initializing video player: $error");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading video: $error'), backgroundColor: Colors.red)
        );
      }
    });

    // Add listener to hide controls after a delay when playing
    _controller.addListener(() {
      if (_controller.value.isPlaying && _showControls) {
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && _controller.value.isPlaying) {
            setState(() {
              _showControls = false;
            });
          }
        });
      }
      // Make sure controls reappear if video pauses or ends (if not looping)
      if (!_controller.value.isPlaying && !_showControls) {
        if (mounted) {
          setState(() {
            _showControls = true;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    // Ensure disposing of the VideoPlayerController to free up resources.
    _controller.dispose();
    super.dispose();
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    // If controls are shown and video is playing, hide them after delay
    if (_showControls && _controller.value.isPlaying) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _controller.value.isPlaying) {
          setState(() {
            _showControls = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Black background for video player
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.5), // Semi-transparent AppBar
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder(
        future: _initializeVideoPlayerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            // If the VideoPlayerController has finished initialization, use
            // the data it provides to limit the aspect ratio of the video.
            return Center(
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                // Use a Stack to overlay controls
                child: Stack(
                  alignment: Alignment.center, // Center play/pause button
                  children: <Widget>[
                    // The actual video player
                    GestureDetector(
                        onTap: _toggleControls, // Tap video to toggle controls
                        child: VideoPlayer(_controller)
                    ),
                    // Play/Pause Button Overlay (only shown when controls are visible)
                    AnimatedOpacity(
                      opacity: _showControls ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: IgnorePointer( // Don't block taps on video when hidden
                        ignoring: !_showControls,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              // If the video is playing, pause it.
                              if (_controller.value.isPlaying) {
                                _controller.pause();
                              } else {
                                // If the video is paused, play it.
                                _controller.play();
                                // Start timer to hide controls again
                                Future.delayed(const Duration(seconds: 3), () {
                                  if (mounted && _controller.value.isPlaying) {
                                    setState(() => _showControls = false);
                                  }
                                });
                              }
                            });
                          },
                          child: Container(
                            // Larger tappable area for the button
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4), // Background for visibility
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                              size: 50.0,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Progress Bar (at the bottom, only shown when controls are visible)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: AnimatedOpacity(
                        opacity: _showControls ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: IgnorePointer(
                          ignoring: !_showControls,
                          child: Container(
                            color: Colors.black.withOpacity(0.5), // Background for progress bar
                            child: VideoProgressIndicator(
                              _controller,
                              allowScrubbing: true,
                              padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                              colors: VideoProgressColors(
                                playedColor: kPrimaryTeal, // Use app color
                                bufferedColor: Colors.white54,
                                backgroundColor: Colors.transparent, // Background is handled by container
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          } else if (snapshot.hasError) {
            // If initialization failed, display an error message
            return Center(
              child: Text("Error loading video", style: TextStyle(color: Colors.red)),
            );
          } else {
            // Otherwise, display a loading indicator.
            return Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
        },
      ),
    );
  }
}

// END OF FILE screens/messaging/widgets/video_player_screen.dart