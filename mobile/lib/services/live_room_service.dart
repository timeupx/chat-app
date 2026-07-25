import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../models/live_room_model.dart';
import '../utils/secure_storage_helper.dart';

/// Thrown when a `/api/live-rooms` request fails. [message] is safe to show
/// directly to the user.
class LiveRoomException implements Exception {
  final String message;
  LiveRoomException(this.message);

  @override
  String toString() => message;
}

/// A single chat message returned by the message-history endpoint.
class LiveMessageModel {
  final String username;
  final String message;

  const LiveMessageModel({required this.username, required this.message});

  factory LiveMessageModel.fromJson(Map<String, dynamic> json) {
    return LiveMessageModel(
      username: json['name'] as String? ?? 'Unknown',
      message: json['message'] as String? ?? '',
    );
  }
}

/// HTTP client for the `/api/live-rooms` REST endpoints: create/list/detail,
/// go-live/end-live, message history, and room-image upload.
class LiveRoomService {
  static const _timeout = Duration(seconds: 15);

  static String get _baseUrl {
    if (kIsWeb) {
      return dotenv.env['WEB_BASE_URL'] ?? 'http://localhost:4000';
    }
    return dotenv.env['BASE_URL'] ?? '';
  }

  Future<Map<String, String>> _headers() async {
    final token = await SecureStorageHelper.getToken();
    return {
      'Content-Type': 'application/json',
      // This backend's `auth` middleware reads the raw JWT directly off
      // the Authorization header - no "Bearer " prefix.
      'Authorization': ?token,
    };
  }

  Map<String, dynamic> _unwrap(http.Response response) {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw LiveRoomException('Received an invalid response from the server.');
    }

    if ((response.statusCode == 200 || response.statusCode == 201) && body['success'] == true) {
      return body;
    }
    throw LiveRoomException(
      body['message'] as String? ?? 'Request failed (${response.statusCode})',
    );
  }

  Future<List<LiveRoomModel>> listRooms() async {
    final uri = Uri.parse('$_baseUrl/api/live-rooms');
    final response = await http.get(uri, headers: await _headers()).timeout(_timeout);
    final body = _unwrap(response);

    return (body['data'] as List)
        .map((e) => LiveRoomModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<LiveRoomModel> getRoomDetail(String roomId) async {
    final uri = Uri.parse('$_baseUrl/api/live-rooms/$roomId');
    final response = await http.get(uri, headers: await _headers()).timeout(_timeout);
    final body = _unwrap(response);
    return LiveRoomModel.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<LiveRoomModel> createRoom({
    required String roomName,
    required String roomImage,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/live-rooms');
    final response = await http
        .post(
          uri,
          headers: await _headers(),
          body: jsonEncode({
            'roomName': roomName,
            'roomImage': roomImage,
          }),
        )
        .timeout(_timeout);
    final body = _unwrap(response);
    return LiveRoomModel.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<void> goLive(String roomId) async {
    final uri = Uri.parse('$_baseUrl/api/live-rooms/$roomId/go-live');
    final response = await http.patch(uri, headers: await _headers()).timeout(_timeout);
    _unwrap(response);
  }

  Future<void> endLive(String roomId) async {
    final uri = Uri.parse('$_baseUrl/api/live-rooms/$roomId/end-live');
    final response = await http.patch(uri, headers: await _headers()).timeout(_timeout);
    _unwrap(response);
  }

  Future<List<LiveMessageModel>> getMessages(String roomId) async {
    final uri = Uri.parse('$_baseUrl/api/live-rooms/$roomId/messages');
    final response = await http.get(uri, headers: await _headers()).timeout(_timeout);
    final body = _unwrap(response);

    return (body['data'] as List)
        .map((e) => LiveMessageModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Uploads [imageFile] and returns its public URL. Reads bytes (not
  /// [XFile.path]) so this works on Flutter Web too, where the picked
  /// file has no real filesystem path.
  Future<String> uploadImage(XFile imageFile) async {
    final uri = Uri.parse('$_baseUrl/api/live-rooms/upload-image');
    final token = await SecureStorageHelper.getToken();

    final request = http.MultipartRequest('POST', uri);
    if (token != null) request.headers['Authorization'] = token;

    final bytes = await imageFile.readAsBytes();

    // Without an explicit contentType, MultipartFile.fromBytes defaults to
    // application/octet-stream, which the backend's image-type filter
    // rejects - this is what caused the "Only JPEG, PNG, WEBP, or GIF
    // images are allowed" 500. XFile.mimeType is usually set correctly by
    // image_picker; fall back to guessing from the filename otherwise.
    final mimeType = imageFile.mimeType ?? _guessMimeType(imageFile.name);

    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename: imageFile.name,
        contentType: MediaType.parse(mimeType),
      ),
    );

    final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamedResponse);
    final body = _unwrap(response);

    return (body['data'] as Map<String, dynamic>)['url'] as String;
  }

  String _guessMimeType(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }
}
