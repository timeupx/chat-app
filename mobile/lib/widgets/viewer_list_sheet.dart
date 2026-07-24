import 'dart:async';

import 'package:flutter/material.dart';

import '../models/viewer_model.dart';
import '../services/room_socket_service.dart';

/// Host-only moderation panel: current viewers with Ban / Chat Mute / Warn /
/// Invite-as-Guest actions. Backed live by [RoomSocketService.viewerList] -
/// nothing here is mocked.
class ViewerListSheet extends StatefulWidget {
  const ViewerListSheet({super.key});

  @override
  State<ViewerListSheet> createState() => _ViewerListSheetState();
}

class _ViewerListSheetState extends State<ViewerListSheet> {
  final _roomSocket = RoomSocketService.instance;
  List<ViewerModel> _viewers = [];
  StreamSubscription<List<ViewerModel>>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = _roomSocket.viewerList.listen((viewers) {
      if (mounted) setState(() => _viewers = viewers);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _promptBan(ViewerModel viewer) async {
    final reasonController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Ban ${viewer.name}?'),
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
              _roomSocket.banUser(viewer.userId, reason: reason.isEmpty ? null : reason);
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Ban'),
          ),
        ],
      ),
    );
  }

  Future<void> _promptWarn(ViewerModel viewer) async {
    final reasonController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Warn ${viewer.name}'),
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
              _roomSocket.warnUser(viewer.userId, reason);
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Send Warning'),
          ),
        ],
      ),
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
                  'Viewers',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              Expanded(
                child: _viewers.isEmpty
                    ? const Center(
                        child: Text('No viewers yet', style: TextStyle(color: Colors.white54)),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _viewers.length,
                        itemBuilder: (context, index) {
                          final viewer = _viewers[index];
                          final tags = [
                            if (viewer.isGuest) 'Guest',
                            if (viewer.isMuted) 'Chat muted',
                          ].join(' • ');

                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(viewer.name.isNotEmpty ? viewer.name[0].toUpperCase() : '?'),
                            ),
                            title: Text(viewer.name, style: const TextStyle(color: Colors.white)),
                            subtitle: tags.isEmpty
                                ? null
                                : Text(tags, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            trailing: PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, color: Colors.white),
                              onSelected: (action) {
                                switch (action) {
                                  case 'ban':
                                    _promptBan(viewer);
                                  case 'mute':
                                    _roomSocket.chatMuteUser(viewer.userId);
                                  case 'unmute':
                                    _roomSocket.chatUnmuteUser(viewer.userId);
                                  case 'warn':
                                    _promptWarn(viewer);
                                  case 'invite':
                                    _roomSocket.inviteGuest(viewer.userId);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: 'ban', child: Text('Ban')),
                                PopupMenuItem(
                                  value: viewer.isMuted ? 'unmute' : 'mute',
                                  child: Text(viewer.isMuted ? 'Chat Unmute' : 'Chat Mute'),
                                ),
                                const PopupMenuItem(value: 'warn', child: Text('Warn')),
                                if (!viewer.isGuest)
                                  const PopupMenuItem(value: 'invite', child: Text('Invite as Guest')),
                              ],
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
