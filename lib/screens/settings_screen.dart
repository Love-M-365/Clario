// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:clario/providers/auth_provider.dart';
import 'package:clario/providers/theme_provider.dart';
import 'package:clario/providers/user_data_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui'; // For blur effect

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Use Consumer3 to access all needed providers
    return Consumer3<AuthProvider, ThemeProvider, UserDataProvider>(
      builder: (context, authProvider, themeProvider, userDataProvider, child) {
        final displayName = userDataProvider.user?.name ??
            authProvider.user?.displayName ??
            'User';
        final displayEmail = authProvider.user?.email ?? '';

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor:
                    theme.appBarTheme.backgroundColor?.withOpacity(0.8),
                flexibleSpace: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(color: Colors.transparent),
                  ),
                ),
                elevation: 0,
                pinned: true,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new,
                      color: theme.colorScheme.onSurface),
                  onPressed: () =>
                      context.canPop() ? context.pop() : context.go('/home'),
                ),
                title: Text(
                  'Settings',
                  style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold),
                ),
                centerTitle: true,
              ),
              SliverList(
                delegate: SliverChildListDelegate(
                  [
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildProfileSection(
                                  context, displayName, displayEmail)
                              .animate()
                              .fadeIn(duration: 600.ms)
                              .slideY(begin: 0.2, curve: Curves.easeOut),
                          const SizedBox(height: 32),

                          // ✅ Pass context
                          _buildSectionHeader(context, 'Account'),
                          _buildSettingsGroup(context, [
                            _buildSettingItem(
                              icon: Icons.face_retouching_natural_outlined,
                              title: 'Customize Avatar',
                              subtitle: 'Change your AI companion',
                              onTap: () => context.go('/home/avatar-prompt'),
                            ),
                            _buildDivider(),
                            _buildSettingItem(
                              icon: Icons.notifications_outlined,
                              title: 'Notifications',
                              subtitle: 'Manage preferences',
                              onTap: () {},
                            ),
                          ]),
                          const SizedBox(height: 24),

                          // ✅ Pass context
                          _buildSectionHeader(context, 'Appearance'),
                          _buildSettingsGroup(context, [
                            _buildSettingItem(
                              icon: Icons.palette_outlined,
                              title: 'Color Theme',
                              subtitle: themeProvider
                                  .getThemeName(themeProvider.currentTheme),
                              onTap: () {
                                context.go('/home/debug-dashboard');
                              },
                            ),
                          ]),
                          const SizedBox(height: 24),

                          // ✅ Pass context
                          _buildSectionHeader(context, 'Support'),
                          _buildSettingsGroup(context, [
                            _buildSettingItem(
                              icon: Icons.privacy_tip_outlined,
                              title: 'Privacy Policy',
                              subtitle: 'View our policy',
                              onTap: () {},
                            ),
                            _buildDivider(),
                            _buildSettingItem(
                              icon: Icons.help_outline,
                              title: 'Help & Support',
                              subtitle: 'Contact us or find help',
                              onTap: () {},
                            ),
                            _buildDivider(),
                            _buildSettingItem(
                              icon: Icons.info_outline,
                              title: 'About Clario',
                              subtitle: 'App version and details',
                              onTap: () {},
                            ),
                          ]),
                          const SizedBox(height: 24),

                          _buildSettingsGroup(context, [
                            _buildSettingItem(
                              icon: Icons.logout,
                              title: 'Sign Out',
                              subtitle: 'Sign out of your account',
                              onTap: () =>
                                  _showSignOutDialog(context, authProvider),
                              isDestructive: true,
                            ),
                          ]),
                          const SizedBox(height: 32),
                        ],
                      )
                          .animate()
                          .slideY(begin: 0.1, duration: 500.ms, delay: 100.ms)
                          .fadeIn(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Helper Widgets ---

  Widget _buildProfileSection(BuildContext context, String name, String email) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(Icons.person,
                size: 30, color: theme.colorScheme.onPrimaryContainer),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                if (email.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text(email,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.hintColor)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Added BuildContext context parameter
  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context); // Now context is available
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: theme.hintColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 0.8,
        ),
      ),
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildSettingsGroup(BuildContext context, List<Widget> items) {
    final theme = Theme.of(context);
    return Animate(
      effects: const [FadeEffect(), SlideEffect(begin: Offset(0, 0.1))],
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: AnimateList(
              interval: 100.ms,
              effects: [
                FadeEffect(duration: 400.ms, curve: Curves.easeOut),
                SlideEffect(
                    begin: const Offset(0.05, 0),
                    duration: 400.ms,
                    curve: Curves.easeOut),
              ],
              children: items,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    String subtitle = '',
    required VoidCallback onTap,
    Widget? trailing,
    bool isDestructive = false,
  }) {
    return Builder(builder: (context) {
      final theme = Theme.of(context);
      Color itemColor =
          isDestructive ? Colors.red.shade400 : theme.colorScheme.onSurface;
      Color iconColor =
          isDestructive ? Colors.red.shade400 : theme.colorScheme.primary;

      return ListTile(
        leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20)),
        title: Text(title,
            style: TextStyle(fontWeight: FontWeight.w500, color: itemColor)),
        subtitle: subtitle.isNotEmpty
            ? Text(subtitle,
                style: TextStyle(color: theme.hintColor, fontSize: 12))
            : null,
        trailing: trailing ??
            Icon(Icons.chevron_right, color: theme.hintColor.withOpacity(0.5)),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      );
    });
  }

  Widget _buildDivider() {
    return Builder(builder: (context) {
      return Divider(
          height: 0.5,
          thickness: 0.5,
          indent: 60,
          color: Theme.of(context).dividerColor.withOpacity(0.5));
    });
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
              await context.read<AuthProvider>().signOut();
              if (context.mounted) {
                Navigator.pop(context);
                context.go('/login');
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
