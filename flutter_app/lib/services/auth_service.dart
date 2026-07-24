import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Thrown when the backend rejects a request or the request fails to
/// complete. [message] is safe to show directly to the user.
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

/// Talks to the Express.js `/api/auth` endpoints.
class AuthService {
  static const _requestTimeout = Duration(seconds: 30);

  /// Base URL of the backend.
  ///
  /// Flutter Web runs in the browser and talks to the backend directly over
  /// `localhost`, so it uses WEB_BASE_URL instead of BASE_URL (which points
  /// at the Android emulator's `10.0.2.2` host alias).
  static String get _baseUrl {
    if (kIsWeb) {
      return dotenv.env['WEB_BASE_URL'] ?? 'http://localhost:4000';
    }
    return dotenv.env['BASE_URL'] ?? '';
  }

  /// Logs a user in.
  ///
  /// On success returns the decoded `data` object from the backend response,
  /// e.g. `{"accessToken": "..."}`.
  ///
  /// Throws [AuthException] with the backend-provided message (or a sensible
  /// fallback) if the request fails or the server rejects the credentials.
  Future<Map<String, dynamic>> login(String email, String password) async {
    final uri = Uri.parse('$_baseUrl/api/auth/login');

    late final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw AuthException(
        'The server took too long to respond (>${_requestTimeout.inSeconds}s). '
        'Make sure the backend is running on port 4000.',
      );
    } on http.ClientException catch (e) {
      // On Flutter Web, a blocked CORS request surfaces here (not as a
      // SocketException) - typically "Failed to fetch".
      throw AuthException(
        kIsWeb
            ? 'Network error: ${e.message}. If this is CORS-related, make '
                'sure the backend allows requests from this origin.'
            : 'Network error: ${e.message}',
      );
    } on SocketException {
      throw AuthException(
        'Could not reach the server. Check your connection and BASE_URL.',
      );
    } on FormatException {
      throw AuthException('Received an invalid response from the server.');
    } catch (e) {
      throw AuthException('Something went wrong: $e');
    }

    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw AuthException('Received an invalid response from the server.');
    }

    // Backend wraps every response as { success, message, data }.
    if (response.statusCode == 200 || response.statusCode == 201) {
      if (body['success'] == true) {
        return (body['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      }
    }

    final errorMessage = body['message'] as String? ?? 'Login failed';
    throw AuthException(errorMessage);
  }
}
