import 'dart:io' show File; // Only for mobile
import 'dart:typed_data' show Uint8List; // For web
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Mobile: Upload using File
  Future<String> uploadHandwrittenNotesMobile(
      String filePath, {
        Function(double)? onProgress,
      }) async {
    File file = File(filePath);
    String fileName = filePath.split('/').last;
    Reference ref = _storage.ref().child('handwritten_notes/$fileName');
    UploadTask uploadTask = ref.putFile(file);

    // Track upload progress
    uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
      double progress = snapshot.bytesTransferred / snapshot.totalBytes;
      if (onProgress != null) onProgress(progress);
    });

    TaskSnapshot snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  // Web: Upload using Uint8List (bytes)
  Future<String> uploadHandwrittenNotesWeb(
      Uint8List bytes,
      String fileName, {
        Function(double)? onProgress,
      }) async {
    Reference ref = _storage.ref().child('handwritten_notes/$fileName');
    UploadTask uploadTask = ref.putData(bytes);

    // Track upload progress
    uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
      double progress = snapshot.bytesTransferred / snapshot.totalBytes;
      if (onProgress != null) onProgress(progress);
    });

    TaskSnapshot snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }
}