import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';
import '../utils/logger.dart';

class FirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _usersCollection = 'users';

  /// Create a new user profile in Firestore
  static Future<bool> createUserProfile(UserProfile profile) async {
    try {
      AppLogger.info('Creating user profile for UID: ${profile.uid}');

      await _firestore
          .collection(_usersCollection)
          .doc(profile.uid)
          .set(profile.toJson());

      AppLogger.info('User profile created successfully');
      return true;
    } catch (e) {
      AppLogger.error('Error creating user profile: $e');
      return false;
    }
  }

  /// Get user profile from Firestore
  static Future<UserProfile?> getUserProfile(String uid) async {
    try {
      AppLogger.info('Fetching user profile for UID: $uid');

      final doc = await _firestore.collection(_usersCollection).doc(uid).get();

      if (doc.exists && doc.data() != null) {
        final profile = UserProfile.fromJson(doc.data()!);
        AppLogger.info('User profile fetched successfully');
        return profile;
      } else {
        AppLogger.info('User profile not found');
        return null;
      }
    } catch (e) {
      AppLogger.error('Error fetching user profile: $e');
      return null;
    }
  }

  /// Update user profile in Firestore
  static Future<bool> updateUserProfile(UserProfile profile) async {
    try {
      AppLogger.info('Updating user profile for UID: ${profile.uid}');

      await _firestore
          .collection(_usersCollection)
          .doc(profile.uid)
          .update(profile.toJson());

      AppLogger.info('User profile updated successfully');
      return true;
    } catch (e) {
      AppLogger.error('Error updating user profile: $e');
      return false;
    }
  }

  /// Update only token count for efficiency
  static Future<bool> updateTokenCount(String uid, int newTokenCount) async {
    try {
      AppLogger.info('Updating token count for UID: $uid to $newTokenCount');

      await _firestore.collection(_usersCollection).doc(uid).update({
        'tokenCount': newTokenCount,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      AppLogger.info('Token count updated successfully');
      return true;
    } catch (e) {
      AppLogger.error('Error updating token count: $e');
      return false;
    }
  }

  /// Check if user has enough tokens
  static Future<bool> checkTokenAvailability(String uid) async {
    try {
      AppLogger.info('Checking token availability for UID: $uid');

      final profile = await getUserProfile(uid);
      if (profile != null) {
        final hasTokens = profile.tokenCount > 0;
        AppLogger.info(
          'Token check result: $hasTokens (${profile.tokenCount} tokens)',
        );
        return hasTokens;
      }

      AppLogger.info('User profile not found, no tokens available');
      return false;
    } catch (e) {
      AppLogger.error('Error checking token availability: $e');
      return false;
    }
  }

  /// Consume one token (reduce by 1)
  static Future<bool> consumeToken(String uid) async {
    try {
      AppLogger.info('Consuming token for UID: $uid');

      // Use transaction to ensure atomicity
      return await _firestore.runTransaction<bool>((transaction) async {
        final docRef = _firestore.collection(_usersCollection).doc(uid);
        final doc = await transaction.get(docRef);

        if (!doc.exists) {
          AppLogger.error('User profile not found when consuming token');
          return false;
        }

        final currentTokens = doc.data()?['tokenCount'] ?? 0;
        if (currentTokens <= 0) {
          AppLogger.error('No tokens available to consume');
          return false;
        }

        transaction.update(docRef, {
          'tokenCount': currentTokens - 1,
          'updatedAt': DateTime.now().toIso8601String(),
        });

        AppLogger.info(
          'Token consumed successfully. Remaining: ${currentTokens - 1}',
        );
        return true;
      });
    } catch (e) {
      AppLogger.error('Error consuming token: $e');
      return false;
    }
  }

  /// Add tokens (for watching ads, purchases, etc.)
  static Future<bool> addTokens(String uid, int tokensToAdd) async {
    try {
      AppLogger.info('Adding $tokensToAdd tokens for UID: $uid');

      // Use transaction to ensure atomicity
      return await _firestore.runTransaction<bool>((transaction) async {
        final docRef = _firestore.collection(_usersCollection).doc(uid);
        final doc = await transaction.get(docRef);

        if (!doc.exists) {
          AppLogger.error('User profile not found when adding tokens');
          return false;
        }

        final currentTokens = doc.data()?['tokenCount'] ?? 0;
        transaction.update(docRef, {
          'tokenCount': currentTokens + tokensToAdd,
          'updatedAt': DateTime.now().toIso8601String(),
        });

        AppLogger.info(
          'Tokens added successfully. New total: ${currentTokens + tokensToAdd}',
        );
        return true;
      });
    } catch (e) {
      AppLogger.error('Error adding tokens: $e');
      return false;
    }
  }
}
