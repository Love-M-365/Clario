// lib/utils/app_router.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/home/main_navigation.dart';
import '../screens/splash_screen.dart';
import '../screens/onboarding/onboarding_screen.dart'; // Make sure this is imported

final GoRouter _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      name: 'onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      name: 'register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/home',
      name: 'home',
      builder: (context, state) => const MainNavigation(),
    ),
  ],
  // REMOVE THIS ENTIRE REDIRECT BLOCK
  // redirect: (BuildContext context, GoRouterState state) {
  //   final authProvider = Provider.of<AuthProvider>(context, listen: false);
  //   final isLoggedIn = authProvider.isLoggedIn;
  //   final isGoingToSplash = state.matchedLocation == '/';
  //
  //   if (isGoingToSplash) {
  //     return null;
  //   }
  //
  //   if (!isLoggedIn) {
  //     final isLoggingInOrRegistering = state.matchedLocation == '/login' || state.matchedLocation == '/register';
  //     return isLoggingInOrRegistering ? null : '/login';
  //   }
  //
  //   if (isLoggedIn && (state.matchedLocation == '/login' || state.matchedLocation == '/register')) {
  //     return '/home';
  //   }
  //
  //   return null;
  // },
);

GoRouter get appRouter => _router;
