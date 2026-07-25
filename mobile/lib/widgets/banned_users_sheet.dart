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
    // Confirm on the root navigator so the dialog is not trapped under /
    // behind this modal bottom sheet (common on Flutter web).
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2E),
        title: Text(
          'Unban ${user.name}?',
          style: const TextStyle(color: Colors.white),
        ),
        content: const Text(
          'They will be able to rejoin this room.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext, rootNavigator: true).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext, rootNavigator: true).pop(true),
            child: const Text('Unban'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    // Optimistic UI so the row disappears immediately; the socket broadcast
    // / unbanAck will reconcile the canonical list right after.
    setState(() {
      _bannedUsers = _bannedUsers.where((u) => u.userId != user.userId).toList();
    });
    _roomSocket.unbanUser(user.userId);
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
                            trailing: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white24,
                                foregroundColor: Colors.white,
                              ),
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
