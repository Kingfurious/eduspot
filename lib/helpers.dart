import 'package:flutter/material.dart';
import 'VideoWidget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const Color kBackgroundGradientStart = Color(0xFFF5F7FA);
const Color kBackgroundGradientEnd = Color(0xFFE0EAF1);
const Color kCardBackground = Color(0xFFFFFFFF);
const Color kPrimaryTeal = Color(0xFF26A69A);
const Color kSecondaryCoral = Color(0xFFFF7043);
const Color kTextPrimary = Color(0xFF263238);
const Color kTextSecondary = Color(0xFF78909C);
const Color kIconInactive = Color(0xFFB0BEC5);
const Color kShadowColor = Color(0x1A000000);

String formatTimestamp(dynamic timestamp) {
  if (timestamp is Timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}';
  }
  return 'Just now';
}

Widget buildContentPreview(BuildContext context, Map<String, dynamic> data, {double? height}) {
  print('Building content preview for type: ${data['type']}, mediaUrl: ${data['mediaUrl']}, mediaUrl type: ${data['mediaUrl'].runtimeType}');
  switch (data['type']) {
    case 'image':
      if (data['mediaUrl'] == null) {
        return Center(
          child: Text(
            'No image available',
            style: TextStyle(color: kTextSecondary),
          ),
        );
      }

      String? imageUrl;
      if (data['mediaUrl'] is List && (data['mediaUrl'] as List).isNotEmpty) {
        imageUrl = (data['mediaUrl'] as List)[0].toString();
      } else if (data['mediaUrl'] is String) {
        imageUrl = data['mediaUrl'] as String;
      }

      return imageUrl != null && imageUrl.isNotEmpty
          ? Image.network(
        imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: height ?? double.infinity,
        errorBuilder: (context, error, stackTrace) {
          print('Image load error: $error');
          return Center(
            child: Text(
              'Image failed to load',
              style: TextStyle(color: kTextSecondary),
            ),
          );
        },
      )
          : Center(
        child: Text(
          'No image available',
          style: TextStyle(color: kTextSecondary),
        ),
      );
    case 'video':
      return Stack(
        alignment: Alignment.center,
        children: [
          Container(
            color: kBackgroundGradientEnd.withOpacity(0.3),
            width: double.infinity,
            height: height ?? double.infinity,
          ),
          GestureDetector(
            onTap: () {
              print('Video preview tapped, mediaUrl: ${data['mediaUrl']}');
              if (data['mediaUrl'] != null && data['mediaUrl'].isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VideoWidget(videoUrl: data['mediaUrl']),
                  ),
                ).then((_) => print('Returned from VideoWidget'));
              } else {
                print('Invalid or missing mediaUrl for video');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Invalid video URL.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Container(
              width: double.infinity,
              height: height ?? double.infinity,
              color: Colors.transparent,
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
      return Container(
        padding: const EdgeInsets.all(16.0),
        width: double.infinity,
        height: height ?? double.infinity,
        color: kCardBackground.withOpacity(0.95),
        child: Center(
          child: Text(
            data['content'] ?? 'No content',
            textAlign: TextAlign.center,
            style: TextStyle(color: kTextPrimary, fontSize: 16),
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
  }
}