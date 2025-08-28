import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // For auth check
import 'package:google_mobile_ads/google_mobile_ads.dart'; // For AdMob
import 'package:firebase_messaging/firebase_messaging.dart'; // For FCM
import 'package:cloud_firestore/cloud_firestore.dart'; // For Firestore
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // Added for local notifications
import 'splashscreen.dart';
import 'wecomescreen.dart'; // Corrected typo from wecomescreen.dart
import 'onboardingscreen.dart';
import 'login_screen.dart'; // Contains LoginScreen
import 'home_page.dart' as home; // Contains DashboardScreen
import 'student_details.dart' as students; // Contains CreateProfilePage
import 'firebase_options.dart';
import 'Services/presence_service.dart'; // Added for PresenceService

// Initialize flutter_local_notifications
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Define notification channel for Android
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel', // ID
  'High Importance Notifications', // Name
  description: 'This channel is used for important notifications.',
  importance: Importance.high,
);

// Background message handler for FCM
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Background message received: ${message.notification?.title}");
  // You can add additional logic here, such as storing the message in Firestore
}

// Global Navigator key to handle navigation from notifications
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("🔥 Firebase initialized successfully");
  } catch (e) {
    print("🔥 Firebase initialization error: $e");
  }

  // Initialize AdMob
  try {
    await MobileAds.instance.initialize();
    print("📢 AdMob initialized successfully");
  } catch (e) {
    print("📢 AdMob initialization error: $e");
  }

  // Initialize flutter_local_notifications
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings initializationSettingsDarwin =
      DarwinInitializationSettings();
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsDarwin,
  );
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      // Handle notification tap when app is in foreground
      if (response.payload != null) {
        final data = Map<String, String>.fromEntries(
          response.payload!
              .split('&')
              .map((e) => e.split('='))
              .map((e) => MapEntry(e[0], e[1])),
        );
        _handleNotificationNavigationFromPayload(data);
      }
    },
  );

  // Create the notification channel on Android
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // Initialize Firebase Cloud Messaging (FCM)
  await setupFirebaseMessaging();

  runApp(const MyApp());
}

Future<void> setupFirebaseMessaging() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // Request permission for notifications (iOS)
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    print("User granted notification permission");
  } else {
    print("User denied notification permission");
  }

  // Get the FCM token and store it in Firestore
  String? token = await messaging.getToken();
  if (token != null) {
    print("FCM Token: $token");
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmToken': token,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      print("FCM token stored for user ${user.uid}");
    }
  }

  // Handle token refresh
  messaging.onTokenRefresh.listen((token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmToken': token,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      print("FCM token refreshed and updated for user ${user.uid}");
    }
  });

  // Handle foreground messages
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    print("Foreground message received: ${message.notification?.title}");
    if (message.notification != null) {
      // Show local notification for foreground messages
      await flutterLocalNotificationsPlugin.show(
        message.hashCode, // Unique ID for the notification
        message.notification?.title,
        message.notification?.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: message.data.entries
            .map((e) => '${e.key}=${e.value}')
            .join('&'), // Pass data as payload
      );
    }
  });

  // Handle background messages
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Handle messages when app is opened from a terminated state
  FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
    if (message != null) {
      _handleNotificationNavigation(message);
    }
  });

  // Handle messages when app is opened from background
  FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationNavigation);
}

void _handleNotificationNavigation(RemoteMessage message) {
  final data = message.data;
  _handleNotificationNavigationFromPayload(data);
}

void _handleNotificationNavigationFromPayload(Map<String, dynamic> data) {
  final type = data['type'] as String?;
  final postId = data['postId'] as String?;

  if (postId != null &&
      postId.isNotEmpty &&
      navigatorKey.currentState != null) {
    // No specific navigation for comments or explore after removal.
    // Handle other types of notifications here if applicable.
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late PresenceService _presenceService;

  @override
  void initState() {
    super.initState();
    _presenceService = PresenceService(); // Initialize PresenceService

    // Listen to auth state changes to update FCM token
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user != null) {
        String? token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
            'fcmToken': token,
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          print("FCM token updated for user ${user.uid} on auth state change");
        }
      }
    });
  }

  @override
  void dispose() {
    _presenceService.dispose(); // Clean up PresenceService
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "My App",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      navigatorKey: navigatorKey, // Add the navigator key
      initialRoute: "/", // Always start with SplashScreen
      routes: {
        "/": (context) => SplashScreen(),
        "/welcome": (context) => WelcomeScreen(),
        "/onboarding": (context) => OnboardingScreen(),
        "/login": (context) => const LoginScreen(),
        "/student_details": (context) =>
            students.CreateProfilePage(fullName: "Default Student"),
        "/home_page": (context) => home.DashboardScreen(
              username: FirebaseAuth.instance.currentUser?.displayName ?? '',
            ), // Pass username dynamically
      },
    );
  }
}
