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

import '../screens/EmptyChair/chatbot_screen.dart';
import '../screens/EmptyChair/empty_chair_screen.dart';
import '../screens/EmptyChair/summary_screen.dart';
import '../screens/home/NotificationPanelScreen.dart';
import '../screens/settings_screen.dart';

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
      routes: [
        GoRoute(
          path: 'empty-chair-intro',
          name: 'empty_chair_intro',
          builder: (context, state) => const EmptyChairIntroScreen(),
        ),
        GoRoute(
          path: '/chatbot',
          builder: (context, state) => const ChatbotScreen(),
        ),
        GoRoute(
          path: '/emptyChair',
          builder: (context, state) => const EmptyChairScreen(),
        ),
        GoRoute(
          path: '/summary',
          builder: (context, state) => const SummaryScreen(),
        ),
        GoRoute(
          path: 'notifications',
          name: 'notifications',
          builder: (context, state) => const NotificationPanelScreen(),
        ),
        GoRoute(
          path: 'settings',
          name: 'settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),
  ],
  redirect: (BuildContext context, GoRouterState state) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bool isLoggedIn = authProvider.isLoggedIn;
    final bool isReady = authProvider.isReady;

    final isStarting = state.matchedLocation == '/';
    final isAuthPage = state.matchedLocation == '/login' ||
        state.matchedLocation == '/register';
    final isOnboarding = state.matchedLocation == '/onboarding';

    // Wait for auth state to be ready
    if (!isReady) return null;

    // If not logged in:
    // - If on onboarding or an auth page, allow.
    // - Otherwise, redirect to login.
    if (!isLoggedIn) {
      if (isOnboarding || isAuthPage) return null;
      return '/login';
    }

    // If logged in:
    // - If on an auth page, redirect to home.
    if (isLoggedIn) {
      if (isAuthPage) return '/home';
    }

    // No redirection needed
    return null;
  },
);

GoRouter get appRouter => _router;
