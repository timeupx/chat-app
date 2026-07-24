import 'dart:convert';

/// Decodes the payload of a JWT without verifying its signature.
///
/// Verification happens server-side; here we only need to read the claims
/// (name, email, role, ...) the backend already embedded in the access
/// token (see `auth.service.ts` -> `jwt.sign`) so the Profile screen can
/// show the logged-in user without a dedicated `/me` endpoint.
Map<String, dynamic>? decodeJwtPayload(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return null;

    final normalized = base64Url.normalize(parts[1]);
    final payload = utf8.decode(base64Url.decode(normalized));
    return jsonDecode(payload) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}
