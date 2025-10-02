import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import '../../models/generated_image.dart';
import '../../utils/logger.dart';

class GalleryItem extends StatelessWidget {
  final GeneratedImage image;

  const GalleryItem({super.key, required this.image});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        AppLogger.info('Gallery item tapped: ${image.id}');
        _showImageDetails(context);
      },
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: _buildImage(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    image.prompt,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.palette_rounded,
                        size: 12,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        image.style,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImageDetails(BuildContext context) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Image
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _buildImage(fit: BoxFit.contain),
                ),
              ),
            ),

            // Details
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prompt',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(image.prompt, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.palette_rounded,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        image.style,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatDate(image.timestamp),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _saveImageToGallery(context);
                          },
                          icon: const Icon(Icons.download_rounded),
                          label: const Text('Save'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            AppLogger.info('Share from details');
                            _shareImageWithCaption();
                          },
                          icon: const Icon(Icons.share_rounded),
                          label: const Text('Share'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _saveImageToGallery(BuildContext context) async {
    try {
      AppLogger.info('Save from details');

      if (image.imageBytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No image data available to save'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Check if Gal is available (for modern Android/iOS)
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final granted = await Gal.requestAccess();
        if (!granted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Gallery access permission is required to save images',
              ),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
      }

      // Save image to temporary file first
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/free_image_genie_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(image.imageBytes!);

      // Save to gallery using Gal
      await Gal.putImage(file.path);

      // Clean up temporary file
      await file.delete();

      AppLogger.info('Image saved successfully to gallery');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Image saved to gallery successfully! 🎉'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      AppLogger.error('Error saving image to gallery: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _shareImageWithCaption() async {
    try {
      String caption =
          'Check out this amazing image I generated with Free Image Genie! 🎨✨';

      if (image.prompt.isNotEmpty) {
        caption += '\n\nPrompt: "${image.prompt}"';
      }

      if (image.style.isNotEmpty) {
        caption += '\nStyle: ${image.style}';
      }

      caption += '\n\n#FreeImageGenie #AIArt #Generated';

      if (image.imageBytes != null) {
        // Save image bytes to temporary file and share with caption
        final tempDir = await getTemporaryDirectory();
        final file = await File(
          '${tempDir.path}/shared_image_${DateTime.now().millisecondsSinceEpoch}.png',
        ).create();
        await file.writeAsBytes(image.imageBytes!);

        await Share.shareXFiles([XFile(file.path)], text: caption);
      } else if (image.imageUrl.isNotEmpty) {
        // Share URL with caption
        await Share.share('$caption\n\nImage: ${image.imageUrl}');
      } else {
        // Share just the caption
        await Share.share(caption);
      }
    } catch (e) {
      AppLogger.error('Error sharing image: $e');
      // Fallback to text-only sharing
      String fallbackCaption =
          'Check out this amazing image I generated with Free Image Genie! 🎨✨';
      if (image.prompt.isNotEmpty) {
        fallbackCaption += '\n\nPrompt: "${image.prompt}"';
      }
      await Share.share(fallbackCaption);
    }
  }

  Widget _buildImage({BoxFit fit = BoxFit.cover}) {
    if (image.imageBytes != null) {
      // Display image from bytes
      return Image.memory(
        image.imageBytes!,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[300],
            child: const Center(child: Icon(Icons.error_outline, size: 48)),
          );
        },
      );
    } else if (image.imageUrl.isNotEmpty) {
      // Display image from URL
      return Image.network(
        image.imageUrl,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[300],
            child: const Center(child: Icon(Icons.error_outline, size: 48)),
          );
        },
      );
    } else {
      // Fallback
      return Container(
        color: Colors.grey[300],
        child: const Center(child: Icon(Icons.image_not_supported, size: 48)),
      );
    }
  }
}
