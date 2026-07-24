import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wraps [FlutterSecureStorage] so the rest of the app never talks to the
/// platform keychain/keystore directly.
class SecureStorageHelper {
  SecureStorageHelper._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _accessTokenKey = 'access_token';

  /// Persists the access token returned by the backend on login.
  static Future<void> saveToken(String token) async {
    await _storage.write(key: _accessTokenKey, value: token);
  }

  /// Returns the stored access token, or `null` if the user isn't logged in.
  static Future<String?> getToken() async {
    return _storage.read(key: _accessTokenKey);
  }

  /// Clears the stored token. Call this on logout.
  static Future<void> deleteToken() async {
    await _storage.delete(key: _accessTokenKey);
  }
}
