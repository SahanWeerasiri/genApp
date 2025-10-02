import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/logger.dart';

class ApiService {
  // Backend API configuration
  static const String _baseUrl =
      'http://10.10.18.95:5000'; // Android emulator localhost
  // static const String _baseUrl = 'http://localhost:5000'; // Use this for iOS simulator or web
  // static const String _baseUrl = 'http://YOUR_COMPUTER_IP:5000'; // Use this for physical device

  /// Generate an image using the backend API
  static Future<Map<String, dynamic>?> generateImage({
    required String prompt,
    required String style,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/api/generate');

      final requestBody = {'prompt': prompt, 'style': style};

      AppLogger.info('Calling API: $url with body: $requestBody');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      AppLogger.info('API Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        AppLogger.info('API Response: Image generated successfully');
        return responseData;
      } else {
        final errorData = jsonDecode(response.body);
        AppLogger.error('API Error: ${errorData['message']}');
        throw Exception('API Error: ${errorData['message']}');
      }
    } catch (e) {
      AppLogger.error('Network error calling generate API: $e');
      throw Exception('Network error: $e');
    }
  }

  /// Health check endpoint
  static Future<bool> checkHealth() async {
    try {
      final url = Uri.parse('$_baseUrl/api/health');
      final response = await http.get(url);
      return response.statusCode == 200;
    } catch (e) {
      AppLogger.error('Health check failed: $e');
      return false;
    }
  }

  /// Get available styles from backend (if implemented)
  static Future<List<String>?> getStyles() async {
    try {
      final url = Uri.parse('$_baseUrl/api/styles');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<String>.from(data['styles']);
      }
      return null;
    } catch (e) {
      AppLogger.error('Failed to get styles: $e');
      return null;
    }
  }
}
