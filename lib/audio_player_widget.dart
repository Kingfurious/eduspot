// START OF FILE screens/messaging/widgets/audio_player_widget.dart

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'app_colors.dart'; // Adjust path if your constants are elsewhere

class AudioPlayerWidget extends StatefulWidget {
  final String sourceUrl;
  final bool isMe; // To potentially style based on sender
  final String? fileName;
  const AudioPlayerWidget({
    Key? key,
    required this.sourceUrl,
    required this.isMe,
    this.fileName,
  }) : super(key: key);

  @override
  _AudioPlayerWidgetState createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isSeeking = false; // To prevent UI jumps during seek

  @override
  void initState() {
    super.initState();
    print("Building AudioPlayerWidget"); // Debug print

    // Listen to state changes
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playerState = state);
    });
    // Listen to duration changes
    _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) setState(() => _duration = duration);
    });
    // Listen to position changes
    _audioPlayer.onPositionChanged.listen((position) {
      // Only update position if not currently seeking
      if (mounted && !_isSeeking) setState(() => _position = position);
    });
    // Listen to seek complete events to re-enable position updates
    _audioPlayer.onSeekComplete.listen((event) {
      if (mounted) {
        setState(() {
          _isSeeking = false;
        });
      }
    });

    // Set the source URL initially.
    // Using Source instead of Url directly allows for better future flexibility
    _audioPlayer.setSource(UrlSource(widget.sourceUrl)).catchError((error) {
      print("Error setting audio source for ${widget.sourceUrl}: $error");
      // Optionally update UI to show an error state
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error loading audio."), backgroundColor: Colors.red));
      }
    });
  }

  @override
  void dispose() {
    // Stop and release the player resources
    // Using try-catch as dispose might throw if player is already released
    try {
      _audioPlayer.stop();
      _audioPlayer.release();
      _audioPlayer.dispose();
    } catch(e) {
      print("Error disposing audio player: $e");
    }
    super.dispose();
  }

  Future<void> _playPause() async {
    try {
      if (_playerState == PlayerState.playing) {
        await _audioPlayer.pause();
      } else {
        // If stopped or completed, ensure source is set before resuming
        // Checking state prevents unnecessary calls to setSource if already paused
        if (_playerState == PlayerState.stopped || _playerState == PlayerState.completed) {
          await _audioPlayer.setSource(UrlSource(widget.sourceUrl));
          // Optional: Seek to beginning if completed?
          // if (_playerState == PlayerState.completed) {
          //   await _audioPlayer.seek(Duration.zero);
          // }
        }
        await _audioPlayer.resume(); // Plays if not playing, resumes if paused
      }
    } catch (e) {
      print("Error during play/pause: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error playing audio."), backgroundColor: Colors.red));
    }
  }

  // Helper to format duration (e.g., 0:15, 1:23)
  String _formatDuration(Duration d) {
    try {
      String twoDigits(int n) => n.toString().padLeft(2, '0');
      final minutes = twoDigits(d.inMinutes.remainder(60));
      final seconds = twoDigits(d.inSeconds.remainder(60));
      return "$minutes:$seconds";
    } catch (e) {
      return "00:00"; // Fallback
    }
  }


  @override
  Widget build(BuildContext context) {
    final color = widget.isMe ? Colors.white : kPrimaryTeal;
    final inactiveColor = widget.isMe ? Colors.white70 : kTextSecondary;

    // This padding adds space around the entire audio player content within the bubble
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        // Row will try to fill the horizontal space provided by the bubble's Container
        children: [
          // --- Play/Pause Button ---
          IconButton(
            icon: Icon(
              _playerState == PlayerState.playing
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_filled,
              color: color,
              size: 30, // Fixed size for the icon button
            ),
            onPressed: _playPause,
            padding: EdgeInsets.zero, // Remove default padding
            constraints: BoxConstraints(), // Remove default size constraints
            tooltip: _playerState == PlayerState.playing ? "Pause" : "Play",
          ),
          SizedBox(width: 8), // Fixed spacing

          // --- Text, Slider, Duration Area ---
          // Expanded takes up all remaining horizontal space in the Row
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, // Align text/slider left
              mainAxisSize: MainAxisSize.min, // Column takes minimum vertical space
              children: [
                // Optional: Display filename
                if (widget.fileName != null && widget.fileName!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    // Text is constrained horizontally by the parent Expanded/Column
                    child: Text(
                      widget.fileName!,
                      style: TextStyle(fontSize: 12, color: color.withOpacity(0.9), fontWeight: FontWeight.w500),
                      maxLines: 1, // Prevent wrapping
                      overflow: TextOverflow.ellipsis, // Show ellipsis if too long
                    ),
                  ),

                // Container for Slider and Duration Text
                // Helps manage layout whether loading or playing
                Container(
                  // Ensure this container doesn't cause vertical issues
                  constraints: BoxConstraints(minHeight: 35), // Minimum height for visual consistency
                  child: (_duration > Duration.zero)
                      ? Column( // Stack Slider + Duration Text vertically
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch, // Make slider fill width
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 2.0,
                          thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6.0),
                          overlayShape: RoundSliderOverlayShape(overlayRadius: 12.0),
                          thumbColor: color,
                          activeTrackColor: color,
                          inactiveTrackColor: inactiveColor.withOpacity(0.3),
                          overlayColor: color.withAlpha(32),
                          trackShape: RoundedRectSliderTrackShape(), // Use standard track shape
                          // Reduce padding around the slider if needed
                          activeTickMarkColor: Colors.transparent,
                          inactiveTickMarkColor: Colors.transparent,
                        ),
                        child: Slider(
                          value: _position.inSeconds.toDouble().clamp(0.0, _duration.inSeconds.toDouble()),
                          min: 0.0,
                          max: _duration.inSeconds.toDouble(),
                          onChangeStart: (value) {
                            if(mounted) setState(() => _isSeeking = true);
                          },
                          onChangeEnd: (value) async {
                            final position = Duration(seconds: value.toInt());
                            await _audioPlayer.seek(position);
                            // Seek complete listener handles _isSeeking = false
                            // Update position display immediately after seek finishes if needed
                            if (mounted) setState(() => _position = position);
                          },
                          onChanged: (value) {
                            // Update position display while dragging
                            if (mounted) setState(() {
                              _position = Duration(seconds: value.toInt());
                            });
                          },
                        ),
                      ),
                      // Padding around the duration text
                      Padding(
                        padding: const EdgeInsets.only(top: 0, bottom: 2), // Adjust vertical padding
                        child: Text(
                          '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                          style: TextStyle(fontSize: 10, color: inactiveColor),
                          textAlign: TextAlign.center, // Center duration text
                        ),
                      ),
                    ],
                  )
                      : Center( // Display when duration is zero (loading)
                    child: SizedBox( // Use SizedBox for consistent height during loading
                      height: 35, // Match approx height of slider+text
                      child: Align(
                        alignment: Alignment.center,
                        child: Text(
                          "Loading audio...",
                          style: TextStyle(fontSize: 10, color: inactiveColor),
                        ),
                      ),
                    ),
                  ),
                ), // End Container for Slider/Duration/Loading
              ],
            ),
          ), // End Expanded for Text/Slider Area
        ],
      ),
    );
  }
}

// END OF FILE screens/messaging/widgets/audio_player_widget.dart// START OF FILE screens/messaging/widgets/audio_player_widget.dart
//
// import 'package:flutter/material.dart';
// import 'package:audioplayers/audioplayers.dart';
// import 'app_colors.dart'; // Adjust path if your constants are elsewhere
//
// class AudioPlayerWidget extends StatefulWidget {
//   final String sourceUrl;
//   final bool isMe; // To potentially style based on sender
//   final String? fileName;
//   const AudioPlayerWidget({
//     Key? key,
//     required this.sourceUrl,
//     required this.isMe,
//     this.fileName,
//   }) : super(key: key);
//
//   @override
//   _AudioPlayerWidgetState createState() => _AudioPlayerWidgetState();
// }
//
// class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
//   final AudioPlayer _audioPlayer = AudioPlayer();
//   PlayerState _playerState = PlayerState.stopped;
//   Duration _duration = Duration.zero;
//   Duration _position = Duration.zero;
//   bool _isSeeking = false; // To prevent UI jumps during seek
//
//   @override
//   void initState() {
//     super.initState();
//     print("Building AudioPlayerWidget"); // Debug print
//
//     // Listen to state changes
//     _audioPlayer.onPlayerStateChanged.listen((state) {
//       if (mounted) setState(() => _playerState = state);
//     });
//     // Listen to duration changes
//     _audioPlayer.onDurationChanged.listen((duration) {
//       if (mounted) setState(() => _duration = duration);
//     });
//     // Listen to position changes
//     _audioPlayer.onPositionChanged.listen((position) {
//       // Only update position if not currently seeking
//       if (mounted && !_isSeeking) setState(() => _position = position);
//     });
//     // Listen to seek complete events to re-enable position updates
//     _audioPlayer.onSeekComplete.listen((event) {
//       if (mounted) {
//         setState(() {
//           _isSeeking = false;
//         });
//       }
//     });
//
//     // Set the source URL initially.
//     // Using Source instead of Url directly allows for better future flexibility
//     _audioPlayer.setSource(UrlSource(widget.sourceUrl)).catchError((error) {
//       print("Error setting audio source for ${widget.sourceUrl}: $error");
//       // Optionally update UI to show an error state
//       if (mounted) {
//          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error loading audio."), backgroundColor: Colors.red));
//       }
//     });
//   }
//
//   @override
//   void dispose() {
//     // Stop and release the player resources
//     // Using try-catch as dispose might throw if player is already released
//     try {
//        _audioPlayer.stop();
//        _audioPlayer.release();
//        _audioPlayer.dispose();
//     } catch(e) {
//        print("Error disposing audio player: $e");
//     }
//     super.dispose();
//   }
//
//   Future<void> _playPause() async {
//     try {
//       if (_playerState == PlayerState.playing) {
//         await _audioPlayer.pause();
//       } else {
//         // If stopped or completed, ensure source is set before resuming
//         // Checking state prevents unnecessary calls to setSource if already paused
//         if (_playerState == PlayerState.stopped || _playerState == PlayerState.completed) {
//           await _audioPlayer.setSource(UrlSource(widget.sourceUrl));
//           // Optional: Seek to beginning if completed?
//           // if (_playerState == PlayerState.completed) {
//           //   await _audioPlayer.seek(Duration.zero);
//           // }
//         }
//         await _audioPlayer.resume(); // Plays if not playing, resumes if paused
//       }
//     } catch (e) {
//        print("Error during play/pause: $e");
//        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error playing audio."), backgroundColor: Colors.red));
//     }
//   }
//
//   // Helper to format duration (e.g., 0:15, 1:23)
//   String _formatDuration(Duration d) {
//     try {
//       String twoDigits(int n) => n.toString().padLeft(2, '0');
//       final minutes = twoDigits(d.inMinutes.remainder(60));
//       final seconds = twoDigits(d.inSeconds.remainder(60));
//       return "$minutes:$seconds";
//     } catch (e) {
//       return "00:00"; // Fallback
//     }
//   }
//
//
//   @override
//   Widget build(BuildContext context) {
//     final color = widget.isMe ? Colors.white : kPrimaryTeal;
//     final inactiveColor = widget.isMe ? Colors.white70 : kTextSecondary;
//
//     // This padding adds space around the entire audio player content within the bubble
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 5.0),
//       child: Row(
//         // Row will try to fill the horizontal space provided by the bubble's Container
//         children: [
//           // --- Play/Pause Button ---
//           IconButton(
//             icon: Icon(
//               _playerState == PlayerState.playing
//                   ? Icons.pause_circle_filled
//                   : Icons.play_circle_filled,
//               color: color,
//               size: 30, // Fixed size for the icon button
//             ),
//             onPressed: _playPause,
//             padding: EdgeInsets.zero, // Remove default padding
//             constraints: BoxConstraints(), // Remove default size constraints
//             tooltip: _playerState == PlayerState.playing ? "Pause" : "Play",
//           ),
//           SizedBox(width: 8), // Fixed spacing
//
//           // --- Text, Slider, Duration Area ---
//           // Expanded takes up all remaining horizontal space in the Row
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start, // Align text/slider left
//               mainAxisSize: MainAxisSize.min, // Column takes minimum vertical space
//               children: [
//                 // Optional: Display filename
//                 if (widget.fileName != null && widget.fileName!.isNotEmpty)
//                   Padding(
//                     padding: const EdgeInsets.only(bottom: 4.0),
//                     // Text is constrained horizontally by the parent Expanded/Column
//                     child: Text(
//                       widget.fileName!,
//                       style: TextStyle(fontSize: 12, color: color.withOpacity(0.9), fontWeight: FontWeight.w500),
//                       maxLines: 1, // Prevent wrapping
//                       overflow: TextOverflow.ellipsis, // Show ellipsis if too long
//                     ),
//                   ),
//
//                 // Container for Slider and Duration Text
//                 // Helps manage layout whether loading or playing
//                 Container(
//                   // Ensure this container doesn't cause vertical issues
//                   constraints: BoxConstraints(minHeight: 35), // Minimum height for visual consistency
//                   child: (_duration > Duration.zero)
//                       ? Column( // Stack Slider + Duration Text vertically
//                           mainAxisSize: MainAxisSize.min,
//                           crossAxisAlignment: CrossAxisAlignment.stretch, // Make slider fill width
//                           children: [
//                             SliderTheme(
//                               data: SliderTheme.of(context).copyWith(
//                                 trackHeight: 2.0,
//                                 thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6.0),
//                                 overlayShape: RoundSliderOverlayShape(overlayRadius: 12.0),
//                                 thumbColor: color,
//                                 activeTrackColor: color,
//                                 inactiveTrackColor: inactiveColor.withOpacity(0.3),
//                                 overlayColor: color.withAlpha(32),
//                                 trackShape: RoundedRectSliderTrackShape(), // Use standard track shape
//                                 // Reduce padding around the slider if needed
//                                 activeTickMarkColor: Colors.transparent,
//                                 inactiveTickMarkColor: Colors.transparent,
//                               ),
//                               child: Slider(
//                                 value: _position.inSeconds.toDouble().clamp(0.0, _duration.inSeconds.toDouble()),
//                                 min: 0.0,
//                                 max: _duration.inSeconds.toDouble(),
//                                 onChangeStart: (value) {
//                                   if(mounted) setState(() => _isSeeking = true);
//                                 },
//                                 onChangeEnd: (value) async {
//                                   final position = Duration(seconds: value.toInt());
//                                   await _audioPlayer.seek(position);
//                                   // Seek complete listener handles _isSeeking = false
//                                   // Update position display immediately after seek finishes if needed
//                                   if (mounted) setState(() => _position = position);
//                                 },
//                                 onChanged: (value) {
//                                   // Update position display while dragging
//                                   if (mounted) setState(() {
//                                     _position = Duration(seconds: value.toInt());
//                                   });
//                                 },
//                               ),
//                             ),
//                             // Padding around the duration text
//                             Padding(
//                               padding: const EdgeInsets.only(top: 0, bottom: 2), // Adjust vertical padding
//                               child: Text(
//                                 '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
//                                 style: TextStyle(fontSize: 10, color: inactiveColor),
//                                 textAlign: TextAlign.center, // Center duration text
//                               ),
//                             ),
//                           ],
//                         )
//                       : Center( // Display when duration is zero (loading)
//                           child: SizedBox( // Use SizedBox for consistent height during loading
//                              height: 35, // Match approx height of slider+text
//                              child: Align(
//                                 alignment: Alignment.center,
//                                 child: Text(
//                                   "Loading audio...",
//                                   style: TextStyle(fontSize: 10, color: inactiveColor),
//                                 ),
//                              ),
//                           ),
//                         ),
//                 ), // End Container for Slider/Duration/Loading
//               ],
//             ),
//           ), // End Expanded for Text/Slider Area
//         ],
//       ),
//     );
//   }
// }
//
// // END OF FILE screens/messaging/widgets/audio_player_widget.dart