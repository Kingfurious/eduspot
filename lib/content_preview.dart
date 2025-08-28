// START OF FILE content_preview.dart

import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'VideoWidget.dart'; // Assuming video_widget.dart is in the same widgets directory

// Utility function for building content preview
Widget buildContentPreview(BuildContext context, Map<String, dynamic> data,
    {double? height}) {
  final contentType = data['type'] as String?;
  final mediaUrlDynamic = data['mediaUrl'];
  final contentText = data['content'] as String?;

  // Add robust logging
  print(
      'Building content preview: type=$contentType, mediaUrlType=${mediaUrlDynamic?.runtimeType}, content=${contentText?.substring(0, (contentText?.length ?? 0) > 50 ? 50 : (contentText?.length ?? 0))}...'); // Log truncated content

  switch (contentType) {
    case 'image':
      String? imageUrl;

      if (mediaUrlDynamic == null) {
        print('Content preview: Image mediaUrl is null.');
        // Keep imageUrl as null
      } else if (mediaUrlDynamic is List) {
        if (mediaUrlDynamic.isNotEmpty && mediaUrlDynamic[0] is String) {
          imageUrl = mediaUrlDynamic[0];
          print('Content preview: Image mediaUrl is a list, using first item: $imageUrl');
        } else {
          print('Content preview: Image mediaUrl is a list but empty or first item is not a String.');
        }
      } else if (mediaUrlDynamic is String) {
        imageUrl = mediaUrlDynamic;
        print('Content preview: Image mediaUrl is a String: $imageUrl');
      } else {
        print('Content preview: Image mediaUrl is of unexpected type: ${mediaUrlDynamic.runtimeType}');
      }

      if (imageUrl != null && imageUrl.isNotEmpty) {
        // Validate URL format (basic check)
        if (!imageUrl.toLowerCase().startsWith('http://') && !imageUrl.toLowerCase().startsWith('https://')) {
          print('Content preview: Invalid image URL format: $imageUrl');
          return _buildPlaceholder('Invalid Image URL', height);
        }

        return Image.network(
          imageUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: height ?? double.infinity,
          // Add loading builder for better UX
          loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
            if (loadingProgress == null) return child; // Image loaded
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(kPrimaryTeal),
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            print('Content preview: Image load error for $imageUrl: $error');
            // Log specific error type if possible
            if (error is NetworkImageLoadException) {
              print('NetworkImageLoadException details: statusCode=${error.statusCode}, uri=${error.uri}');
            }
            return _buildPlaceholder('Image failed to load', height);
          },
        );
      } else {
        return _buildPlaceholder('No image available', height);
      }

    case 'video':
      String? videoUrl;
      if (mediaUrlDynamic is String && mediaUrlDynamic.isNotEmpty) {
        videoUrl = mediaUrlDynamic;
        print('Content preview: Video mediaUrl: $videoUrl');
      } else {
        print('Content preview: Video mediaUrl is null, empty, or not a String.');
      }


      return Stack(
        alignment: Alignment.center,
        children: [
          Container(
            color: kCardBackground.withOpacity(0.1), // Light background for video placeholder
            width: double.infinity,
            height: height ?? double.infinity,
          ),
          GestureDetector(
            onTap: () {
              if (videoUrl != null) {
                // Basic URL validation
                if (!videoUrl.toLowerCase().startsWith('http://') && !videoUrl.toLowerCase().startsWith('https://')) {
                  print('Content preview: Invalid video URL format on tap: $videoUrl');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Invalid video URL format.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                print('Content preview: Video preview tapped, navigating to VideoWidget with URL: $videoUrl');
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VideoWidget(videoUrl: videoUrl!), // Pass validated URL
                  ),
                ).then((_) => print('Returned from VideoWidget'));
              } else {
                print('Content preview: Invalid or missing mediaUrl for video on tap.');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cannot play video: Invalid URL.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Container(
              width: double.infinity,
              height: height ?? double.infinity,
              color: Colors.transparent, // Ensure GestureDetector receives taps
              child: const Icon(
                Icons.play_circle_outline,
                size: 50,
                color: kPrimaryTeal,
              ),
            ),
          ),
        ],
      );

    case 'text':
    case 'code':
    default:
      print('Content preview: Displaying text/code content.');
      return Container(
        padding: const EdgeInsets.all(16.0),
        width: double.infinity,
        height: height ?? double.infinity, // Use provided height or expand
        color: kCardBackground.withOpacity(0.95), // Slightly opaque background
        alignment: Alignment.center, // Center the text
        child: Text(
          (contentText != null && contentText.isNotEmpty) ? contentText : 'No content available',
          textAlign: TextAlign.center,
          style: TextStyle(color: kTextPrimary, fontSize: 16),
          maxLines: 6, // Limit lines for preview
          overflow: TextOverflow.ellipsis, // Add ellipsis if text overflows
        ),
      );
  }
}

// Helper widget for placeholders
Widget _buildPlaceholder(String message, double? height) {
  print('Content preview: Displaying placeholder: "$message"');
  return Container(
    width: double.infinity,
    height: height ?? double.infinity,
    color: kBackgroundGradientEnd.withOpacity(0.2), // Use a subtle background
    alignment: Alignment.center,
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: TextStyle(color: kTextSecondary, fontSize: 14),
    ),
  );
}


// END OF FILE content_preview.dart