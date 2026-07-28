import 'dart:async';

import 'package:flutter/material.dart';

import '../models/banned_user_model.dart';
import '../services/room_socket_service.dart';

/// Host-only panel listing everyone currently banned from the room, with an
/// Unban action. Backed live by [RoomSocketService.bannedUsers].
///
/// There was previously no way to even see who was banned - a host could
/// ban someone but had no UI path to undo it again.
class BannedUsersSheet extends StatefulWidget {
  const BannedUsersSheet({super.key});

  @override
  State<BannedUsersSheet> createState() => _BannedUsersSheetState();
}

class _BannedUsersSheetState extends State<BannedUsersSheet> {
  final _roomSocket = RoomSocketService.instance;
  // Seed with whatever the service already knows - the broadcast stream
  // below only carries *future* updates, so without this the sheet would
  // show "No banned users" until the next ban/unban, even if bans already
  // existed when it was opened.
  late List<BannedUserModel> _banned = _roomSocket.currentBannedUsers;
  StreamSubscription<List<BannedUserModel>>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = _roomSocket.bannedUsers.listen((banned) {
      if (mounted) setState(() => _banned = banned);
    });
    // Belt-and-suspenders: also ask the server directly in case the cached
    // snapshot is stale (e.g. banned from a different device/session).
    _roomSocket.refreshBannedUsers();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
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
                child: _banned.isEmpty
                    ? const Center(
                        child: Text('No banned users', style: TextStyle(color: Colors.white54)),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _banned.length,
                        itemBuilder: (context, index) {
                          final user = _banned[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.red.withValues(alpha: 0.25),
                              child: Text(
                                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                              ),
                            ),
                            title: Text(user.name, style: const TextStyle(color: Colors.white)),
                            subtitle: user.reason != null && user.reason!.isNotEmpty
                                ? Text(
                                    user.reason!,
                                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                                  )
                                : null,
                            trailing: OutlinedButton(
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                              onPressed: () => _roomSocket.unbanUser(user.userId),
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
