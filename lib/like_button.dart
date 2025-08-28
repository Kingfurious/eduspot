// START OF FILE like_button.dart

import 'package:flutter/material.dart';
import 'app_colors.dart'; // Adjust path if needed

class LikeButton extends StatefulWidget {
  final bool isLiked;
  final int likeCount;
  final Future<bool> Function() onTap; // Changed to match original CommentScreen usage

  const LikeButton({
    Key? key,
    required this.isLiked,
    required this.likeCount,
    required this.onTap,
  }) : super(key: key);

  @override
  _LikeButtonState createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> {
  bool _isLikedInternal = false;
  int _likeCountInternal = 0;
  bool _isLoading = false; // To prevent rapid tapping

  @override
  void initState() {
    super.initState();
    _isLikedInternal = widget.isLiked;
    _likeCountInternal = widget.likeCount;
  }

  // Update state if the parent widget rebuilds with different values
  @override
  void didUpdateWidget(covariant LikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLiked != oldWidget.isLiked || widget.likeCount != oldWidget.likeCount) {
      setState(() {
        _isLikedInternal = widget.isLiked;
        _likeCountInternal = widget.likeCount;
      });
    }
  }

  Future<void> _handleTap() async {
    if (_isLoading) return; // Prevent action if already processing

    setState(() {
      _isLoading = true;
    });

    try {
      // The onTap function should return the new liked status
      final newLikedStatus = await widget.onTap();

      // Update the internal state based on the result from onTap
      // This makes the button visually react immediately based on the parent's logic
      setState(() {
        _isLikedInternal = newLikedStatus;
        // Optimistically update count - parent stream will provide the final value
        if (newLikedStatus && !widget.isLiked) { // Liked
          _likeCountInternal++;
        } else if (!newLikedStatus && widget.isLiked) { // Unliked
          _likeCountInternal--;
          if (_likeCountInternal < 0) _likeCountInternal = 0; // Ensure count doesn't go below 0
        }
      });
    } catch (e) {
      print("Error during LikeButton tap: $e");
      // Optionally revert state or show error
    } finally {
      if (mounted) { // Check if widget is still in the tree
        setState(() {
          _isLoading = false;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    // Use the internal state for display
    bool displayLiked = _isLikedInternal;
    int displayCount = _likeCountInternal;

    return GestureDetector(
      onTap: _handleTap,
      child: Row(
        mainAxisSize: MainAxisSize.min, // Prevent row from expanding unnecessarily
        children: [
          _isLoading
              ? SizedBox(
            width: 18, // Consistent size with icon
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.0,
              valueColor: AlwaysStoppedAnimation<Color>(kPrimaryTeal),
            ),
          )
              : Icon(
            displayLiked ? Icons.thumb_up : Icons.thumb_up_outlined, // Using thumb_up as in CommentScreen
            color: displayLiked ? kPrimaryTeal : kIconInactive,
            size: 20, // Slightly smaller size consistent with CommentScreen usage
          ),
          const SizedBox(width: 4),
          Text(
            // Display 'like' or 'likes' based on count
            '$displayCount ${displayCount == 1 ? 'like' : 'likes'}',
            style: TextStyle(
              color: kTextSecondary,
              fontSize: 12, // Consistent with CommentScreen usage
            ),
          ),
        ],
      ),
    );
  }
}

// END OF FILE like_button.dart