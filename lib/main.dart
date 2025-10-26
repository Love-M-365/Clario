// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart'; // Local AuthProvider
import 'providers/theme_provider.dart';
import 'providers/user_data_provider.dart';
import 'utils/app_router.dart';
import 'utils/theme_data.dart';
import 'package:firebase_auth/firebase_auth.dart'
    as firebase_auth; // Alias Firebase import
import 'services/sensor_service.dart'; // ✅ Add this import

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print('Firebase initialization error: $e');
  }

  // ✅ Initialize SensorService before running the app
  final sensorService = SensorService();
  await sensorService.init();

  runApp(ClarionApp(sensorService: sensorService));
}

class ClarionApp extends StatelessWidget {
  final SensorService sensorService;

  const ClarionApp({super.key, required this.sensorService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) => AuthProvider()), // Local AuthProvider
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => UserDataProvider()),
        Provider.value(
            value: sensorService), // ✅ Provide SensorService globally
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp.router(
            title: 'Clario',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.getTheme(themeProvider.currentTheme),
            routerConfig: appRouter,
          );
        },
      ),
    );
  }
}
