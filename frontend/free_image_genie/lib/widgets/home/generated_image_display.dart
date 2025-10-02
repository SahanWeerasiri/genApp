import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import '../../utils/logger.dart';

class GeneratedImageDisplay extends StatelessWidget {
  final String? imageUrl;
  final Uint8List? imageBytes;
  final String? prompt;
  final String? style;

  const GeneratedImageDisplay({
    super.key,
    this.imageUrl,
    this.imageBytes,
    this.prompt,
    this.style,
  }) : assert(
         imageUrl != null || imageBytes != null,
         'Either imageUrl or imageBytes must be provided',
       );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: _buildImage(),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _saveImageToGallery(context),
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Save'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      AppLogger.info('Share pressed');
                      _shareImage();
                    },
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Share'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    if (imageBytes != null) {
      // Display image from bytes
      return Image.memory(
        imageBytes!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return AspectRatio(
            aspectRatio: 1,
            child: Container(
              color: Colors.grey[300],
              child: const Center(child: Icon(Icons.error_outline, size: 48)),
            ),
          );
        },
      );
    } else if (imageUrl != null && imageUrl!.isNotEmpty) {
      // Display image from URL
      return Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return AspectRatio(
            aspectRatio: 1,
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return AspectRatio(
            aspectRatio: 1,
            child: Container(
              color: Colors.grey[300],
              child: const Center(child: Icon(Icons.error_outline, size: 48)),
            ),
          );
        },
      );
    } else {
      // Fallback
      return AspectRatio(
        aspectRatio: 1,
        child: Container(
          color: Colors.grey[300],
          child: const Center(child: Icon(Icons.image_not_supported, size: 48)),
        ),
      );
    }
  }

  Future<void> _saveImageToGallery(BuildContext context) async {
    try {
      AppLogger.info('Save to gallery pressed');

      if (imageBytes == null) {
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
      await file.writeAsBytes(imageBytes!);

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

  Future<void> _shareImage() async {
    try {
      String caption =
          'Check out this amazing image I generated with Free Image Genie! 🎨✨';

      if (prompt != null && prompt!.isNotEmpty) {
        caption += '\n\nPrompt: "$prompt"';
      }

      if (style != null && style!.isNotEmpty) {
        caption += '\nStyle: $style';
      }

      caption += '\n\n#FreeImageGenie #AIArt #Generated';

      if (imageBytes != null) {
        // Save image bytes to temporary file and share with caption
        final tempDir = await getTemporaryDirectory();
        final file = await File(
          '${tempDir.path}/shared_image_${DateTime.now().millisecondsSinceEpoch}.png',
        ).create();
        await file.writeAsBytes(imageBytes!);

        await Share.shareXFiles([XFile(file.path)], text: caption);
      } else if (imageUrl != null && imageUrl!.isNotEmpty) {
        // Share URL with caption
        await Share.share('$caption\n\nImage: $imageUrl');
      } else {
        // Share just the caption
        await Share.share(caption);
      }
    } catch (e) {
      AppLogger.error('Error sharing image: $e');
      // Fallback to text-only sharing
      String fallbackCaption =
          'Check out this amazing image I generated with Free Image Genie! 🎨✨';
      if (prompt != null && prompt!.isNotEmpty) {
        fallbackCaption += '\n\nPrompt: "$prompt"';
      }
      await Share.share(fallbackCaption);
    }
  }
}
