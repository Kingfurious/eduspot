import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UploadProjectScreen extends StatefulWidget {
  @override
  _UploadProjectScreenState createState() => _UploadProjectScreenState();
}

class _UploadProjectScreenState extends State<UploadProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _githubLinkController = TextEditingController();

  Future<void> _uploadProject() async {
    if (_formKey.currentState!.validate()) {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('projects').add({
          'uid': user.uid,
          'title': _titleController.text,
          'description': _descriptionController.text,
          'githubLink': _githubLinkController.text,
          'uploadedAt': Timestamp.now(),
        });        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Project uploaded successfully')));
        _formKey.currentState!.reset();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Upload Project')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(labelText: 'Project Title'),
                validator: (value) => value!.isEmpty ? 'Enter project title' : null,
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(labelText: 'Project Description'),
                validator: (value) => value!.isEmpty ? 'Enter project description' : null,
              ),
              TextFormField(
                controller: _githubLinkController,
                decoration: InputDecoration(labelText: 'GitHub Link (optional)'),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _uploadProject,
                child: Text('Upload Project'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}