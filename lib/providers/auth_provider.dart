import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';

/// Provider for authentication state management.
/// Notifies listeners when auth state changes.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  bool _isAuthenticated = false;
  bool _isLoading = true;
  String? _currentUser;
  String? _errorMessage;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    _checkAuthStatus();
  }

  /// Checks if user is already logged in (on app start).
  Future<void> _checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      _isAuthenticated = await _authService.isLoggedIn();
      if (_isAuthenticated) {
        _currentUser = await _authService.getCurrentUser();
      }
    } catch (e) {
      debugPrint('Error checking auth status: $e');
      _isAuthenticated = false;
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Attempts to log in with the given credentials.
  Future<bool> login(
    String username,
    String password, {
    bool rememberMe = false,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _authService.login(
        username,
        password,
        rememberMe: rememberMe,
      );

      if (success) {
        _isAuthenticated = true;
        _currentUser = username;
        _errorMessage = null;
      } else {
        _isAuthenticated = false;
        _errorMessage = 'Username atau password salah';
      }
    } catch (e) {
      _isAuthenticated = false;
      _errorMessage = 'Terjadi kesalahan: $e';
    }

    _isLoading = false;
    notifyListeners();
    return _isAuthenticated;
  }

  /// Logs out the current user.
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    await _authService.logout();

    _isAuthenticated = false;
    _currentUser = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Clears any error message.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
