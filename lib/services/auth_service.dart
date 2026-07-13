// lib/services/auth_service.dart
// Authentication Service - Handles all user authentication operations
// Uses Firebase Authentication for secure user management

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Check if user is logged in
  bool get isLoggedIn => _auth.currentUser != null;

  /// Register new user with email and password
  /// Creates user in Firebase Auth and stores additional data in Firestore
  Future<String?> registerUser({
    required String email,
    required String password,
    required String name,
    String role = 'PATIENT',
  }) async {
    try {
      // Create user in Firebase Authentication
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(
            email: email.trim().toLowerCase(),
            password: password,
          );

      // Update display name
      await userCredential.user?.updateDisplayName(name);

      // Create user document in Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'user_id': userCredential.user!.uid,
        'email': email.trim().toLowerCase(),
        'name': name.trim(),
        'role': role,
        'timezone': 'Asia/Dhaka',
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Create default notification preferences
      await _firestore
          .collection('notification_preferences')
          .doc(userCredential.user!.uid)
          .set({
            'pref_id': userCredential.user!.uid,
            'user_id': userCredential.user!.uid,
            'push_enabled': true,
            'daily_summary': false,
            'quiet_start': null,
            'quiet_end': null,
            'sound': 'default',
            'snooze_minutes': 10,
            'updated_at': FieldValue.serverTimestamp(),
          });

      notifyListeners();
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return _getErrorMessage(e);
    } catch (e) {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Login user with email and password
  Future<String?> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      notifyListeners();
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return _getErrorMessage(e);
    } catch (e) {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Logout current user
  Future<void> logoutUser() async {
    try {
      await _auth.signOut();
      notifyListeners();
    } catch (e) {
      debugPrint('Logout error: $e');
    }
  }

  /// Get user profile data from Firestore
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      debugPrint('Get user profile error: $e');
      return null;
    }
  }

  /// Update user profile
  Future<bool> updateUserProfile(
    String userId,
    Map<String, dynamic> data,
  ) async {
    try {
      data['updated_at'] = FieldValue.serverTimestamp();
      await _firestore.collection('users').doc(userId).update(data);
      return true;
    } catch (e) {
      debugPrint('Update user profile error: $e');
      return false;
    }
  }

  /// Reset password - sends reset email
  Future<String?> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return _getErrorMessage(e);
    } catch (e) {
      return 'Failed to send reset email. Please try again.';
    }
  }

  /// Get user-friendly error messages
  String _getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'weak-password':
        return 'Password is too weak. Please use at least 6 characters.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'operation-not-allowed':
        return 'Operation not allowed. Please contact support.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}
