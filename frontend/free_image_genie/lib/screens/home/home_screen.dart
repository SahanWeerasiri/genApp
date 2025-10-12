import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/image_provider.dart' as app;
import '../../providers/auth_provider.dart';
import '../../widgets/home/prompt_input.dart';
import '../../widgets/home/style_selector.dart';
import '../../widgets/home/generated_image_display.dart';
import '../../widgets/rewarded_ad_button.dart';
import '../../services/api_service.dart';
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

  Future<void> _onAdRewardEarned() async {
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

  Future<void> _generateImage() async {
    if (_promptController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a prompt')));
      return;
    }

    AppLogger.info('Generate button pressed');

    final authProvider = context.read<AuthProvider>();

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
    if (authProvider.tokenCount <= 0) {
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
      // Generate image with authentication token
      await context.read<app.ImageProvider>().generateImage(
        context,
        _promptController.text.trim(),
        _selectedStyle,
      );

      // Token consumption is now handled automatically by the backend
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
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              authProvider.userEmail,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            Row(
              children: [
                const Icon(Icons.stars_rounded, size: 16, color: Colors.amber),
                const SizedBox(width: 4),
                Text(
                  '${authProvider.tokenCount} tokens',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: RewardedAdButton(
              onRewardEarned: _onAdRewardEarned,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.play_circle_filled,
                      color: Colors.white,
                      size: 16,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Watch Ad',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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
