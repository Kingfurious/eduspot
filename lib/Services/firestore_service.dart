import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:eduspark/models/note.dart'; // Adjust path as per your project
import 'package:eduspark/models/Studentprofile.dart'; // Adjust path as per your project

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String?> _uploadFile(File? file) async {
    if (file == null) return null; // Return null if no file is provided
    String fileName = DateTime.now().millisecondsSinceEpoch.toString();
    Reference ref = _storage.ref().child('notes/$fileName');
    UploadTask uploadTask = ref.putFile(file);
    TaskSnapshot snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  Future<void> uploadNote(File? file, String title, String desc, String userId) async {
    String? fileUrl = await _uploadFile(file); // Handle nullable file
    StudentProfile profile = await getUserProfile(userId);
    await _db.collection('notes').add({
      'userId': userId,
      'title': title,
      'description': desc,
      'fileUrl': fileUrl, // Will be null if no file is uploaded
      'userName': profile.fullName,
      'userImageUrl': profile.imageUrl,
      'likes': 0,
      'dislikes': 0,
      'views': 0,
      'rating': 0.0,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Note>> getNotes() {
    return _db.collection('notes').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Note.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Stream<List<Note>> getTopNotes() {
    return _db
        .collection('notes')
        .orderBy('views', descending: true)
        .limit(10)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Note.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Future<StudentProfile> getUserProfile(String userId) async {
    DocumentSnapshot doc = await _db.collection('studentprofile').doc(userId).get();
    return StudentProfile.fromMap(doc.data() as Map<String, dynamic>);
  }

  Future<void> incrementViews(String noteId) async {
    await _db.collection('notes').doc(noteId).update({
      'views': FieldValue.increment(1),
    });
  }
}