import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../utils/logger.dart';

class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String _userEmail = '';
  String _userName = '';
  String _userPhotoUrl = '';
  String _userId = '';
  int _tokenCount = 0;
  String _errorMessage = '';

  // Secure storage for access token
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const String _tokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';

  // Google Sign-In instance
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  // Firebase Auth instance
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  // Backend API configuration - Multiple workers for load balancing
  static const String _baseIp = 'http://192.168.1.2';
  static const List<int> _workerPorts = [5001, 5002, 5003];
  static final Random _random = Random();

  /// Get a random worker URL for load balancing
  static String get _baseUrl {
    final randomPort = _workerPorts[_random.nextInt(_workerPorts.length)];
    return '$_baseIp:$randomPort';
  }

  // Getters
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String get userEmail => _userEmail;
  String get userName => _userName;
  String get userPhotoUrl => _userPhotoUrl;
  String get userId => _userId;
  int get tokenCount => _tokenCount;
  String get errorMessage => _errorMessage;

  AuthProvider() {
    _initializeGoogleSignIn();
    _initializeAuth();
  }

  // Initialize GoogleSignIn with serverClientId
  Future<void> _initializeGoogleSignIn() async {
    try {
      await _googleSignIn.initialize(
        serverClientId:
            '55625441561-ru9e5qejc9lhs7kifti53f8d58ktr5ur.apps.googleusercontent.com',
      );
      AppLogger.info('GoogleSignIn initialized with serverClientId');
    } catch (e) {
      AppLogger.error('Failed to initialize GoogleSignIn: $e');
    }
  }

  Future<void> _initializeAuth() async {
    _setLoading(true);
    try {
      // Check if we have a stored access token
      final storedToken = await _secureStorage.read(key: _tokenKey);

      if (storedToken != null) {
        AppLogger.info('Found stored access token, verifying...');
        final isValid = await _verifyToken(storedToken);

        if (isValid) {
          AppLogger.info('Stored token is valid, user authenticated');
          _setLoading(false);
          return;
        } else {
          AppLogger.info('Stored token is invalid, attempting refresh...');
          final refreshSuccess = await refreshAccessToken();
          if (refreshSuccess) {
            AppLogger.info('Token refreshed successfully');
            _setLoading(false);
            return;
          } else {
            AppLogger.info('Token refresh failed, clearing stored tokens');
            await _clearStoredTokens();
          }
        }
      }

      AppLogger.info('No valid stored token found, user needs to sign in');
      _setLoading(false);
    } catch (e) {
      AppLogger.error('Auth initialization error: $e');
      _errorMessage = 'Failed to initialize authentication';
      _setLoading(false);
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  Future<bool> _verifyToken(String token) async {
    try {
      final baseUrl = _baseUrl; // Get random worker URL
      final url = Uri.parse('$baseUrl/api/verify');
      AppLogger.info('Verifying token with worker: $baseUrl');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'access_token': token}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final user = data['user'];

        _isAuthenticated = true;
        _userId = user['uid'];
        _userEmail = user['email'] ?? '';
        _userName = user['name'] ?? '';
        _userPhotoUrl = user['photoUrl'] ?? '';
        _tokenCount = user['tokenCount'] ?? 0;
        _errorMessage = '';

        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.error('Token verification error: $e');
      return false;
    }
  }

  Future<bool> refreshAccessToken() async {
    try {
      final refreshToken = await _secureStorage.read(key: _refreshTokenKey);
      if (refreshToken == null) return false;

      final baseUrl = _baseUrl; // Get random worker URL
      final url = Uri.parse('$baseUrl/api/refresh');
      AppLogger.info('Refreshing token with worker: $baseUrl');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newAccessToken = data['access_token'];

        await _secureStorage.write(key: _tokenKey, value: newAccessToken);
        return await _verifyToken(newAccessToken);
      }
      return false;
    } catch (e) {
      AppLogger.error('Token refresh error: $e');
      return false;
    }
  }

  Future<void> _clearStoredTokens() async {
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
  }

  Future<void> signInWithGoogle() async {
    try {
      _setLoading(true);
      _errorMessage = '';

      AppLogger.info('Starting Google sign in...');

      // Sign out from any previous Firebase session
      await _firebaseAuth.signOut();
      await _googleSignIn.signOut();

      // Start Google Sign-In flow using authenticate method
      final GoogleSignInAccount? googleUser = await _googleSignIn
          .authenticate();

      if (googleUser == null) {
        AppLogger.info('Google sign in cancelled by user');
        _setLoading(false);
        return;
      }

      AppLogger.info('Google sign in successful, getting authentication...');

      // Get Google authentication
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      final UserCredential userCredential = await _firebaseAuth
          .signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user == null) {
        throw Exception('Firebase authentication failed');
      }

      AppLogger.info(
        'Firebase authentication successful, registering with backend...',
      );

      // Register/login with backend
      await _registerWithBackend(user, googleUser);
    } catch (e) {
      AppLogger.error('Sign in error: $e');
      _errorMessage = _getErrorMessage(e);
      _isAuthenticated = false;
      _setLoading(false);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _registerWithBackend(
    User firebaseUser,
    GoogleSignInAccount googleUser,
  ) async {
    try {
      final baseUrl = _baseUrl; // Get random worker URL
      final url = Uri.parse('$baseUrl/api/register');

      final requestBody = {
        'uid': firebaseUser.uid,
        'email': firebaseUser.email ?? googleUser.email,
        'name': firebaseUser.displayName ?? googleUser.displayName ?? 'User',
        'photoUrl': firebaseUser.photoURL ?? googleUser.photoUrl ?? '',
      };

      AppLogger.info('Registering with backend worker: $baseUrl');
      AppLogger.info('Registering user: ${requestBody['email']}');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final accessToken = data['access_token'];
        final refreshToken = data['refresh_token'];
        final user = data['user'];

        // Store tokens securely
        await _secureStorage.write(key: _tokenKey, value: accessToken);
        await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);

        // Update user state
        _isAuthenticated = true;
        _userId = user['uid'];
        _userEmail = user['email'] ?? '';
        _userName = user['name'] ?? '';
        _userPhotoUrl = user['photoUrl'] ?? '';
        _tokenCount = user['tokenCount'] ?? 0;
        _errorMessage = '';

        AppLogger.info('Backend registration successful, user authenticated');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception('Backend registration failed: ${errorData['message']}');
      }
    } catch (e) {
      AppLogger.error('Backend registration error: $e');
      throw Exception('Failed to register with backend: $e');
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<String?> getAccessToken() async {
    return await _secureStorage.read(key: _tokenKey);
  }

  Future<void> updateTokenCount(int newCount) async {
    _tokenCount = newCount;
    notifyListeners();
  }

  /// Refresh token count from backend
  Future<void> refreshTokenCount() async {
    try {
      final baseUrl = _baseUrl; // Get random worker URL
      final url = Uri.parse('$baseUrl/api/user/tokens');
      final accessToken = await getAccessToken();

      if (accessToken == null) {
        AppLogger.error('No access token available for token refresh');
        return;
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      };

      AppLogger.info('Refreshing token count from worker: $baseUrl');
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newTokenCount = data['tokenCount'] as int;
        _tokenCount = newTokenCount;
        notifyListeners();
        AppLogger.info('Token count refreshed: $newTokenCount');
      } else {
        AppLogger.error(
          'Failed to refresh token count: ${response.statusCode}',
        );
      }
    } catch (e) {
      AppLogger.error('Error refreshing token count: $e');
    }
  }

  String _getErrorMessage(dynamic error) {
    if (error is GoogleSignInException) {
      return switch (error.code) {
        GoogleSignInExceptionCode.canceled => 'Sign in cancelled',
        _ => 'Google Sign-In error: ${error.description}',
      };
    }
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'account-exists-with-different-credential' =>
          'Account exists with different credentials',
        'invalid-credential' => 'Invalid credentials',
        'operation-not-allowed' => 'Operation not allowed',
        'user-disabled' => 'User account has been disabled',
        'user-not-found' => 'User not found',
        'wrong-password' => 'Wrong password',
        _ => 'Authentication error: ${error.message}',
      };
    }
    return 'An unexpected error occurred: $error';
  }
}
