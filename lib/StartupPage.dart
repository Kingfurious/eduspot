import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ExerciseForm extends StatefulWidget {
  @override
  _ExerciseFormState createState() => _ExerciseFormState();
}

class _ExerciseFormState extends State<ExerciseForm> {
  final _formKey = GlobalKey<FormState>();

  // Form fields
  String selectedDomain = "Python"; // Default selected domain
  String exerciseName = "";
  String difficulty = "";
  String exerciseDetails = "";
  String expectedAnswer = "";

  // List to store learning steps
  List<Map<String, String>> learningSteps = [];

  // Controllers for learning step input fields
  TextEditingController stepTitleController = TextEditingController();
  TextEditingController stepContentController = TextEditingController();
  TextEditingController stepImageUrlController = TextEditingController();

  // Available domains
  final List<String> domains = ["Python", "Machine Learning", "Flutter", "AI"];

  // Function to add a learning step
  void addStep() {
    if (stepTitleController.text.isNotEmpty &&
        stepContentController.text.isNotEmpty &&
        stepImageUrlController.text.isNotEmpty) {
      setState(() {
        learningSteps.add({
          "title": stepTitleController.text,
          "content": stepContentController.text,
          "image_url": stepImageUrlController.text,
        });
      });

      // Clear text fields after adding step
      stepTitleController.clear();
      stepContentController.clear();
      stepImageUrlController.clear();
    }
  }

  // Function to submit form data to Firestore
  Future<void> submitExercise() async {
    if (_formKey.currentState!.validate()) {
      FirebaseFirestore firestore = FirebaseFirestore.instance;

      await firestore.collection(selectedDomain).doc(exerciseName).set({
        "exercise_name": exerciseName,
        "learning_steps": learningSteps,
        "exercise_details": exerciseDetails,
        "expected_answer": expectedAnswer,
        "difficulty": difficulty,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Exercise added successfully!")),
      );

      // Clear the form after submission
      setState(() {
        exerciseName = "";
        difficulty = "";
        exerciseDetails = "";
        expectedAnswer = "";
        learningSteps.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Add Exercise")),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dropdown for domain selection
                DropdownButtonFormField<String>(
                  value: selectedDomain,
                  onChanged: (value) {
                    setState(() {
                      selectedDomain = value!;
                    });
                  },
                  items: domains.map((domain) {
                    return DropdownMenuItem(value: domain, child: Text(domain));
                  }).toList(),
                  decoration: InputDecoration(labelText: "Select Domain"),
                ),

                TextFormField(
                  decoration: InputDecoration(labelText: "Exercise Name"),
                  onChanged: (value) => exerciseName = value,
                  validator: (value) =>
                  value!.isEmpty ? "Enter exercise name" : null,
                ),

                TextFormField(
                  decoration: InputDecoration(labelText: "Difficulty"),
                  onChanged: (value) => difficulty = value,
                  validator: (value) =>
                  value!.isEmpty ? "Enter difficulty level" : null,
                ),

                TextFormField(
                  decoration: InputDecoration(labelText: "Exercise Details"),
                  onChanged: (value) => exerciseDetails = value,
                  validator: (value) =>
                  value!.isEmpty ? "Enter exercise details" : null,
                ),

                TextFormField(
                  decoration: InputDecoration(labelText: "Expected Answer"),
                  onChanged: (value) => expectedAnswer = value,
                  validator: (value) =>
                  value!.isEmpty ? "Enter expected answer" : null,
                ),

                SizedBox(height: 20),
                Text(
                  "Add Learning Steps:",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),

                TextFormField(
                  controller: stepTitleController,
                  decoration: InputDecoration(labelText: "Step Title"),
                ),

                TextFormField(
                  controller: stepContentController,
                  decoration: InputDecoration(labelText: "Step Content"),
                ),

                TextFormField(
                  controller: stepImageUrlController,
                  decoration: InputDecoration(labelText: "Image URL"),
                ),

                ElevatedButton(
                  onPressed: addStep,
                  child: Text("Add Step"),
                ),

                // Display added steps
                Column(
                  children: learningSteps.map((step) {
                    return ListTile(
                      title: Text(step["title"]!),
                      subtitle: Text(step["content"]!),
                      leading: Image.network(step["image_url"]!,
                          width: 50, height: 50, fit: BoxFit.cover),
                    );
                  }).toList(),
                ),

                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: submitExercise,
                  child: Text("Submit Exercise"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
