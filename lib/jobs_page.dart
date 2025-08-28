// lib/jobs_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// App Colors
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

class JobsPage extends StatefulWidget {
  const JobsPage({Key? key}) : super(key: key);

  @override
  _JobsPageState createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _companyController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _salaryController = TextEditingController();
  final _applicationUrlController = TextEditingController();
  final _companyLogoController = TextEditingController();
  final _requirementsController = TextEditingController();
  final _tagsController = TextEditingController();

  String? _selectedJobType;
  String? _selectedDomain;
  DateTime? _selectedDeadline;
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<String> _jobTypes = ['Full-time', 'Part-time', 'Internship'];

  final List<String> _jobDomains = [
    'Software Development',
    'Web Development',
    'Mobile Development (iOS/Android)',
    'Data Science / AI / ML',
    'Cloud Computing (AWS/Azure/GCP)',
    'Cybersecurity',
    'DevOps / SRE',
    'UI/UX Design',
    'Product Management',
    'Project Management',
    'Business Analysis',
    'Marketing & Sales',
    'Content Creation / Writing',
    'Human Resources',
    'Finance & Accounting',
    'Customer Support',
    'Hardware Engineering',
    'Mechanical Engineering',
    'Electrical Engineering',
    'Other IT/Technical',
    'Other Non-Technical'
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _titleController.dispose();
    _companyController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _salaryController.dispose();
    _applicationUrlController.dispose();
    _companyLogoController.dispose();
    _requirementsController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _selectDeadline(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDeadline ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryBlue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDeadline) {
      setState(() {
        _selectedDeadline = picked;
      });
    }
  }

  List<String> _stringToList(String? text) {
    if (text == null || text.trim().isEmpty) {
      return [];
    }
    return text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  Future<void> _submitJob() async {
    if (_formKey.currentState!.validate() &&
        _selectedJobType != null &&
        _selectedDomain != null &&
        _selectedDeadline != null) {
      setState(() => _isLoading = true);

      try {
        List<String> requirementsList = _stringToList(_requirementsController.text);
        List<String> tagsList = _stringToList(_tagsController.text);

        await FirebaseFirestore.instance.collection('jobs').add({
          'title': _titleController.text.trim(),
          'company': _companyController.text.trim(),
          'location': _locationController.text.trim(),
          'description': _descriptionController.text.trim(),
          'requirements': requirementsList,
          'salary': _salaryController.text.trim(),
          'applicationUrl': _applicationUrlController.text.trim(),
          'postedDate': Timestamp.now(),
          'deadline': Timestamp.fromDate(_selectedDeadline!),
          'jobType': _selectedJobType,
          'domain': _selectedDomain,
          'tags': tagsList,
          'companyLogo': _companyLogoController.text.trim(),
        });

        _showSuccessDialog();
        _resetForm();
      } catch (e) {
        _showErrorSnackBar('Failed to post job: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    } else {
      _validateAndShowError();
    }
  }

  void _resetForm() {
    _formKey.currentState!.reset();
    setState(() {
      _selectedJobType = null;
      _selectedDomain = null;
      _selectedDeadline = null;
    });
    _titleController.clear();
    _companyController.clear();
    _locationController.clear();
    _descriptionController.clear();
    _salaryController.clear();
    _applicationUrlController.clear();
    _companyLogoController.clear();
    _requirementsController.clear();
    _tagsController.clear();
  }

  void _validateAndShowError() {
    if (_selectedJobType == null) {
      _showErrorSnackBar('Please select a job type.');
    } else if (_selectedDomain == null) {
      _showErrorSnackBar('Please select a job domain.');
    } else if (_selectedDeadline == null) {
      _showErrorSnackBar('Please select an application deadline.');
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.successColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Success!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Your job posting has been published successfully.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: const Text('Continue'),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.gradientStart, AppColors.gradientEnd],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const SafeArea(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Post a New Job',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Share exciting opportunities with the community',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            ),
          ),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Basic Information Section
                      _buildSectionHeader('Basic Information', Icons.info_outline),
                      const SizedBox(height: 16),
                      _buildModernCard([
                        _buildTextFormField(
                            _titleController,
                            'Job Title',
                            Icons.work_outline,
                            hint: 'e.g., Senior Flutter Developer'
                        ),
                        _buildTextFormField(
                            _companyController,
                            'Company Name',
                            Icons.business,
                            hint: 'e.g., Tech Innovations Ltd.'
                        ),
                        _buildTextFormField(
                            _locationController,
                            'Location',
                            Icons.location_on_outlined,
                            hint: 'e.g., Remote, New York, Hybrid'
                        ),
                      ]),

                      const SizedBox(height: 24),

                      // Job Details Section
                      _buildSectionHeader('Job Details', Icons.description_outlined),
                      const SizedBox(height: 16),
                      _buildModernCard([
                        _buildTextFormField(
                            _descriptionController,
                            'Job Description',
                            Icons.description,
                            maxLines: 5,
                            hint: 'Describe the role, responsibilities, and what makes this opportunity exciting...'
                        ),
                        _buildTextFormField(
                            _requirementsController,
                            'Requirements',
                            Icons.checklist,
                            hint: 'Flutter, Dart, 3+ years experience, Bachelor\'s degree'
                        ),
                        _buildTextFormField(
                            _salaryController,
                            'Salary/Compensation',
                            Icons.attach_money,
                            isRequired: false,
                            hint: 'e.g., \$60k-80k/year, \$25/hour, Competitive'
                        ),
                      ]),

                      const SizedBox(height: 24),

                      // Classification Section
                      _buildSectionHeader('Classification', Icons.category_outlined),
                      const SizedBox(height: 16),
                      _buildModernCard([
                        _buildJobTypeDropdown(),
                        const SizedBox(height: 16),
                        _buildDomainDropdown(),
                        const SizedBox(height: 16),
                        _buildDeadlinePicker(),
                      ]),

                      const SizedBox(height: 24),

                      // Additional Information Section
                      _buildSectionHeader('Additional Information', Icons.add_circle_outline),
                      const SizedBox(height: 16),
                      _buildModernCard([
                        _buildTextFormField(
                            _tagsController,
                            'Skills & Tags',
                            Icons.tag,
                            hint: 'Flutter, Dart, REST API, Git, Agile'
                        ),
                        _buildTextFormField(
                            _companyLogoController,
                            'Company Logo URL',
                            Icons.image,
                            isRequired: false,
                            inputType: TextInputType.url,
                            hint: 'https://company.com/logo.png'
                        ),
                        _buildTextFormField(
                            _applicationUrlController,
                            'External Application URL',
                            Icons.link,
                            isRequired: false,
                            inputType: TextInputType.url,
                            hint: 'https://company.com/apply/job-123'
                        ),
                      ]),

                      const SizedBox(height: 40),

                      // Submit Button
                      Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.gradientStart, AppColors.gradientEnd],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryBlue.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _submitJob,
                          icon: _isLoading
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                              : const Icon(Icons.publish, size: 24),
                          label: Text(
                            _isLoading ? 'Publishing...' : 'Publish Job',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: AppColors.primaryBlue,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildModernCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildTextFormField(
      TextEditingController controller,
      String label,
      IconData icon, {
        int maxLines = 1,
        bool isRequired = true,
        TextInputType inputType = TextInputType.text,
        String? hint,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: inputType,
        style: const TextStyle(
          fontSize: 16,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: AppColors.primaryBlue),
          labelStyle: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          hintStyle: TextStyle(
            color: AppColors.textSecondary.withOpacity(0.6),
            fontSize: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.errorColor, width: 2),
          ),
          filled: true,
          fillColor: AppColors.veryLightBlue.withOpacity(0.3),
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        ),
        validator: (value) {
          if (isRequired && (value == null || value.trim().isEmpty)) {
            return 'Please enter $label';
          }
          if (inputType == TextInputType.url && value != null && value.isNotEmpty && !(Uri.tryParse(value)?.hasAbsolutePath ?? false)) {
            return 'Please enter a valid URL';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildJobTypeDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedJobType,
      decoration: InputDecoration(
        labelText: 'Job Type',
        prefixIcon: const Icon(Icons.work_outline, color: AppColors.primaryBlue),
        labelStyle: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
        ),
        filled: true,
        fillColor: AppColors.veryLightBlue.withOpacity(0.3),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
      items: _jobTypes.map((String type) {
        return DropdownMenuItem<String>(
          value: type,
          child: Text(
            type,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
        );
      }).toList(),
      onChanged: (newValue) {
        setState(() {
          _selectedJobType = newValue;
        });
      },
      validator: (value) => value == null ? 'Job type is required' : null,
    );
  }

  Widget _buildDomainDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedDomain,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Job Domain',
        prefixIcon: const Icon(Icons.category_outlined, color: AppColors.primaryBlue),
        labelStyle: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
        ),
        filled: true,
        fillColor: AppColors.veryLightBlue.withOpacity(0.3),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
      items: _jobDomains.map((String domain) {
        return DropdownMenuItem<String>(
          value: domain,
          child: Text(
            domain,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (newValue) {
        setState(() {
          _selectedDomain = newValue;
        });
      },
      validator: (value) => value == null ? 'Job domain is required' : null,
    );
  }

  Widget _buildDeadlinePicker() {
    return InkWell(
      onTap: () => _selectDeadline(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.textSecondary.withOpacity(0.3),
          ),
          borderRadius: BorderRadius.circular(12),
          color: AppColors.veryLightBlue.withOpacity(0.3),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today,
              color: AppColors.primaryBlue,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Application Deadline',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedDeadline == null
                        ? 'Select deadline'
                        : DateFormat('EEEE, MMMM d, yyyy').format(_selectedDeadline!),
                    style: TextStyle(
                      color: _selectedDeadline == null
                          ? AppColors.textSecondary.withOpacity(0.6)
                          : AppColors.textPrimary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: AppColors.textSecondary.withOpacity(0.5),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}