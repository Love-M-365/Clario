// lib/navigation/main_navigation.dart

import 'dart:ui'; // Required for the blur effect
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for haptic feedback
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../screens/home/main_dashboard_screen.dart';
import '../../screens/sleep_screen.dart';
import '../../screens/empty_chair_intro_screen.dart';
import '../../screens/journal_history_screen.dart';
import '../../enum/app_theme_type.dart';

// A simple data class to hold all properties for a navigation item.
// This is much cleaner than managing multiple separate lists.
class _BottomNavItem {
  final Widget screen;
  final IconData icon;
  final String label;

  const _BottomNavItem({
    required this.screen,
    required this.icon,
    required this.label,
  });
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  // A single, organized list for all navigation items.
  final List<_BottomNavItem> _navItems = [
    _BottomNavItem(
      screen: const MainDashboardScreen(),
      icon: Icons.home_rounded,
      label: 'Home',
    ),
    _BottomNavItem(
      screen: const EmptyChairIntroScreen(),
      icon: Icons.chair_rounded,
      label: 'Reflect',
    ),
    _BottomNavItem(
      screen: const JournalHistoryScreen(),
      icon: Icons.edit_note_rounded,
      label: 'Journal',
    ),
    _BottomNavItem(
      screen: const SleepScreen(),
      icon: Icons.bedtime_rounded,
      label: 'Sleep',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The body now correctly displays the screen from our _navItems list.
      body: _navItems[_currentIndex].screen,
      bottomNavigationBar: CustomBottomNavBar(
        items: _navItems,
        currentIndex: _currentIndex,
        onTap: (index) {
          // Add haptic feedback for a better user experience
          HapticFeedback.lightImpact();
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}

// Custom Bottom Navigation Bar with a Modern Glassmorphism Effect
class CustomBottomNavBar extends StatelessWidget {
  final List<_BottomNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const CustomBottomNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.currentTheme == AppThemeType.calm;

    // Define colors based on the theme
    final navBarColor = isDarkMode
        ? Colors.black.withOpacity(0.5)
        : Colors.white.withOpacity(0.5);
    final selectedItemColor =
        isDarkMode ? Colors.lightBlue.shade200 : Theme.of(context).primaryColor;
    final unselectedItemColor =
        isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30.0),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
            child: Container(
              height: 65,
              decoration: BoxDecoration(
                color: navBarColor,
                borderRadius: BorderRadius.circular(30.0),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: items.asMap().entries.map((entry) {
                  final int index = entry.key;
                  final _BottomNavItem item = entry.value;
                  return _buildNavItem(
                    item: item,
                    index: index,
                    isSelected: currentIndex == index,
                    selectedColor: selectedItemColor,
                    unselectedColor: unselectedItemColor,
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required _BottomNavItem item,
    required int index,
    required bool isSelected,
    required Color selectedColor,
    required Color unselectedColor,
  }) {
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque, // Ensures the whole area is tappable
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected ? selectedColor.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              item.icon,
              color: isSelected ? selectedColor : unselectedColor,
              size: 24,
            ),
            // The label animates its width to appear and disappear smoothly
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: Padding(
                padding: EdgeInsets.only(left: isSelected ? 8.0 : 0.0),
                child: Text(
                  isSelected ? item.label : "",
                  style: TextStyle(
                    color: selectedColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.clip,
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
