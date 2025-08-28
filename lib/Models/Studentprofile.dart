import 'package:cloud_firestore/cloud_firestore.dart'; // Import this to use Timestamp

class StudentProfile {
  final String careerGoal;
  final String collegeName;
  final DateTime createdAt;
  final String department;
  final String email;
  final String fullName;
  final String imageUrl;
  final String phoneNumber;
  final List<String> portfolioLinks;
  final String primarySkill;
  final String year;

  StudentProfile({
    required this.careerGoal,
    required this.collegeName,
    required this.createdAt,
    required this.department,
    required this.email,
    required this.fullName,
    required this.imageUrl,
    required this.phoneNumber,
    required this.portfolioLinks,
    required this.primarySkill,
    required this.year,
  });

  factory StudentProfile.fromMap(Map<String, dynamic> data) {
    return StudentProfile(
      careerGoal: data['careerGoal'] ?? '',
      collegeName: data['collegeName'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(), // Handle null case
      department: data['department'] ?? '',
      email: data['email'] ?? '',
      fullName: data['fullName'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      portfolioLinks: List<String>.from(data['portfolioLinks'] ?? []),
      primarySkill: data['primarySkill'] ?? '',
      year: data['year'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'careerGoal': careerGoal,
      'collegeName': collegeName,
      'createdAt': Timestamp.fromDate(createdAt), // Convert DateTime to Timestamp for Firestore
      'department': department,
      'email': email,
      'fullName': fullName,
      'imageUrl': imageUrl,
      'phoneNumber': phoneNumber,
      'portfolioLinks': portfolioLinks,
      'primarySkill': primarySkill,
      'year': year,
    };
  }
}