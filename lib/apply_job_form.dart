// lib/apply_job_form.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Optional: Import if using flutter_chips_input for skills
// import 'package:flutter_chips_input/flutter_chips_input.dart';


class ApplyJobForm extends StatefulWidget {
  final String jobId;
  const ApplyJobForm({Key? key, required this.jobId}) : super(key: key);

  @override
  _ApplyJobFormState createState() => _ApplyJobFormState();
}

class _ApplyJobFormState extends State<ApplyJobForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _resumeUrlController = TextEditingController();
  final _portfolioUrlController = TextEditingController();
  final _coverLetterController = TextEditingController();
  final _qualificationController = TextEditingController();
  // Using simple text controller for skills for now
  final _skillsController = TextEditingController();

  bool _isLoading = false;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    // Pre-fill if user is logged in
    if (_currentUser != null) {
      _nameController.text = _currentUser!.displayName ?? '';
      _emailController.text = _currentUser!.email ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _resumeUrlController.dispose();
    _portfolioUrlController.dispose();
    _coverLetterController.dispose();
    _qualificationController.dispose();
    _skillsController.dispose();
    super.dispose();
  }

  // Helper to split comma-separated string into a list
  List<String> _stringToList(String? text) {
    if (text == null || text.trim().isEmpty) {
      return [];
    }
    return text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  Future<void> _submitApplication() async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to apply.'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        List<String> skillsList = _stringToList(_skillsController.text);

        await FirebaseFirestore.instance.collection('JobApplications').add({
          'jobId': widget.jobId,
          'applicantId': _currentUser!.uid, // Store applicant's user ID
          'applicantName': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'resumeUrl': _resumeUrlController.text.trim(),
          'portfolioUrl': _portfolioUrlController.text.trim(),
          'coverLetter': _coverLetterController.text.trim(),
          'skills': skillsList,
          'qualification': _qualificationController.text.trim(),
          'appliedDate': Timestamp.now(),
          'status': 'Submitted', // Initial status
        });

        Navigator.pop(context); // Close bottom sheet
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Application submitted successfully!'), backgroundColor: Colors.green),
        );

      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit application: $e'), backgroundColor: Colors.red),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(25.0),
      // Max height to prevent excessive growth, adjust as needed
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: SingleChildScrollView( // Makes the content scrollable if it overflows
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min, // Take minimum space needed
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Apply for Job', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Divider(height: 20),
              _buildTextFormField(_nameController, 'Full Name', icon: Icons.person),
              _buildTextFormField(_emailController, 'Contact Email', icon: Icons.email, inputType: TextInputType.emailAddress),
              _buildTextFormField(_resumeUrlController, 'Resume URL (e.g., Google Drive, Dropbox)', icon: Icons.link, inputType: TextInputType.url),
              _buildTextFormField(_portfolioUrlController, 'Portfolio/GitHub URL (Optional)', icon: Icons.link, isRequired: false, inputType: TextInputType.url),
              _buildTextFormField(_qualificationController, 'Current Qualification (e.g., B.Tech 3rd Year)', icon: Icons.school),
              _buildTextFormField(_skillsController, 'Relevant Skills (comma-separated)', icon: Icons.lightbulb_outline),
              _buildTextFormField(_coverLetterController, 'Cover Letter / Why you?', icon: Icons.description, maxLines: 4),

              const SizedBox(height: 25),
              Center(
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton.icon(
                  icon: const Icon(Icons.send),
                  label: const Text('Submit Application'),
                  onPressed: _submitApplication,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    textStyle: const TextStyle(fontSize: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10), // Space at the bottom
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextFormField(TextEditingController controller, String label, {IconData? icon, int maxLines = 1, bool isRequired = true, TextInputType inputType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon, size: 20) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey[100],
          contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
        ),
        maxLines: maxLines,
        keyboardType: inputType,
        validator: (value) {
          if (isRequired && (value == null || value.trim().isEmpty)) {
            return 'Please enter $label';
          }
          if (inputType == TextInputType.emailAddress && value != null && !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
            return 'Please enter a valid email address';
          }
          if (inputType == TextInputType.url && value != null && value.isNotEmpty && !(Uri.tryParse(value)?.hasAbsolutePath ?? false)) {
            return 'Please enter a valid URL';
          }
          return null;
        },
      ),
    );
  }
}