import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/image_provider.dart' as app;
import '../../providers/auth_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../widgets/home/prompt_input.dart';
import '../../widgets/home/style_selector.dart';
import '../../widgets/home/generated_image_display.dart';
import '../../utils/logger.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _promptController = TextEditingController();
  String _selectedStyle = 'Painted Anime';

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _generateImage() async {
    if (_promptController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a prompt')));
      return;
    }

    AppLogger.info('Generate button pressed');

    final authProvider = context.read<AuthProvider>();
    final userProfileProvider = context.read<UserProfileProvider>();

    // Check if user is authenticated
    if (!authProvider.isAuthenticated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to generate images')),
        );
      }
      return;
    }

    // Check token availability
    final hasTokens = await userProfileProvider.checkTokenAvailability();
    if (!hasTokens) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No tokens available. Watch an ad to earn more!'),
          ),
        );
      }
      return;
    }

    try {
      // Generate image with user ID
      await context.read<app.ImageProvider>().generateImage(
        _promptController.text.trim(),
        _selectedStyle,
        userId: authProvider.userId,
      );

      // If successful, consume token from user profile
      await userProfileProvider.consumeToken();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Generation failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageProvider = context.watch<app.ImageProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Free Image Genie'), centerTitle: true),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Prompt Input
                PromptInput(
                  controller: _promptController,
                  enabled: !imageProvider.isGenerating,
                ),
                const SizedBox(height: 16),

                // Style Selector
                StyleSelector(
                  selectedStyle: _selectedStyle,
                  onStyleChanged: (style) {
                    setState(() {
                      _selectedStyle = style;
                    });
                    AppLogger.info('Style changed to: $style');
                  },
                  enabled: !imageProvider.isGenerating,
                ),
                const SizedBox(height: 24),

                // Generate Button
                ElevatedButton(
                  onPressed: imageProvider.isGenerating ? null : _generateImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.auto_awesome_rounded),
                      const SizedBox(width: 8),
                      Text(
                        imageProvider.isGenerating
                            ? 'Generating...'
                            : 'Generate Image',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Generated Image Display
                if (imageProvider.currentImageBytes != null ||
                    imageProvider.currentImageUrl != null)
                  GeneratedImageDisplay(
                    imageBytes: imageProvider.currentImageBytes,
                    imageUrl: imageProvider.currentImageUrl,
                    prompt: _promptController.text.trim(),
                    style: _selectedStyle,
                  ),
              ],
            ),
          ),

          // Loading Overlay
          if (imageProvider.isGenerating)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: theme.colorScheme.primary,
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Creating your masterpiece...',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
