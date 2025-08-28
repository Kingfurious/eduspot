import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UploadProjectScreenForm extends StatefulWidget {
  const UploadProjectScreenForm({super.key});

  @override
  State<UploadProjectScreenForm> createState() => _UploadProjectScreenState();
}

class _UploadProjectScreenState extends State<UploadProjectScreenForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _resourcesController = TextEditingController();
  final TextEditingController _skillsController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _collegeNameController = TextEditingController();
  final TextEditingController _companyNameController = TextEditingController();
  bool _askHelp = false;
  String? _selectedIdentity;

  final List<String> _identityOptions = ["College", "App Developer", "Company", "Student"];
  final List<String> _submissionTypes = ["code", "text"]; // Submission type options

  final List<Map<String, dynamic>> _levels = [];

  @override
  void initState() {
    super.initState();
    _addLevel();
  }

  void _addLevel() {
    setState(() {
      _levels.add({
        'level': TextEditingController(text: 'Level ${_levels.length + 1}'),
        'title': TextEditingController(),
        'description': TextEditingController(),
        'submissionType': 'code', // Default to code
        'expectedOutput': TextEditingController(), // For code
        'requiredKeywords': TextEditingController(), // For code or text
      });
    });
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedIdentity == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select your identity')),
        );
        return;
      }

      final firestore = FirebaseFirestore.instance;
      final projectId = _titleController.text.trim(); // Use project title as document ID

      final projectData = {
        'askHelp': _askHelp,
        'identity': _selectedIdentity,
        'description': _descriptionController.text,
        'progress': 0.0,
        'resources': _resourcesController.text.isEmpty
            ? []
            : _resourcesController.text.split(',').map((e) => e.trim()).toList(),
        'roadmap': _levels.map((level) => {
          'level': level['level']!.text,
          'title': level['title']!.text,
          'description': level['description']!.text,
        }).toList(),
        'skillsNeeded': _skillsController.text.split(',').map((e) => e.trim()).toList(),
        'tags': _tagsController.text.split(',').map((e) => e.trim()).toList(),
        'title': _titleController.text,
        if (_selectedIdentity == 'College') 'collegeName': _collegeNameController.text,
        if (_selectedIdentity == 'Company') 'companyName': _companyNameController.text,
      };

      try {
        // Use set() with the project title as the document ID instead of add()
        await firestore.collection('projects').doc(projectId).set(projectData);

        // Store level answers under the same project ID
        for (var level in _levels) {
          final levelData = {
            'submissionType': level['submissionType'],
            'description': level['description']!.text,
          };

          if (level['submissionType'] == 'code') {
            levelData['expectedOutput'] = level['expectedOutput']!.text;
            if (level['requiredKeywords']!.text.isNotEmpty) {
              levelData['requiredKeywords'] =
                  level['requiredKeywords']!.text.split(',').map((e) => e.trim()).toList();
            }
          } else {
            if (level['requiredKeywords']!.text.isNotEmpty) {
              levelData['expectedKeywords'] =
                  level['requiredKeywords']!.text.split(',').map((e) => e.trim()).toList();
            }
          }

          await firestore
              .collection('answers')
              .doc(projectId)
              .collection('levels')
              .doc(level['level']!.text)
              .set(levelData);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Project and answers uploaded successfully!')),
        );

        // Clear form
        _titleController.clear();
        _descriptionController.clear();
        _resourcesController.clear();
        _skillsController.clear();
        _tagsController.clear();
        _collegeNameController.clear();
        _companyNameController.clear();
        setState(() {
          _askHelp = false;
          _selectedIdentity = null;
          _levels.clear();
          _addLevel();
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Project Title'),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedIdentity,
                decoration: const InputDecoration(labelText: 'Who are you?'),
                items: _identityOptions.map((identity) {
                  return DropdownMenuItem(value: identity, child: Text(identity));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedIdentity = value;
                    _collegeNameController.clear();
                    _companyNameController.clear();
                  });
                },
                validator: (value) => value == null ? 'Please select an identity' : null,
              ),
              const SizedBox(height: 16),
              if (_selectedIdentity == 'College')
                TextFormField(
                  controller: _collegeNameController,
                  decoration: const InputDecoration(labelText: 'College Name'),
                  validator: (value) => value!.isEmpty ? 'Please enter your college name' : null,
                ),
              if (_selectedIdentity == 'College') const SizedBox(height: 16),
              if (_selectedIdentity == 'Company')
                TextFormField(
                  controller: _companyNameController,
                  decoration: const InputDecoration(labelText: 'Company Name'),
                  validator: (value) => value!.isEmpty ? 'Please enter your company name' : null,
                ),
              if (_selectedIdentity == 'Company') const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Ask Help: '),
                  Switch(
                    value: _askHelp,
                    onChanged: (value) => setState(() => _askHelp = value),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _resourcesController,
                decoration: const InputDecoration(labelText: 'Resources (comma-separated URLs)'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _skillsController,
                decoration: const InputDecoration(labelText: 'Skills Needed (comma-separated)'),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tagsController,
                decoration: const InputDecoration(labelText: 'Tags (comma-separated)'),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 24),
              const Text('Levels', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ..._levels.map((level) => _buildLevelForm(level)).toList(),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _addLevel,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade300),
                child: const Text('Add Level'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text('Submit Project'),
              ),
            ],
          ),
        ),
      ),
    );
  }

// Add these new fields to your _buildLevelForm method in the UploadProjectScreenForm

  Widget _buildLevelForm(Map<String, dynamic> level) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: level['level'],
              decoration: const InputDecoration(labelText: 'Level (e.g., Level 1)'),
              validator: (value) => value!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: level['title'],
              decoration: const InputDecoration(labelText: 'Level Title'),
              validator: (value) => value!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: level['description'],
              decoration: const InputDecoration(labelText: 'Level Description'),
              maxLines: 2,
              validator: (value) => value!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: level['submissionType'],
              decoration: const InputDecoration(labelText: 'Submission Type'),
              items: _submissionTypes.map((type) {
                return DropdownMenuItem(value: type, child: Text(type));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  level['submissionType'] = value;
                  level['expectedOutput']!.clear();
                  level['requiredKeywords']!.clear();
                });
              },
            ),
            const SizedBox(height: 12),

            // Basic verification fields (existing)
            if (level['submissionType'] == 'code')
              TextFormField(
                controller: level['expectedOutput'],
                decoration: const InputDecoration(labelText: 'Expected Output'),
                maxLines: 2,
                validator: (value) => value!.isEmpty ? 'Required for code submission' : null,
              ),
            if (level['submissionType'] == 'code') const SizedBox(height: 12),

            TextFormField(
              controller: level['requiredKeywords'],
              decoration: const InputDecoration(
                labelText: 'Required Keywords (comma-separated)',
                hintText: 'e.g., print, def for code; dataset, features for text',
              ),
              maxLines: 2,
            ),

            // Divider for enhanced verification section
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text('Enhanced Verification (Optional)',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ),
                Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 16),

            // Enhanced verification fields
            TextFormField(
              controller: level['passingScore'] ?? TextEditingController(text: '70'),
              decoration: const InputDecoration(
                labelText: 'Passing Score (%)',
                hintText: 'Default: 70%',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),

            if (level['submissionType'] == 'code') ...[
              // Output key phrases for partial matching
              TextFormField(
                controller: level['outputKeyPhrases'] ?? TextEditingController(),
                decoration: const InputDecoration(
                  labelText: 'Output Key Phrases (comma-separated)',
                  hintText: 'e.g., accuracy, precision, model trained successfully',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),

              // Expected metrics with tolerance
              ExpansionTile(
                title: Text('Expected Metrics',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add metrics to check in output (e.g., accuracy, loss)',
                          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                        ),
                        const SizedBox(height: 8),

                        // This would ideally be a dynamic list of metrics
                        // For simplicity, we'll add a few common ones
                        _buildMetricField(level, 'accuracy', 'Expected accuracy value (e.g., 0.85)'),
                        _buildMetricField(level, 'loss', 'Expected loss value (e.g., 0.35)'),
                        _buildMetricField(level, 'f1', 'Expected F1 score (e.g., 0.82)'),

                        const SizedBox(height: 8),
                        Text(
                          'Note: Values will be checked with ±5% tolerance by default',
                          style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Conceptual understanding patterns
              ExpansionTile(
                title: Text('Conceptual Understanding Patterns',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Define patterns that demonstrate conceptual understanding (30% of grade)',
                          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: level['domainPattern1_name'] ?? TextEditingController(),
                          decoration: const InputDecoration(
                            labelText: 'Pattern 1 Name',
                            hintText: 'e.g., CNN Architecture',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: level['domainPattern1_keywords'] ?? TextEditingController(),
                          decoration: const InputDecoration(
                            labelText: 'Pattern 1 Keywords (comma-separated)',
                            hintText: 'e.g., Conv2D, MaxPooling2D, kernel_size',
                          ),
                          maxLines: 2,
                        ),

                        const SizedBox(height: 16),
                        TextFormField(
                          controller: level['domainPattern2_name'] ?? TextEditingController(),
                          decoration: const InputDecoration(
                            labelText: 'Pattern 2 Name',
                            hintText: 'e.g., Validation Technique',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: level['domainPattern2_keywords'] ?? TextEditingController(),
                          decoration: const InputDecoration(
                            labelText: 'Pattern 2 Keywords (comma-separated)',
                            hintText: 'e.g., validation_split, cross_val, test_size',
                          ),
                          maxLines: 2,
                        ),

                        const SizedBox(height: 16),
                        TextFormField(
                          controller: level['domainPattern3_name'] ?? TextEditingController(),
                          decoration: const InputDecoration(
                            labelText: 'Pattern 3 Name (optional)',
                            hintText: 'e.g., Data Preprocessing',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: level['domainPattern3_keywords'] ?? TextEditingController(),
                          decoration: const InputDecoration(
                            labelText: 'Pattern 3 Keywords (comma-separated)',
                            hintText: 'e.g., normalize, StandardScaler, preprocessing',
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],

            // Project type - affects feedback suggestions
            const SizedBox(height: 12),
            TextFormField(
              controller: level['projectType'] ?? TextEditingController(),
              decoration: const InputDecoration(
                labelText: 'Project Type',
                hintText: 'e.g., ml, data_analysis, algorithm',
              ),
            ),
          ],
        ),
      ),
    );
  }

// Helper method to build metric input fields
  Widget _buildMetricField(Map<String, dynamic> level, String metricName, String hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: TextFormField(
        controller: level['metric_$metricName'] ?? TextEditingController(),
        decoration: InputDecoration(
          labelText: metricName.isNotEmpty
              ? metricName[0].toUpperCase() + metricName.substring(1)
              : '',
          hintText: hint,
          isDense: true,
        ),
        keyboardType: TextInputType.numberWithOptions(decimal: true),
      ),
    );
  }

// Prepare enhanced verification data for Firestore
  void _prepareLevelData(Map<String, dynamic> levelData, Map<String, dynamic> level) {
    // Basic fields (existing)
    levelData['submissionType'] = level['submissionType'];
    levelData['description'] = level['description']!.text;

    if (level['submissionType'] == 'code') {
      levelData['expectedOutput'] = level['expectedOutput']!.text;
    }

    if (level['requiredKeywords']!.text.isNotEmpty) {
      levelData['requiredKeywords'] =
          level['requiredKeywords']!.text.split(',').map((e) => e.trim()).toList();
    }

    // Enhanced verification fields
    if (level['passingScore'] != null && level['passingScore'].text.isNotEmpty) {
      levelData['passingScore'] = double.tryParse(level['passingScore'].text) ?? 70.0;
    }

    if (level['outputKeyPhrases'] != null && level['outputKeyPhrases'].text.isNotEmpty) {
      levelData['outputKeyPhrases'] =
          level['outputKeyPhrases'].text.split(',').map((e) => e.trim()).toList();
    }

    // Add metrics
    Map<String, dynamic> metrics = {};
    for (final metric in ['accuracy', 'loss', 'f1']) {
      final controller = level['metric_$metric'];
      if (controller != null && controller.text.isNotEmpty) {
        final value = double.tryParse(controller.text);
        if (value != null) {
          metrics[metric] = {
            'name': metric,
            'value': value,
            'tolerance': 0.05 // Default 5% tolerance
          };
        }
      }
    }

    if (metrics.isNotEmpty) {
      levelData['expectedMetrics'] = metrics;
    }

    // Add concept patterns
    List<Map<String, dynamic>> conceptPatterns = [];
    for (int i = 1; i <= 3; i++) {
      final nameController = level['domainPattern${i}_name'];
      final keywordsController = level['domainPattern${i}_keywords'];

      if (nameController != null && keywordsController != null &&
          nameController.text.isNotEmpty && keywordsController.text.isNotEmpty) {
        conceptPatterns.add({
          'name': nameController.text,
          'keywords': keywordsController.text.split(',').map((e) => e.trim()).toList(),
          'weight': 1.0
        });
      }
    }

    if (conceptPatterns.isNotEmpty) {
      levelData['conceptPatterns'] = conceptPatterns;
    }

    // Add project type
    if (level['projectType'] != null && level['projectType'].text.isNotEmpty) {
      levelData['projectType'] = level['projectType'].text;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _resourcesController.dispose();
    _skillsController.dispose();
    _tagsController.dispose();
    _collegeNameController.dispose();
    _companyNameController.dispose();
    for (var level in _levels) {
      level['level']!.dispose();
      level['title']!.dispose();
      level['description']!.dispose();
      level['expectedOutput']!.dispose();
      level['requiredKeywords']!.dispose();
    }
    super.dispose();
  }
}