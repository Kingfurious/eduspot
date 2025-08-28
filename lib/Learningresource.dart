import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  runApp(MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
    ),
    home: const LearningResources(),
  ));
}

// WebViewPage to display the resource URL
class WebViewPage extends StatelessWidget {
  final String url;
  final String title;

  const WebViewPage({super.key, required this.url, required this.title});

  @override
  Widget build(BuildContext context) {
    final WebViewController controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(url));

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: WebViewWidget(controller: controller),
    );
  }
}

class LearningResources extends StatefulWidget {
  const LearningResources({super.key});

  @override
  _LearningResourcesState createState() => _LearningResourcesState();
}

class _LearningResourcesState extends State<LearningResources> {
  String? selectedDomain;
  String? selectedType;
  String searchQuery = '';
  bool isFilterVisible = false;

  // Original colors from the provided code
  final Color primaryBlue = const Color(0xFF1976D2);
  final Color lightBlue = const Color(0xFF64B5F6);
  final Color veryLightBlue = const Color(0xFFE3F2FD);
  final Color darkBlue = const Color(0xFF0D47A1);
  final Color accentBlue = const Color(0xFF29B6F6);

  // Predefined domains and types for filtering
  final List<String> domains = [
    'AI',
    'Software Development',
    'Data Science',
    'Cybersecurity',
    'Robotics',
  ];

  final List<String> types = ['Video', 'Journal', 'Paper'];

  final TextEditingController _searchController = TextEditingController();

  int get appliedFiltersCount =>
      (selectedDomain != null ? 1 : 0) +
          (selectedType != null ? 1 : 0) +
          (searchQuery.isNotEmpty ? 1 : 0);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleFilterVisibility() {
    setState(() {
      isFilterVisible = !isFilterVisible;
    });
  }

  void _clearFilters() {
    setState(() {
      selectedDomain = null;
      selectedType = null;
      searchQuery = '';
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Learning Resources',
            style: TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(15),
            bottomRight: Radius.circular(15),
          ),
        ),
        actions: [
          IconButton(
            icon: Badge(
              label: Text(
                appliedFiltersCount.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
              isLabelVisible: appliedFiltersCount > 0,
              child: const Icon(Icons.tune),
            ),
            onPressed: _toggleFilterVisibility,
            tooltip: 'Filters',
          ),
          if (appliedFiltersCount > 0)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: _clearFilters,
              tooltip: 'Clear filters',
            ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search resources...',
                prefixIcon: Icon(Icons.search, color: primaryBlue),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: accentBlue, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),

          // Filter Section
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: isFilterVisible ? null : 0,
            constraints: BoxConstraints(
              maxHeight: isFilterVisible ? MediaQuery.of(context).size.height * 0.6 : 0,
            ),
            decoration: BoxDecoration(
              color: veryLightBlue,
              borderRadius: isFilterVisible ? const BorderRadius.vertical(bottom: Radius.circular(15)) : BorderRadius.zero,
              boxShadow: isFilterVisible ? [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ] : [],
            ),
            padding: isFilterVisible ? const EdgeInsets.fromLTRB(16, 8, 16, 16) : EdgeInsets.zero,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Filters',
                          style: TextStyle(
                            color: darkBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (appliedFiltersCount > 0)
                          TextButton.icon(
                            icon: Icon(Icons.clear_all, size: 16, color: primaryBlue),
                            label: Text('Clear all', style: TextStyle(color: primaryBlue)),
                            onPressed: _clearFilters,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                      ],
                    ),
                    Divider(color: lightBlue.withOpacity(0.5)),

                    // Domain Filter
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 4),
                      child: Text(
                        'Domain:',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: darkBlue,
                        ),
                      ),
                    ),
                    _buildDomainSelector(),

                    // Type Filter
                    Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 4),
                      child: Text(
                        'Resource Type:',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: darkBlue,
                        ),
                      ),
                    ),
                    _buildTypeSelector(),

                    // Filter Summary
                    if (appliedFiltersCount > 0) _buildFilterSummary(),
                  ],
                ),
              ),
            ),
          ),

          // Resource List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _buildQuery().snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: primaryBlue),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                var resources = snapshot.data!.docs;

                // Apply search filter
                resources = resources.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  String title = (data['title'] ?? '').toLowerCase();
                  String description = (data['description'] ?? '').toLowerCase();
                  return title.contains(searchQuery) || description.contains(searchQuery);
                }).toList();

                if (resources.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: resources.length,
                  itemBuilder: (context, index) {
                    var resource = resources[index].data() as Map<String, dynamic>;
                    return _buildResourceCard(resource, context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDomainSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilterChip(
          label: const Text('All Domains'),
          selected: selectedDomain == null,
          onSelected: (_) {
            setState(() {
              selectedDomain = null;
            });
          },
          backgroundColor: Colors.white,
          selectedColor: lightBlue.withOpacity(0.6),
          checkmarkColor: darkBlue,
          labelStyle: TextStyle(
            color: selectedDomain == null ? darkBlue : Colors.black87,
            fontWeight: selectedDomain == null ? FontWeight.bold : FontWeight.normal,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: selectedDomain == null ? lightBlue : Colors.transparent,
              width: 1,
            ),
          ),
        ),
        ...domains.map((domain) => FilterChip(
          label: Text(domain),
          selected: selectedDomain == domain,
          onSelected: (selected) {
            setState(() {
              selectedDomain = selected ? domain : null;
            });
          },
          backgroundColor: Colors.white,
          selectedColor: primaryBlue,
          checkmarkColor: Colors.white,
          labelStyle: TextStyle(
            color: selectedDomain == domain ? Colors.white : Colors.black87,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: selectedDomain == domain ? primaryBlue : Colors.grey.withOpacity(0.3),
              width: 1,
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildTypeSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilterChip(
          label: const Text('All Types'),
          selected: selectedType == null,
          onSelected: (_) {
            setState(() {
              selectedType = null;
            });
          },
          backgroundColor: Colors.white,
          selectedColor: lightBlue.withOpacity(0.6),
          checkmarkColor: darkBlue,
          labelStyle: TextStyle(
            color: selectedType == null ? darkBlue : Colors.black87,
            fontWeight: selectedType == null ? FontWeight.bold : FontWeight.normal,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: selectedType == null ? lightBlue : Colors.transparent,
              width: 1,
            ),
          ),
        ),
        ...types.map((type) => FilterChip(
          label: Text(type),
          selected: selectedType == type,
          onSelected: (selected) {
            setState(() {
              selectedType = selected ? type : null;
            });
          },
          backgroundColor: Colors.white,
          selectedColor: accentBlue,
          checkmarkColor: Colors.white,
          labelStyle: TextStyle(
            color: selectedType == type ? Colors.white : Colors.black87,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: selectedType == type ? accentBlue : Colors.grey.withOpacity(0.3),
              width: 1,
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildFilterSummary() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: lightBlue.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_alt, size: 16, color: primaryBlue),
              const SizedBox(width: 4),
              Text(
                'Applied Filters:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: darkBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (selectedDomain != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• Domain: $selectedDomain'),
            ),
          if (selectedType != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• Type: $selectedType'),
            ),
          if (searchQuery.isNotEmpty)
            Text('• Search: "$searchQuery"'),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No resources found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: darkBlue,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters or search terms',
              style: TextStyle(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (appliedFiltersCount > 0)
              ElevatedButton.icon(
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear Filters'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: _clearFilters,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResourceCard(Map<String, dynamic> resource, BuildContext context) {
    // Determine icon based on resource type
    IconData typeIcon;
    switch (resource['type']) {
      case 'Video':
        typeIcon = Icons.video_library;
        break;
      case 'Journal':
        typeIcon = Icons.article;
        break;
      case 'Paper':
        typeIcon = Icons.description;
        break;
      default:
        typeIcon = Icons.link;
    }

    // Parse tags
    List<String> tags = [];
    if (resource['tags'] is String && (resource['tags'] as String).isNotEmpty) {
      tags = (resource['tags'] as String).split(',').map((e) => e.trim()).toList();
    }

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WebViewPage(
                url: resource['url'] ?? '',
                title: resource['title'] ?? 'Resource',
              ),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: veryLightBlue,
                border: Border(
                  bottom: BorderSide(
                    color: lightBlue.withOpacity(0.5),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryBlue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(typeIcon, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      resource['title'] ?? 'Untitled',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: darkBlue,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.open_in_new,
                    color: primaryBlue,
                    size: 20,
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    resource['description'] ?? 'No description available',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Resource metadata
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.category,
                            size: 16,
                            color: primaryBlue,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            resource['domain'] ?? 'Unknown Domain',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.source,
                            size: 16,
                            color: primaryBlue,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            resource['source'] ?? 'Unknown Source',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Tags
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: tags.map((tag) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: accentBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: accentBlue.withOpacity(0.3)),
                        ),
                        child: Text(
                          '#$tag',
                          style: TextStyle(
                            fontSize: 12,
                            color: accentBlue,
                          ),
                        ),
                      )).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build Firestore query based on filters
  Query _buildQuery() {
    Query query = FirebaseFirestore.instance.collection('case_resources');

    if (selectedDomain != null) {
      query = query.where('domain', isEqualTo: selectedDomain);
    }
    if (selectedType != null) {
      query = query.where('type', isEqualTo: selectedType);
    }

    return query;
  }
}