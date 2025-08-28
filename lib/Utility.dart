import 'package:android_intent_plus/android_intent.dart';

import 'package:android_intent_plus/flag.dart';

// ✅ Function to check if Usage Access is granted
Future<bool> isUsageAccessGranted() async {
  // Usage Access cannot be checked directly; user must enable it manually
  return false; // Always return false since there's no direct API for it
}

// ✅ Function to open Usage Access settings
void requestUsageAccessPermission() {
  final AndroidIntent intent = AndroidIntent(
    action: 'android.settings.USAGE_ACCESS_SETTINGS',
    flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
  );
  intent.launch();
}
