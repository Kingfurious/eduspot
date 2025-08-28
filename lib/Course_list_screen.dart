// screens/courses_list_screen.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/course.dart';
import 'course_detail_screen.dart';
import '/Services/ad_service.dart'; // Import the ad service

// Color Palette
const Color primaryBlue = Color(0xFF1976D2);
const Color lightBlue = Color(0xFF64B5F6);
const Color veryLightBlue = Color(0xFFE3F2FD);
const Color darkBlue = Color(0xFF0D47A1);
const Color accentBlue = Color(0xFF29B6F6);

class CoursesListScreen extends StatefulWidget {
  @override
  _CoursesListScreenState createState() => _CoursesListScreenState();
}

class _CoursesListScreenState extends State<CoursesListScreen> {
  String _selectedCategory = 'All Categories';
  final List<String> _categories = ['All Categories'];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchExpanded = false;

  @override
  void initState() {
    super.initState();
    // Fetch categories when screen initializes
    _fetchCategories();

    // Preload the interstitial ad
    AdService.loadInterstitialAd();
  }

  Future<void> _fetchCategories() async {
    try {
      final QuerySnapshot snapshot =
          await FirebaseFirestore.instance.collection('courses').get();
      final allCategories = ['All Categories'];

      snapshot.docs.forEach((doc) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['category'] != null &&
            !allCategories.contains(data['category'])) {
          allCategories.add(data['category'] as String);
        }
      });

      if (mounted) {
        setState(() {
          _categories.clear();
          _categories.addAll(allCategories);
        });
      }
    } catch (e) {
      print('Error fetching categories: $e');
    }
  }

  // Modified navigation method to show ads
  void _navigateToCourseDetail(BuildContext context, Course course) async {
    // Show an ad before navigation
    await AdService.showInterstitialAd();

    // Then navigate to the course detail screen
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CourseDetailScreen(course: course),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildCategoryFilter(),
          Expanded(
            child: _buildCoursesList(),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: primaryBlue,
      title: _isSearchExpanded
          ? TextField(
              controller: _searchController,
              style: TextStyle(color: Colors.white),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                hintText: 'Search courses...',
                hintStyle: TextStyle(color: Colors.white70),
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search, color: Colors.white70),
                suffixIcon: IconButton(
                  icon: Icon(Icons.clear, color: Colors.white70),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                      _isSearchExpanded = false;
                    });
                  },
                ),
              ),
              onSubmitted: (value) {
                setState(() {
                  _searchQuery = value;
                  _isSearchExpanded = false;
                });
              },
            )
          : Text(
              'Explore Courses',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
      actions: [
        IconButton(
          icon: Icon(_isSearchExpanded ? Icons.close : Icons.search,
              color: Colors.white),
          onPressed: () {
            setState(() {
              _isSearchExpanded = !_isSearchExpanded;
              if (!_isSearchExpanded) {
                _searchQuery = _searchController.text;
              }
            });
          },
        ),
        if (!_isSearchExpanded)
          IconButton(
            icon: Icon(Icons.filter_list, color: Colors.white),
            onPressed: () {
              _showFilterBottomSheet();
            },
          ),
      ],
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter Courses',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            _selectedCategory = 'All Categories';
                          });
                          setState(() {
                            _selectedCategory = 'All Categories';
                          });
                        },
                        child: Text('Reset'),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Categories',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories.map((category) {
                      final isSelected = category == _selectedCategory;
                      return ChoiceChip(
                        label: Text(category),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setModalState(() {
                              _selectedCategory = category;
                            });
                            setState(() {
                              _selectedCategory = category;
                            });
                          }
                        },
                        backgroundColor: Colors.grey.shade200,
                        selectedColor: primaryBlue,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: Text('Apply Filters'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      height: 50,
      padding: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = category == _selectedCategory;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategory = category;
              });
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: EdgeInsets.only(right: 10, top: 8, bottom: 8),
              decoration: BoxDecoration(
                color: isSelected ? primaryBlue : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  category,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCoursesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('courses').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
            ),
          );
        }

        if (snapshot.hasError) {
          print("Firestore error: ${snapshot.error}");
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red),
                SizedBox(height: 16),
                Text(
                  'Error loading courses',
                  style: TextStyle(fontSize: 18),
                ),
                SizedBox(height: 8),
                Text(
                  '${snapshot.error}',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          print("No data in snapshot or empty docs list");
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.school_outlined, size: 48, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No courses available',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade700),
                ),
              ],
            ),
          );
        }

        print("Number of documents in snapshot: ${snapshot.data!.docs.length}");

        final courses = snapshot.data!.docs
            .map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              try {
                return Course.fromFirestore(data, doc.id);
              } catch (e) {
                print('Error parsing course ${doc.id}: $e');
                return null;
              }
            })
            .where((course) => course != null)
            .cast<Course>()
            .toList();

        print("Number of valid courses after parsing: ${courses.length}");

        // Filter by category
        if (_selectedCategory != 'All Categories') {
          courses.removeWhere((course) => course.category != _selectedCategory);
          print("After category filter: ${courses.length} courses");
        }

        // Filter by search query
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          courses.removeWhere((course) =>
              !(course.name?.toLowerCase().contains(query) ?? false) &&
              !(course.description?.toLowerCase().contains(query) ?? false) &&
              !(course.teacherName?.toLowerCase().contains(query) ?? false));
          print("After search filter: ${courses.length} courses");
        }

        if (courses.isEmpty) {
          // If no courses after filtering, offer an option to clear filters
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 48, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No courses match your criteria',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade700),
                ),
                SizedBox(height: 8),
                Text(
                  'Try adjusting your filters or search terms',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
                SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedCategory = 'All Categories';
                      _searchQuery = '';
                      _searchController.clear();
                    });
                  },
                  icon: Icon(Icons.refresh),
                  label: Text('Clear Filters'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
          );
        }

        // If we have courses, display them
        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: courses.length,
          itemBuilder: (context, index) {
            final course = courses[index];
            return _buildCourseCard(course, context);
          },
        );
      },
    );
  }

  Widget _buildCourseCard(Course course, BuildContext context) {
    return Card(
      elevation: 4,
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          // Use the modified navigation method that shows ads
          _navigateToCourseDetail(context, course);
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Course image with improved handling
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              child: Stack(
                children: [
                  Builder(builder: (context) {
                    String imageUrl = course.imageUrl ?? '';
                    if (imageUrl.contains('imgurl=')) {
                      try {
                        // Extract the imgurl parameter from Google Images URL
                        final urlParamStart = imageUrl.indexOf('imgurl=') + 7;
                        final urlParamEnd =
                            imageUrl.indexOf('&', urlParamStart);
                        if (urlParamEnd > urlParamStart) {
                          final encodedUrl =
                              imageUrl.substring(urlParamStart, urlParamEnd);
                          // Decode the URL (it's URL encoded in the Google link)
                          imageUrl = Uri.decodeFull(encodedUrl);
                        }
                      } catch (e) {
                        print('Error extracting image URL: $e');
                        // Fallback to the original URL if extraction fails
                      }
                    }

                    // Handle different image formats
                    if (imageUrl.startsWith('data:image')) {
                      // Base64 image handling
                      return Container(
                        height: 150,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: MemoryImage(
                              base64Decode(imageUrl.split(',')[1]),
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    } else {
                      // Network image handling
                      return Image.network(
                        imageUrl.isNotEmpty
                            ? imageUrl
                            : 'https://via.placeholder.com/400x200?text=No+Image',
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          print(
                              "Error loading image for course ${course.id}: $error");
                          return Container(
                            height: 150,
                            width: double.infinity,
                            color: Colors.grey.shade300,
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              color: Colors.grey.shade700,
                              size: 36,
                            ),
                          );
                        },
                      );
                    }
                  }),

                  // Teacher info as an overlay with improved handling
                  if (course.teacherImage != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Builder(builder: (context) {
                          String teacherImageUrl = course.teacherImage!;

                          // Also handle Google Images URLs for teacher images
                          if (teacherImageUrl.contains('imgurl=')) {
                            try {
                              final urlParamStart =
                                  teacherImageUrl.indexOf('imgurl=') + 7;
                              final urlParamEnd =
                                  teacherImageUrl.indexOf('&', urlParamStart);
                              if (urlParamEnd > urlParamStart) {
                                final encodedUrl = teacherImageUrl.substring(
                                    urlParamStart, urlParamEnd);
                                teacherImageUrl = Uri.decodeFull(encodedUrl);
                              }
                            } catch (e) {
                              print('Error extracting teacher image URL: $e');
                            }
                          }

                          // Handle base64 teacher images if needed
                          if (teacherImageUrl.startsWith('data:image')) {
                            return CircleAvatar(
                              radius: 20,
                              backgroundImage: MemoryImage(
                                base64Decode(teacherImageUrl.split(',')[1]),
                              ),
                              backgroundColor: Colors.grey.shade300,
                            );
                          } else {
                            return CircleAvatar(
                              radius: 20,
                              backgroundImage: NetworkImage(teacherImageUrl),
                              onBackgroundImageError: (exception, stackTrace) {
                                print(
                                    "Error loading teacher image: $exception");
                              },
                              backgroundColor: Colors.grey.shade300,
                              child: teacherImageUrl.isEmpty
                                  ? Icon(Icons.person,
                                      size: 20, color: Colors.grey.shade700)
                                  : null,
                            );
                          }
                        }),
                      ),
                    ),
                ],
              ),
            ),

            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category and Level badges
                  Row(
                    children: [
                      if (course.category != null)
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade100,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            course.category!,
                            style: TextStyle(
                              color: Colors.indigo.shade800,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      SizedBox(width: 8),
                      if (course.level != null)
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getLevelColor(course.level!),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            course.level!,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 12),

                  // Course title
                  Text(
                    course.name ?? 'No Title',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8),

                  // Course description
                  Text(
                    course.description ?? 'No description available',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 12),

                  // Course info row
                  Row(
                    children: [
                      Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                      SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          course.teacherName ?? 'Unknown Instructor',
                          style: TextStyle(color: Colors.grey.shade700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Spacer(),
                      Icon(Icons.calendar_today,
                          size: 16, color: Colors.grey.shade600),
                      SizedBox(width: 4),
                      Text(
                        course.duration ?? 'N/A',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),

                  // Rating and price row
                  Row(
                    children: [
                      // Rating
                      if (course.rating != null) ...[
                        Icon(Icons.star, size: 18, color: Colors.amber),
                        SizedBox(width: 4),
                        Text(
                          course.rating.toString(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        SizedBox(width: 4),
                        Text(
                          '(${course.enrolledStudents ?? 0} students)',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      Spacer(),
                      // Price
                      Text(
                        '₹${course.coursePrice ?? 'Free'}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
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

  Color _getLevelColor(String level) {
    switch (level.toLowerCase()) {
      case 'beginner':
      case 'easy':
        return Colors.green.shade600;
      case 'intermediate':
      case 'medium':
        return Colors.orange.shade600;
      case 'advanced':
      case 'hard':
        return Colors.red.shade600;
      default:
        return Colors.blue.shade600;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
