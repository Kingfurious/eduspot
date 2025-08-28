import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class NotificationService {
  static const String TYPE_LIKE = 'like';
  static const String TYPE_COMMENT = 'comment';
  static const String TYPE_MILESTONE = 'milestone';

  // FCM server key (store securely in production, e.g., in environment variables)
  static const String _fcmServerKey = 'YOUR_FCM_SERVER_KEY'; // Replace with your FCM server key

  Future<void> createNotification({
    required String userId,
    required String type,
    required String actorId,
    String? actorName,
    String? actorPhotoURL,
    required String postId,
    required String postTitle,
    String? postImageURL,
    String? commentId,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || userId == currentUser.uid) return;

      // Store notification in Firestore
      final notificationData = {
        'userId': userId,
        'type': type,
        'postId': postId,
        'actorId': actorId,
        'actorName': actorName ?? 'Someone',
        'actorPhotoURL': actorPhotoURL,
        'postTitle': postTitle,
        'postImageURL': postImageURL,
        'commentId': commentId,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      };

      await FirebaseFirestore.instance.collection('notifications').add(notificationData);

      // Send push notification via FCM
      await _sendPushNotification(userId, type, actorName, postTitle, postId: postId);
    } catch (e) {
      print("Error creating notification: $e");
    }
  }

  Future<void> createMilestoneNotification({
    required String userId,
    required String postId,
    required String postTitle,
    required int likeCount,
  }) async {
    try {
      final notificationData = {
        'userId': userId,
        'type': TYPE_MILESTONE,
        'postId': postId,
        'postTitle': postTitle,
        'likeCount': likeCount,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      };

      await FirebaseFirestore.instance.collection('notifications').add(notificationData);

      // Send push notification via FCM
      await _sendPushNotification(userId, TYPE_MILESTONE, null, postTitle, postId: postId, likeCount: likeCount);
    } catch (e) {
      print("Error creating milestone notification: $e");
    }
  }

  Future<void> _sendPushNotification(
      String userId,
      String type,
      String? actorName,
      String postTitle, {
        required String postId, // Add postId as a required parameter
        int? likeCount,
      }) async {
    try {
      // Fetch the user's FCM token from Firestore (assuming it's stored in the user's document)
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (!userDoc.exists) return;

      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      String? fcmToken = userData['fcmToken'] as String?;

      if (fcmToken == null || fcmToken.isEmpty) {
        print("No FCM token found for user $userId");
        return;
      }

      // Construct the notification message based on type
      String title;
      String body;

      switch (type) {
        case TYPE_LIKE:
          title = 'New Like';
          body = '${actorName ?? "Someone"} liked your post "$postTitle".';
          break;
        case TYPE_COMMENT:
          title = 'New Comment';
          body = '${actorName ?? "Someone"} commented on your post "$postTitle".';
          break;
        case TYPE_MILESTONE:
          title = 'Milestone Reached';
          body = 'Your post "$postTitle" has reached $likeCount likes!';
          break;
        default:
          return;
      }

      // Construct the FCM payload
      final message = {
        'to': fcmToken,
        'notification': {
          'title': title,
          'body': body,
        },
        'data': {
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          'type': type,
          'postId': postId, // Now postId is defined
        },
      };

      // Send the push notification via FCM
      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$_fcmServerKey',
        },
        body: jsonEncode(message),
      );

      if (response.statusCode == 200) {
        print("Push notification sent successfully to $userId: $title - $body");
      } else {
        print("Failed to send push notification: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("Error sending push notification: $e");
    }
  }
}