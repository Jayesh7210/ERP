import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized session persistence service for storing authentication tokens,
/// user profiles, and active backend URL configurations.
class SessionService {
  static const String _keyUser = 'erp_session_user';
  static const String _keyToken = 'erp_auth_token';
  static const String _keyApiUrl = 'erp_api_base_url';

  /// Save logged-in user profile to persistent storage
  static Future<void> saveUser(Map<String, dynamic> user, {String? token}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUser, jsonEncode(user));
      if (token != null && token.isNotEmpty) {
        await prefs.setString(_keyToken, token);
      }
    } catch (e) {
      // Gracefully handle any platform storage exception
    }
  }

  /// Retrieve cached user profile if exists
  static Future<Map<String, dynamic>?> getUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userStr = prefs.getString(_keyUser);
      if (userStr != null && userStr.isNotEmpty) {
        return jsonDecode(userStr) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Get auth token if available
  static Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyToken);
    } catch (_) {}
    return null;
  }

  /// Clear session on user logout
  static Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyUser);
      await prefs.remove(_keyToken);
    } catch (_) {}
  }

  /// Save customized API base URL (e.g. LAN IP for physical device or cloud url)
  static Future<void> saveApiBaseUrl(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyApiUrl, url.trim());
    } catch (_) {}
  }

  /// Retrieve saved API base URL
  static Future<String?> getApiBaseUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final url = prefs.getString(_keyApiUrl);
      if (url != null && url.isNotEmpty) {
        return url;
      }
    } catch (_) {}
    return null;
  }
}
