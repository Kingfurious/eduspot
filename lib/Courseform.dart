import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CourseForm extends StatefulWidget {
  @override
  _CourseFormState createState() => _CourseFormState();
}

class _CourseFormState extends State<CourseForm> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  TextEditingController nameController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();
  TextEditingController durationController = TextEditingController();
  TextEditingController startDateController = TextEditingController();
  TextEditingController endDateController = TextEditingController();
  TextEditingController categoryController = TextEditingController();
  TextEditingController levelController = TextEditingController();
  TextEditingController imageUrlController = TextEditingController();
  TextEditingController ratingController = TextEditingController();
  TextEditingController enrolledStudentsController = TextEditingController();
  TextEditingController tagsController = TextEditingController();
  TextEditingController prerequisitesController = TextEditingController();
  TextEditingController teacherNameController = TextEditingController();
  TextEditingController teacherBioController = TextEditingController();
  TextEditingController teacherImageController = TextEditingController();
  TextEditingController teacherEmailController = TextEditingController();
  TextEditingController teacherContactController = TextEditingController();
  TextEditingController coursePriceController = TextEditingController();

  List<TextEditingController> syllabusControllers = [TextEditingController()];

  void addSyllabusField() {
    setState(() {
      syllabusControllers.add(TextEditingController());
    });
  }

  Future<void> submitCourse() async {
    if (_formKey.currentState!.validate()) {
      try {
        await _firestore.collection('courses').doc(nameController.text).set({
          'name': nameController.text,
          'description': descriptionController.text,
          'duration': durationController.text,
          'startDate': startDateController.text,
          'endDate': endDateController.text,
          'category': categoryController.text,
          'level': levelController.text,
          'imageUrl': imageUrlController.text,
          'rating': double.parse(ratingController.text),
          'enrolledStudents': int.parse(enrolledStudentsController.text),
          'tags': tagsController.text.split(','),
          'prerequisites': prerequisitesController.text,
          'teacherName': teacherNameController.text,
          'teacherBio': teacherBioController.text,
          'teacherImage': teacherImageController.text,
          'teacherEmail': teacherEmailController.text,
          'teacherContact': teacherContactController.text,
          'coursePrice': double.parse(coursePriceController.text),
          'syllabus': syllabusControllers.map((controller) => controller.text).toList(),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Course Added Successfully!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add New Course')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(controller: nameController, decoration: InputDecoration(labelText: 'Course Name'), validator: (value) => value!.isEmpty ? 'Required' : null),
                TextFormField(controller: descriptionController, decoration: InputDecoration(labelText: 'Description'), validator: (value) => value!.isEmpty ? 'Required' : null),
                TextFormField(controller: durationController, decoration: InputDecoration(labelText: 'Duration'), validator: (value) => value!.isEmpty ? 'Required' : null),
                TextFormField(controller: startDateController, decoration: InputDecoration(labelText: 'Start Date'), validator: (value) => value!.isEmpty ? 'Required' : null),
                TextFormField(controller: endDateController, decoration: InputDecoration(labelText: 'End Date'), validator: (value) => value!.isEmpty ? 'Required' : null),
                TextFormField(controller: categoryController, decoration: InputDecoration(labelText: 'Category'), validator: (value) => value!.isEmpty ? 'Required' : null),
                TextFormField(controller: levelController, decoration: InputDecoration(labelText: 'Level'), validator: (value) => value!.isEmpty ? 'Required' : null),
                TextFormField(controller: imageUrlController, decoration: InputDecoration(labelText: 'Image URL'), validator: (value) => value!.isEmpty ? 'Required' : null),
                TextFormField(controller: ratingController, decoration: InputDecoration(labelText: 'Rating'), keyboardType: TextInputType.number, validator: (value) => value!.isEmpty ? 'Required' : null),
                TextFormField(controller: enrolledStudentsController, decoration: InputDecoration(labelText: 'Enrolled Students'), keyboardType: TextInputType.number, validator: (value) => value!.isEmpty ? 'Required' : null),
                TextFormField(controller: tagsController, decoration: InputDecoration(labelText: 'Tags (comma-separated)'), validator: (value) => value!.isEmpty ? 'Required' : null),
                TextFormField(controller: prerequisitesController, decoration: InputDecoration(labelText: 'Prerequisites'), validator: (value) => value!.isEmpty ? 'Required' : null),
                TextFormField(controller: teacherNameController, decoration: InputDecoration(labelText: 'Teacher Name'), validator: (value) => value!.isEmpty ? 'Required' : null),
                TextFormField(controller: teacherBioController, decoration: InputDecoration(labelText: 'Teacher Bio'), validator: (value) => value!.isEmpty ? 'Required' : null),
                TextFormField(controller: teacherImageController, decoration: InputDecoration(labelText: 'Teacher Image URL'), validator: (value) => value!.isEmpty ? 'Required' : null),
                TextFormField(controller: teacherEmailController, decoration: InputDecoration(labelText: 'Teacher Email'), validator: (value) => value!.isEmpty ? 'Required' : null),
                TextFormField(controller: coursePriceController, decoration: InputDecoration(labelText: 'Course Price'), keyboardType: TextInputType.number, validator: (value) => value!.isEmpty ? 'Required' : null),
                ...syllabusControllers.map((controller) => TextFormField(controller: controller, decoration: InputDecoration(labelText: 'Syllabus Topic'), validator: (value) => value!.isEmpty ? 'Required' : null)).toList(),
                ElevatedButton(onPressed: addSyllabusField, child: Text('Add Syllabus Topic')),
                SizedBox(height: 20),
                ElevatedButton(onPressed: submitCourse, child: Text('Submit')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
