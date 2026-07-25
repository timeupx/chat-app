import 'dart:async';

import 'package:flutter/material.dart';

import '../models/banned_user_model.dart';
import '../services/room_socket_service.dart';

/// Host-only panel listing users banned from the current room, with an
/// Unban action. Backed live by [RoomSocketService.bannedUsers].
class BannedUsersSheet extends StatefulWidget {
  const BannedUsersSheet({super.key});

  @override
  State<BannedUsersSheet> createState() => _BannedUsersSheetState();
}

class _BannedUsersSheetState extends State<BannedUsersSheet> {
  final _roomSocket = RoomSocketService.instance;
  late List<BannedUserModel> _bannedUsers;
  StreamSubscription<List<BannedUserModel>>? _sub;

  @override
  void initState() {
    super.initState();
    // Seed from the cache so opening the sheet after join isn't empty
    // while waiting for the next broadcast.
    _bannedUsers = List.from(_roomSocket.currentBannedUsers);
    _sub = _roomSocket.bannedUsers.listen((users) {
      if (mounted) setState(() => _bannedUsers = users);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _promptUnban(BannedUserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Unban ${user.name}?'),
        content: const Text(
          'They will be able to rejoin this room.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Unban'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _roomSocket.unbanUser(user.userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.25,
      maxChildSize: 0.8,
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
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              Expanded(
                child: _bannedUsers.isEmpty
                    ? const Center(
                        child: Text('No banned users', style: TextStyle(color: Colors.white54)),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _bannedUsers.length,
                        itemBuilder: (context, index) {
                          final user = _bannedUsers[index];
                          final reason = user.reason?.trim();
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?'),
                            ),
                            title: Text(user.name, style: const TextStyle(color: Colors.white)),
                            subtitle: reason == null || reason.isEmpty
                                ? null
                                : Text(
                                    reason,
                                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                                  ),
                            trailing: TextButton(
                              onPressed: () => _promptUnban(user),
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
