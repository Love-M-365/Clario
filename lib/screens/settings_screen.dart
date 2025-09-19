import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:clario/providers/auth_provider.dart';
import 'package:clario/providers/theme_provider.dart';
import 'package:clario/utils/theme_data.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, ThemeProvider>(
      builder: (context, authProvider, themeProvider, child) {
        return Scaffold(
          extendBodyBehindAppBar: true, // This is the key fix
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => context.go('/home'),
            ),
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0C1324), // Dark blue
                  Color(0xFF131A2D), // Slightly lighter dark blue
                ],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    const Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    )
                        .animate()
                        .fadeIn(
                          duration: 800.ms,
                        )
                        .slideX(
                          begin: -0.3,
                          duration: 800.ms,
                          curve: Curves.easeOut,
                        ),
                    const SizedBox(height: 32),
                    // Profile Section
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .primaryColor
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Icon(
                              Icons.person,
                              size: 30,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  authProvider.user?.displayName ?? 'User',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  authProvider.user?.email ?? '',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.edit,
                            color: Colors.grey.shade400,
                          ),
                        ],
                      ),
                    )
                        .animate()
                        .fadeIn(
                          duration: 800.ms,
                          delay: 200.ms,
                        )
                        .slideY(
                          begin: 0.3,
                          duration: 800.ms,
                          curve: Curves.easeOut,
                        ),
                    const SizedBox(height: 24),
                    // Settings Options
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                          width: 1.0,
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildSettingItem(
                            icon: Icons.notifications_outlined,
                            title: 'Notifications',
                            subtitle: 'Manage your notification preferences',
                            onTap: () {},
                          ),
                          _buildDivider(),
                          _buildSettingItem(
                            icon: Icons.privacy_tip_outlined,
                            title: 'Privacy',
                            subtitle: 'Control your data and privacy settings',
                            onTap: () {},
                          ),
                          _buildDivider(),
                          _buildSettingItem(
                            icon: Icons.help_outline,
                            title: 'Help & Support',
                            subtitle: 'Get help and contact support',
                            onTap: () {},
                          ),
                          _buildDivider(),
                          _buildSettingItem(
                            icon: Icons.info_outline,
                            title: 'About',
                            subtitle: 'App version and information',
                            onTap: () {},
                          ),
                          _buildDivider(),
                          _buildSettingItem(
                            icon: Icons.logout,
                            title: 'Sign Out',
                            subtitle: 'Sign out of your account',
                            onTap: () =>
                                _showSignOutDialog(context, authProvider),
                            isDestructive: true,
                          ),
                        ],
                      ),
                    ).animate().fadeIn(
                          duration: 800.ms,
                          delay: 600.ms,
                        ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDestructive
                      ? Colors.red.withOpacity(0.1)
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isDestructive ? Colors.red : Colors.grey.shade400,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDestructive ? Colors.red : Colors.white,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      color: Colors.white.withOpacity(0.1),
    );
  }

  void _showSignOutDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await authProvider.signOut();
              if (context.mounted) {
                Navigator.pop(context);
                context.go('/login');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
