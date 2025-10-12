import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import '../utils/logger.dart';
import '../providers/auth_provider.dart';

class ApiService {
  // Backend API configuration - Multiple workers for load balancing
  static const String _baseIp = 'http://192.168.1.2';
  static const List<int> _workerPorts = [5001, 5002, 5003];
  static final Random _random = Random();

  /// Get a random worker URL for load balancing
  static String get _baseUrl {
    final randomPort = _workerPorts[_random.nextInt(_workerPorts.length)];
    return '$_baseIp:$randomPort';
  }

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

  /// Refresh access token if expired
  static Future<bool> _refreshTokenIfNeeded(BuildContext context) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final refreshed = await authProvider.refreshAccessToken();

      if (refreshed) {
        AppLogger.info('Access token refreshed successfully');
        return true;
      } else {
        AppLogger.error('Failed to refresh access token');
        return false;
      }
    } catch (e) {
      AppLogger.error('Error refreshing token: $e');
      return false;
    }
  }

  /// Make authenticated API call with automatic token refresh
  static Future<http.Response> _makeAuthenticatedRequest(
    BuildContext context,
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final baseUrl = _baseUrl; // Get random worker URL
    final url = Uri.parse('$baseUrl$endpoint');

    // First attempt with current token
    Map<String, String> headers = await _getAuthHeaders(context);

    http.Response response;
    if (method.toUpperCase() == 'GET') {
      response = await http.get(url, headers: headers);
    } else {
      response = await http.post(
        url,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );
    }

    // If 401 (unauthorized), try to refresh token and retry once
    if (response.statusCode == 401) {
      AppLogger.info('Received 401, attempting token refresh...');

      final refreshed = await _refreshTokenIfNeeded(context);
      if (refreshed) {
        // Retry with new token
        headers = await _getAuthHeaders(context);
        if (method.toUpperCase() == 'GET') {
          response = await http.get(url, headers: headers);
        } else {
          response = await http.post(
            url,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
        }
        AppLogger.info(
          'Retried request after token refresh: ${response.statusCode}',
        );
      }
    }

    return response;
  }

  /// Generate an image using the backend API
  static Future<Map<String, dynamic>?> generateImage({
    required BuildContext context,
    required String prompt,
    required String style,
  }) async {
    try {
      final requestBody = {'prompt': prompt, 'style': style};

      AppLogger.info('Calling API: /api/generate with body: $requestBody');

      final response = await _makeAuthenticatedRequest(
        context,
        'POST',
        '/api/generate',
        body: requestBody,
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
      final baseUrl = _baseUrl; // Get random worker URL
      final url = Uri.parse('$baseUrl/api/health');
      AppLogger.info('Health check using worker: $baseUrl');
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
      final baseUrl = _baseUrl; // Get random worker URL
      final url = Uri.parse('$baseUrl/api/styles');
      AppLogger.info('Getting styles from worker: $baseUrl');
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
      AppLogger.info('Getting user tokens');
      final response = await _makeAuthenticatedRequest(
        context,
        'GET',
        '/api/user/tokens',
      );

      AppLogger.info('Get tokens API Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        AppLogger.info('User tokens retrieved: ${data['tokenCount']}');
        return data['tokenCount'];
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
      AppLogger.info('Getting user profile');
      final response = await _makeAuthenticatedRequest(
        context,
        'GET',
        '/api/user/profile',
      );

      AppLogger.info('Get profile API Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        AppLogger.info('User profile retrieved');
        return data['profile'];
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
      final requestBody = {'tokens': tokens};
      print('DEBUG: ApiService.addTokensToUser - Tokens: $tokens');
      print('DEBUG: ApiService.addTokensToUser - Request body: $requestBody');

      final response = await _makeAuthenticatedRequest(
        context,
        'POST',
        '/api/user/tokens/add',
        body: requestBody,
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
