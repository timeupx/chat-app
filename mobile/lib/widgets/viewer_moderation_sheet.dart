import 'package:flutter/material.dart';

import '../services/room_socket_service.dart';

/// Host-only quick actions (Chat Mute, Invite as Guest, Warn, Ban) for a
/// single viewer - triggered by tapping their name in the live chat feed,
/// as an alternative to opening the full Viewer List sheet just to act on
/// one person.
Future<void> showViewerModerationSheet(
  BuildContext context, {
  required RoomSocketService roomSocket,
  required String userId,
  required String name,
  required bool isMuted,
  required bool isGuest,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF1C1C1E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const Divider(color: Colors.white12, height: 16),
            ListTile(
              leading: Icon(isMuted ? Icons.mic : Icons.mic_off, color: Colors.white70),
              title: Text(
                isMuted ? 'Chat Unmute' : 'Chat Mute',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                if (isMuted) {
                  roomSocket.chatUnmuteUser(userId);
                } else {
                  roomSocket.chatMuteUser(userId);
                }
              },
            ),
            if (!isGuest)
              ListTile(
                leading: const Icon(Icons.co_present, color: Colors.white70),
                title: const Text('Invite as Guest', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  roomSocket.inviteGuest(userId);
                },
              ),
            if (isGuest)
              ListTile(
                leading: const Icon(Icons.person_remove_alt_1, color: Colors.orangeAccent),
                title: const Text(
                  'Remove from Live',
                  style: TextStyle(color: Colors.orangeAccent),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  roomSocket.removeGuest(userId);
                },
              ),
            ListTile(
              leading: const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
              title: const Text('Warn', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _promptWarn(context, roomSocket, userId, name);
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.redAccent),
              title: const Text('Ban', style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _promptBan(context, roomSocket, userId, name);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

Future<void> _promptBan(
  BuildContext context,
  RoomSocketService roomSocket,
  String userId,
  String name,
) async {
  final reasonController = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Ban $name?'),
      content: TextField(
        controller: reasonController,
        decoration: const InputDecoration(hintText: 'Reason (optional)'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () {
            final reason = reasonController.text.trim();
            roomSocket.banUser(userId, reason: reason.isEmpty ? null : reason);
            Navigator.of(dialogContext).pop();
          },
          child: const Text('Ban'),
        ),
      ],
    ),
  );
}

Future<void> _promptWarn(
  BuildContext context,
  RoomSocketService roomSocket,
  String userId,
  String name,
) async {
  final reasonController = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Warn $name'),
      content: TextField(
        controller: reasonController,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Reason for the warning'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final reason = reasonController.text.trim();
            if (reason.isEmpty) return;
            roomSocket.warnUser(userId, reason);
            Navigator.of(dialogContext).pop();
          },
          child: const Text('Send Warning'),
        ),
      ],
    ),
  );
}
