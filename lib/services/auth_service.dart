import 'package:shared_preferences/shared_preferences.dart';

/// A simple local authentication service.
/// This is a placeholder that stores credentials locally.
/// Replace with Supabase Auth when ready for production.
class AuthService {
  static const String _keyIsLoggedIn = 'auth_is_logged_in';
  static const String _keyUsername = 'auth_username';
  static const String _keyRememberMe = 'auth_remember_me';

  // Hardcoded credentials for development
  // TODO: Replace with Supabase Auth
  static const Map<String, String> _validCredentials = {
    'admin': 'samsat2024',
    'operator': 'operator123',
  };

  /// Attempts to log in with the given credentials.
  /// Returns true if successful, false otherwise.
  Future<bool> login(
    String username,
    String password, {
    bool rememberMe = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Check against hardcoded credentials
    if (_validCredentials.containsKey(username) &&
        _validCredentials[username] == password) {
      await prefs.setBool(_keyIsLoggedIn, true);
      await prefs.setString(_keyUsername, username);
      await prefs.setBool(_keyRememberMe, rememberMe);
      return true;
    }

    return false;
  }

  /// Logs out the current user.
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, false);
    await prefs.remove(_keyUsername);
  }

  /// Checks if a user is currently logged in.
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  /// Gets the currently logged-in username.
  Future<String?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (await isLoggedIn()) {
      return prefs.getString(_keyUsername);
    }
    return null;
  }

  /// Checks if "Remember Me" was selected.
  Future<bool> isRememberMeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyRememberMe) ?? false;
  }
}
