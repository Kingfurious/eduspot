import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PresenceService with WidgetsBindingObserver {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isUpdating = false;
  static const Duration _updateInterval = Duration(seconds: 30);
  static const Duration _onlineThreshold = Duration(minutes: 5);

  PresenceService() {
    WidgetsBinding.instance.addObserver(this);
    _startUpdating();
  }

  // Update lastActive timestamp
  Future<void> _updateLastActive() async {
    final user = _auth.currentUser;
    if (user != null && _isUpdating) {
      try {
        await _firestore.collection('users').doc(user.uid).set({
          'lastActive': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        print('Error updating lastActive: $e');
      }
    }
  }

  // Start periodic updates
  void _startUpdating() {
    _isUpdating = true;
    _updateLastActive();
    Future.doWhile(() async {
      await Future.delayed(_updateInterval);
      if (_isUpdating) {
        await _updateLastActive();
        return true;
      }
      return false;
    });
  }

  // Stop updates when app is in background
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isUpdating = true;
      _updateLastActive();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _isUpdating = false;
    }
  }

  // Check if a user is online based on lastActive
  bool isUserOnline(Timestamp? lastActive) {
    if (lastActive == null) return false;
    final now = DateTime.now();
    final lastActiveTime = lastActive.toDate();
    return now.difference(lastActiveTime) <= _onlineThreshold;
  }

  // Clean up observer
  void dispose() {
    _isUpdating = false;
    WidgetsBinding.instance.removeObserver(this);
  }
}