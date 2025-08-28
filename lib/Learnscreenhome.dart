import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'Learninstructionspage.dart';

class LearnHomePage extends StatelessWidget {
  final List<Map<String, dynamic>> domains = [
    {
      'name': 'AI',
      'description': 'Artificial Intelligence & Neural Networks',
      'icon': Icons.psychology,
      'color': const Color(0xFF9C27B0),
    },
    {
      'name': 'C++',
      'description': 'System Programming & Competitive Coding',
      'icon': Icons.developer_board,
      'color': const Color(0xFF607D8B),
    },
    {
      'name': 'Flutter',
      'description': 'Cross-platform Mobile Development',
      'icon': Icons.flutter_dash,
      'color': const Color(0xFF02569B),
    },
    {
      'name': 'Java',
      'description': 'Object-Oriented Programming',
      'icon': Icons.coffee,
      'color': const Color(0xFFF44336),
    },
    {
      'name': 'JavaScript',
      'description': 'Web Development & Node.js',
      'icon': Icons.javascript,
      'color': const Color(0xFFFF9800),
    },
    {
      'name': 'Python',
      'description': 'Data Science & Web Development',
      'icon': Icons.code,
      'color': const Color(0xFF3F51B5),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // Enhanced App Bar with better design
          SliverAppBar(
            expandedHeight: 220,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF1976D2),
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Learn to Code',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF2196F3),
                      Color(0xFF1976D2),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    // Decorative circles
                    Positioned(
                      top: -50,
                      right: -50,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 60,
                      left: -30,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),

                    // Main content
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.school,
                              size: 40,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Choose Your Programming Domain',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Domains Grid with fixed overflow issues
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: domains.isEmpty
                ? SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.code_off,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No domains available',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            )
                : SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.68, // Further increased height to eliminate overflow
              ),
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final domain = domains[index];
                  return _buildDomainCard(context, domain);
                },
                childCount: domains.length,
              ),
            ),
          ),

          // Enhanced Footer with blue theme
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFE3F2FD),
                    const Color(0xFFBBDEFB),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF64B5F6).withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1976D2).withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1976D2).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lightbulb,
                      size: 32,
                      color: Color(0xFF1976D2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Pro Tip',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1976D2),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start with Python if you\'re a beginner, or choose AI for cutting-edge machine learning challenges!',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF263238),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDomainCard(BuildContext context, Map<String, dynamic> domain) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(domain['name']).snapshots(),
      builder: (context, snapshot) {
        String problemCount = 'Loading...';

        if (snapshot.hasData) {
          int count = snapshot.data!.docs.length;
          problemCount = count == 0 ? 'Coming Soon' : '$count Problem${count == 1 ? '' : 's'}';
        } else if (snapshot.hasError) {
          problemCount = 'Error';
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 15,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProblemListPage(),
                    settings: RouteSettings(arguments: domain['name']),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16), // Reduced padding
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon and problem count row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10), // Reduced padding
                          decoration: BoxDecoration(
                            color: domain['color'].withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12), // Reduced radius
                            border: Border.all(
                              color: domain['color'].withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            domain['icon'],
                            size: 22, // Reduced size
                            color: domain['color'],
                          ),
                        ),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6, // Reduced padding
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE3F2FD),
                              borderRadius: BorderRadius.circular(10), // Reduced radius
                              border: Border.all(
                                color: const Color(0xFF64B5F6).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              problemCount,
                              style: GoogleFonts.inter(
                                fontSize: 8, // Reduced font size
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1976D2),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12), // Reduced spacing

                    // Domain name
                    Text(
                      domain['name'],
                      style: GoogleFonts.poppins(
                        fontSize: 16, // Reduced font size
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 4), // Reduced spacing

                    // Description - Reduced height to prevent overflow
                    SizedBox(
                      height: 28, // Reduced height
                      child: Text(
                        domain['description'],
                        style: GoogleFonts.inter(
                          fontSize: 10, // Reduced font size
                          color: Colors.grey[600],
                          height: 1.2, // Reduced line height
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    const SizedBox(height: 12), // Reduced spacing

                    // Start button with enhanced design
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10), // Reduced padding
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            domain['color'],
                            domain['color'].withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10), // Reduced radius
                        boxShadow: [
                          BoxShadow(
                            color: domain['color'].withOpacity(0.3),
                            blurRadius: 6, // Reduced blur
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Explore',
                            style: GoogleFonts.inter(
                              fontSize: 12, // Reduced font size
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 4), // Reduced spacing
                          const Icon(
                            Icons.arrow_forward,
                            size: 14, // Reduced size
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}