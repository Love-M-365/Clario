// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/user_data_provider.dart';
import 'utils/app_router.dart';
import 'utils/theme_data.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_messaging/firebase_messaging.dart';

import './screens/home/main_navigation.dart';
// ✅ Import your main navigation

// --- ADDED IMPORTS FOR AUDIO SERVICE ---
import 'package:audio_service/audio_service.dart';
import './audio_handler.dart'; // The file we created for background audio
// --- END ADDED IMPORTS ---

// --- GLOBAL AUDIO HANDLER ---
late MyAudioHandler audioHandler;
// --- END GLOBAL AUDIO HANDLER ---

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('📬 Handling background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // ✅ Initialize Firebase Cloud Messaging
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    final fcm = FirebaseMessaging.instance;
    await fcm.requestPermission();
    final token = await fcm.getToken();
    print('🔑 FCM Token: $token');
  } catch (e) {
    print('Firebase initialization error: $e');
  }

  // ✅ Ensure audioHandler is always initialized before app starts
  try {
    audioHandler = await AudioService.init(
      builder: () => MyAudioHandler(), // From audio_handler.dart
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.example.clario.audio',
        androidNotificationChannelName: 'Clario Sleep Sounds',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
    print('🎧 AudioService initialized successfully');
  } catch (e) {
    print('AudioService initialization error: $e');
    // 👇 Fallback: still assign a dummy instance to prevent LateInitializationError
    audioHandler = MyAudioHandler();
  }

  runApp(const ClarionApp());
}

class ClarionApp extends StatefulWidget {
  const ClarionApp({super.key});

  @override
  State<ClarionApp> createState() => _ClarionAppState();
}

class _ClarionAppState extends State<ClarionApp> {
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();

    // 🔹 Foreground notifications (Existing code, unchanged)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final title = message.notification?.title ?? 'Sleep Update';
      final body =
          message.notification?.body ?? 'Check your latest sleep data!';
      print('🔔 Foreground notification: $title - $body');

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title\n$body')),
          );
        }
      });
    });

    // 🔹 Notification taps (Existing code, unchanged)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('🟢 Notification tapped — opening Sleep tab...');

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // ✅ Navigate to MainNavigation and switch to the Sleep tab
          _navKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => const MainNavigationWrapper(initialIndex: 3),
            ),
            (route) => false,
          );
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => UserDataProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp.router(
            title: 'Clario',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.getTheme(themeProvider.currentTheme),
            routerConfig: appRouter,
            key: _navKey, // Kept your key as requested
          );
        },
      ),
    );
  }
}

/// ✅ A small wrapper for MainNavigation (Existing code, unchanged)
/// This allows starting directly on a specific tab (e.g., Sleep)
class MainNavigationWrapper extends StatefulWidget {
  final int initialIndex;
  const MainNavigationWrapper({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends State<MainNavigationWrapper> {
  @override
  Widget build(BuildContext context) {
    return MainNavigationWithIndex(initialIndex: widget.initialIndex);
  }
}
