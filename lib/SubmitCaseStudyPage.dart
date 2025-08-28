import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SubmitCaseStudyPage extends StatefulWidget {
  final String caseStudyId;
  SubmitCaseStudyPage(this.caseStudyId);

  @override
  _SubmitCaseStudyPageState createState() => _SubmitCaseStudyPageState();
}

class _SubmitCaseStudyPageState extends State<SubmitCaseStudyPage> {
  String? fileUrl;

  Future<void> uploadFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      var file = result.files.single;
      var ref = FirebaseStorage.instance.ref().child("case_studies/${file.name}");
      await ref.putData(file.bytes!);
      fileUrl = await ref.getDownloadURL();
      setState(() {});
    }
  }

  Future<void> submitCaseStudy() async {
    if (fileUrl != null) {
      await FirebaseFirestore.instance.collection('user_submissions').add({
        "case_study_id": widget.caseStudyId,
        "document_url": fileUrl,
        "status": "pending"
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Submitted for review!")));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Submit Case Study")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(onPressed: uploadFile, child: Text("Upload File")),
            if (fileUrl != null) Text("File Uploaded!"),
            SizedBox(height: 20),
            ElevatedButton(onPressed: submitCaseStudy, child: Text("Submit")),
          ],
        ),
      ),
    );
  }
}
