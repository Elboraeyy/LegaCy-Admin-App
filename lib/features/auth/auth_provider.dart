import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:admin_app/core/network/api_client.dart';
import 'package:admin_app/core/config/api_config.dart';

/// Manages authentication state across the app.
/// Exposes [isLoggedIn], [token], [user] for the UI.
class AuthProvider extends ChangeNotifier {
  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';
  static const _savedEmailKey = 'saved_admin_email';
  static const _savedPasswordKey = 'saved_admin_password';
  static const _secureStorage = FlutterSecureStorage();

  String? _token;
  Map<String, dynamic>? _user;
  bool _isLoading = false;
  String? _errorMessage;

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get isLoggedIn => _token != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  String get displayName =>
      _user?['username'] ?? _user?['name'] ?? 'Admin';
  String? get adminName => displayName;
  String get role => _user?['role'] ?? 'admin';
  String get initials => displayName.isNotEmpty ? displayName[0].toUpperCase() : 'A';

  Future<({String? email, String? password})> getSavedCredentials() async {
    final email = await _secureStorage.read(key: _savedEmailKey);
    final password = await _secureStorage.read(key: _savedPasswordKey);

    return (email: email, password: password);
  }

  /// Try to restore a saved session on app launch.
  Future<void> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString(_tokenKey);
    final savedUser = prefs.getString(_userKey);

    if (savedToken != null && savedUser != null) {
      _token = savedToken;
      _user = jsonDecode(savedUser) as Map<String, dynamic>;
      notifyListeners();
    }
  }

  /// Log in with email/password against the Next.js API.
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final client = ApiClient();
      final response = await client.post(
        ApiConfig.loginEndpoint,
        body: {'email': email, 'password': password},
      );

      _token = response['token'] as String?;
      _user = response['user'] as Map<String, dynamic>?;

      // Persist session
      final prefs = await SharedPreferences.getInstance();
      if (_token != null) {
        await prefs.setString(_tokenKey, _token!);
      }
      if (_user != null) {
        await prefs.setString(_userKey, jsonEncode(_user));
      }
      await _secureStorage.write(key: _savedEmailKey, value: email);
      await _secureStorage.write(key: _savedPasswordKey, value: password);

      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Connection error. Please check your network.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Log out — clear token + navigate to login.
  Future<void> logout() async {
    _token = null;
    _user = null;
    _errorMessage = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);

    notifyListeners();
  }

  void updateAvatar(String newAvatarUrl) {
    if (_user != null) {
      _user!['avatar'] = newAvatarUrl;
      // Persist the updated user data
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString(_userKey, jsonEncode(_user));
      });
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
