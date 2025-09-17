// lib/providers/auth_provider.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  User? _user;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isReady = false; // Add this new property

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _user != null;
  bool get isReady => _isReady; // Add this new getter

  AuthProvider() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      _isReady = true; // Set to true once the initial auth state is known
      notifyListeners();
    });
  }

  // Method to manage the loading state
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Method to clear the error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> signInWithEmailAndPassword(String email, String password) async {
    try {
      setLoading(true);
      clearError();

      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      _user = result.user;

      if (_user != null) {
        // Update last login timestamp in Realtime Database
        await _dbRef
            .child("users/${_user!.uid}/lastLoginAt")
            .set(DateTime.now().toIso8601String());
      }

      setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      setLoading(false);
      _errorMessage = _getErrorMessage(e.code);
      notifyListeners();
      return false;
    } catch (_) {
      setLoading(false);
      _errorMessage = 'An unexpected error occurred';
      notifyListeners();
      return false;
    }
  }

  Future<bool> createUserWithEmailAndPassword(
      String email, String password, Map<String, dynamic> userData) async {
    try {
      setLoading(true);
      clearError();

      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      _user = result.user;

      if (_user != null) {
        await _user!.sendEmailVerification();

        // Save new user data to Realtime Database
        await _dbRef.child("users/${_user!.uid}").set({
          ...userData,
          'email': email,
          'createdAt': DateTime.now().toIso8601String(),
          'lastLoginAt': DateTime.now().toIso8601String(),
        });
      }

      setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      setLoading(false);
      _errorMessage = _getErrorMessage(e.code);
      notifyListeners();
      return false;
    } catch (_) {
      setLoading(false);
      _errorMessage = 'An unexpected error occurred';
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      _user = null;
      notifyListeners();
    } catch (_) {
      _errorMessage = 'Error signing out';
      notifyListeners();
    }
  }

  String _getErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'invalid-email':
        return 'The email address is not valid.';
      default:
        return 'An error occurred. Please try again.';
    }
  }
}
