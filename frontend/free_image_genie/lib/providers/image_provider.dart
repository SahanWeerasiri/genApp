import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import '../services/api_service.dart';
import '../utils/logger.dart';

class ImageProvider extends ChangeNotifier {
  String? _currentImageUrl;
  Uint8List? _currentImageBytes;
  bool _isGenerating = false;
  int _tokens = 100;

  String? get currentImageUrl => _currentImageUrl;
  Uint8List? get currentImageBytes => _currentImageBytes;
  bool get isGenerating => _isGenerating;
  int get tokens => _tokens;

  Future<void> generateImage(
    BuildContext context,
    String prompt,
    String style,
  ) async {
    try {
      AppLogger.info('Generating image with prompt: $prompt, style: $style');
      _isGenerating = true;
      notifyListeners();

      // Call the backend API using ApiService
      final response = await ApiService.generateImage(
        context: context,
        prompt: prompt,
        style: style,
      );

      if (response != null) {
        // Decode the base64 image
        final imageBytes = base64Decode(response['image']);

        // Store the current image bytes
        _currentImageBytes = imageBytes;
        _currentImageUrl = null; // Clear URL since we're using bytes

        // Note: Token reduction is now handled by the backend and AuthProvider
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
