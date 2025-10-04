import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/firestore_service.dart';
import '../services/api_service.dart';
import '../utils/logger.dart';

class UserProfileProvider extends ChangeNotifier {
  UserProfile? _userProfile;
  bool _isLoading = false;
  String _errorMessage = '';

  UserProfile? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  int get tokenCount => _userProfile?.tokenCount ?? 0;

  /// Create a new user profile during signup
  Future<bool> createUserProfile({
    required String uid,
    required String email,
    required String name,
    String photoUrl = '',
  }) async {
    try {
      _setLoading(true);
      AppLogger.info('Creating user profile for: $email');

      final profile = UserProfile(
        uid: uid,
        email: email,
        name: name,
        photoUrl: photoUrl,
        tokenCount: 5, // Initial token count
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final success = await FirestoreService.createUserProfile(profile);
      if (success) {
        _userProfile = profile;
        _errorMessage = '';
        AppLogger.info('User profile created successfully');
      } else {
        _errorMessage = 'Failed to create user profile';
        AppLogger.error(_errorMessage);
      }

      _setLoading(false);
      return success;
    } catch (e) {
      _errorMessage = 'Error creating user profile: $e';
      AppLogger.error(_errorMessage);
      _setLoading(false);
      return false;
    }
  }

  /// Load user profile from Firestore
  Future<bool> loadUserProfile(String uid) async {
    try {
      _setLoading(true);
      AppLogger.info('Loading user profile for UID: $uid');

      // Try to load from backend API first, then fallback to Firestore
      Map<String, dynamic>? profileData;

      try {
        profileData = await ApiService.getUserProfile(uid);
        if (profileData != null) {
          AppLogger.info('User profile loaded from backend API');
        }
      } catch (e) {
        AppLogger.error('Backend API error: $e');
      }

      // Fallback to direct Firestore access
      if (profileData == null) {
        try {
          final profile = await FirestoreService.getUserProfile(uid);
          if (profile != null) {
            profileData = profile.toJson();
            AppLogger.info('User profile loaded from Firestore');
          }
        } catch (e) {
          AppLogger.error('Firestore error: $e');
        }
      }

      if (profileData != null) {
        _userProfile = UserProfile.fromJson(profileData);
        _errorMessage = '';
        _setLoading(false);
        return true;
      } else {
        // Create default profile if none exists
        _userProfile = UserProfile(
          uid: uid,
          email: '',
          name: '',
          photoUrl: '',
          tokenCount: 5,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        _errorMessage = '';
        AppLogger.info('Using default user profile');
        _setLoading(false);
        return true;
      }
    } catch (e) {
      _errorMessage = 'Error loading user profile: $e';
      AppLogger.error(_errorMessage);
      _setLoading(false);
      return false;
    }
  }

  /// Update user profile
  Future<bool> updateUserProfile(UserProfile updatedProfile) async {
    try {
      _setLoading(true);
      AppLogger.info('Updating user profile for UID: ${updatedProfile.uid}');

      final profileToUpdate = updatedProfile.copyWith(
        updatedAt: DateTime.now(),
      );

      final success = await FirestoreService.updateUserProfile(profileToUpdate);
      if (success) {
        _userProfile = profileToUpdate;
        _errorMessage = '';
        AppLogger.info('User profile updated successfully');
      } else {
        _errorMessage = 'Failed to update user profile';
        AppLogger.error(_errorMessage);
      }

      _setLoading(false);
      return success;
    } catch (e) {
      _errorMessage = 'Error updating user profile: $e';
      AppLogger.error(_errorMessage);
      _setLoading(false);
      return false;
    }
  }

  /// Check if user has enough tokens for image generation
  Future<bool> checkTokenAvailability() async {
    if (_userProfile == null) return false;

    try {
      // Try to get latest token count from backend
      final latestTokenCount = await ApiService.getUserTokens(
        _userProfile!.uid,
      );
      if (latestTokenCount != null) {
        // Update local profile with latest token count
        _userProfile = _userProfile!.copyWith(
          tokenCount: latestTokenCount,
          updatedAt: DateTime.now(),
        );
        notifyListeners();
        return latestTokenCount > 0;
      }

      // Fallback to Firestore
      final hasTokens = await FirestoreService.checkTokenAvailability(
        _userProfile!.uid,
      );

      // Refresh profile to get latest token count
      if (hasTokens) {
        await loadUserProfile(_userProfile!.uid);
      }

      return hasTokens;
    } catch (e) {
      AppLogger.error('Error checking token availability: $e');
      // Return local token count as fallback
      return _userProfile!.tokenCount > 0;
    }
  }

  /// Consume a token for image generation
  Future<bool> consumeToken() async {
    if (_userProfile == null) return false;

    try {
      AppLogger.info('Consuming token for user: ${_userProfile!.uid}');

      // Note: Token consumption is now handled by the backend API
      // We just need to update the local profile to reflect the change
      if (_userProfile!.tokenCount > 0) {
        _userProfile = _userProfile!.copyWith(
          tokenCount: _userProfile!.tokenCount - 1,
          updatedAt: DateTime.now(),
        );
        notifyListeners();
        AppLogger.info(
          'Token consumed locally. Remaining: ${_userProfile!.tokenCount}',
        );
        return true;
      }

      return false;
    } catch (e) {
      AppLogger.error('Error consuming token: $e');
      return false;
    }
  }

  /// Add tokens (for watching ads, purchases, etc.)
  Future<bool> addTokens(int tokensToAdd) async {
    print('DEBUG: addTokens called with $tokensToAdd tokens');

    if (_userProfile == null) {
      print('DEBUG: No user profile found');
      return false;
    }

    try {
      AppLogger.info(
        'Adding $tokensToAdd tokens for user: ${_userProfile!.uid}',
      );
      print('DEBUG: Calling ApiService.addTokensToUser...');

      // Try to add tokens via backend API
      final success = await ApiService.addTokensToUser(
        _userProfile!.uid,
        tokensToAdd,
      );

      print('DEBUG: ApiService.addTokensToUser returned: $success');

      if (success) {
        // Update local profile
        _userProfile = _userProfile!.copyWith(
          tokenCount: _userProfile!.tokenCount + tokensToAdd,
          updatedAt: DateTime.now(),
        );
        notifyListeners();
        AppLogger.info(
          'Tokens added via API. New total: ${_userProfile!.tokenCount}',
        );
        print(
          'DEBUG: Tokens added successfully via API. New total: ${_userProfile!.tokenCount}',
        );
        return true;
      }

      print('DEBUG: API failed, trying Firestore fallback...');
      // Fallback to Firestore
      final firestoreSuccess = await FirestoreService.addTokens(
        _userProfile!.uid,
        tokensToAdd,
      );

      print('DEBUG: Firestore addTokens returned: $firestoreSuccess');

      if (firestoreSuccess) {
        // Update local profile
        _userProfile = _userProfile!.copyWith(
          tokenCount: _userProfile!.tokenCount + tokensToAdd,
          updatedAt: DateTime.now(),
        );
        notifyListeners();
        AppLogger.info(
          'Tokens added via Firestore. New total: ${_userProfile!.tokenCount}',
        );
        print(
          'DEBUG: Tokens added successfully via Firestore. New total: ${_userProfile!.tokenCount}',
        );
        return true;
      }

      print('DEBUG: Both API and Firestore failed');
      return false;
    } catch (e) {
      AppLogger.error('Error adding tokens: $e');
      print('DEBUG: Exception in addTokens: $e');
      return false;
    }
  }

  /// Refresh user profile from Firestore
  Future<void> refreshProfile() async {
    if (_userProfile != null) {
      await loadUserProfile(_userProfile!.uid);
    }
  }

  /// Clear user profile (on logout)
  void clearProfile() {
    _userProfile = null;
    _errorMessage = '';
    notifyListeners();
    AppLogger.info('User profile cleared');
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
