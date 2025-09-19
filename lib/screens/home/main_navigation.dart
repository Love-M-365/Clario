import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import 'main_dashboard_screen.dart'; // Your dashboard screen
import '../sleep_screen.dart';
import '../settings_screen.dart';
import '../empty_chair_intro_screen.dart'; // New screen for Empty Chair mode
import '../../enum/app_theme_type.dart';
import '../../utils/theme_data.dart';
import '../journal_history_screen.dart'; // Import the new journal screen

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const MainDashboardScreen(),
    const EmptyChairIntroScreen(),
    const SleepScreen(),
    const JournalHistoryScreen(), // New journal screen at index 2
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: _screens[_currentIndex],
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}

// Custom Bottom Navigation Bar
class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.currentTheme == AppThemeType.calm;

    final navBarColor = isDarkMode ? Colors.black : Colors.white;
    final selectedIconColor = isDarkMode ? Colors.lightBlue[200] : Colors.blue;
    final unselectedIconColor = isDarkMode ? Colors.white : Colors.black;

    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(context, Icons.home_outlined, 0, unselectedIconColor,
              selectedIconColor),
          _buildNavItem(context, Icons.chair_outlined, 3, unselectedIconColor,
              selectedIconColor),
          _buildNavItem(context, Icons.history_edu_outlined, 2,
              unselectedIconColor, selectedIconColor),
          _buildNavItem(context, Icons.bedtime_outlined, 1, unselectedIconColor,
              selectedIconColor), // New Journal/History icon
          // Now at index 3
          // Now at index 4
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, IconData icon, int index,
      Color unselectedColor, Color? selectedColor) {
    bool isSelected = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: isSelected
            ? BoxDecoration(
                color: unselectedColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              )
            : null,
        child: Icon(
          icon,
          color: isSelected ? selectedColor : unselectedColor,
          size: 24,
        ),
      ),
    );
  }
}
