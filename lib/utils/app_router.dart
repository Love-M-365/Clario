// lib/utils/app_router.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/home/main_navigation.dart';
import '../screens/splash_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/auth/verify_email_screen.dart';
import '../screens/questionnaire/questionnaire_screen.dart';
import '../screens/empty_chair_intro_screen.dart';
import '../screens/empty_chair_session_screen.dart';
import '../screens/empty_chair_setup_screen.dart';

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
      path: '/verify-email',
      name: 'verify_email',
      builder: (context, state) => const VerifyEmailScreen(),
    ),
    GoRoute(
      path: '/questionnaire',
      name: 'questionnaire',
      builder: (context, state) => const QuestionnaireScreen(),
    ),
    GoRoute(
      path: '/home',
      name: 'home',
      builder: (context, state) => const MainNavigation(),
    ),
    GoRoute(
      path: '/empty-chair/intro',
      name: 'empty_chair_intro',
      builder: (context, state) => const EmptyChairIntroScreen(),
    ),
    GoRoute(
      path: '/empty-chair/setup',
      name: 'empty_chair_setup',
      builder: (context, state) => const EmptyChairSetupScreen(),
    ),
    GoRoute(
      path: '/empty-chair/session',
      name: 'empty_chair_session',
      builder: (context, state) => EmptyChairSessionScreen(
        chairMemberName: state.extra as String,
      ),
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
