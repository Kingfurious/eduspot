import 'package:cloud_firestore/cloud_firestore.dart';

// Message model updated with read receipt functionality
class Message {
  final String senderId;
  final String receiverId;
  final String? content;
  final Timestamp timestamp;
  final String type; // 'text', 'image', 'video', 'audio', 'deleted'
  final String? mediaUrl;
  final String? fileName;
  final String? storagePath;
  final List<String> deletedFor;
  final bool isRead; // Whether the message has been read by the recipient
  final Timestamp? readTimestamp; // When the message was read

  Message({
    required this.senderId,
    required this.receiverId,
    this.content,
    required this.timestamp,
    required this.type,
    this.mediaUrl,
    this.fileName,
    this.storagePath,
    required this.deletedFor,
    this.isRead = false, // Default to false (unread)
    this.readTimestamp,
  });

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      content: map['content'],
      timestamp: map['timestamp'] ?? Timestamp.now(),
      type: map['type'] ?? 'text',
      mediaUrl: map['mediaUrl'],
      fileName: map['fileName'],
      storagePath: map['storagePath'],
      deletedFor: List<String>.from(map['deletedFor'] ?? []),
      isRead: map['isRead'] ?? false,
      readTimestamp: map['readTimestamp'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'content': content,
      'timestamp': timestamp,
      'type': type,
      'mediaUrl': mediaUrl,
      'fileName': fileName,
      'storagePath': storagePath,
      'deletedFor': deletedFor,
      'isRead': isRead,
      'readTimestamp': readTimestamp,
    };
  }
}