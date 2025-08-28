// models/course.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Course {
  final String id;
  final String? name;
  final String? description;
  final String? imageUrl;
  final String? coursePrice;
  final String? duration;
  final String? startDate;
  final String? endDate;
  final String? level;
  final String? teacherName;
  final String? teacherBio;
  final String? teacherEmail;
  final String? teacherImage;
  final String? teacherContact;
  final String? category;
  final String? prerequisites;
  final int? rating;
  final int? enrolledStudents;
  final List<String> syllabus;
  final List<String> tags;

  Course({
    required this.id,
    this.name,
    this.description,
    this.imageUrl,
    this.coursePrice,
    this.duration,
    this.startDate,
    this.endDate,
    this.level,
    this.teacherName,
    this.teacherBio,
    this.teacherEmail,
    this.teacherImage,
    this.teacherContact,
    this.category,
    this.prerequisites,
    this.rating,
    this.enrolledStudents,
    this.syllabus = const [],
    this.tags = const [],
  });

  factory Course.fromFirestore(Map<String, dynamic> data, String docId) {
    // Debug logging to help identify issues
    print('Parsing course with docId: $docId');
    print('Raw data: $data');

    // Safely extract data with type checking
    return Course(
      id: docId,
      name: _safeString(data, 'name'),
      description: _safeString(data, 'description'),
      imageUrl: _safeString(data, 'imageUrl'),
      coursePrice: _safeString(data, 'coursePrice'),
      duration: _safeString(data, 'duration'),
      startDate: _safeString(data, 'startDate'),
      endDate: _safeString(data, 'endDate'),
      level: _safeString(data, 'level'),
      teacherName: _safeString(data, 'teacherName'),
      teacherBio: _safeString(data, 'teacherBio'),
      teacherEmail: _safeString(data, 'teacherEmail'),
      teacherImage: _safeString(data, 'teacherImage'),
      teacherContact: _safeString(data, 'teacherContact'),
      category: _safeString(data, 'category'),
      prerequisites: _safeString(data, 'prerequisites'),
      rating: _safeInt(data, 'rating'),
      enrolledStudents: _safeInt(data, 'enrolledStudents'),
      syllabus: _safeStringList(data, 'syllabus'),
      tags: _safeStringList(data, 'tags'),
    );
  }

  // Safe getters for different data types
  static String? _safeString(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return null;
    return value.toString();
  }

  static int? _safeInt(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is double) return value.toInt();
    return null;
  }

  static List<String> _safeStringList(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return [];
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    return [];
  }
}