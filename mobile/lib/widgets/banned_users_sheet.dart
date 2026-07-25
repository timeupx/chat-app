import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../services/room_socket_service.dart';
import '../utils/secure_storage_helper.dart';

class BannedUserModel {
  final String userId;
  final String userName;
  final String? reason;
  final DateTime bannedAt;

  const BannedUserModel({
    required this.userId,
    required this.userName,
    required this.reason,
    required this.bannedAt,
  });

  factory BannedUserModel.fromJson(Map<String, dynamic> json) {
    return BannedUserModel(
      userId: json['userId'] as String? ?? '',
      userName: json['userName'] as String? ?? 'Unknown',
      reason: json['reason'] as String?,
      bannedAt: DateTime.parse(json['bannedAt'] as String),
    );
  }
}

class BannedUsersSheet extends StatefulWidget {
  final String roomName;

  const BannedUsersSheet({super.key, required this.roomName});

  @override
  State<BannedUsersSheet> createState() => _BannedUsersSheetState();
}

class _BannedUsersSheetState extends State<BannedUsersSheet> {
  final _roomSocket = RoomSocketService.instance;
  List<BannedUserModel> _bannedUsers = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadBannedUsers();
  }

  Future<void> _loadBannedUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await SecureStorageHelper.getToken();
      final baseUrl = kIsWeb
          ? (dotenv.env['WEB_BASE_URL'] ?? 'http://localhost:4000')
          : (dotenv.env['BASE_URL'] ?? '');
      final uri = Uri.parse(
        '$baseUrl/api/live-rooms/${Uri.encodeComponent(widget.roomName)}/banned-users',
      );

      final response = await http
          .get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': token,
            },
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || body['success'] != true) {
        throw Exception(
          body['message'] as String? ?? 'Failed to load banned users',
        );
      }

      final data = (body['data'] as List?) ?? const [];
      setState(() {
        _bannedUsers = data
            .map(
              (item) => BannedUserModel.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _unbanUser(BannedUserModel user) async {
    _roomSocket.unbanUser(user.userId);
    if (!mounted) return;
    setState(
      () => _bannedUsers.removeWhere((item) => item.userId == user.userId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Banned Users',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      )
                    : _bannedUsers.isEmpty
                    ? const Center(
                        child: Text(
                          'No banned users',
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _bannedUsers.length,
                        itemBuilder: (context, index) {
                          final user = _bannedUsers[index];
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(
                                user.userName.isNotEmpty
                                    ? user.userName[0].toUpperCase()
                                    : '?',
                              ),
                            ),
                            title: Text(
                              user.userName,
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle:
                                user.reason != null && user.reason!.isNotEmpty
                                ? Text(
                                    user.reason!,
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  )
                                : null,
                            trailing: TextButton(
                              onPressed: () => _unbanUser(user),
                              child: const Text('Unban'),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
