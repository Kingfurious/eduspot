import 'package:cloud_firestore/cloud_firestore.dart';

class AdModel {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String? videoUrl;
  final String targetUrl;
  final String advertiserName;
  final Timestamp expiryDate;
  final String placementLocation;
  final int impressions;
  final bool isActive;

  AdModel({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    this.videoUrl,
    required this.targetUrl,
    required this.advertiserName,
    required this.expiryDate,
    required this.placementLocation,
    required this.impressions,
    required this.isActive,
  });

  factory AdModel.fromMap(Map<String, dynamic> map, String documentId) {
    return AdModel(
      id: documentId,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      videoUrl: map['videoUrl'],
      targetUrl: map['targetUrl'] ?? '',
      advertiserName: map['advertiserName'] ?? '',
      expiryDate: map['expiryDate'] ?? Timestamp.now(),
      placementLocation: map['placementLocation'] ?? 'home',
      impressions: map['impressions'] ?? 0,
      isActive: map['isActive'] ?? false,
    );
  }
}