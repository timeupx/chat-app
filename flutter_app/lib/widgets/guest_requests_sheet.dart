import 'dart:async';

import 'package:flutter/material.dart';

import '../models/guest_request_model.dart';
import '../services/room_socket_service.dart';

/// Host-only panel listing pending "request to be guest" viewers, with
/// Accept/Reject actions. Backed live by [RoomSocketService.guestRequests].
class GuestRequestsSheet extends StatefulWidget {
  const GuestRequestsSheet({super.key});

  @override
  State<GuestRequestsSheet> createState() => _GuestRequestsSheetState();
}

class _GuestRequestsSheetState extends State<GuestRequestsSheet> {
  final _roomSocket = RoomSocketService.instance;
  List<GuestRequestModel> _requests = [];
  StreamSubscription<List<GuestRequestModel>>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = _roomSocket.guestRequests.listen((requests) {
      if (mounted) setState(() => _requests = requests);
    });
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
                  'Guest Requests',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              Expanded(
                child: _requests.isEmpty
                    ? const Center(
                        child: Text('No pending requests', style: TextStyle(color: Colors.white54)),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _requests.length,
                        itemBuilder: (context, index) {
                          final request = _requests[index];
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(request.name.isNotEmpty ? request.name[0].toUpperCase() : '?'),
                            ),
                            title: Text(request.name, style: const TextStyle(color: Colors.white)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.check_circle, color: Colors.green),
                                  tooltip: 'Accept',
                                  onPressed: () => _roomSocket.acceptGuestRequest(request.userId),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.cancel, color: Colors.red),
                                  tooltip: 'Reject',
                                  onPressed: () => _roomSocket.rejectGuestRequest(request.userId),
                                ),
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
