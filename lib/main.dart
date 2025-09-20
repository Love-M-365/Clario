// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart'; // This is your local AuthProvider
import 'providers/theme_provider.dart';
import 'providers/user_data_provider.dart';
import 'utils/app_router.dart';
import 'utils/theme_data.dart';
import 'package:firebase_auth/firebase_auth.dart'
    as firebase_auth; // Alias the Firebase import

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print('Firebase initialization error: $e');
  }

  runApp(const ClarionApp());
}

class ClarionApp extends StatelessWidget {
  const ClarionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) =>
                AuthProvider()), // Now Dart knows this is your local AuthProvider
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
          );
        },
      ),
    );
  }
}
