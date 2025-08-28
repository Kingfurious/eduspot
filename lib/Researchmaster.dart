import 'package:flutter/material.dart';
import 'Researchmasterdetail.dart';
import 'Researchmasterdetail.dart' as detail;

import 'package:flutter/services.dart';

// Color Palette
const Color primaryBlue = Color(0xFF1976D2);
const Color lightBlue = Color(0xFF64B5F6);
const Color veryLightBlue = Color(0xFFE3F2FD);
const Color darkBlue = Color(0xFF0D47A1);
const Color accentBlue = Color(0xFF29B6F6);

void main() {
  runApp(const ResearchAssistantApp());
}

class ResearchAssistantApp extends StatelessWidget {
  const ResearchAssistantApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Research Assistant',
      theme: ThemeData(
        primaryColor: primaryBlue,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Roboto',
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryBlue,
            foregroundColor: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: lightBlue),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primaryBlue, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: lightBlue),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        cardTheme: CardThemeData(
          elevation: 4,
          shadowColor: Colors.black.withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const Researchmaster(),
    );
  }
}



class Researchmaster extends StatefulWidget {
  const Researchmaster({Key? key}) : super(key: key);

  @override
  State<Researchmaster> createState() => _ResearchmasterState();
}

class _ResearchmasterState extends State<Researchmaster> {
  @override
  void initState() {
    super.initState();
    // Hide status bar when this page is initialized
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );
  }

  @override
  void dispose() {
    // Restore status bar when navigating away from this page
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Modern app bar with 3D depth effect (full width only)
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
            ),
            child: Column(
              children: [
                // Hero section with 3D depth effect - full width
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 45, 24, 24),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        primaryBlue,
                        darkBlue,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryBlue.withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Text
                      const Text(
                        "Find the Perfect Tool",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Subtitle
                      Text(
                        "Browse our collection of research support tools designed to help you succeed.",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tools grid
          Expanded(
            child: ResearchToolsGrid(),
          ),
        ],
      ),
    );
  }
}

class ResearchToolsGrid extends StatelessWidget {
  ResearchToolsGrid({Key? key}) : super(key: key);

  final List<ResearchTool> tools = [

    ResearchTool(
      title: 'Plagiarism Checking & Reduction (incl AI)',
      icon: Icons.auto_fix_high_outlined,
      color: lightBlue,
      description: 'Check and Improve the originality of your content with turnitin',
      originalTitle: 'Plagiarism Reduction',
    ),
    ResearchTool(
      title: 'Innovation Documentation',
      icon: Icons.lightbulb_outline,
      color: accentBlue,
      description: 'Get assistance with documenting your patents professionally',
      originalTitle: 'Patent Writing',
    ),
    ResearchTool(
      title: 'Scientific Manuscript',
      icon: Icons.science_outlined,
      color: primaryBlue,
      description: 'Structure your research findings into publication-ready manuscripts',
      originalTitle: 'SCI Paper Writing',
    ),
    ResearchTool(
      title: 'Academic Guidance',
      icon: Icons.school_outlined,
      color: darkBlue,
      description: 'Get guidance on developing comprehensive academic documents',
      originalTitle: 'Thesis Writing',
    ),
    ResearchTool(
      title: 'Book Chapter Writing',
      icon: Icons.book_outlined,
      color: lightBlue,
      description: 'Organize and develop your research into book chapter format',
      originalTitle: 'Book Chapter Writing',
    ),
    ResearchTool(
      title: 'Project PPT Making',
      icon: Icons.slideshow_outlined,
      color: accentBlue,
      description: 'Create impressive presentations to showcase your projects',
      originalTitle: 'Project Presentation Making',
    ),
    ResearchTool(
      title: 'Visual Research',
      icon: Icons.videocam_outlined,
      color: primaryBlue,
      description: 'Transform your research into engaging video content',
      originalTitle: 'Project Video Making',
    ),
    ResearchTool(
      title: 'Business Concept',
      icon: Icons.business_outlined,
      color: darkBlue,
      description: 'Create compelling business pitches for your ideas',
      originalTitle: 'Business Pitch Making',
    ),
    ResearchTool(
      title: 'Project Report',
      icon: Icons.description_outlined,
      color: lightBlue,
      description: 'Develop comprehensive and well-structured project reports',
      originalTitle: 'Project Report Making',
    ),
    ResearchTool(
      title: 'BE Full Project Guidance',
      icon: Icons.engineering_outlined,
      color: accentBlue,
      description: 'Get guidance and support for BE projects',
      originalTitle: 'BE Projects Making',
    ),
    ResearchTool(
      title: 'ME Full Project Support',
      icon: Icons.psychology_outlined,
      color: primaryBlue,
      description: 'Get guidance and support for ME projects',
      originalTitle: 'ME Projects Making',
    ),
    ResearchTool(
      title: 'Machine Learning Coding',
      icon: Icons.book_online_rounded,
      color: primaryBlue,
      description: 'Get Machine Learning codes with Anydesk Support according to your project',
      originalTitle: 'ML Coding',
    ),

  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 16.0,
        mainAxisSpacing: 16.0,
      ),
      itemCount: tools.length,
      itemBuilder: (context, index) {
        return ToolCard(tool: tools[index]);
      },
    );
  }
}

class ToolCard extends StatelessWidget {
  final ResearchTool tool;

  const ToolCard({
    Key? key,
    required this.tool,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
        decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
    boxShadow: [
    BoxShadow(
    color: Colors.black.withOpacity(0.05),
    blurRadius: 10,
    offset: const Offset(0, 4),
    ),
    ],
    ),
    child: Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
    onTap: () {
    Navigator.push(
    context,
    MaterialPageRoute(
    builder: (context) => ToolDetailsPage(tool: convertToDetailTool(tool)),
    ),
    );
    },
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
    // Top section with icon and title
    Container(
    height: 100,
    decoration: BoxDecoration(
    gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
    tool.color,
    tool.color.withOpacity(0.7),
    ],
    ),
    ),
    child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
    // Icon
    Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
    color: Colors.white.withOpacity(0.3),
    shape: BoxShape.circle,
    ),
    child: Icon(
    tool.icon,
    color: Colors.white,
    size: 24,
    ),
    ),
    const SizedBox(height: 8),
    // Title in the colored section
    Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Text(
    tool.title,
    style: const TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 14,
    height: 1.2,
    color: Colors.white,
    ),
    textAlign: TextAlign.center,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    ),
    ),
    ],
    ),
    ),

    // Description section
    Expanded(
    child: Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    // Description with expanded height
    Expanded(
    child: Text(
    tool.description,
    style: TextStyle(
    fontSize: 12,
    color: Colors.grey.shade600,
    height: 1.3,
    ),
    ),
    ),

    // Access button at the bottom
    Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.symmetric(vertical: 6),
    decoration: BoxDecoration(
    color: tool.color.withOpacity(0.1),
    borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
    Text(
    'View Details',
    style: TextStyle(
    color: tool.color,
    fontWeight: FontWeight.w600,
    fontSize: 12,
    ),
    ),
    const SizedBox(width: 4),
    Icon(
    Icons.arrow_forward,
    size: 12,
    color: tool.color,
    ),
    ],
    ),
    ),
    ],
    ),
    ),
    ),
    ],
    ),
    ),
    ),
    );
  }
}

class ResearchTool {
  final String title;
  final IconData icon;
  final Color color;
  final String description;
  final String originalTitle;  // The original service name (for internal reference)

  ResearchTool({
    required this.title,
    required this.icon,
    required this.color,
    required this.description,
    required this.originalTitle,
  });
}

// Add this conversion method
detail.ResearchTool convertToDetailTool(ResearchTool tool) {
  return detail.ResearchTool(
    title: tool.title,
    icon: tool.icon,
    color: tool.color,
    description: tool.description,
    originalTitle: tool.originalTitle,
  );
}