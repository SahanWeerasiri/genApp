import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/generated_image.dart';
import '../services/api_service.dart';
import '../utils/logger.dart';

class ImageProvider extends ChangeNotifier {
  List<GeneratedImage> _gallery = [];
  String? _currentImageUrl;
  Uint8List? _currentImageBytes;
  bool _isGenerating = false;
  int _tokens = 100;

  List<GeneratedImage> get gallery => _gallery;
  String? get currentImageUrl => _currentImageUrl;
  Uint8List? get currentImageBytes => _currentImageBytes;
  bool get isGenerating => _isGenerating;
  int get tokens => _tokens;

  Future<void> loadGalleryFromDevice() async {
    try {
      AppLogger.info('Loading images from device gallery...');

      // Request permission to access photos
      final PermissionState permission =
          await PhotoManager.requestPermissionExtend();
      if (!permission.isAuth) {
        AppLogger.error('Photo permission denied');
        return;
      }

      // Get all albums
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
      );

      if (albums.isEmpty) {
        AppLogger.info('No albums found');
        return;
      }

      // Get images from the main album (Camera Roll / All Photos)
      final AssetPathEntity album = albums.first;
      final List<AssetEntity> assets = await album.getAssetListRange(
        start: 0,
        end: 100, // Load last 100 images
      );

      // Filter for images that might be from our app (by checking file name patterns)
      final List<GeneratedImage> loadedImages = [];

      for (final AssetEntity asset in assets) {
        try {
          // Check if this is likely an image from our app
          if (asset.title?.contains('free_image_genie') == true ||
              asset.title?.contains('FreeImageGenie') == true) {
            // Get image bytes
            final Uint8List? bytes = await asset.originBytes;
            if (bytes != null) {
              // Create a GeneratedImage object
              final generatedImage = GeneratedImage(
                id: asset.id,
                imageUrl: '',
                prompt: 'Loaded from gallery',
                style: 'Unknown',
                timestamp: asset.createDateTime,
                imageBytes: bytes,
              );

              loadedImages.add(generatedImage);
              AppLogger.info('Loaded image from gallery: ${asset.title}');
            }
          }
        } catch (e) {
          AppLogger.error('Error loading image ${asset.id}: $e');
        }
      }

      // Add loaded images to gallery (avoid duplicates)
      for (final image in loadedImages) {
        if (!_gallery.any((existing) => existing.id == image.id)) {
          _gallery.add(image);
        }
      }

      // Sort gallery by timestamp (newest first)
      _gallery.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      AppLogger.info(
        'Loaded ${loadedImages.length} images from device gallery',
      );
      notifyListeners();
    } catch (e) {
      AppLogger.error('Error loading gallery from device: $e');
    }
  }

  Future<void> generateImage(String prompt, String style) async {
    try {
      AppLogger.info('Generating image with prompt: $prompt, style: $style');
      _isGenerating = true;
      notifyListeners();

      // Call the backend API using ApiService
      final response = await ApiService.generateImage(
        prompt: prompt,
        style: style,
      );

      if (response != null) {
        // Decode the base64 image
        final imageBytes = base64Decode(response['image']);

        // Create a GeneratedImage object
        final generatedImage = GeneratedImage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          imageUrl: '', // We don't have a URL, we have bytes
          prompt: prompt,
          style: style,
          timestamp: DateTime.now(),
          imageBytes: imageBytes, // Pass the image bytes
        );

        // Store the image bytes and add to gallery
        _currentImageBytes = imageBytes;
        _currentImageUrl = null; // Clear URL since we're using bytes
        _gallery.insert(0, generatedImage);
        _tokens -= 1;

        AppLogger.info('Image generated successfully');
      } else {
        throw Exception('Failed to generate image');
      }

      _isGenerating = false;
      notifyListeners();
    } catch (e) {
      AppLogger.error('Error generating image: $e');
      _isGenerating = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> saveToGallery(GeneratedImage image) async {
    try {
      AppLogger.info('Saving image to gallery: ${image.id}');

      if (image.imageBytes == null) {
        AppLogger.error('No image bytes available to save');
        return false;
      }

      // Check if Gal is available (for modern Android/iOS)
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final granted = await Gal.requestAccess();
        if (!granted) {
          AppLogger.error('Gallery access permission denied');
          return false;
        }
      }

      // Save image to temporary file first
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/free_image_genie_${image.id}.png');
      await file.writeAsBytes(image.imageBytes!);

      // Save to gallery using Gal
      await Gal.putImage(file.path);

      // Clean up temporary file
      await file.delete();

      AppLogger.info('Image saved successfully to gallery');
      return true;
    } catch (e) {
      AppLogger.error('Error saving image to gallery: $e');
      return false;
    }
  }

  Future<bool> saveCurrentImageToGallery() async {
    if (_currentImageBytes == null) {
      AppLogger.error('No current image to save');
      return false;
    }

    try {
      // Check if Gal is available (for modern Android/iOS)
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final granted = await Gal.requestAccess();
        if (!granted) {
          AppLogger.error('Gallery access permission denied');
          return false;
        }
      }

      // Save image to temporary file first
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/free_image_genie_current_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(_currentImageBytes!);

      // Save to gallery using Gal
      await Gal.putImage(file.path);

      // Clean up temporary file
      await file.delete();

      AppLogger.info('Current image saved successfully to gallery');
      return true;
    } catch (e) {
      AppLogger.error('Error saving current image to gallery: $e');
      return false;
    }
  }

  Future<void> watchAdForTokens() async {
    try {
      AppLogger.info('Watching ad for tokens');
      await Future.delayed(const Duration(seconds: 2));
      _tokens += 10;
      AppLogger.info('Tokens added. New balance: $_tokens');
      notifyListeners();
    } catch (e) {
      AppLogger.error('Error watching ad: $e');
    }
  }
}
