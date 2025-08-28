import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'apply_job_form.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' as math;

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
  static const Color warningColor = Color(0xFFFF9800);
  static const Color gradientStart = Color(0xFF2196F3);
  static const Color gradientEnd = Color(0xFF1976D2);
}

class JobDetailPage extends StatefulWidget {
  final String jobId;

  const JobDetailPage({Key? key, required this.jobId}) : super(key: key);

  @override
  State<JobDetailPage> createState() => _JobDetailPageState();
}

class _JobDetailPageState extends State<JobDetailPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isFavorited = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();

    // Set status bar style
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _launchURL(String urlString) async {
    try {
      final Uri url = Uri.parse(urlString);
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $urlString');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Could not open link: ${e.toString()}');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w500),
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
            const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w500),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('jobs').doc(widget.jobId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState();
          }
          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return _buildNotFoundState();
          }

          Map<String, dynamic> jobData = snapshot.data!.data() as Map<String, dynamic>;
          return _buildJobContent(jobData);
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.gradientStart, AppColors.gradientEnd],
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              strokeWidth: 3,
            ),
            SizedBox(height: 16),
            Text(
              'Loading job details...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.gradientStart, AppColors.gradientEnd],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Oops! Something went wrong',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Unable to load job details',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Go Back'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primaryBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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

  Widget _buildNotFoundState() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.gradientStart, AppColors.gradientEnd],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.search_off_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Job Not Found',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'This job posting might have been removed or doesn\'t exist',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Go Back'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primaryBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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

  Widget _buildJobContent(Map<String, dynamic> jobData) {
    String? externalUrl = jobData['applicationUrl'];
    bool hasExternalUrl = externalUrl != null && externalUrl.isNotEmpty;

    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(jobData),
        SliverToBoxAdapter(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                children: [
                  _buildJobHeader(jobData),
                  _buildJobDetails(jobData),
                  _buildApplySection(hasExternalUrl, externalUrl),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSliverAppBar(Map<String, dynamic> jobData) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: AppColors.gradientStart,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.gradientStart, AppColors.gradientEnd],
          ),
        ),
      ),
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),

        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: Icon(
              _isFavorited ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: _isFavorited ? Colors.red.shade300 : Colors.white,
            ),
            onPressed: () {
              setState(() {
                _isFavorited = !_isFavorited;
              });
              _showSuccessSnackBar(
                _isFavorited ? 'Added to favorites' : 'Removed from favorites',
              );
            },
          ),
        ),
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.share_rounded, color: Colors.white),
            onPressed: () {
              // Implement share functionality
              _showSuccessSnackBar('Share feature coming soon!');
            },
          ),
        ),
      ],

    );
  }

  Widget _buildJobHeader(Map<String, dynamic> jobData) {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCompanyLogo(jobData),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      jobData['title'] ?? 'Job Title',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      jobData['company'] ?? 'Company Name',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildJobMetadata(jobData),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildJobTypeAndSalary(jobData),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1);
  }

  Widget _buildCompanyLogo(Map<String, dynamic> jobData) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: jobData['companyLogo'] == null || jobData['companyLogo']!.isEmpty
            ? const LinearGradient(
          colors: [AppColors.gradientStart, AppColors.gradientEnd],
        )
            : null,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: jobData['companyLogo'] != null && jobData['companyLogo']!.isNotEmpty
          ? ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          jobData['companyLogo']!,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _buildLogoFallback(jobData),
        ),
      )
          : _buildLogoFallback(jobData),
    );
  }

  Widget _buildLogoFallback(Map<String, dynamic> jobData) {
    return Center(
      child: Text(
        (jobData['company'] ?? 'C')[0].toUpperCase(),
        style: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildJobMetadata(Map<String, dynamic> jobData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.location_on_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                jobData['location'] ?? 'Location not specified',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              Icons.schedule_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              'Posted ${_getTimeAgo(jobData['postedDate'])}',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildJobTypeAndSalary(Map<String, dynamic> jobData) {
    return Row(
      children: [
        _buildJobTypeChip(jobData['jobType']),
        const SizedBox(width: 12),
        if (jobData['salary'] != null && jobData['salary'].toString().isNotEmpty)
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.successColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.successColor.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.attach_money_rounded,
                    size: 16,
                    color: AppColors.successColor,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      jobData['salary'].toString(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.successColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildJobTypeChip(String? jobType) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _getJobTypeColor(jobType).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _getJobTypeColor(jobType).withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: _getJobTypeColor(jobType),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            jobType ?? 'Not specified',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _getJobTypeColor(jobType),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobDetails(Map<String, dynamic> jobData) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          _buildDetailCard(
            'Job Description',
            Icons.description_rounded,
            jobData['description'] ?? 'No description provided.',
          ).animate().fadeIn(duration: 600.ms, delay: 200.ms),
          const SizedBox(height: 16),
          _buildDetailCard(
            'Requirements',
            Icons.checklist_rounded,
            jobData['requirements'],
            isList: true,
          ).animate().fadeIn(duration: 600.ms, delay: 300.ms),
          const SizedBox(height: 16),
          _buildDetailCard(
            'Skills & Tags',
            Icons.local_offer_rounded,
            jobData['tags'],
            isChipList: true,
          ).animate().fadeIn(duration: 600.ms, delay: 400.ms),
          const SizedBox(height: 16),
          _buildDeadlineCard(jobData).animate().fadeIn(duration: 600.ms, delay: 500.ms),
        ],
      ),
    );
  }

  Widget _buildDetailCard(String title, IconData icon, dynamic content,
      {bool isList = false, bool isChipList = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
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
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildContentWidget(content, isList: isList, isChipList: isChipList),
        ],
      ),
    );
  }

  Widget _buildContentWidget(dynamic content, {bool isList = false, bool isChipList = false}) {
    if (content == null) {
      return Text(
        'Not specified',
        style: TextStyle(
          fontSize: 15,
          color: AppColors.textSecondary,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    if (isChipList && content is List) {
      final List<String> items = content.cast<String>();
      if (items.isEmpty) {
        return Text(
          'No tags specified',
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary,
            fontStyle: FontStyle.italic,
          ),
        );
      }
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items.map((tag) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.gradientStart.withOpacity(0.1),
                AppColors.gradientEnd.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primaryBlue.withOpacity(0.2),
            ),
          ),
          child: Text(
            tag,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.primaryBlue,
            ),
          ),
        )).toList(),
      );
    }

    if (isList && content is List) {
      final List<String> items = content.cast<String>();
      if (items.isEmpty) {
        return Text(
          'No requirements specified',
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary,
            fontStyle: FontStyle.italic,
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 6),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item,
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        )).toList(),
      );
    }

    return Text(
      content.toString(),
      style: TextStyle(
        fontSize: 15,
        color: AppColors.textPrimary,
        height: 1.6,
      ),
    );
  }

  Widget _buildDeadlineCard(Map<String, dynamic> jobData) {
    final deadline = jobData['deadline'];
    if (deadline == null) return const SizedBox.shrink();

    final DateTime deadlineDate = (deadline as Timestamp).toDate();
    final int daysLeft = deadlineDate.difference(DateTime.now()).inDays;
    final bool isUrgent = daysLeft <= 3;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isUrgent ? AppColors.errorColor.withOpacity(0.05) : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: isUrgent ? Border.all(color: AppColors.errorColor.withOpacity(0.3)) : null,
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
      Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUrgent
            ? AppColors.errorColor.withOpacity(0.1)
            : AppColors.warningColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        isUrgent ? Icons.warning_rounded : Icons.schedule_rounded,
        color: isUrgent ? AppColors.errorColor : AppColors.warningColor,
        size: 24,
      ),
    ),
    const SizedBox(width: 16),
    Expanded(
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Text(
    'Application Deadline',
    style: TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    ),
    ),
    const SizedBox(height: 4),
    Text(
    DateFormat('MMMM d, yyyy').format(deadlineDate),
    style: TextStyle(
    fontSize: 14,
    color: AppColors.textSecondary,
    ),
    ),
    if (daysLeft >= 0) ...[
    const SizedBox(height: 4),
    Text(
    daysLeft == 0
    ? 'Last day to apply!'
        : daysLeft == 1
    ? '1 day left'
        : '$daysLeft days left',
    style: TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: isUrgent ? AppColors.errorColor : AppColors.warningColor,
    ),
    )  ] else ...[
        const SizedBox(height: 4),
      Text(
        'Application deadline has passed',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.errorColor,
        ),
      ),
    ],
    ],
    ),
    ),
          ],
      ),
    );
  }

  Widget _buildApplySection(bool hasExternalUrl, String? externalUrl) {
    final deadline = DateTime.now().add(const Duration(days: 30)); // Default for demo
    final bool canApply = deadline.isAfter(DateTime.now());

    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: canApply
            ? const LinearGradient(
          colors: [AppColors.gradientStart, AppColors.gradientEnd],
        )
            : LinearGradient(
          colors: [
            AppColors.textSecondary.withOpacity(0.5),
            AppColors.textSecondary.withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: canApply ? [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ] : [],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  canApply
                      ? (hasExternalUrl ? Icons.launch_rounded : Icons.send_rounded)
                      : Icons.block_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      canApply ? 'Ready to Apply?' : 'Application Closed',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      canApply
                          ? (hasExternalUrl
                          ? 'Apply directly on company website'
                          : 'Submit your application through our platform')
                          : 'The application deadline has passed',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canApply ? () {
                if (hasExternalUrl) {
                  _launchURL(externalUrl!);
                } else {
                  _showApplyForm(context, widget.jobId);
                }
              } : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: canApply ? AppColors.primaryBlue : AppColors.textSecondary,
                disabledBackgroundColor: Colors.white.withOpacity(0.3),
                disabledForegroundColor: Colors.white.withOpacity(0.5),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    canApply
                        ? (hasExternalUrl ? 'Apply on Company Site' : 'Apply Now')
                        : 'Application Closed',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    canApply
                        ? (hasExternalUrl ? Icons.open_in_new_rounded : Icons.arrow_forward_rounded)
                        : Icons.close_rounded,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          if (canApply && !hasExternalUrl) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.security_rounded,
                  size: 16,
                  color: Colors.white.withOpacity(0.7),
                ),
                const SizedBox(width: 6),
                Text(
                  'Your data is secure and private',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 600.ms, delay: 600.ms).slideY(begin: 0.1);
  }

  Color _getJobTypeColor(String? jobType) {
    switch (jobType?.toLowerCase()) {
      case 'full-time':
        return AppColors.primaryBlue;
      case 'part-time':
        return AppColors.warningColor;
      case 'internship':
        return AppColors.successColor;
      case 'contract':
        return AppColors.accentBlue;
      case 'freelance':
        return const Color(0xFF9C27B0);
      default:
        return AppColors.textSecondary;
    }
  }

  String _getTimeAgo(dynamic postedDate) {
    if (postedDate == null) return 'recently';

    DateTime date;
    if (postedDate is Timestamp) {
      date = postedDate.toDate();
    } else if (postedDate is DateTime) {
      date = postedDate;
    } else {
      return 'recently';
    }

    final Duration difference = DateTime.now().difference(date);

    if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} month${(difference.inDays / 30).floor() == 1 ? '' : 's'} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'just now';
    }
  }

  void _showApplyForm(BuildContext context, String jobId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadowColor.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.gradientStart, AppColors.gradientEnd],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.work_outline_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Apply for Job',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Fill out the form below to submit your application',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Form content
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: ApplyJobForm(jobId: jobId),
                ),
              ),
            ],
          ),
        ).animate().slideY(
          duration: 400.ms,
          begin: 1.0,
          curve: Curves.easeOutCubic,
        );
      },
    );
  }
}

// Enhanced Apply Job Form (you can replace this with your existing form)
class ApplyJobForm extends StatefulWidget {
  final String jobId;

  const ApplyJobForm({Key? key, required this.jobId}) : super(key: key);

  @override
  State<ApplyJobForm> createState() => _ApplyJobFormState();
}

class _ApplyJobFormState extends State<ApplyJobForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _coverLetterController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _coverLetterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField(
              controller: _nameController,
              label: 'Full Name',
              icon: Icons.person_outline_rounded,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your full name';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _emailController,
              label: 'Email Address',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your email address';
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                  return 'Please enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _phoneController,
              label: 'Phone Number',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _coverLetterController,
              label: 'Cover Letter',
              icon: Icons.description_outlined,
              maxLines: 5,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please write a brief cover letter';
                }
                if (value.trim().length < 50) {
                  return 'Cover letter should be at least 50 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.veryLightBlue.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primaryBlue.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.primaryBlue,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your application will be reviewed by the hiring team. You\'ll receive a confirmation email shortly.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitApplication,
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
                    gradient: _isSubmitting
                        ? LinearGradient(
                      colors: [
                        AppColors.textSecondary.withOpacity(0.5),
                        AppColors.textSecondary.withOpacity(0.7),
                      ],
                    )
                        : const LinearGradient(
                      colors: [AppColors.gradientStart, AppColors.gradientEnd],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Container(
                    alignment: Alignment.center,
                    child: _isSubmitting
                        ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            strokeWidth: 2,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Submitting...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                        : SizedBox(
                      height: 48, // Adjust this value to increase/decrease button height
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Submit Application',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.send_rounded, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
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
          borderSide: const BorderSide(
            color: AppColors.primaryBlue,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.errorColor,
            width: 1.5,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.errorColor,
            width: 2,
          ),
        ),
        filled: true,
        fillColor: AppColors.background.withOpacity(0.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Simulate API call
      await Future.delayed(const Duration(seconds: 2));

      // Add your actual submission logic here
      // await FirebaseFirestore.instance.collection('applications').add({
      //   'jobId': widget.jobId,
      //   'name': _nameController.text.trim(),
      //   'email': _emailController.text.trim(),
      //   'phone': _phoneController.text.trim(),
      //   'coverLetter': _coverLetterController.text.trim(),
      //   'submittedAt': FieldValue.serverTimestamp(),
      // });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Application submitted successfully! You\'ll hear back soon.',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Failed to submit application: ${e.toString()}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
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
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}