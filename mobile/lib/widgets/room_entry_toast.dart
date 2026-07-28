import 'package:flutter/material.dart';

/// Temporary overlay shown inside a live room when a viewer fully enters:
/// "admin joined" / "rana joined".
class RoomEntryToast extends StatelessWidget {
  final String username;

  const RoomEntryToast({super.key, required this.username});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.center,
        child: AnimatedOpacity(
          opacity: 1,
          duration: const Duration(milliseconds: 200),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              '$username joined',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
