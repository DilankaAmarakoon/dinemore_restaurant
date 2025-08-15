import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml_rpc/client_c.dart' as xml_rpc;

class AuthProvider with ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _errorMessage;

  // Hardcoded configuration for restaurant - FIXED URL FORMAT
  static const String _baseUrl = "dinemorego-uat-22681767.dev.odoo.com"; // No https here
  static const String _database = "dinemorego-uat-22681767";

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      final username = prefs.getString('username');

      if (userId != null && username != null) {
        _isAuthenticated = true;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error checking auth status: $e');
    }
  }

  Future<bool> login(String username, String password , String macAddress) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Authenticate with Odoo
      final userId = await _authenticateWithOdoo(username, password);

      if (userId > 0) {
        // Verify device has content
        final hasContent = await _verifyDeviceContent(userId, password , macAddress);

        if (hasContent) {
          await _saveAuthData(userId, username, password,macAddress);
          _isAuthenticated = true;
          _isLoading = false;
          notifyListeners();
          return true;
        } else {
          _errorMessage = 'No content found for this device. Please contact your administrator.';
        }
      } else {
        _errorMessage = 'Invalid username or password.';
      }
    } catch (e) {
      _errorMessage = 'Connection error. Please check your internet connection.';
      debugPrint('Login error: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<int> _authenticateWithOdoo(String username, String password) async {
    try {
      // FIXED: Use consistent URL format
      final userId = await xml_rpc.call(
        Uri.parse('https://$_baseUrl/xmlrpc/2/common'),
        'login',
        [_database, username, password],
      );

      debugPrint("Authentication response: $userId");
      if(userId > 1){
        final preferences = await SharedPreferences.getInstance();
        await preferences.setInt("user_Id", userId);
        await preferences.setString("password", password);
      }
      return userId is int ? userId : -1;
    } catch (e) {
      debugPrint('Authentication error: $e');
      return -1;
    }
  }

  Future<bool> _verifyDeviceContent(int userId, String password ,String macAddress) async {
    try {
      final content = await xml_rpc.call(
        Uri.parse('https://$_baseUrl/xmlrpc/2/object'),
        'execute_kw',
        [
          _database,
          userId,
          password,
          'restaurant.display.line',
          'search_read',
          [
            [['device_ip', '=', macAddress]]
          ],
        ],
      );

      debugPrint("Content verification response: $content");
      return content is List && content.isNotEmpty;
    } catch (e) {
      debugPrint('Content verification error: $e');
      return false;
    }
  }

  Future<void> _saveAuthData(int userId, String username, String password , String macAddress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('user_id', userId);
    await prefs.setString('username', username);
    await prefs.setString('password', password);
    await prefs.setString('base_url', _baseUrl);
    await prefs.setString('database', _database);
    await prefs.setString('device_id', macAddress);
  }
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      _isAuthenticated = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Logout error: $e');
    }
  }
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}