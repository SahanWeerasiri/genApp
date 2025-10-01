import 'package:flutter/material.dart';
import '../models/generated_image.dart';
import '../utils/logger.dart';

class ImageProvider extends ChangeNotifier {
  List<GeneratedImage> _gallery = [];
  String? _currentImageUrl;
  bool _isGenerating = false;
  int _tokens = 100;

  List<GeneratedImage> get gallery => _gallery;
  String? get currentImageUrl => _currentImageUrl;
  bool get isGenerating => _isGenerating;
  int get tokens => _tokens;

  Future<void> generateImage(String prompt, String style) async {
    try {
      AppLogger.info('Generating image with prompt: $prompt, style: $style');
      _isGenerating = true;
      notifyListeners();

      // Simulate API call to Python backend
      await Future.delayed(const Duration(seconds: 3));

      // Mock generated image
      final generatedImage = GeneratedImage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        imageUrl: 'https://picsum.photos/512/512?random=${DateTime.now().millisecondsSinceEpoch}',
        prompt: prompt,
        style: style,
        timestamp: DateTime.now(),
      );

      _currentImageUrl = generatedImage.imageUrl;
      _gallery.insert(0, generatedImage);
      _tokens -= 1;

      AppLogger.info('Image generated successfully');
      _isGenerating = false;
      notifyListeners();
    } catch (e) {
      AppLogger.error('Error generating image: $e');
      _isGenerating = false;
      notifyListeners();
      rethrow;
    }
  }

  void saveToGallery(GeneratedImage image) {
    AppLogger.info('Saving image to gallery: ${image.id}');
    // Implementation for saving to device gallery
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
