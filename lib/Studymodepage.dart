import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Color palette matching the rest of the app
const Color primaryBlue = Color(0xFF1976D2);
const Color lightBlue = Color(0xFF64B5F6);
const Color veryLightBlue = Color(0xFFE3F2FD);
const Color darkBlue = Color(0xFF0D47A1);
const Color accentBlue = Color(0xFF2196F3);
const Color surfaceColor = Colors.white;
const Color shadowColor = Color(0x1A000000);
const Color backgroundGrey = Color(0xFFF5F7FA);

class FocusLockScreen extends StatefulWidget {
  const FocusLockScreen({Key? key}) : super(key: key);

  @override
  _FocusLockScreenState createState() => _FocusLockScreenState();
}

class _FocusLockScreenState extends State<FocusLockScreen> with WidgetsBindingObserver {
  // Timer variables
  int _selectedHours = 0;
  int _selectedMinutes = 25; // Default to 25 minutes
  bool _isLockActive = false;
  Timer? _timer;
  int _remainingSeconds = 0;
  DateTime? _lockStartTime;
  DateTime? _lastResumeTime;
  int _totalLeaveCount = 0;
  int _commitmentScore = 100; // Start with perfect score
  final int _penaltyPerLeave = 5; // Deduct 5 points each time they leave

  // App distraction list
  final List<String> _distractingApps = [
    'Instagram',
    'WhatsApp',
    'Snapchat',
    'TikTok',
    'YouTube',
    'Twitter',
    'Facebook',
    'Games',
    'Netflix',
    'Messaging'
  ];

  List<String> _selectedDistractions = [];

  // Study stats
  int _totalStudyMinutesToday = 0;
  int _totalStudySessionsToday = 0;
  int _bestCommitmentScore = 100;

  // User info
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _commitmentController = TextEditingController();
  String _commitment = '';

  // For handling route changes within the app
  bool _needsStatsRefresh = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Load stats immediately when screen is created
    _loadStudyStats();
    _loadSavedDistractions();

    // Also load backup from SharedPreferences in case Firestore is slow
    _loadStatsFromSharedPreferences();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _commitmentController.dispose();
    super.dispose();
  }



  // Add this method to be called when the widget is activated
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Check if we need to refresh stats (when returning to this screen)
    if (_needsStatsRefresh) {
      _loadStudyStats();
      _needsStatsRefresh = false;
    }
  }

  Future<void> _loadStudyStats() async {
    // Add this debug print to trace execution
    print("Loading study stats from Firestore...");

    final user = _auth.currentUser;
    if (user != null) {
      try {
        // Get today's study sessions - use exact timestamp comparison
        final today = DateTime.now();
        final startOfDay = DateTime(today.year, today.month, today.day);

        print("Fetching sessions for user ${user.uid} after ${startOfDay.toString()}");

        final QuerySnapshot studySessions = await FirebaseFirestore.instance
            .collection('studySessions')
            .where('userId', isEqualTo: user.uid)
            .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
            .get();

        print("Found ${studySessions.docs.length} study sessions today");

        int totalMinutes = 0;
        int bestScore = 0;

        for (var doc in studySessions.docs) {
          final data = doc.data() as Map<String, dynamic>;
          print("Session data: ${data.toString()}");

          int durationMinutes = 0;
          if (data['durationMinutes'] != null) {
            if (data['durationMinutes'] is int) {
              durationMinutes = data['durationMinutes'] as int;
            } else if (data['durationMinutes'] is double) {
              durationMinutes = (data['durationMinutes'] as double).toInt();
            } else {
              durationMinutes = (data['durationMinutes'] as num).toInt();
            }
          }

          totalMinutes += durationMinutes;
          print("Added $durationMinutes minutes, total now: $totalMinutes");

          // Check for commitment score
          if (data['commitmentScore'] != null && data['commitmentScore'] is num) {
            int score = (data['commitmentScore'] as num).toInt();
            if (score > bestScore) {
              bestScore = score;
            }
          }
        }

        // Also store this in SharedPreferences as a backup
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('todayStudyMinutes', totalMinutes);
        await prefs.setInt('todayStudySessions', studySessions.docs.length);
        await prefs.setInt('todayBestScore', bestScore > 0 ? bestScore : 100);

        print("Saved to SharedPreferences: Minutes=$totalMinutes, Sessions=${studySessions.docs.length}, BestScore=${bestScore > 0 ? bestScore : 100}");

        if (mounted) {
          setState(() {
            _totalStudyMinutesToday = totalMinutes;
            _totalStudySessionsToday = studySessions.docs.length;
            _bestCommitmentScore = bestScore > 0 ? bestScore : 100;

            print("Updated state with: Minutes=$_totalStudyMinutesToday, Sessions=$_totalStudySessionsToday, BestScore=$_bestCommitmentScore");
          });
        }
      } catch (e) {
        print("Error loading study stats from Firestore: $e");
        // Fall back to SharedPreferences if Firestore fails
        _loadStatsFromSharedPreferences();
      }
    } else {
      print("No user logged in. Unable to load stats from Firestore.");
      // Fall back to SharedPreferences
      _loadStatsFromSharedPreferences();
    }
  }
  Future<void> _loadStatsFromSharedPreferences() async {
    print("Falling back to SharedPreferences for stats");
    try {
      final prefs = await SharedPreferences.getInstance();
      final minutes = prefs.getInt('todayStudyMinutes') ?? 0;
      final sessions = prefs.getInt('todayStudySessions') ?? 0;
      final bestScore = prefs.getInt('todayBestScore') ?? 100;

      print("Loaded from SharedPreferences: Minutes=$minutes, Sessions=$sessions, BestScore=$bestScore");

      if (mounted) {
        setState(() {
          _totalStudyMinutesToday = minutes;
          _totalStudySessionsToday = sessions;
          _bestCommitmentScore = bestScore;
        });
      }
    } catch (e) {
      print("Error loading stats from SharedPreferences: $e");
    }
  }

  Future<void> _loadSavedDistractions() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _selectedDistractions = prefs.getStringList('distractions') ?? [];
      });
    }
  }

  Future<void> _saveSelectedDistractions() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('distractions', _selectedDistractions);
  }

  void _startFocusLock() {
    // Make sure they've entered a commitment
    if (_commitment.isEmpty) {
      _showCommitmentInputDialog();
      return;
    }

    final totalSeconds = (_selectedHours * 3600) + (_selectedMinutes * 60);

    setState(() {
      _isLockActive = true;
      _remainingSeconds = totalSeconds;
      _lockStartTime = DateTime.now();
      _lastResumeTime = DateTime.now();
      _totalLeaveCount = 0;
      _commitmentScore = 100;
    });

    // Create timer that ticks every second
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          } else {
            _completeFocusSession();
          }
        });
      }
    });

    // Keep screen on during study session
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
    Wakelock.enable();
  }

  void _pauseFocusLock() {
    _timer?.cancel();
    setState(() {
      _isLockActive = false;
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    Wakelock.disable();
    _showConfirmStopDialog();
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isLockActive = false;
      _remainingSeconds = 0;
      _lockStartTime = null;
      _lastResumeTime = null;
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    Wakelock.disable();
  }

  void _completeFocusSession() {
    _timer?.cancel();

    final durationMinutes = _lockStartTime != null
        ? DateTime.now().difference(_lockStartTime!).inMinutes
        : 0;

    // Save study session to Firestore
    _saveFocusSession(durationMinutes);

    setState(() {
      _isLockActive = false;
    });

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    Wakelock.disable();

    // Show completion dialog
    _showCompletionDialog(durationMinutes);
  }

  Future<void> _saveFocusSession(int durationMinutes) async {
    final user = _auth.currentUser;
    if (user != null && _lockStartTime != null) {
      try {
        // Add study session to Firestore
        await FirebaseFirestore.instance.collection('studySessions').add({
          'userId': user.uid,
          'startTime': Timestamp.fromDate(_lockStartTime!),
          'endTime': Timestamp.fromDate(DateTime.now()),
          'durationMinutes': durationMinutes,
          'distractions': _totalLeaveCount,
          'commitmentScore': _commitmentScore,
          'commitment': _commitment,
          'distractingApps': _selectedDistractions,
          // Add a timestamp to ensure we can sort by creation time
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Immediately update local stats
        setState(() {
          _totalStudySessionsToday += 1;
          _totalStudyMinutesToday += durationMinutes;
          if (_commitmentScore > _bestCommitmentScore) {
            _bestCommitmentScore = _commitmentScore;
          }
        });

        // Save to SharedPreferences as well
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('todayStudyMinutes', _totalStudyMinutesToday);
        await prefs.setInt('todayStudySessions', _totalStudySessionsToday);
        await prefs.setInt('todayBestScore', _bestCommitmentScore);

        print("Updated stats after session: Minutes=$_totalStudyMinutesToday, Sessions=$_totalStudySessionsToday, BestScore=$_bestCommitmentScore");

        // Also refresh from Firestore to ensure consistency
        _loadStudyStats();
      } catch (e) {
        print("Error saving focus session to Firestore: $e");

        // Even if Firestore fails, update local cache
        final prefs = await SharedPreferences.getInstance();

        // Get current values first
        final currentMinutes = prefs.getInt('todayStudyMinutes') ?? 0;
        final currentSessions = prefs.getInt('todayStudySessions') ?? 0;
        final currentBestScore = prefs.getInt('todayBestScore') ?? 100;

        // Update with new session data
        await prefs.setInt('todayStudyMinutes', currentMinutes + durationMinutes);
        await prefs.setInt('todayStudySessions', currentSessions + 1);
        await prefs.setInt('todayBestScore',
            _commitmentScore > currentBestScore ? _commitmentScore : currentBestScore);
      }
    }
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

// 6. Make sure to update whenever app is resumed
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // If the app is resumed, refresh the stats
    if (state == AppLifecycleState.resumed) {
      print("App resumed - refreshing stats");
      _loadStudyStats();

      if (_isLockActive) {
        // User returned to the app during active focus session
        if (_lastResumeTime != null) {
          final awayDuration = DateTime.now().difference(_lastResumeTime!);

          // If they were away for more than 10 seconds, count it as a distraction
          if (awayDuration.inSeconds > 10) {
            setState(() {
              _totalLeaveCount++;
              // Reduce commitment score, minimum 0
              _commitmentScore = (_commitmentScore - _penaltyPerLeave).clamp(0, 100);
            });

            // Show a dialog to remind them of their commitment
            _showCommitmentReminderDialog();
          }
        }

        _lastResumeTime = DateTime.now();
      }
    } else if (state == AppLifecycleState.paused) {
      // User left the app - make sure we have the latest data saved
      if (_isLockActive) {
        print("User left the focus app while session active");
      } else {
        // Save our current state to SharedPreferences before app goes to background
        _saveCurrentStatsToPrefs();
      }
    }
  }

  Future<void> _saveCurrentStatsToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('todayStudyMinutes', _totalStudyMinutesToday);
      await prefs.setInt('todayStudySessions', _totalStudySessionsToday);
      await prefs.setInt('todayBestScore', _bestCommitmentScore);
      print("Saved current stats to SharedPreferences before app paused");
    } catch (e) {
      print("Error saving stats to SharedPreferences: $e");
    }
  }

// 8. Add code to reset stats at the start of a new day
  Future<void> _checkForNewDay() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUsedDateStr = prefs.getString('lastUsedDate');

      final today = DateTime.now();
      final todayStr = "${today.year}-${today.month}-${today.day}";

      if (lastUsedDateStr != null && lastUsedDateStr != todayStr) {
        // It's a new day, reset the stats
        print("New day detected! Resetting daily stats");
        await prefs.setInt('todayStudyMinutes', 0);
        await prefs.setInt('todayStudySessions', 0);
        await prefs.setInt('todayBestScore', 100);

        if (mounted) {
          setState(() {
            _totalStudyMinutesToday = 0;
            _totalStudySessionsToday = 0;
            _bestCommitmentScore = 100;
          });
        }
      }

      // Update the last used date
      await prefs.setString('lastUsedDate', todayStr);
    } catch (e) {
      print("Error checking for new day: $e");
    }
  }

  void _showCommitmentInputDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: surfaceColor,
        elevation: 8,
        title: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: lightBlue.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.psychology,
                color: primaryBlue,
                size: 40,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Your Study Commitment',
              style: GoogleFonts.poppins(
                color: darkBlue,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Writing your commitment makes you 42% more likely to follow through. What do you want to accomplish in this study session?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _commitmentController,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'e.g., "I will complete my math homework and understand the key concepts"',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: primaryBlue, width: 2),
                  ),
                  contentPadding: EdgeInsets.all(16),
                ),
              ),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (_commitmentController.text.trim().isNotEmpty) {
                    setState(() {
                      _commitment = _commitmentController.text.trim();
                    });
                    Navigator.pop(context);
                    _startFocusLock();
                  } else {
                    // Show error or vibrate
                    HapticFeedback.mediumImpact();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentBlue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
                child: Text(
                  'I Commit to Focus',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCommitmentReminderDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: surfaceColor,
        elevation: 8,
        title: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.orange[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange[700],
                size: 60,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'You Got Distracted',
              style: GoogleFonts.poppins(
                color: Colors.orange[700],
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'You left your study session to use another app. Remember your commitment:',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: veryLightBlue.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: lightBlue, width: 1),
                ),
                child: Text(
                  _commitment,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: darkBlue,
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Your commitment score is now $_commitmentScore%',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentBlue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
                child: Text(
                  'Back to Studying',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showExitConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: surfaceColor,
        elevation: 8,
        title: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.red[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: Colors.red[700],
                size: 60,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'End Focus Session?',
              style: GoogleFonts.poppins(
                color: Colors.red[700],
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Text(
          'Your study time is not yet finished. Do you want to end the session now?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16,
            height: 1.5,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Keep Studying',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Close dialog
                      _completeFocusSession(); // End the session
                      Navigator.pop(context); // Exit the screen
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'End Session',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showConfirmStopDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: surfaceColor,
        elevation: 8,
        title: Text(
          'End Focus Session?',
          style: GoogleFonts.poppins(
            color: darkBlue,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
          textAlign: TextAlign.center,
        ),
        content: Text(
          'Are you sure you want to end your current focus session? Your progress will be saved.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black87,
            fontSize: 15,
            height: 1.5,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // Resume the timer
                      _startFocusLock();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'No, Continue',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _completeFocusSession();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentBlue,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'End Session',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCompletionDialog(int durationMinutes) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: surfaceColor,
        elevation: 8,
        title: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.green[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                color: Colors.green[700],
                size: 60,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Great job!',
              style: GoogleFonts.poppins(
                color: Colors.green[700],
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'You completed a ${durationMinutes} minute focus session!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: veryLightBlue.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _buildStatRow(
                        icon: Icons.timer_outlined,
                        label: 'Focus Time',
                        value: '$durationMinutes minutes'
                    ),
                    SizedBox(height: 8),
                    _buildStatRow(
                      icon: Icons.phonelink_erase_outlined,
                      label: 'Distractions',
                      value: '$_totalLeaveCount',
                    ),
                    SizedBox(height: 8),
                    _buildStatRow(
                      icon: Icons.psychology_outlined,
                      label: 'Commitment Score',
                      value: '$_commitmentScore%',
                    ),
                  ],
                ),
              ),
              if (_commitment.isNotEmpty) ...[
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green[200]!, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Commitment:',
                        style: TextStyle(
                          color: Colors.green[800],
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        _commitment,
                        style: TextStyle(
                          color: Colors.black87,
                          fontStyle: FontStyle.italic,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _resetTimer();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentBlue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
                child: Text(
                  'Done',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDistractionSelectionDialog() {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
          children: [
      Container(
      margin: EdgeInsets.only(top: 10, bottom: 4),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(10),
      ),
    ),
    Padding(
    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    child: Row(
    children: [
    Icon(Icons.psychology_outlined, color: primaryBlue, size: 24),
    SizedBox(width: 10),
    Text(
    'What Distracts You?',
    style: GoogleFonts.poppins(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: darkBlue,
    ),
    ),
    Spacer(),
    IconButton(
    icon: Icon(Icons.close, color: Colors.grey[600]),
    onPressed: () => Navigator.pop(context),
    ),
    ],
    ),
    ),
    Divider(),
    Padding(
    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    child: Text(
    'Select the apps or activities that usually distract you during study time. We\'ll help you remember your commitment when you\'re tempted.',
    style: TextStyle(
    color: Colors.grey[700],
    fontSize: 14,
    height: 1.5,
    ),
    ),
    ),
    Expanded(
    child: ListView.builder(
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    itemCount: _distractingApps.length,
    itemBuilder: (context, index) {
    final app = _distractingApps[index];
    final isSelected = _selectedDistractions.contains(app);

    return CheckboxListTile(
    value: isSelected,
      onChanged: (value) {
        setState(() {
          if (value == true) {
            if (!_selectedDistractions.contains(app)) {
              _selectedDistractions.add(app);
            }
          } else {
            _selectedDistractions.remove(app);
          }
        });
      },
      title: Text(
        app,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? primaryBlue : Colors.black87,
        ),
      ),
      activeColor: accentBlue,
      checkColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
    },
    ),
    ),
            Divider(height: 1),
            Padding(
              padding: EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () {
                  _saveSelectedDistractions();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentBlue,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Save Selection (${_selectedDistractions.length})',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
      ),
        ),
    );
  }

  String _formatTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;

    return [
      if (hours > 0) hours.toString().padLeft(2, '0'),
      minutes.toString().padLeft(2, '0'),
      remainingSeconds.toString().padLeft(2, '0'),
    ].join(':');
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // If timer is active, show confirmation dialog
        if (_isLockActive) {
          _showExitConfirmationDialog();
          return false; // Prevent default back button behavior
        }

        // Set flag to refresh stats when user returns to this screen
        _needsStatsRefresh = true;
        return true; // Allow default back button behavior
      },
      child: Scaffold(
        backgroundColor: backgroundGrey,
        appBar: _isLockActive
            ? null // Hide app bar in lock mode for more focus
            : AppBar(
          backgroundColor: primaryBlue,
          elevation: 0,
          title: Text(
            'Focus Lock',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              // Set flag to refresh stats when user returns to this screen
              _needsStatsRefresh = true;
              Navigator.pop(context);
            },
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(24),
            ),
          ),
        ),
        body: SafeArea(
          child: _isLockActive
              ? _buildLockActiveScreen()
              : _buildSetupScreen(),
        ),
      ),
    );
  }

  Widget _buildLockActiveScreen() {
    final timeString = _formatTime(_remainingSeconds);

    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Top spacer
            Spacer(flex: 1),

            // Timer display
            Text(
              timeString,
              style: GoogleFonts.poppins(
                fontSize: 64,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Remaining Focus Time',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),

            // Middle section with commitment
            Spacer(flex: 1),
            if (_commitment.isNotEmpty) ...[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'YOUR COMMITMENT:',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        _commitment,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Stats section
            Spacer(flex: 1),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildLockStatItem(
                    value: '$_commitmentScore',
                    label: 'COMMITMENT\nSCORE',
                    icon: Icons.psychology_outlined,
                  ),
                  _buildLockStatItem(
                    value: '$_totalLeaveCount',
                    label: 'TIMES\nDISTRACTED',
                    icon: Icons.phonelink_erase_outlined,
                  ),
                ],
              ),
            ),

            // Bottom spacer and exit button
            Spacer(flex: 1),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: ElevatedButton(
                onPressed: _pauseFocusLock,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.withOpacity(0.2),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.red.withOpacity(0.3)),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.exit_to_app, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'End Focus Session',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLockStatItem({
    required String value,
    required String label,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.white70,
          size: 24,
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 11,
            letterSpacing: 0.5,
            height: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildSetupScreen() {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        // Stats card
        _buildMaterialCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.bar_chart, color: primaryBlue, size: 20),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Today\'s Progress',
                    style: GoogleFonts.poppins(
                      color: darkBlue,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatCard(
                    icon: Icons.timer_outlined,
                    value: _totalStudyMinutesToday.toString(),
                    label: 'Minutes',
                  ),
                  _buildStatCard(
                    icon: Icons.calendar_today_outlined,
                    value: _totalStudySessionsToday.toString(),
                    label: 'Sessions',
                  ),
                  _buildStatCard(
                    icon: Icons.psychology_outlined,
                    value: _bestCommitmentScore.toString(),
                    label: 'Best Score',
                  ),
                ],
              ),
            ],
          ),
        ),

        SizedBox(height: 20),

        // Focus lock explanation
        _buildMaterialCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.lock_outlined, color: primaryBlue, size: 20),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Focus Lock Mode',
                    style: GoogleFonts.poppins(
                      color: darkBlue,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Text(
                'Focus Lock creates a distraction-free environment. If you try to use other apps during a focus session, we\'ll remind you of your commitment and your score will decrease.',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              SizedBox(height: 16),
              // Fixed the overflow by changing Row to Column
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    _buildInfoChip(
                      icon: Icons.psychology_outlined,
                      label: 'COMMITMENT SCORE',
                      description: 'Start at 100%. Lose points when you get distracted.',
                    ),
                    SizedBox(height: 12),
                    _buildInfoChip(
                      icon: Icons.phonelink_erase_outlined,
                      label: 'DISTRACTION TRACKING',
                      description: 'We count when you leave the app during focus time.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 20),

        // Timer card
        _buildMaterialCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.timer, color: primaryBlue, size: 20),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Set Focus Time',
                    style: GoogleFonts.poppins(
                      color: darkBlue,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),

              // Timer settings
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: veryLightBlue.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    // Select hours
                    Row(
                      children: [
                        Text(
                          'Hours',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: darkBlue,
                          ),
                        ),
                        Spacer(),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: shadowColor.withOpacity(0.1),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: Icon(Icons.remove, color: Colors.grey[700]),
                                onPressed: _selectedHours > 0
                                    ? () {
                                  setState(() {
                                    _selectedHours--;
                                  });
                                }
                                    : null,
                              ),
                              Container(
                                width: 40,
                                alignment: Alignment.center,
                                child: Text(
                                  _selectedHours.toString(),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.add, color: primaryBlue),
                                onPressed: _selectedHours < 8
                                    ? () {
                                  setState(() {
                                    _selectedHours++;
                                  });
                                }
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 16),

                    // Select minutes
                    Row(
                      children: [
                        Text(
                          'Minutes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: darkBlue,
                          ),
                        ),
                        Spacer(),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: shadowColor.withOpacity(0.1),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: Icon(Icons.remove, color: Colors.grey[700]),
                                onPressed: _selectedMinutes > 0
                                    ? () {
                                  setState(() {
                                    _selectedMinutes = (_selectedMinutes - 5).clamp(0, 55);
                                  });
                                }
                                    : null,
                              ),
                              Container(
                                width: 40,
                                alignment: Alignment.center,
                                child: Text(
                                  _selectedMinutes.toString(),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.add, color: primaryBlue),
                                onPressed: _selectedMinutes < 55
                                    ? () {
                                  setState(() {
                                    _selectedMinutes = (_selectedMinutes + 5).clamp(0, 55);
                                  });
                                }
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20),

              // Quick presets
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildPresetButton('25 min', onTap: () {
                    setState(() {
                      _selectedHours = 0;
                      _selectedMinutes = 25;
                    });
                  }),
                  _buildPresetButton('45 min', onTap: () {
                    setState(() {
                      _selectedHours = 0;
                      _selectedMinutes = 45;
                    });
                  }),
                  _buildPresetButton('1 hour', onTap: () {
                    setState(() {
                      _selectedHours = 1;
                      _selectedMinutes = 0;
                    });
                  }),
                  _buildPresetButton('2 hours', onTap: () {
                    setState(() {
                      _selectedHours = 2;
                      _selectedMinutes = 0;
                    });
                  }),
                ],
              ),

              SizedBox(height: 24),

              // Start button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_selectedHours > 0 || _selectedMinutes > 0) ? _startFocusLock : null,
                  icon: Icon(Icons.lock_outline),
                  label: Text(
                    'Start Focus Lock',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentBlue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    disabledForegroundColor: Colors.grey[500],
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Identify distractions section
        SizedBox(height: 20),
        _buildMaterialCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.psychology_outlined, color: primaryBlue, size: 20),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Your Distractions',
                    style: GoogleFonts.poppins(
                      color: darkBlue,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),

              // Selected distractions
              if (_selectedDistractions.isEmpty)
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: veryLightBlue.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: lightBlue,
                        size: 24,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Identify which apps or activities distract you most during study time.',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _selectedDistractions.map((app) => Chip(
                    label: Text(app),
                    backgroundColor: veryLightBlue,
                    labelStyle: TextStyle(color: darkBlue),
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  )).toList(),
                ),

              SizedBox(height: 16),

              // Select distractions button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showDistractionSelectionDialog,
                  icon: Icon(_selectedDistractions.isEmpty ? Icons.add : Icons.edit),
                  label: Text(
                    _selectedDistractions.isEmpty
                        ? 'Identify Your Distractions'
                        : 'Edit Distractions (${_selectedDistractions.length})',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryBlue,
                    side: BorderSide(color: lightBlue),
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 30),
      ],
    );
  }

  // Fixed info chip to prevent overflow
  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String description,
  }) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: veryLightBlue.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Wrap with Flexible to prevent overflow
          Row(
            mainAxisSize: MainAxisSize.min, // Added to prevent overflow
            children: [
              Icon(icon, color: primaryBlue, size: 16),
              SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: primaryBlue,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis, // Added to handle overflow
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          // Text with controlled overflow
          Text(
            description,
            style: TextStyle(
              fontSize: 12,
              color: Colors.black87,
              height: 1.3,
            ),
            maxLines: 3, // Limit to 3 lines
          ),
        ],
      ),
    );
  }

  Widget _buildPresetButton(String label, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: shadowColor.withOpacity(0.1),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: primaryBlue,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: accentBlue, size: 28),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: darkBlue,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: accentBlue, size: 16),
        ),
        SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            color: Colors.black87,
            fontSize: 14,
          ),
        ),
        Spacer(),
        Text(
          value,
          style: TextStyle(
            color: darkBlue,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildMaterialCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: child,
      ),
    );
  }
}

// Add Wakelock functionality to keep screen on
// You'll need to add the wakelock package to your pubspec.yaml
class Wakelock {
  static Future<void> enable() async {
    try {
      // Keep screen on
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: [], // Hide status bar and navigation bar
      );
      // You can also use the actual wakelock package here
      print("Wakelock enabled");
    } catch (e) {
      print("Failed to enable wakelock: $e");
    }
  }

  static Future<void> disable() async {
    try {
      // Restore normal screen behavior
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values, // Show all UI elements again
      );
      print("Wakelock disabled");
    } catch (e) {
      print("Failed to disable wakelock: $e");
    }
  }
}