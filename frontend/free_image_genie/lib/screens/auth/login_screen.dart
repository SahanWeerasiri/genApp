import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/auth/google_sign_in_button.dart';
import '../../utils/logger.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [Colors.black, Colors.grey.shade900]
                : [Colors.blue.shade50, Colors.blue.shade100],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Consumer<AuthProvider>(
                builder: (context, authProvider, child) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // App Icon
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          size: 60,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // App Name
                      Text(
                        'Free Image Genie',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Generate stunning images with AI',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onBackground.withOpacity(
                            0.7,
                          ),
                        ),
                      ),
                      const SizedBox(height: 64),

                      // Loading indicator
                      if (authProvider.isLoading) ...[
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          'Signing you in...',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onBackground.withOpacity(
                              0.7,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ] else ...[
                        // Sign In Button
                        GoogleSignInButton(
                          text: 'Sign in with Google',
                          onPressed: () async {
                            try {
                              AppLogger.info('Sign in button pressed');
                              await authProvider.signInWithGoogle();
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Sign in failed: ${authProvider.errorMessage}',
                                    ),
                                    backgroundColor: theme.colorScheme.error,
                                  ),
                                );
                              }
                            }
                          },
                        ),
                        const SizedBox(height: 32),
                      ],

                      // Error message
                      if (authProvider.errorMessage.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: theme.colorScheme.error.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            authProvider.errorMessage,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Terms
                      Text(
                        'By continuing, you agree to our Terms of Service\nand Privacy Policy',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onBackground.withOpacity(
                            0.5,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
