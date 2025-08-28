import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'MentorBookingForm.dart';
import 'MentorBookingForm.dart';

class AppColors {
static const Color primaryBlue = Color(0xFF1976D2);
static const Color lightBlue = Color(0xFF64B5F6);
static const Color veryLightBlue = Color(0xFFE3F2FD);
static const Color darkBlue = Color(0xFF0D47A1);
static const Color accentBlue = Color(0xFF29B6F6);
static const Color textPrimary = Color(0xFF263238);
static const Color textSecondary = Color(0xFF607D8B);
static const Color background = Color(0xFFF5F7FA);
static const Color cardBackground = Colors.white;
static const Color shadowColor = Color(0xFF000000);
static const Color errorColor = Color(0xFFD32F2F);
static const Color successColor = Color(0xFF388E3C);
static const Color gradientStart = Color(0xFF2196F3);
static const Color gradientEnd = Color(0xFF1976D2);
static const Color watercolorLight = Color(0xFFBBDEFB);
static const Color watercolorDark = Color(0xFF42A5F5);
static const Color gridColor1 = Color(0xFFFF8A80);
static const Color gridColor2 = Color(0xFF80D8FF);
static const Color gridColor3 = Color(0xFFFFD180);
static const Color gridColor4 = Color(0xFFFF6F61);
static const Color gridColor5 = Color(0xFFB388FF);
static const Color gridColor6 = Color(0xFFFF80AB);
static const Color gridColor7 = Color(0xFF4CAF50);
static const Color gridColor8 = Color(0xFFFFD740);
static const Color gridColor9 = Color(0xFF82B1FF);
static const Color glassBackground = Color(0x80FFFFFF);
static const Color glassBorder = Color(0x33FFFFFF);
}

class MentorPage extends StatelessWidget {
  const MentorPage({Key? key}) : super(key: key);


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mentors'),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.gradientStart, AppColors.gradientEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.background, AppColors.veryLightBlue],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('mentors').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primaryBlue),
                ),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error loading mentors',
                  style: TextStyle(
                    color: AppColors.errorColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Text(
                  'No mentors found',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }

            final mentors = snapshot.data!.docs;
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: mentors.length,
              itemBuilder: (context, index) {
                final mentorData = mentors[index].data() as Map<String,
                    dynamic>;
                final mentorId = mentors[index].id;
                final name = mentorData['name'] ?? 'Unknown Mentor';
                final domain = mentorData['domain'] ?? 'N/A';
                final profilePic = mentorData['profilePic'] ?? '';
                final price = mentorData['price']?.toString() ?? '0';

                return _buildMentorCard(
                  context,
                  mentorId: mentorId,
                  name: name,
                  domain: domain,
                  profilePic: profilePic,
                  price: price,
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildMentorCard(BuildContext context, {
    required String mentorId,
    required String name,
    required String domain,
    required String profilePic,
    required String price,
  }) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowColor.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.primaryBlue.withOpacity(0.2),
            backgroundImage: profilePic.isNotEmpty
                ? NetworkImage(profilePic)
                : null,
            child: profilePic.isEmpty
                ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: AppColors.primaryBlue,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            )
                : null,
          ),
          title: Text(
            name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                domain,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '₹$price',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBlue,
                ),
              ),
            ],
          ),
          trailing: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      MentorBookingForm(
                        mentorId: mentorId,
                        mentorName: name,
                        price: double.parse(price),
                        mentorImage: profilePic, // Fixed to use profilePic
                      ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text(
              'Book Now',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}