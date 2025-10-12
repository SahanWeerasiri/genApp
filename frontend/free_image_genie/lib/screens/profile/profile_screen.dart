import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/rewarded_ad_button.dart';
import '../../utils/logger.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    // No need to load user profile separately as auth provider handles everything
  }

  void _onAdRewardEarned() async {
    print('DEBUG: _onAdRewardEarned called');

    try {
      // Add 2 tokens via API service
      final success = await ApiService.addTokensToUser(context, 2);

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You earned 2 tokens!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to add tokens. Please try again.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      AppLogger.error('Error adding tokens: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error adding tokens. Please try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }

    print('DEBUG: _onAdRewardEarned completed');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Profile Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: theme.colorScheme.primary,
                    child: Text(
                      authProvider.userEmail.isNotEmpty
                          ? authProvider.userEmail[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    authProvider.userEmail,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Tokens Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [Colors.red.shade900, Colors.red.shade700]
                      : [Colors.blue.shade700, Colors.blue.shade500],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.stars_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${authProvider.tokenCount}',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Available Tokens',
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  RewardedAdButton(onRewardEarned: _onAdRewardEarned),
                  const SizedBox(height: 8),
                  const RewardAdInfo(),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Settings Section
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Theme Toggle
                  ListTile(
                    leading: Icon(
                      isDark
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    title: const Text('Dark Mode'),
                    trailing: Switch(
                      value: isDark,
                      onChanged: (value) {
                        AppLogger.info('Theme toggle: $value');
                        themeProvider.toggleTheme(value);
                      },
                      activeColor: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
