import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/logger.dart';

class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  String _userEmail = '';
  String _userName = '';
  String _userPhotoUrl = '';
  String _userId = '';
  GoogleSignInAccount? _currentUser;
  User? _firebaseUser;
  final bool _isAuthorized = false;
  String _errorMessage = '';

  // Google Sign-In instance
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  // Firebase Auth instance
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  // Getters
  bool get isAuthenticated => _isAuthenticated;
  String get userEmail => _userEmail;
  String get userName => _userName;
  String get userPhotoUrl => _userPhotoUrl;
  String get userId => _userId;
  GoogleSignInAccount? get currentUser => _currentUser;
  User? get firebaseUser => _firebaseUser;
  bool get isAuthorized => _isAuthorized;
  String get errorMessage => _errorMessage;

  AuthProvider() {
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    await _initializeGoogleSignIn();
    await _initializeFirebaseAuth();
  }

  Future<void> _initializeFirebaseAuth() async {
    try {
      // Listen to Firebase Auth state changes
      _firebaseAuth.authStateChanges().listen(_handleFirebaseAuthStateChange);

      // Check if user is already signed in
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        await _handleFirebaseAuthStateChange(user);
      }
    } catch (e) {
      AppLogger.error('Firebase Auth initialization error: $e');
      _errorMessage = 'Failed to initialize Firebase Auth';
      notifyListeners();
    }
  }

  Future<void> _handleFirebaseAuthStateChange(User? user) async {
    _firebaseUser = user;

    if (user != null) {
      _isAuthenticated = true;
      _userId = user.uid;
      _userEmail = user.email ?? '';
      _userName = user.displayName ?? '';
      _userPhotoUrl = user.photoURL ?? '';
      AppLogger.info('Firebase user authenticated: ${user.email}');
    } else {
      _isAuthenticated = false;
      _userId = '';
      _userEmail = '';
      _userName = '';
      _userPhotoUrl = '';
      AppLogger.info('Firebase user signed out');
    }

    notifyListeners();
  }

  Future<void> _initializeGoogleSignIn() async {
    try {
      // Initialize Google Sign-In
      await _googleSignIn.initialize();

      // Listen to authentication events
      _googleSignIn.authenticationEvents.listen(_handleAuthenticationEvent);

      // Attempt lightweight authentication on app start
      await _googleSignIn.attemptLightweightAuthentication();
    } catch (e) {
      AppLogger.error('Google Sign-In initialization error: $e');
      _errorMessage = 'Failed to initialize Google Sign-In';
      notifyListeners();
    }
  }

  Future<void> _handleAuthenticationEvent(
    GoogleSignInAuthenticationEvent event,
  ) async {
    final GoogleSignInAccount? user = switch (event) {
      GoogleSignInAuthenticationEventSignIn() => event.user,
      GoogleSignInAuthenticationEventSignOut() => null,
    };

    setState(() {
      _currentUser = user;
      _isAuthenticated = user != null;
      _errorMessage = '';
    });

    if (user != null) {
      _userEmail = user.email;
      _userName = user.displayName ?? '';
      _userPhotoUrl = user.photoUrl ?? '';
      AppLogger.info('User signed in: ${user.email}');
    } else {
      _userEmail = '';
      _userName = '';
      _userPhotoUrl = '';
      AppLogger.info('User signed out');
    }

    notifyListeners();
  }

  void setState(VoidCallback fn) {
    fn();
    notifyListeners();
  }

  Future<void> signInWithGoogle() async {
    try {
      AppLogger.info('Attempting Google sign in with Firebase');
      _errorMessage = '';
      notifyListeners();

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn
          .authenticate();

      if (googleUser == null) {
        AppLogger.info('Sign in cancelled by user');
        return;
      }

      // Try to get the authentication token
      try {
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        // Try to create Firebase credential with available tokens
        AuthCredential? credential;

        // Check what tokens are available and create credential accordingly
        if (googleAuth.idToken != null) {
          credential = GoogleAuthProvider.credential(
            idToken: googleAuth.idToken,
          );
        }

        if (credential != null) {
          // Sign in to Firebase with the Google credential
          final UserCredential userCredential = await _firebaseAuth
              .signInWithCredential(credential);
          AppLogger.info(
            'Firebase sign in successful: ${userCredential.user?.email}',
          );
        } else {
          // Fallback: create anonymous user and update profile
          final UserCredential userCredential = await _firebaseAuth
              .signInAnonymously();
          await userCredential.user?.updateDisplayName(googleUser.displayName);
          await userCredential.user?.updatePhotoURL(googleUser.photoUrl);
          AppLogger.info(
            'Firebase anonymous sign in with Google profile: ${googleUser.email}',
          );
        }
      } catch (authError) {
        AppLogger.error('Firebase auth error: $authError');
        // Fallback to anonymous sign in with Google profile data
        final UserCredential userCredential = await _firebaseAuth
            .signInAnonymously();
        await userCredential.user?.updateDisplayName(googleUser.displayName);
        await userCredential.user?.updatePhotoURL(googleUser.photoUrl);
        AppLogger.info(
          'Firebase fallback sign in with Google profile: ${googleUser.email}',
        );
      }

      _currentUser = googleUser;

      // The Firebase auth state change listener will handle updating the UI state
    } catch (e) {
      AppLogger.error('Sign in error: $e');
      _errorMessage = _getErrorMessage(e);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signUpWithGoogle() async {
    // Sign up is the same as sign in for Google OAuth
    return signInWithGoogle();
  }

  Future<void> logout() async {
    try {
      AppLogger.info('Logging out');

      // Sign out from Firebase Auth
      await _firebaseAuth.signOut();

      // Sign out from Google Sign-In
      await _googleSignIn.disconnect();

      // Clear local state
      _isAuthenticated = false;
      _userEmail = '';
      _userName = '';
      _userPhotoUrl = '';
      _userId = '';
      _currentUser = null;
      _firebaseUser = null;
      _errorMessage = '';

      notifyListeners();
    } catch (e) {
      AppLogger.error('Logout error: $e');
      _errorMessage = 'Failed to logout';
      notifyListeners();
    }
  }

  String _getErrorMessage(dynamic error) {
    if (error is GoogleSignInException) {
      return switch (error.code) {
        GoogleSignInExceptionCode.canceled => 'Sign in canceled',
        _ => 'Google Sign-In error: ${error.description}',
      };
    }
    return 'An unexpected error occurred: $error';
  }
}
