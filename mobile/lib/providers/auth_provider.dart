import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';
import '../utils/secure_storage_helper.dart';

/// Holds auth-related UI state (loading/error) and coordinates
/// [AuthService] with [SecureStorageHelper]. Exposed to the widget tree
/// via `ChangeNotifierProvider` in main.dart.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  bool isLoading = false;

  /// Attempts to log the user in and persists the access token on success.
  ///
  /// Returns `true` on success. On failure, throws an [AuthException] with
  /// a message safe to display to the user.
  Future<bool> login(String email, String password) async {
    isLoading = true;
    notifyListeners();

    try {
      final data = await _authService.login(email, password);
      final token = data['accessToken'] as String?;

      if (token == null) {
        throw AuthException('No access token returned by the server.');
      }

      await SecureStorageHelper.saveToken(token);
      return true;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
