// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import '../models/user_model.dart';

// enum AuthStatus { unauthenticated, loading, authenticated }

// class AuthProvider extends ChangeNotifier {
//   UserModel? _user;
//   AuthStatus _status = AuthStatus.loading;
//   String? _error;

//   UserModel? get user => _user;
//   AuthStatus get status => _status;
//   String? get error => _error;
//   bool get isAuthenticated => _status == AuthStatus.authenticated;

//   AuthProvider() {
//     _loadSession();
//   }

//   Future<void> _loadSession() async {
//     final prefs = await SharedPreferences.getInstance();
//     final raw = prefs.getString('user');
//     if (raw != null) {
//       try {
//         _user = UserModel.fromJson(jsonDecode(raw));
//         _status = AuthStatus.authenticated;
//       } catch (_) {
//         _status = AuthStatus.unauthenticated;
//       }
//     } else {
//       _status = AuthStatus.unauthenticated;
//     }
//     notifyListeners();
//   }

//   Future<bool> login(String email, String password) async {
//     _error = null;
//     _status = AuthStatus.loading;
//     notifyListeners();

//     await Future.delayed(const Duration(milliseconds: 1200));

//     // Mock Cognito-ready login
//     if (email.isEmpty || password.isEmpty) {
//       _error = 'Please enter email and password.';
//       _status = AuthStatus.unauthenticated;
//       notifyListeners();
//       return false;
//     }

//     // Check if user was previously registered in this session
//     final prefs = await SharedPreferences.getInstance();
//     final raw = prefs.getString('registered_$email');

//     UserModel user;
//     if (raw != null) {
//       final data = jsonDecode(raw);
//       if (data['password'] != password) {
//         _error = 'Invalid credentials.';
//         _status = AuthStatus.unauthenticated;
//         notifyListeners();
//         return false;
//       }
//       user = UserModel.fromJson(data['user']);
//     } else {
//       // Default to student if not registered
//       user = UserModel(
//         id: 'mock_${DateTime.now().millisecondsSinceEpoch}',
//         name: email.split('@').first,
//         email: email,
//         role: 'student',
//         xp: 1240,
//         streak: 7,
//         createdAt: DateTime.now(),
//       );
//     }

//     _user = user;
//     _status = AuthStatus.authenticated;
//     await prefs.setString('user', jsonEncode(user.toJson()));
//     notifyListeners();
//     return true;
//   }

//   Future<bool> register({
//     required String name,
//     required String email,
//     required String password,
//     required String role,
//   }) async {
//     _error = null;
//     _status = AuthStatus.loading;
//     notifyListeners();

//     await Future.delayed(const Duration(milliseconds: 1400));

//     if (name.isEmpty || email.isEmpty || password.isEmpty) {
//       _error = 'Please fill all fields.';
//       _status = AuthStatus.unauthenticated;
//       notifyListeners();
//       return false;
//     }

//     final user = UserModel(
//       id: 'user_${DateTime.now().millisecondsSinceEpoch}',
//       name: name,
//       email: email,
//       role: role,
//       xp: 0,
//       streak: 0,
//       createdAt: DateTime.now(),
//     );

//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString('registered_$email', jsonEncode({
//       'password': password,
//       'user': user.toJson(),
//     }));

//     _user = user;
//     _status = AuthStatus.authenticated;
//     await prefs.setString('user', jsonEncode(user.toJson()));
//     notifyListeners();
//     return true;
//   }

//   Future<void> logout() async {
//     _user = null;
//     _status = AuthStatus.unauthenticated;
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.remove('user');
//     notifyListeners();
//   }

//   Future<void> addXP(int amount) async {
//     if (_user == null) return;
//     _user = _user!.copyWith(xp: _user!.xp + amount);
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString('user', jsonEncode(_user!.toJson()));
//     notifyListeners();
//   }
// }




//  Updated 2

//  Updated 2

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'package:cogniops/providers/auth_service.dart';
import '../services/api_service.dart';

enum AuthStatus { loading, unauthenticated, needsVerification, authenticated }

class AuthProvider extends ChangeNotifier {
  UserModel?  _user;
  AuthStatus  _status = AuthStatus.loading;
  String?     _error;
  String?     _pendingEmail; // for OTP verification flow

  UserModel?  get user    => _user;
  AuthStatus  get status  => _status;
  String?     get error   => _error;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  final _auth = AuthService();
  final _api  = ApiService();

  AuthProvider() { _restoreSession(); }

  // ── Restore persisted session on app start ────────────────────────────────
  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString('cogniops_user');
    if (raw != null) {
      try {
        _user   = UserModel.fromJson(jsonDecode(raw));
        _status = AuthStatus.authenticated;
        // Silently refresh progress from backend
        _syncProgressFromBackend();
      } catch (_) {
        _status = AuthStatus.unauthenticated;
      }
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  // ── Sign Up ───────────────────────────────────────────────────────────────
  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    _error  = null;
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      await _auth.signUp(name: name, email: email, password: password, role: role);
      _pendingEmail = email;
      _status = AuthStatus.needsVerification;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _error  = e.message;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  // ── Confirm OTP after sign-up ─────────────────────────────────────────────
  Future<bool> confirmSignUp({required String email, required String code}) async {
    _error  = null;
    _status = AuthStatus.loading;
    notifyListeners();
    try {
      await _auth.confirmSignUp(email: email, code: code);
      _status = AuthStatus.unauthenticated; // now they can log in
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _error  = e.message;
      _status = AuthStatus.needsVerification;
      notifyListeners();
      return false;
    }
  }

  Future<void> resendCode(String email) async {
    await _auth.resendCode(email);
  }

  // ── Sign In ───────────────────────────────────────────────────────────────
  Future<bool> login(String email, String password) async {
    _error  = null;
    _status = AuthStatus.loading;
    notifyListeners();
    try {
      final cognitoUser = await _auth.signIn(email: email, password: password);

      // Build UserModel from Cognito claims + fetch real data from DynamoDB
      final profile = await _fetchOrCreateProfile(
        userId: cognitoUser.sub,
        name:   cognitoUser.name,
        email:  cognitoUser.email,
        role:   cognitoUser.role,
      );

      _user   = profile;
      _status = AuthStatus.authenticated;
      await _persistUser(profile);
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      if (e.needsVerification) {
        _pendingEmail = email;
        _status = AuthStatus.needsVerification;
      } else {
        _error  = e.message;
        _status = AuthStatus.unauthenticated;
      }
      notifyListeners();
      return false;
    }
  }

  // ── Sign Out ──────────────────────────────────────────────────────────────
  Future<void> logout() async {
    await _auth.signOut();
    _user   = null;
    _status = AuthStatus.unauthenticated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cogniops_user');
    notifyListeners();
  }

  // ── Add XP (called after quiz/roadmap) ───────────────────────────────────
  Future<void> addXP(int amount, {int modulesDelta = 0}) async {
    if (_user == null) return;
    // Optimistic update
    _user = _user!.copyWith(xp: _user!.xp + amount);
    notifyListeners();
    await _persistUser(_user!);
    // Sync to backend
    try {
      await _api.addXP(amount, modulesDelta: modulesDelta);
    } catch (_) {}
  }

  // ── Get pending email for OTP screen ─────────────────────────────────────
  String get pendingEmail => _pendingEmail ?? '';

  // ── Helpers ───────────────────────────────────────────────────────────────
  Future<UserModel> _fetchOrCreateProfile({
    required String userId,
    required String name,
    required String email,
    required String role,
  }) async {
    try {
      // Save profile to DynamoDB (creates if not exists)
      await _api.saveProfile(name: name, email: email, role: role);
      // Fetch real progress
      final progress = await _api.getProgress();
      return UserModel(
        id:        userId,
        name:      name,
        email:     email,
        role:      role,
        xp:        (progress['xp']     as num?)?.toInt() ?? 0,
        streak:    (progress['streak'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.now(),
      );
    } catch (_) {
      // Offline fallback
      return UserModel(
        id: userId, name: name, email: email,
        role: role, xp: 0, streak: 0, createdAt: DateTime.now(),
      );
    }
  }

  Future<void> _syncProgressFromBackend() async {
    if (_user == null) return;
    try {
      final progress = await _api.getProgress();
      _user = _user!.copyWith(
        xp:     (progress['xp']     as num?)?.toInt() ?? _user!.xp,
        streak: (progress['streak'] as num?)?.toInt() ?? _user!.streak,
      );
      await _persistUser(_user!);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _persistUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cogniops_user', jsonEncode(user.toJson()));
  }
}