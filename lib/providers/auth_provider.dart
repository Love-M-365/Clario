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
  Future<bool> checkUserExists(String uid) async {
  final snapshot = await _dbRef.child("users/$uid").get();
  return snapshot.exists;
}

Future<void> saveUserData(String uid, Map<String, dynamic> data) async {
  await _dbRef.child("users/$uid").set(data);
}


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

  Future<bool> signInWithGoogle() async {
  try {
    setLoading(true);
    clearError();

    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      setLoading(false);
      return false; // User cancelled
    }

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // 👇 This automatically creates the user in Firebase if not exists
    final UserCredential result = await _auth.signInWithCredential(credential);
    _user = result.user;

    if (_user != null) {
      final uid = _user!.uid;
      final snapshot = await _dbRef.child("users/$uid").get();

      if (!snapshot.exists) {
        // 👇 If user not found in DB, this is the first signup
        await _dbRef.child("users/$uid").set({
          'name': _user!.displayName ?? '',
          'email': _user!.email ?? '',
          'createdAt': DateTime.now().toIso8601String(),
          'lastLoginAt': DateTime.now().toIso8601String(),
          'isNewUser': true, // 👈 optional flag
        });

        print("🆕 New Google user created.");
      } else {
        // 👇 Existing user login
        await _dbRef
            .child("users/$uid/lastLoginAt")
            .set(DateTime.now().toIso8601String());
        print("✅ Returning Google user logged in.");
      }
    }

    setLoading(false);
    return true;
  } on FirebaseAuthException catch (e) {
    setLoading(false);
    _errorMessage = _getErrorMessage(e.code);
    notifyListeners();
    return false;
  } catch (e) {
    setLoading(false);
    _errorMessage = 'An unexpected error occurred: $e';
    notifyListeners();
    return false;
  }
}
  Future<void> signOut() async {
    await _auth.signOut();
    await GoogleSignIn().signOut();
    _user = null;
    notifyListeners();
  }

  // 👇 Add this below signOut or anywhere near the end of the class
  String _getErrorMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'weak-password':
        return 'The password is too weak.';
      case 'account-exists-with-different-credential':
        return 'This email is linked with another sign-in method.';
      default:
        return 'An unknown error occurred. Please try again.';
    }
  }
}


