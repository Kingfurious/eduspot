// START OF FILE screens/messaging/widgets/full_screen_image_viewer.dart

import 'package:flutter/material.dart';

class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  const FullScreenImageViewer({Key? key, required this.imageUrl}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.5), // Make AppBar slightly transparent
        elevation: 0, // No shadow
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.white), // White close icon
          onPressed: () => Navigator.pop(context),
          tooltip: "Close",
        ),
      ),
      body: SafeArea( // Ensure image doesn't overlap status bar etc.
        child: Center(
          // InteractiveViewer allows pinch-to-zoom and panning
          child: InteractiveViewer(
            panEnabled: true, // Enable panning
            boundaryMargin: EdgeInsets.all(20), // Margin around the image
            minScale: 0.5, // Minimum zoom level
            maxScale: 4.0, // Maximum zoom level
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain, // Show the whole image within the viewport
              // Add loading and error builders for better UX
              loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                if (loadingProgress == null) return child; // Image loaded
                return Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white), // White progress indicator
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                        : null, // Indeterminate if total size unknown
                  ),
                );
              },
              errorBuilder: (BuildContext context, Object exception, StackTrace? stackTrace) {
                print("Error loading full-screen image: $exception");
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, color: Colors.red, size: 50),
                      SizedBox(height: 10),
                      Text(
                        "Could not load image",
                        style: TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// END OF FILE screens/messaging/widgets/full_screen_image_viewer.dart