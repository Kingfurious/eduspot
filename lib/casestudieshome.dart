import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'CaseStudyDetailPage.dart';
import 'Learningresource.dart';

class CasestudiesHomePage extends StatefulWidget {
  @override
  _CasestudiesHomePageState createState() => _CasestudiesHomePageState();
}

class _CasestudiesHomePageState extends State<CasestudiesHomePage> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<String> _selectedDomains = [];
  List<String> _selectedSkills = [];
  List<String> _availableDomains = [];
  List<String> _availableSkills = [];
  bool _isLoading = true;
  bool _showResourcesHint = true;

  // Animation controller for resources fab
  late AnimationController _animationController;
  late Animation<double> _animation;

  // Define sky blue color palette
  final Color primaryBlue = Color(0xFF1976D2);
  final Color lightBlue = Color(0xFF64B5F6);
  final Color veryLightBlue = Color(0xFFE3F2FD);
  final Color darkBlue = Color(0xFF0D47A1);
  final Color accentBlue = Color(0xFF29B6F6);

  @override
  void initState() {
    super.initState();
    _fetchAvailableFilters();

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });

    // Initialize animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Create a curved animation
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );

    // Start the animation after a short delay
    Future.delayed(Duration(milliseconds: 500), () {
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _fetchAvailableFilters() async {
    setState(() {
      _isLoading = true;
    });

    // Fetch unique domains
    final domainsSnapshot = await FirebaseFirestore.instance
        .collection('case_studies')
        .get();

    Set<String> domains = {};
    Set<String> skills = {};

    for (var doc in domainsSnapshot.docs) {
      var data = doc.data();
      if (data['domain'] != null) {
        domains.add(data['domain'] as String);
      }

      if (data['skills'] != null) {
        String skillsString = data['skills'] as String;
        List<String> skillsList = skillsString.split(',')
            .map((skill) => skill.trim())
            .where((skill) => skill.isNotEmpty)
            .toList();
        skills.addAll(skillsList);
      }
    }

    setState(() {
      _availableDomains = domains.toList()..sort();
      _availableSkills = skills.toList()..sort();
      _isLoading = false;
    });
  }

  bool _matchesFilters(Map<String, dynamic> caseStudy) {
    // Check search query
    if (_searchQuery.isNotEmpty) {
      String title = (caseStudy['title'] ?? '').toLowerCase();
      String description = (caseStudy['description'] ?? '').toLowerCase();
      String challenges = (caseStudy['challenges'] ?? '').toLowerCase();

      if (!title.contains(_searchQuery.toLowerCase()) &&
          !description.contains(_searchQuery.toLowerCase()) &&
          !challenges.contains(_searchQuery.toLowerCase())) {
        return false;
      }
    }

    // Check domain filter
    if (_selectedDomains.isNotEmpty) {
      String domain = caseStudy['domain'] ?? '';
      if (!_selectedDomains.contains(domain)) {
        return false;
      }
    }

    // Check skills filter
    if (_selectedSkills.isNotEmpty) {
      String skillsString = caseStudy['skills'] ?? '';
      List<String> caseStudySkills = skillsString.split(',')
          .map((skill) => skill.trim())
          .where((skill) => skill.isNotEmpty)
          .toList();

      bool hasMatchingSkill = false;
      for (var skill in _selectedSkills) {
        if (caseStudySkills.contains(skill)) {
          hasMatchingSkill = true;
          break;
        }
      }

      if (!hasMatchingSkill) {
        return false;
      }
    }

    return true;
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15.0),
              ),
              title: Text(
                'Filter Case Studies',
                style: TextStyle(
                  color: darkBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Container(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                          'Domains',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: darkBlue,
                          )
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: _availableDomains.map((domain) {
                          return FilterChip(
                            label: Text(domain),
                            selected: _selectedDomains.contains(domain),
                            selectedColor: lightBlue,
                            checkmarkColor: Colors.white,
                            backgroundColor: veryLightBlue,
                            labelStyle: TextStyle(
                              color: _selectedDomains.contains(domain) ? Colors.white : darkBlue,
                            ),
                            onSelected: (selected) {
                              setStateDialog(() {
                                if (selected) {
                                  _selectedDomains.add(domain);
                                } else {
                                  _selectedDomains.remove(domain);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      Text(
                          'Skills',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: darkBlue,
                          )
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: _availableSkills.map((skill) {
                          return FilterChip(
                            label: Text(skill),
                            selected: _selectedSkills.contains(skill),
                            selectedColor: lightBlue,
                            checkmarkColor: Colors.white,
                            backgroundColor: veryLightBlue,
                            labelStyle: TextStyle(
                              color: _selectedSkills.contains(skill) ? Colors.white : darkBlue,
                            ),
                            onSelected: (selected) {
                              setStateDialog(() {
                                if (selected) {
                                  _selectedSkills.add(skill);
                                } else {
                                  _selectedSkills.remove(skill);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  child: Text(
                    'Clear All',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  onPressed: () {
                    setStateDialog(() {
                      _selectedDomains = [];
                      _selectedSkills = [];
                    });
                  },
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Apply'),
                  onPressed: () {
                    setState(() {
                      // Apply filters in parent widget
                    });
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }



  void _navigateToLearningResources() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LearningResources(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        primaryColor: primaryBlue,
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: primaryBlue,
          secondary: accentBlue,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: primaryBlue,
          elevation: 0,
        ),
        scaffoldBackgroundColor: Colors.grey[50],
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Case Studies',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          actions: [
            // Learning resources navigation icon
            IconButton(
              icon: Stack(
                children: [
                  Icon(Icons.school, color: Colors.white),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      constraints: BoxConstraints(
                        minWidth: 12,
                        minHeight: 12,
                      ),
                      child: Text(
                        'New',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
              tooltip: 'Learning Resources',
              onPressed: _navigateToLearningResources,
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: IconButton(
                icon: Icon(Icons.filter_list, color: Colors.white),
                onPressed: _showFilterDialog,
                tooltip: 'Filter case studies',
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: primaryBlue,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    spreadRadius: 1,
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    style: TextStyle(color: Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Search case studies...',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      prefixIcon: Icon(Icons.search, color: primaryBlue),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey[600]),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(vertical: 12.0),
                    ),
                  ),

                  // Learning Resources Banner
                  Container(
                    margin: EdgeInsets.only(top: 16),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: veryLightBlue,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: lightBlue),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lightbulb, color: Colors.amber),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Enhance Your Learning',
                                style: TextStyle(
                                  color: darkBlue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Access videos, articles, and exercises tailored to your case studies',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: _navigateToLearningResources,
                          style: TextButton.styleFrom(
                            backgroundColor: accentBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          child: Text('Explore'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Display filter chips
            if (_selectedDomains.isNotEmpty || _selectedSkills.isNotEmpty)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Active Filters:',
                      style: TextStyle(
                        color: darkBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: [
                        ..._selectedDomains.map((domain) {
                          return Chip(
                            label: Text(
                              'Domain: $domain',
                              style: TextStyle(color: Colors.white, fontSize: 12),
                            ),
                            backgroundColor: primaryBlue,
                            deleteIconColor: Colors.white,
                            onDeleted: () {
                              setState(() {
                                _selectedDomains.remove(domain);
                              });
                            },
                          );
                        }),
                        ..._selectedSkills.map((skill) {
                          return Chip(
                            label: Text(
                              'Skill: $skill',
                              style: TextStyle(color: Colors.white, fontSize: 12),
                            ),
                            backgroundColor: accentBlue,
                            deleteIconColor: Colors.white,
                            onDeleted: () {
                              setState(() {
                                _selectedSkills.remove(skill);
                              });
                            },
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _isLoading
                  ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
                ),
              )
                  : StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('case_studies').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
                      ),
                    );
                  }

                  var allCaseStudies = snapshot.data!.docs;
                  var filteredCaseStudies = allCaseStudies.where((doc) {
                    var caseStudyData = doc.data() as Map<String, dynamic>;
                    return _matchesFilters(caseStudyData);
                  }).toList();

                  if (filteredCaseStudies.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No case studies found',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Try adjusting your filters or search terms',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: ListView.builder(
                      itemCount: filteredCaseStudies.length,
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemBuilder: (context, index) {
                        var caseStudy = filteredCaseStudies[index];
                        var caseStudyData = caseStudy.data() as Map<String, dynamic>;

                        // Extract skills for display
                        List<String> skills = [];
                        if (caseStudyData['skills'] != null) {
                          skills = caseStudyData['skills'].toString().split(',')
                              .map((s) => s.trim())
                              .where((s) => s.isNotEmpty)
                              .take(3) // Limit to 3 skills for display
                              .toList();
                        }

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CaseStudyDetailPage(caseStudyId: caseStudy.id),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Domain badge
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: veryLightBlue,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.domain,
                                          size: 14,
                                          color: primaryBlue,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          caseStudyData['domain'] ?? 'No domain',
                                          style: TextStyle(
                                            color: primaryBlue,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 12),
                                  // Title
                                  Text(
                                    caseStudyData['title'] ?? 'Untitled',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: darkBlue,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  // Description
                                  Text(
                                    caseStudyData['description'] ?? 'No description',
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[800],
                                      height: 1.4,
                                    ),
                                  ),
                                  if (skills.isNotEmpty) SizedBox(height: 16),
                                  // Skills
                                  if (skills.isNotEmpty)
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: skills.map((skill) {
                                        return Container(
                                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: accentBlue.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(
                                              color: accentBlue.withOpacity(0.3),
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            skill,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: accentBlue,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  SizedBox(height: 12),

                                  // Action row with view details and resources
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      // Learning resources button
                                      TextButton.icon(
                                        icon: Icon(
                                          Icons.school,
                                          size: 16,
                                          color: accentBlue,
                                        ),
                                        label: Text(
                                          'Resources',
                                          style: TextStyle(
                                            color: accentBlue,
                                          ),
                                        ),
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        ),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => LearningResources(

                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      SizedBox(width: 8),

                                      // View details button
                                      TextButton.icon(
                                        icon: Icon(
                                          Icons.arrow_forward,
                                          size: 16,
                                          color: primaryBlue,
                                        ),
                                        label: Text(
                                          'View Details',
                                          style: TextStyle(
                                            color: primaryBlue,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        ),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => CaseStudyDetailPage(caseStudyId: caseStudy.id),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),



      ),
    );
  }
}

// Custom painter for tooltip arrow
class TrianglePainter extends CustomPainter {
  final Color color;

  TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}