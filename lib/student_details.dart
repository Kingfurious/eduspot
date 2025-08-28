import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:confetti/confetti.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io' show File, Directory;
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'home_page.dart';
import 'dart:math' as math;
import 'dart:async' as timer;
import 'dart:async';

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
}

class CreateProfilePage extends StatefulWidget {
  final String fullName;
  const CreateProfilePage({Key? key, required this.fullName}) : super(key: key);

  @override
  _CreateProfilePageState createState() => _CreateProfilePageState();
}

class _CreateProfilePageState extends State<CreateProfilePage> with TickerProviderStateMixin {
  int _currentSection = 1;
  File? _image;
  String? _imageUrl;
  bool _isImagePickerActive = false;
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _collegeNameController = TextEditingController();
  final _careerGoalController = TextEditingController();
  String? _selectedSkill;
  String? _selectedDepartment;
  String? _selectedYear;
  final List<String> _portfolioLinks = [];
  final _portfolioLinkController = TextEditingController();
  late ConfettiController _controllerCenter;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fullNameController.text = widget.fullName;
    _controllerCenter = ConfettiController(duration: const Duration(seconds: 3));
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controllerCenter.dispose();
    _slideController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneNumberController.dispose();
    _collegeNameController.dispose();
    _careerGoalController.dispose();
    _portfolioLinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.background,
              AppColors.veryLightBlue,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildModernHeader(),
              Expanded(
                child: isWideScreen
                    ? Row(
                  children: [
                    _buildSidebar(),
                    Expanded(child: _buildContent()),
                  ],
                )
                    : _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.gradientStart, AppColors.gradientEnd],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _imageUrl != null
                      ? Image.network(_imageUrl!, fit: BoxFit.cover)
                      : _image != null && !kIsWeb
                      ? Image.file(_image!, fit: BoxFit.cover)
                      : const Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ).animate().scale(duration: 600.ms),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create Your Profile',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ).animate().fadeIn(duration: 600.ms),
                    const SizedBox(height: 4),
                    Text(
                      'Step ${_currentSection} of 4',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ).animate().fadeIn(duration: 600.ms, delay: 200.ms),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildModernProgressBar(),
        ],
      ),
    );
  }

  Widget _buildModernProgressBar() {
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: AppColors.veryLightBlue,
        borderRadius: BorderRadius.circular(3),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: _currentSection / 4,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.gradientStart, AppColors.gradientEnd],
            ),
            borderRadius: BorderRadius.circular(3),
          ),
        ).animate().scaleX(duration: 400.ms, curve: Curves.easeInOut),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 280,
      color: AppColors.cardBackground,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile Setup',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ).animate().fadeIn(duration: 600.ms),
                const SizedBox(height: 8),
                Text(
                  'Complete all steps to unlock your personalized experience',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ).animate().fadeIn(duration: 600.ms, delay: 200.ms),
                const SizedBox(height: 32),
                _buildSectionItem(1, 'Personal Info', Icons.person_outline_rounded, 'Basic details about you'),
                _buildSectionItem(2, 'Education', Icons.school_outlined, 'Academic background'),
                _buildSectionItem(3, 'Skills', Icons.star_outline_rounded, 'Showcase your talents'),
                _buildSectionItem(4, 'Career Goals', Icons.work_outline_rounded, 'Your aspirations'),
              ],
            ),
          ),
        ],
      ),
    ).animate().slideX(duration: 600.ms);
  }

  Widget _buildSectionItem(int section, String title, IconData icon, String subtitle) {
    final isActive = _currentSection == section;
    final isCompleted = _currentSection > section;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () {
          if (section <= _currentSection) {
            setState(() => _currentSection = section);
            _slideController.forward();
          }
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primaryBlue.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? AppColors.primaryBlue.withOpacity(0.3)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? AppColors.successColor
                      : isActive
                      ? AppColors.primaryBlue
                      : AppColors.textSecondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isCompleted ? Icons.check_rounded : icon,
                  color: isCompleted || isActive
                      ? Colors.white
                      : AppColors.textSecondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                        color: isActive ? AppColors.primaryBlue : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              SlideTransition(
                position: _slideAnimation,
                child: _buildSectionContent(),
              ),
              const SizedBox(height: 32),
              _buildNavigationButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionContent() {
    switch (_currentSection) {
      case 1:
        return _buildBasicSection();
      case 2:
        return _buildEducationSection();
      case 3:
        return _buildSkillsSection();
      case 4:
        return _buildCareerSection();
      case 5:
        return _buildSuccessSection();
      default:
        return const Center(child: Text('Unknown Section'));
    }
  }

  Widget _buildBasicSection() {
    return Container(
      key: const ValueKey(1),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.gradientStart, AppColors.gradientEnd],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Personal Information',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'Tell us about yourself',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ).animate().fadeIn(duration: 600.ms),
          const SizedBox(height: 32),
          Center(
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _imageUrl != null || _image != null
                      ? null
                      : const LinearGradient(
                    colors: [AppColors.gradientStart, AppColors.gradientEnd],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: _imageUrl != null
                      ? Image.network(_imageUrl!, fit: BoxFit.cover)
                      : _image != null && !kIsWeb
                      ? Image.file(_image!, fit: BoxFit.cover)
                      : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.add_a_photo_rounded,
                        size: 32,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add Photo',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ).animate().scale(duration: 600.ms),
              ),
            ),
          ),
          const SizedBox(height: 32),
          _buildModernTextField(_fullNameController, 'Full Name', Icons.person_outline_rounded),
          const SizedBox(height: 20),
          _buildModernTextField(_emailController, 'Email Address', Icons.email_outlined),
          const SizedBox(height: 20),
          _buildPhoneField(),
        ],
      ),
    );
  }

  Widget _buildEducationSection() {
    return Container(
      key: const ValueKey(2),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.gradientStart, AppColors.gradientEnd],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.school_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Education Details',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'Your academic background',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ).animate().fadeIn(duration: 600.ms),
          const SizedBox(height: 32),
          _buildModernTextField(_collegeNameController, 'College/University Name', Icons.school_outlined),
          const SizedBox(height: 20),
          _buildModernDropdown(
            'Department',
            Icons.book_outlined,
            _selectedDepartment,
            [
              'Computer Science',
              'Electronics and Communication',
              'Mechanical Engineering',
              'Civil Engineering',
              'Information Technology',
              'Chemical Engineering',
              'Textile Engineering',
              'Production Engineering',
              'Instrumentation Engineering',
              'Architecture',
              'Biotechnology',
              'Pharmacy',
              'Agriculture'
            ],
                (value) => setState(() => _selectedDepartment = value),
          ),
          const SizedBox(height: 20),
          _buildModernDropdown(
            'Current Year',
            Icons.calendar_today_outlined,
            _selectedYear,
            ['1st Year', '2nd Year', '3rd Year', '4th Year'],
                (value) => setState(() => _selectedYear = value),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsSection() {
    return Container(
      key: const ValueKey(3),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.gradientStart, AppColors.gradientEnd],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.star_outline_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Skills & Portfolio',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'Showcase your talents',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ).animate().fadeIn(duration: 600.ms),
          const SizedBox(height: 32),
          _buildModernDropdown(
            'Primary Skill',
            Icons.code_rounded,
            _selectedSkill,
            [
              'JavaScript',
              'Python',
              'Flutter/Dart',
              'React',
              'Node.js',
              'Java',
              'Swift',
              'Kotlin',
              'C++',
              'Go',
              'Rust',
              'TypeScript',
            ],
                (value) => setState(() => _selectedSkill = value),
          ),
          const SizedBox(height: 24),
          Text(
            'Portfolio Links (Optional)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add links to your GitHub, portfolio website, or other projects',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _portfolioLinkController,
                  decoration: _buildModernInputDecoration(
                    'https://github.com/username/project',
                    Icons.link_rounded,
                  ),
                  keyboardType: TextInputType.url,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 56,
                width: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.gradientStart, AppColors.gradientEnd],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.add_rounded, color: Colors.white),
                  onPressed: () {
                    if (_portfolioLinkController.text.trim().isNotEmpty) {
                      setState(() {
                        _portfolioLinks.add(_portfolioLinkController.text.trim());
                        _portfolioLinkController.clear();
                      });
                    }
                  },
                ),
              ).animate().scale(duration: 600.ms),
            ],
          ),
          if (_portfolioLinks.isNotEmpty) ...[
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _portfolioLinks
                  .map((link) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.veryLightBlue,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.lightBlue.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.link_rounded,
                      size: 16,
                      color: AppColors.primaryBlue,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        link.length > 30 ? '${link.substring(0, 30)}...' : link,
                        style: TextStyle(
                          color: AppColors.primaryBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _portfolioLinks.remove(link)),
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCareerSection() {
    final careerOptions = [
      {'title': 'Frontend Developer', 'icon': Icons.web_rounded},
      {'title': 'Backend Developer', 'icon': Icons.storage_rounded},
      {'title': 'Full Stack Developer', 'icon': Icons.layers_rounded},
      {'title': 'Mobile Developer', 'icon': Icons.phone_android_rounded},
      {'title': 'UI/UX Designer', 'icon': Icons.design_services_rounded},
      {'title': 'Data Scientist', 'icon': Icons.analytics_rounded},
      {'title': 'DevOps Engineer', 'icon': Icons.settings_applications_rounded},
      {'title': 'Product Manager', 'icon': Icons.business_center_rounded},
    ];

    return Container(
      key: const ValueKey(4),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
      Row(
      children: [
      Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.gradientStart, AppColors.gradientEnd],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.work_outline_rounded,
        color: Colors.white,
        size: 24,
      ),
    ),
    const SizedBox(width: 16),
    Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Text(
    'Career Goals',
    style: TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
    ),
    ),
    Text(
    'What do you aspire to become?',
    style: TextStyle(
    fontSize: 14,
    color: AppColors.textSecondary,
    ),
    ),
    ],
    ),
    ],
    ).animate().fadeIn(duration: 600.ms),
    const SizedBox(height: 32),
    _buildModernTextField(
    _careerGoalController,
    'Describe your career aspirations',
    Icons.lightbulb_outline_rounded,
    maxLines: 3,
    ),
    const SizedBox(height: 24),
    Text(
    'Explore Career Paths',
    style: TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    ),
    ),
    const SizedBox(height: 8),
    Text(
    'Get inspired by popular career options in tech',
    style: TextStyle(
    fontSize: 14,
    color: AppColors.textSecondary,
    ),
    ),
    const SizedBox(height: 16),
    GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    childAspectRatio: 3,
    crossAxisSpacing: 12,
    mainAxisSpacing: 12,
    ),
    itemCount: careerOptions.length,
    itemBuilder: (context, index) {
    final career = careerOptions[index];
    return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
    color: AppColors.veryLightBlue.withOpacity(0.5),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
    color: AppColors.lightBlue.withOpacity(0.3),
    width: 1,
    ),
    ),
    child: Row(
    children: [
    Icon(
    career['icon'] as IconData,
    color: AppColors.primaryBlue,
    size: 20,
    ),
    const SizedBox(width: 8),
    Expanded(
    child: Text(
    career['title'] as String,
    style: TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    ),
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    ),
    ),
    ],
    ),
    ).animate().fadeIn(duration: 400.ms, delay: Duration(milliseconds: index * 100));
    },
    ),
          ],
      ),
    );
  }

  Widget _buildSuccessSection() {
    return Container(
      key: const ValueKey(5),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.successColor, Color(0xFF66BB6A)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.successColor.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 50,
                  color: Colors.white,
                ),
              ).animate().scale(duration: 800.ms, curve: Curves.elasticOut),
              const SizedBox(height: 24),
              Text(
                '🎉 Profile Created Successfully!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(duration: 600.ms, delay: 300.ms),
              const SizedBox(height: 12),
              Text(
                'Welcome to your personalized learning journey!\nYou\'re all set to explore amazing opportunities.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ).animate().fadeIn(duration: 600.ms, delay: 500.ms),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.gradientStart, AppColors.gradientEnd],
                  ),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Text(
                  'Get ready for an amazing experience!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ).animate().fadeIn(duration: 600.ms, delay: 700.ms),
            ],
          ),
          ConfettiWidget(
            confettiController: _controllerCenter,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: [
              AppColors.primaryBlue,
              AppColors.lightBlue,
              AppColors.accentBlue,
              AppColors.successColor,
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentSection > 1)
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  setState(() => _currentSection--);
                  _slideController.reset();
                  _slideController.forward();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cardBackground,
                  foregroundColor: AppColors.textSecondary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: AppColors.textSecondary.withOpacity(0.3),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.arrow_back_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Back',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms),
            ),
          if (_currentSection > 1) const SizedBox(width: 16),
          Expanded(
            flex: _currentSection == 1 ? 1 : 2,
            child: ElevatedButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  _formKey.currentState!.save();

                  // Validation checks
                  if (_currentSection == 1 && _imageUrl == null && _image == null) {
                    _showErrorSnackBar('Please upload a profile photo to continue');
                    return;
                  }

                  if (_currentSection == 2 && (_selectedDepartment == null || _selectedYear == null)) {
                    _showErrorSnackBar('Please complete all education fields');
                    return;
                  }

                  if (_currentSection == 3 && _selectedSkill == null) {
                    _showErrorSnackBar('Please select your primary skill');
                    return;
                  }

                  if (_currentSection == 4) {
                    // Show loading state
                    _showSuccessSnackBar('Creating your profile...');
                    _controllerCenter.play();
                    await _saveProfileData();
                    setState(() => _currentSection = 5);

                    // Navigate after delay
                    await Future.delayed(const Duration(seconds: 3));
                    if (mounted) {
                      Navigator.pushReplacement(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (context, animation, secondaryAnimation) =>
                          const ModernLoadingScreen(),
                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
                            return FadeTransition(opacity: animation, child: child);
                          },
                          transitionDuration: const Duration(milliseconds: 500),
                        ),
                      );
                    }
                  } else {
                    setState(() => _currentSection++);
                    _slideController.reset();
                    _slideController.forward();
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ).copyWith(
                backgroundColor: MaterialStateProperty.all(Colors.transparent),
              ),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.gradientStart, AppColors.gradientEnd],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _currentSection == 4 ? 'Create Profile' : 'Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _currentSection == 4
                            ? Icons.check_rounded
                            : Icons.arrow_forward_rounded,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 300.ms),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTextField(
      TextEditingController controller,
      String label,
      IconData icon, {
        int maxLines = 1,
        TextInputType keyboardType = TextInputType.text,
      }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: _buildModernInputDecoration(label, icon),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter $label';
        }
        if (label.toLowerCase().contains('email')) {
          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
            return 'Please enter a valid email address';
          }
        }
        return null;
      },
    ).animate().slideY(duration: 400.ms, begin: 0.1);
  }

  Widget _buildPhoneField() {
    return InternationalPhoneNumberInput(
      onInputChanged: (PhoneNumber number) {},
      selectorConfig: const SelectorConfig(
        selectorType: PhoneInputSelectorType.DROPDOWN,
        setSelectorButtonAsPrefixIcon: true,
        showFlags: true,
        useEmoji: false,
      ),
      ignoreBlank: false,
      autoValidateMode: AutovalidateMode.disabled,
      selectorTextStyle: TextStyle(color: AppColors.textPrimary),
      initialValue: PhoneNumber(isoCode: 'IN'),
      textFieldController: _phoneNumberController,
      formatInput: true,
      keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
      inputDecoration: _buildModernInputDecoration('Phone Number', Icons.phone_outlined),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your phone number';
        }
        return null;
      },
    ).animate().slideY(duration: 400.ms, begin: 0.1);
  }

  Widget _buildModernDropdown(
      String label,
      IconData icon,
      String? value,
      List<String> items,
      void Function(String?) onChanged,
      ) {
    return DropdownButtonFormField<String>(
      decoration: _buildModernInputDecoration(label, icon),
      value: value,
      items: items.map((String item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(
            item,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
            ),
          ),
        );
      }).toList(),
      onChanged: onChanged,
      validator: (value) => value == null ? 'Please select $label' : null,
      dropdownColor: AppColors.cardBackground,
      style: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 16,
      ),
    ).animate().slideY(duration: 400.ms, begin: 0.1);
  }

  InputDecoration _buildModernInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: AppColors.textSecondary,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: Container(
        margin: const EdgeInsets.only(right: 12),
        child: Icon(
          icon,
          color: AppColors.primaryBlue,
          size: 22,
        ),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: AppColors.textSecondary.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: AppColors.textSecondary.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: AppColors.primaryBlue,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: AppColors.errorColor,
          width: 1.5,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: AppColors.errorColor,
          width: 2,
        ),
      ),
      filled: true,
      fillColor: AppColors.background.withOpacity(0.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future _pickImage() async {
    if (_isImagePickerActive) return;
    _isImagePickerActive = true;

    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image == null) {
        _isImagePickerActive = false;
        return;
      }

      if (!kIsWeb) {
        setState(() => _image = File(image.path));
      }

      await _uploadImage(image);
    } catch (e) {
      _showErrorSnackBar('Failed to pick image: ${e.toString()}');
    } finally {
      _isImagePickerActive = false;
    }
  }

  Future<void> _uploadImage(XFile image) async {
    try {
      XFile? compressedFile;

      if (!kIsWeb) {
        Directory tempDir = Directory.systemTemp;
        String filename = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
        compressedFile = await FlutterImageCompress.compressAndGetFile(
          image.path,
          filename,
          quality: 88,
          minWidth: 400,
          minHeight: 400,
        );
        if (compressedFile == null) return;
      } else {
        compressedFile = image;
      }

      final storageRef = firebase_storage.FirebaseStorage.instance
          .ref()
          .child('profile_photos/${DateTime.now().millisecondsSinceEpoch}.jpg');

      final metadata = firebase_storage.SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'uploaded_by': 'profile_creation'},
      );

      final uploadTask = kIsWeb
          ? storageRef.putData(await compressedFile.readAsBytes(), metadata)
          : storageRef.putFile(File(compressedFile.path), metadata);

      await uploadTask.whenComplete(() async {
        _imageUrl = await storageRef.getDownloadURL();
        if (mounted) {
          setState(() {});
          _showSuccessSnackBar('Profile photo uploaded successfully!');
        }
      });
    } catch (e) {
      _showErrorSnackBar('Failed to upload image: ${e.toString()}');
    }
  }

  Future<void> _saveProfileData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('userId');

      if (userId == null) {
        userId = const Uuid().v4();
        await prefs.setString('userId', userId);
      }

      CollectionReference users = FirebaseFirestore.instance.collection('studentprofile');

      await users.doc(userId).set({
        'fullName': _fullNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phoneNumber': _phoneNumberController.text.trim(),
        'imageUrl': _imageUrl,
        'collegeName': _collegeNameController.text.trim(),
        'department': _selectedDepartment,
        'year': _selectedYear,
        'primarySkill': _selectedSkill,
        'portfolioLinks': _portfolioLinks,
        'careerGoal': _careerGoalController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'profileComplete': true,
      });

      // Save locally for quick access
      await prefs.setString('fullName', _fullNameController.text.trim());
      await prefs.setString('email', _emailController.text.trim());
      await prefs.setString('profileImageUrl', _imageUrl ?? '');

    } catch (e) {
      _showErrorSnackBar('Failed to save profile: ${e.toString()}');
      rethrow;
    }
  }
}

// Modern Loading Screen
class ModernLoadingScreen extends StatefulWidget {
  const ModernLoadingScreen({super.key});

  @override
  State<ModernLoadingScreen> createState() => _ModernLoadingScreenState();
}

class _ModernLoadingScreenState extends State<ModernLoadingScreen>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _pulseController;
  late AnimationController _floatingController;
  late Animation<double> _progressAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _floatingAnimation;

  final List<String> _loadingMessages = [
    'Setting up your profile...',
    'Preparing personalized content...',
    'Loading your dashboard...',
    'Almost ready!',
  ];

  int _currentMessageIndex = 0;

  @override
  void initState() {
    super.initState();

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _progressAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _floatingAnimation = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(parent: _floatingController, curve: Curves.easeInOut),
    );

    // Start animations
    _progressController.forward();
    _pulseController.repeat(reverse: true);
    _floatingController.repeat(reverse: true);

    // Update loading messages
    Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (mounted && _currentMessageIndex < _loadingMessages.length - 1) {
        setState(() {
          _currentMessageIndex++;
        });
      } else {
        timer.cancel();
      }
    });

    // Navigate to dashboard after loading
    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
            const DashboardScreen(username: ''),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    _pulseController.dispose();
    _floatingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.background,
              AppColors.veryLightBlue,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Floating elements
              AnimatedBuilder(
                animation: _floatingAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _floatingAnimation.value),
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.gradientStart, AppColors.gradientEnd],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryBlue.withOpacity(0.3),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Animated progress ring
                          AnimatedBuilder(
                            animation: _progressAnimation,
                            builder: (context, child) {
                              return CustomPaint(
                                size: Size(200, 200),
                                painter: CircularProgressPainter(
                                  progress: _progressAnimation.value,
                                  strokeWidth: 8,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              );
                            },
                          ),
                          // Center content
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _pulseAnimation.value,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.rocket_launch_rounded,
                                      size: 50,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(height: 8),
                                    AnimatedBuilder(
                                      animation: _progressAnimation,
                                      builder: (context, child) {
                                        return Text(
                                          '${(_progressAnimation.value * 100).toInt()}%',
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),
              Text(
                'Welcome aboard! 🚀',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: Text(
                  _loadingMessages[_currentMessageIndex],
                  key: ValueKey(_currentMessageIndex),
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
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

// Custom painter for circular progress
class CircularProgressPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color color;

  CircularProgressPainter({
    required this.progress,
    required this.strokeWidth,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}