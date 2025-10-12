import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import '../utils/logger.dart';
import '../providers/auth_provider.dart';

class ApiService {
  // Backend API configuration
  static const String _baseUrl =
      'http://68.233.117.166:5000'; // Use your actual backend IP
  // static const String _baseUrl = 'http://10.10.18.95:5000'; // Alternative IP
  // static const String _baseUrl = 'http://localhost:5000'; // Use this for iOS simulator or web
  // static const String _baseUrl = 'http://YOUR_COMPUTER_IP:5000'; // Use this for physical device

  /// Get authorization headers with access token
  static Future<Map<String, String>> _getAuthHeaders(
    BuildContext context,
  ) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final accessToken = await authProvider.getAccessToken();

    return {
      'Content-Type': 'application/json',
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    };
  }

  /// Generate an image using the backend API
  static Future<Map<String, dynamic>?> generateImage({
    required BuildContext context,
    required String prompt,
    required String style,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/api/generate');
      final headers = await _getAuthHeaders(context);

      final requestBody = {'prompt': prompt, 'style': style};

      AppLogger.info('Calling API: $url with body: $requestBody');

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(requestBody),
      );

      AppLogger.info('API Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        AppLogger.info('API Response: Image generated successfully');
        return responseData;
      } else if (response.statusCode == 401) {
        // Token expired or invalid, try to refresh
        AppLogger.info('Access token expired, attempting refresh...');
        // The auth provider should handle token refresh automatically
        throw Exception('Authentication required');
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

  /// Get user token count from backend
  static Future<int?> getUserTokens(BuildContext context) async {
    try {
      final url = Uri.parse('$_baseUrl/api/user/tokens');
      final headers = await _getAuthHeaders(context);
      final response = await http.get(url, headers: headers);

      AppLogger.info('Get tokens API Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        AppLogger.info('User tokens retrieved: ${data['tokenCount']}');
        return data['tokenCount'];
      } else if (response.statusCode == 401) {
        AppLogger.error('Authentication required for getting tokens');
        return null;
      } else {
        AppLogger.error('Failed to get user tokens: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      AppLogger.error('Error getting user tokens: $e');
      return null;
    }
  }

  /// Get user profile from backend
  static Future<Map<String, dynamic>?> getUserProfile(
    BuildContext context,
  ) async {
    try {
      final url = Uri.parse('$_baseUrl/api/user/profile');
      final headers = await _getAuthHeaders(context);
      final response = await http.get(url, headers: headers);

      AppLogger.info('Get profile API Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        AppLogger.info('User profile retrieved');
        return data['profile'];
      } else if (response.statusCode == 401) {
        AppLogger.error('Authentication required for getting profile');
        return null;
      } else {
        AppLogger.error('Failed to get user profile: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      AppLogger.error('Error getting user profile: $e');
      return null;
    }
  }

  /// Add tokens to user account (for watching ads, etc.)
  static Future<bool> addTokensToUser(BuildContext context, int tokens) async {
    try {
      final url = Uri.parse('$_baseUrl/api/user/tokens/add');
      final headers = await _getAuthHeaders(context);

      print('DEBUG: ApiService.addTokensToUser - URL: $url');
      print('DEBUG: ApiService.addTokensToUser - Tokens: $tokens');

      final requestBody = {'tokens': tokens};
      print('DEBUG: ApiService.addTokensToUser - Request body: $requestBody');

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(requestBody),
      );

      print(
        'DEBUG: ApiService.addTokensToUser - Response status: ${response.statusCode}',
      );
      print(
        'DEBUG: ApiService.addTokensToUser - Response body: ${response.body}',
      );

      AppLogger.info('Add tokens API Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.updateTokenCount(data['tokenCount']);

        AppLogger.info('Tokens added successfully');
        print('DEBUG: ApiService.addTokensToUser - Success');
        return true;
      } else if (response.statusCode == 401) {
        AppLogger.error('Authentication required for adding tokens');
        print('DEBUG: ApiService.addTokensToUser - Authentication failed');
        return false;
      } else {
        AppLogger.error('Failed to add tokens: ${response.statusCode}');
        print(
          'DEBUG: ApiService.addTokensToUser - Failed with status: ${response.statusCode}',
        );
        return false;
      }
    } catch (e) {
      AppLogger.error('Error adding tokens: $e');
      print('DEBUG: ApiService.addTokensToUser - Exception: $e');
      return false;
    }
  }
}
