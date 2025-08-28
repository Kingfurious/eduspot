import 'package:eduspark/UploadProjectForm.dart';
import 'package:eduspark/casestudieshome.dart';
import 'package:eduspark/library_screen.dart';
import 'package:eduspark/upload_notes_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'ProjectDetailsPage.dart';

// Color Palette
const Color primaryBlue = Color(0xFF1976D2);
const Color lightBlue = Color(0xFF64B5F6);
const Color veryLightBlue = Color(0xFFE3F2FD);
const Color darkBlue = Color(0xFF0D47A1);
const Color accentBlue = Color(0xFF29B6F6);

// Homepage
class ProjectsPagetwo extends StatefulWidget {
  const ProjectsPagetwo({super.key});

  @override
  State<ProjectsPagetwo> createState() => _HomePageState();
}

class _HomePageState extends State<ProjectsPagetwo>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _selectedIdentityFilter;
  String? _selectedDomainFilter;
  bool _isFabExpanded = false;
  late AnimationController _animationController;
  bool _showSearch = false;
  bool _filterExpanded = false;

  final List<String> _identityFilters = ['College', 'Company', 'App Developer'];
  final List<String> _domainFilters = [
    'AI',
    'ML',
    'Web Development',
    'Mobile Development',
    'Data Science'
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleFab() {
    setState(() {
      _isFabExpanded = !_isFabExpanded;
      if (_isFabExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final Size size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(210),
        child: Container(
          decoration: BoxDecoration(
            color: primaryBlue,
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: darkBlue.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top section with title and actions
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                      child: Row(
                        children: [
                          _showSearch
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.arrow_back,
                                    color: Colors.white,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    setState(() {
                                      _showSearch = false;
                                      _searchController.clear();
                                    });
                                  },
                                )
                              : Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.school_rounded,
                                    color: primaryBlue,
                                    size: 20,
                                  ),
                                ),
                          const SizedBox(width: 12),
                          if (!_showSearch)
                            Expanded(
                              child: const Text(
                                'EduSpark Projects',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.white,
                                  letterSpacing: 0.2,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          if (_showSearch) const Spacer(),
                          // Actions
                          IconButton(
                            icon: Icon(
                              _showSearch ? Icons.close : Icons.search,
                              color: Colors.white,
                              size: 22,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              setState(() {
                                _showSearch = !_showSearch;
                                if (!_showSearch) {
                                  _searchController.clear();
                                }
                              });
                            },
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: const Icon(
                              Icons.info_outline,
                              color: Colors.white,
                              size: 22,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _showInfoDialog(context),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),

                    // Search bar or subtitle
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: _showSearch
                            ? SizedBox(
                                height: 36,
                                child: TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    hintText: 'Search projects...',
                                    hintStyle:
                                        const TextStyle(color: Colors.white70),
                                    fillColor: Colors.white.withOpacity(0.15),
                                    filled: true,
                                    isDense: true,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding:
                                        const EdgeInsets.symmetric(vertical: 0),
                                    prefixIcon: const Icon(Icons.search,
                                        color: Colors.white70, size: 18),
                                    prefixIconConstraints: const BoxConstraints(
                                        minWidth: 36, minHeight: 36),
                                    suffixIcon: _searchController
                                            .text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear,
                                                color: Colors.white70,
                                                size: 18),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: () {
                                              _searchController.clear();
                                              setState(() {});
                                            },
                                          )
                                        : null,
                                    suffixIconConstraints: const BoxConstraints(
                                        minWidth: 36, minHeight: 36),
                                  ),
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 14),
                                  cursorColor: Colors.white,
                                  autofocus: true,
                                  onChanged: (value) => setState(() {}),
                                ),
                              )
                            : Container(
                                height: 22,
                                width: double.infinity,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.auto_awesome,
                                      color: Colors.amber,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 6),
                                    const Flexible(
                                      child: Text(
                                        'Discover top learning projects',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Modern single-row horizontal scrollable filter design
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Filter header with active filters
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const Spacer(),
                        if (_selectedIdentityFilter != null ||
                            _selectedDomainFilter != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: primaryBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${(_selectedIdentityFilter != null ? 1 : 0) + (_selectedDomainFilter != null ? 1 : 0)} active',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: primaryBlue,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedIdentityFilter = null;
                                      _selectedDomainFilter = null;
                                    });
                                  },
                                  child: const Icon(
                                    Icons.clear,
                                    size: 14,
                                    color: primaryBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 0.5),

                    // Single row horizontal scrollable filters
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: Row(
                          children: [
                            // All filter option
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: const Text('All'),
                                selected: _selectedIdentityFilter == null &&
                                    _selectedDomainFilter == null,
                                selectedColor: darkBlue,
                                backgroundColor: Colors.grey.shade100,
                                labelStyle: TextStyle(
                                  color: _selectedIdentityFilter == null &&
                                          _selectedDomainFilter == null
                                      ? Colors.white
                                      : Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      _selectedIdentityFilter = null;
                                      _selectedDomainFilter = null;
                                    });
                                  }
                                },
                              ),
                            ),

                            // Identity section label
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: primaryBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.badge_outlined,
                                    size: 14,
                                    color: primaryBlue,
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'Identity:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                      color: primaryBlue,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Identity filter options
                            ...List.generate(_identityFilters.length, (index) {
                              final filter = _identityFilters[index];
                              final isSelected =
                                  _selectedIdentityFilter == filter;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(filter),
                                  selected: isSelected,
                                  showCheckmark: false,
                                  selectedColor: primaryBlue,
                                  backgroundColor: Colors.grey.shade100,
                                  labelStyle: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.grey.shade700,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 0),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  onSelected: (selected) {
                                    setState(() {
                                      _selectedIdentityFilter =
                                          selected ? filter : null;
                                    });
                                  },
                                ),
                              );
                            }),

                            // Domain section label
                            Container(
                              margin: const EdgeInsets.only(right: 8, left: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: accentBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.category_outlined,
                                    size: 14,
                                    color: accentBlue,
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'Domain:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                      color: accentBlue,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Domain filter options
                            ...List.generate(_domainFilters.length, (index) {
                              final filter = _domainFilters[index];
                              final isSelected =
                                  _selectedDomainFilter == filter;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(filter),
                                  selected: isSelected,
                                  showCheckmark: false,
                                  selectedColor: accentBlue,
                                  backgroundColor: Colors.grey.shade100,
                                  labelStyle: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.grey.shade700,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 0),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  onSelected: (selected) {
                                    setState(() {
                                      _selectedDomainFilter =
                                          selected ? filter : null;
                                    });
                                  },
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Project List
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('projects')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Center(
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(primaryBlue),
                        ),
                      );
                    }

                    var projects = snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final title =
                          data['title']?.toString().toLowerCase() ?? '';
                      final description =
                          data['description']?.toString().toLowerCase() ?? '';
                      final identity = data['identity']?.toString();
                      final tags = (data['tags'] as List<dynamic>?)
                              ?.map((tag) => tag.toString())
                              .toList() ??
                          [];

                      bool matchesSearch = _searchController.text.isEmpty ||
                          title
                              .contains(_searchController.text.toLowerCase()) ||
                          description
                              .contains(_searchController.text.toLowerCase());
                      bool matchesIdentity = _selectedIdentityFilter == null ||
                          identity == _selectedIdentityFilter;
                      bool matchesDomain = _selectedDomainFilter == null ||
                          tags.contains(_selectedDomainFilter);

                      return matchesSearch && matchesIdentity && matchesDomain;
                    }).toList();

                    if (projects.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/empty_state.png',
                              width: 120,
                              height: 120,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(
                                Icons.search_off_rounded,
                                size: 80,
                                color: Colors.grey.shade300,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No projects found',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: darkBlue,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Try changing your filters or search term',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: projects.length,
                        itemBuilder: (context, index) {
                          final project = projects[index];
                          final projectData =
                              project.data() as Map<String, dynamic>;
                          final projectId = project.id;
                          final title = projectData['title'] ?? 'Untitled';
                          final description =
                              projectData['description'] ?? 'No description';
                          final identity = projectData['identity']?.toString();
                          final tags = (projectData['tags'] as List<dynamic>?)
                                  ?.map((tag) => tag.toString())
                                  .toList() ??
                              [];

                          return FutureBuilder<double>(
                            future: user != null
                                ? _getUserProgress(user.uid, projectId)
                                : Future.value(0.0),
                            builder: (context, progressSnapshot) {
                              final progress = progressSnapshot.data ?? 0.0;
                              final progressPercent = (progress * 100).toInt();

                              return _buildModernProjectCard(
                                context,
                                title,
                                description,
                                identity,
                                tags,
                                projectData['collegeName'] ??
                                    projectData['companyName'] ??
                                    'Eduspark',
                                progress,
                                progressPercent,
                                () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ProjectDetailPage(
                                          projectId: projectId),
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          // FAB Navigation
          Positioned(
            right: 16,
            bottom: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Expanded FABs
                if (_isFabExpanded) ...[
                  _buildNavigationFabItem(
                    label: 'Case Studies',
                    icon: Icons.business_center_rounded,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => CasestudiesHomePage()),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildNavigationFabItem(
                    label: 'Handwritten Notes',
                    icon: Icons.edit_note_rounded,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => LibraryScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],

                // Premium FAB with concentric animated rings
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer animated ring
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: primaryBlue.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                    ),

                    // Middle animated ring
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: primaryBlue.withOpacity(0.5),
                          width: 2,
                        ),
                      ),
                    ),

                    // Main FAB
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Color(0xFF1976D2), // Dark blue
                            Color(0xFF1976D2), // Darker blue
                          ],
                          center: Alignment(0.1, 0.3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.5),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _toggleFab,
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 56,
                            height: 56,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Fancy shine effect
                                Positioned(
                                  top: 12,
                                  left: 12,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.4),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                // Main icon
                                AnimatedIcon(
                                  icon: AnimatedIcons.view_list,
                                  progress: _animationController,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

// New modern project card widget
  // Modern project card widget with enhanced design
  Widget _buildModernProjectCard(
    BuildContext context,
    String title,
    String description,
    String? identity,
    List<String> tags,
    String organization,
    double progress,
    int progressPercent,
    VoidCallback onTap,
  ) {
    final bool hasStarted = progress > 0;

// Get accent color based on identity with enhanced colors
    final Color accentColor = identity == 'College'
        ? const Color(0xFF43A047) // Rich Green
        : identity == 'Company'
            ? const Color(0xFFF57C00) // Deep Orange
            : identity == 'App Developer'
                ? const Color(0xFFD81B60) // Vibrant Pink
                : accentBlue; // Default

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: accentColor.withOpacity(0.08),
              spreadRadius: 2,
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top section with colored accent
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.white,
                    Colors.white,
                    accentColor.withOpacity(0.05),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row with organization badge and identity tag
                  Row(
                    children: [
                      // Organization badge
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: accentColor.withOpacity(0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              identity == 'College'
                                  ? Icons.school_rounded
                                  : identity == 'Company'
                                      ? Icons.business_rounded
                                      : identity == 'App Developer'
                                          ? Icons.developer_mode_rounded
                                          : Icons.school_rounded,
                              color: accentColor,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              organization,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),

                      // Identity tag
                      if (identity != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            identity,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: accentColor,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Title with decorative element
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Decorative vertical line
                      Container(
                        width: 3,
                        height: 24,
                        margin: const EdgeInsets.only(top: 3, right: 10),
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),

                      // Title
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: darkBlue,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Description
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.4,
                      letterSpacing: 0.1,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Tags section
            if (tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: tags.take(3).map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: veryLightBlue,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: primaryBlue.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          fontSize: 12,
                          color: primaryBlue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

            // Progress and action section with background
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  // Progress indicator and text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status and percentage row
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: hasStarted
                                    ? accentColor.withOpacity(0.1)
                                    : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    hasStarted
                                        ? Icons.play_circle_filled_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    size: 14,
                                    color: hasStarted
                                        ? accentColor
                                        : Colors.grey.shade500,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    hasStarted ? 'In Progress' : 'Not Started',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: hasStarted
                                          ? accentColor
                                          : Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            if (hasStarted)
                              Text(
                                '$progressPercent%',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _getProgressColor(progress),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Progress bar with animated look
                        Stack(
                          children: [
                            // Background
                            Container(
                              height: 8,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),

                            // Progress fill
                            Container(
                              height: 8,
                              width: MediaQuery.of(context).size.width *
                                  0.65 *
                                  progress,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    _getProgressColor(progress),
                                    _getProgressColor(progress)
                                        .withOpacity(0.8),
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: [
                                  if (hasStarted && progress > 0.1)
                                    BoxShadow(
                                      color: _getProgressColor(progress)
                                          .withOpacity(0.4),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Action button
                  Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        if (!hasStarted)
                          BoxShadow(
                            color: primaryBlue.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: onTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            hasStarted ? Colors.white : primaryBlue,
                        foregroundColor:
                            hasStarted ? primaryBlue : Colors.white,
                        elevation: hasStarted ? 0 : 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: hasStarted
                              ? BorderSide(color: primaryBlue, width: 1.5)
                              : BorderSide.none,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            hasStarted
                                ? Icons.play_arrow_rounded
                                : Icons.rocket_launch_rounded,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            hasStarted ? 'Continue' : 'Start',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

// Helper function to get a color based on progress percentage
  Color _getProgressColor(double progress) {
    if (progress < 0.3) {
      return const Color(0xFFFF5252); // Red
    } else if (progress < 0.7) {
      return const Color(0xFFFFB300); // Amber
    } else {
      return const Color(0xFF4CAF50); // Green
    }
  }

  // Updated modern empty state when no projects are found
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Visual container with illustration or icon
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: veryLightBlue,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background decoration
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: primaryBlue.withOpacity(0.1),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primaryBlue.withOpacity(0.05),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                  ),

                  // Main icon
                  Icon(
                    Icons.search_off_rounded,
                    size: 60,
                    color: primaryBlue.withOpacity(0.5),
                  ),

                  // Decorative elements
                  Positioned(
                    top: 20,
                    right: 20,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: accentBlue.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),

                  Positioned(
                    bottom: 25,
                    left: 20,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: primaryBlue.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Title text
          const Text(
            'No projects found',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: darkBlue,
              letterSpacing: 0.5,
            ),
          ),

          const SizedBox(height: 16),

          // Description text
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'We couldn\'t find any projects that match your current filters or search term.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Action button
          ElevatedButton.icon(
            onPressed: () {
              // Reset all filters and search
              _searchController.clear();
              setState(() {
                _selectedIdentityFilter = null;
                _selectedDomainFilter = null;
              });
            },
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Reset Filters'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
              elevation: 2,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Alternative action
          TextButton(
            onPressed: () {
              // Expand filter section
              setState(() {
                _filterExpanded = true;
              });
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text(
              'Adjust filters',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

// Helper method for building floating action button items
  Widget _buildNavigationFabItem({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: primaryBlue,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: darkBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }

// In initState, initialize the animation controller:
// @override
// void initState() {
//   super.initState();
//   _animationController = AnimationController(
//     vsync: this,
//     duration: const Duration(milliseconds: 300),
//   );
// }

// Add this method to toggle the FAB:
// void _toggleFab() {
//   setState(() {
//     _isFabExpanded = !_isFabExpanded;
//     if (_isFabExpanded) {
//       _animationController.forward();
//     } else {
//       _animationController.reverse();
//     }
//   });
// }

// Don't forget to dispose the animation controller:
// @override
// void dispose() {
//   _animationController.dispose();
//   super.dispose();
// }

  Widget _buildPillFilter({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color accentColor = primaryBlue,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? accentColor : Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: accentColor.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildProjectCard(
    BuildContext context,
    String title,
    String description,
    String? identity,
    List<String> tags,
    String issuerName,
    double progress,
    int progressPercent,
    VoidCallback onTap,
  ) {
    // Identity-based styling
    final Color cardAccentColor;
    final IconData identityIcon;

    switch (identity) {
      case 'College':
        cardAccentColor = const Color(0xFF4CAF50);
        identityIcon = Icons.school_rounded;
        break;
      case 'Company':
        cardAccentColor = accentBlue;
        identityIcon = Icons.business_rounded;
        break;
      case 'App Developer':
        cardAccentColor = const Color(0xFF9C27B0);
        identityIcon = Icons.developer_mode_rounded;
        break;
      default:
        cardAccentColor = lightBlue;
        identityIcon = Icons.person_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: cardAccentColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card header with accent color
            Container(
              height: 12,
              decoration: BoxDecoration(
                color: cardAccentColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and identity badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: darkBlue,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (identity != null)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: cardAccentColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: cardAccentColor.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                identityIcon,
                                size: 14,
                                color: cardAccentColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                identity,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: cardAccentColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Description
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black.withOpacity(0.7),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 16),

                  // Tags
                  if (tags.isNotEmpty)
                    SizedBox(
                      height: 28,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 8),
                        itemCount: tags.length > 3 ? 3 : tags.length,
                        itemBuilder: (context, index) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: veryLightBlue,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              tags[index],
                              style: const TextStyle(
                                fontSize: 12,
                                color: primaryBlue,
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Issuer name
                  Row(
                    children: [
                      Icon(
                        identity == 'College' ? Icons.school : Icons.business,
                        size: 14,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          issuerName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Progress bar with label
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Progress',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black.withOpacity(0.6),
                              ),
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _getProgressColor(progress),
                                ),
                                minHeight: 6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 1,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 4, horizontal: 8),
                          decoration: BoxDecoration(
                            color: _getProgressColor(progress).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color:
                                  _getProgressColor(progress).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$progressPercent%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: _getProgressColor(progress),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFabItem({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: darkBlue,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Mini FAB
        SizedBox(
          width: 40,
          height: 40,
          child: FloatingActionButton(
            heroTag: label,
            onPressed: onTap,
            backgroundColor: primaryBlue,
            foregroundColor: Colors.white,
            elevation: 2,
            mini: true,
            child: Icon(icon, size: 20),
          ),
        ),
      ],
    );
  }

  Future<double> _getUserProgress(String userId, String projectId) async {
    final doc = await FirebaseFirestore.instance
        .collection('user_answers')
        .doc(userId)
        .collection('projects')
        .doc(projectId)
        .get();
    final progress = doc.data()?['progress'];
    return (progress is num) ? progress.toDouble() : 0.0;
  }

  void _showInfoDialog(BuildContext context) {
    // Get the screen size to handle constraints
    final screenHeight = MediaQuery.of(context).size.height;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        clipBehavior: Clip.antiAlias,
        // Add constraints to prevent the dialog from being too tall
        child: Container(
          constraints: BoxConstraints(
            maxHeight:
                screenHeight * 0.8, // Limit height to 80% of screen height
          ),
          child: SingleChildScrollView(
            // Make the content scrollable
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: const BoxDecoration(
                    color: primaryBlue,
                    gradient: LinearGradient(
                      colors: [primaryBlue, darkBlue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.school,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'How EduSpark Works',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Learn by doing, not just watching!',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      _buildInfoItem(
                        number: "1",
                        title: "Quiz-Based Learning",
                        description:
                            "Each level starts with a quiz (8 questions, 60 seconds each). Score 8/8 to unlock submission. 2 attempts allowed, with a 3-day retry if you fail.",
                        iconData: Icons.quiz_rounded,
                        iconColor: accentBlue,
                      ),
                      const SizedBox(height: 16),
                      _buildInfoItem(
                        number: "2",
                        title: "Problem Solving",
                        description:
                            "Submit code or text solutions after passing the quiz. Your work is verified against expected outputs or keywords.",
                        iconData: Icons.code_rounded,
                        iconColor: const Color(0xFF4CAF50),
                      ),
                      const SizedBox(height: 16),
                      _buildInfoItem(
                        number: "3",
                        title: "Progress Tracking",
                        description:
                            "See your progress with a bar and percentage for each project.",
                        iconData: Icons.trending_up_rounded,
                        iconColor: const Color(0xFFFFA000),
                      ),
                    ],
                  ),
                ),

                // Button
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Got it!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required String number,
    required String title,
    required String description,
    required IconData iconData,
    required Color iconColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              iconData,
              color: iconColor,
              size: 18,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: darkBlue,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black.withOpacity(0.7),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MaterialApp(
    theme: ThemeData(
      primaryColor: primaryBlue,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        primary: primaryBlue,
        secondary: accentBlue,
      ),
      fontFamily: 'Poppins', // Make sure to add this font to your pubspec.yaml
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
      ),
    ),
    home: const ProjectsPagetwo(),
  ));
}
