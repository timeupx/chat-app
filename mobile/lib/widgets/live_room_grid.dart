import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

import '../models/video_filter_settings.dart';
import 'user_slot_widget.dart';

/// Phone-like stage width so Chrome / wide desktops don't stretch seats
/// across the whole monitor.
const double _kMaxStageWidth = 420;

/// Data needed to render one occupied seat in [LiveRoomGrid]. Passing
/// `null` for a seat means "seat is empty" - [UserSlotWidget] then renders
/// a tappable "Join" seat.
class LiveGridSlotData {
  final String userId;
  final String name;
  final String? avatarUrl;
  final VideoTrack? videoTrack;
  final bool isMicMuted;
  final int giftCount;
  final int? level;
  final bool isVip;
  final bool isSvip;

  /// Extra control pinned to this seat's bottom-right corner - e.g. this
  /// viewer's own mic mute toggle on their own seat once they're a guest.
  final Widget? trailing;

  /// Optional beauty filters for the host camera tile.
  final VideoFilterSettings? videoFilters;

  /// Soft blur for local host preview only — remote tiles skip blur.
  final bool enableFilterBlur;

  const LiveGridSlotData({
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.videoTrack,
    this.isMicMuted = false,
    this.giftCount = 0,
    this.level,
    this.isVip = false,
    this.isSvip = false,
    this.trailing,
    this.videoFilters,
    this.enableFilterBlur = true,
  });
}

/// Camera seat grid:
///
/// - **3** → host left, seats 2–3 stacked right (host wider)
/// - **6** → same top block + seats 4–6 bottom row
/// - **9** → equal 3×3 grid (every seat the same size)
class LiveRoomGrid extends StatelessWidget {
  /// Total seats on stage. Must be 3, 6, or 9.
  final int slotCount;

  /// Length must equal [slotCount]. Index 0 = seat 1 (host), etc.
  final List<LiveGridSlotData?> slots;

  /// Extra control rendered on the host's own seat (slot 1).
  final Widget? hostTrailing;

  /// Optional key on seat 1 so gift fly animations can target the host.
  final GlobalKey? hostSlotKey;

  /// Drawn flush under the visual grid (same width) — e.g. gift nickname toast.
  final Widget? footer;

  final void Function(LiveGridSlotData slot)? onTapSlot;
  final void Function(int slotNumber)? onTapEmptySlot;

  const LiveRoomGrid({
    super.key,
    required this.slotCount,
    required this.slots,
    this.hostTrailing,
    this.hostSlotKey,
    this.footer,
    this.onTapSlot,
    this.onTapEmptySlot,
  }) : assert(
         slotCount == 3 || slotCount == 6 || slotCount == 9,
         'slotCount must be 3, 6, or 9',
       ),
       assert(
         slots.length == slotCount,
         'slots length must equal slotCount',
       );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Cap to phone width; also shrink if the stage area is short.
        final cappedW = math.min(constraints.maxWidth, _kMaxStageWidth);
        final maxH = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : cappedW * 1.2;
        final stageW = switch (slotCount) {
          // 9 → height 3s, width 3s  → s ≤ maxH/3
          9 => math.min(cappedW, maxH),
          // 6 → height 3s, width 3s
          6 => math.min(cappedW, maxH),
          // 3 → height ≈ 0.76 * w
          _ => math.min(cappedW, maxH / 0.76),
        };
        final grid = switch (slotCount) {
          9 => _buildEqualNine(stageW),
          6 => _buildSix(stageW),
          _ => _buildThree(stageW),
        };
        // Align sizes to parent; Column(min) keeps toast glued under the
        // real seat block (not the full Expanded height).
        return Align(
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              grid,
              if (footer != null)
                SizedBox(
                  width: stageW,
                  height: 52,
                  child: footer,
                ),
            ],
          ),
        );
      },
    );
  }

  /// 9 seats — flush equal squares in a 3×3 grid.
  Widget _buildEqualNine(double maxW) {
    final s = maxW / 3;
    return SizedBox(
      width: maxW,
      height: 3 * s,
      child: Column(
        children: [
          for (var r = 0; r < 3; r++)
            SizedBox(
              height: s,
              child: Row(
                children: [
                  for (var c = 0; c < 3; c++)
                    SizedBox(
                      width: s,
                      height: s,
                      child: _seat(r * 3 + c + 1),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 6 seats — unit grid so top + bottom columns align (no messy gaps):
  /// host 2×2, seats 2–3 stacked, seats 4–6 bottom row.
  Widget _buildSix(double maxW) {
    final s = maxW / 3;
    final host = 2 * s;
    return SizedBox(
      width: maxW,
      height: host + s,
      child: Column(
        children: [
          SizedBox(
            height: host,
            child: Row(
              children: [
                SizedBox(width: host, height: host, child: _seat(1)),
                SizedBox(
                  width: s,
                  height: host,
                  child: Column(
                    children: [
                      SizedBox(width: s, height: s, child: _seat(2)),
                      SizedBox(width: s, height: s, child: _seat(3)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: s,
            child: Row(
              children: [
                for (var c = 0; c < 3; c++)
                  SizedBox(width: s, height: s, child: _seat(4 + c)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 3 seats — host left (slightly narrower), guests 2–3 larger on right.
  Widget _buildThree(double maxW) {
    final guestS = maxW * 0.38;
    final hostW = maxW - guestS;
    final topH = 2 * guestS;

    return SizedBox(
      width: maxW,
      height: topH,
      child: Row(
        children: [
          SizedBox(width: hostW, height: topH, child: _seat(1)),
          SizedBox(
            width: guestS,
            height: topH,
            child: Column(
              children: [
                SizedBox(width: guestS, height: guestS, child: _seat(2)),
                SizedBox(width: guestS, height: guestS, child: _seat(3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _seat(int slotNumber) {
    final data = slots[slotNumber - 1];
    final Widget seat;
    if (data == null) {
      seat = UserSlotWidget(
        slotNumber: slotNumber,
        isEmpty: true,
        onJoin: onTapEmptySlot == null
            ? null
            : () => onTapEmptySlot!(slotNumber),
      );
    } else {
      seat = UserSlotWidget(
        slotNumber: slotNumber,
        isHost: slotNumber == 1,
        name: data.name,
        avatarUrl: data.avatarUrl,
        videoTrack: data.videoTrack,
        isMicMuted: data.isMicMuted,
        giftCount: data.giftCount,
        level: data.level,
        isVip: data.isVip,
        isSvip: data.isSvip,
        videoFilters: data.videoFilters,
        enableFilterBlur: data.enableFilterBlur,
        trailing: slotNumber == 1
            ? (hostTrailing ?? data.trailing)
            : data.trailing,
        onTap: onTapSlot == null ? null : () => onTapSlot!(data),
      );
    }
    if (slotNumber == 1 && hostSlotKey != null) {
      return KeyedSubtree(key: hostSlotKey, child: seat);
    }
    return seat;
  }
}
