import 'package:flutter/material.dart';
import '../utils/logger.dart';

class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  String _userEmail = '';

  bool get isAuthenticated => _isAuthenticated;
  String get userEmail => _userEmail;

  Future<void> signInWithGoogle() async {
    try {
      AppLogger.info('Attempting Google sign in');
      // Python backend handles actual authentication
      // This is just UI state management
      await Future.delayed(const Duration(seconds: 2));
      _isAuthenticated = true;
      _userEmail = 'user@example.com'; // Will be set by backend
      AppLogger.info('Sign in successful');
      notifyListeners();
    } catch (e) {
      AppLogger.error('Sign in error: $e');
      rethrow;
    }
  }

  Future<void> signUpWithGoogle() async {
    try {
      AppLogger.info('Attempting Google sign up');
      // Python backend handles actual authentication
      await Future.delayed(const Duration(seconds: 2));
      _isAuthenticated = true;
      _userEmail = 'user@example.com'; // Will be set by backend
      AppLogger.info('Sign up successful');
      notifyListeners();
    } catch (e) {
      AppLogger.error('Sign up error: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      AppLogger.info('Logging out');
      _isAuthenticated = false;
      _userEmail = '';
      notifyListeners();
    } catch (e) {
      AppLogger.error('Logout error: $e');
    }
  }
}
