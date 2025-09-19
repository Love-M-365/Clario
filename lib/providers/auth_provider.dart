// lib/providers/auth_provider.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  User? _user;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isReady = false;

  StreamSubscription<User?>? _authSubscription;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _user != null;
  bool get isReady => _isReady;

  AuthProvider() {
    _authSubscription = _auth.authStateChanges().listen((User? user) {
      _user = user;
      _isReady = true;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Email & Password Sign-In
  Future<bool> signInWithEmailAndPassword(String email, String password) async {
    try {
      setLoading(true);
      clearError();

      final UserCredential result = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      _user = result.user;

      if (_user != null) {
        await _dbRef.child("users/${_user!.uid}/lastLoginAt").set(
              DateTime.now().toIso8601String(),
            );
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

  // Register with Email & Password
  Future<bool> registerWithEmailAndPassword(
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

  // Google Sign-In / Sign-Up
  Future<bool> signInWithGoogle() async {
    try {
      setLoading(true);
      clearError();

      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setLoading(false);
        return false; // User cancelled Google Sign-In
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential result =
          await _auth.signInWithCredential(credential);
      _user = result.user;

      if (_user != null) {
        // Save new user data in Realtime Database if not exists
        final snapshot = await _dbRef.child("users/${_user!.uid}").get();
        if (!snapshot.exists) {
          await _dbRef.child("users/${_user!.uid}").set({
            'name': _user!.displayName ?? '',
            'email': _user!.email ?? '',
            'createdAt': DateTime.now().toIso8601String(),
            'lastLoginAt': DateTime.now().toIso8601String(),
          });
        } else {
          // Update last login
          await _dbRef
              .child("users/${_user!.uid}/lastLoginAt")
              .set(DateTime.now().toIso8601String());
        }
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

  // Sign out
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
