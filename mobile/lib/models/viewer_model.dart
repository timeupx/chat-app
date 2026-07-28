/// A participant in a live room, as seen by the host's moderation panel
/// (viewer list) and the stage slot map. Comes from the
/// `room:viewerListUpdated` socket event - never mocked, since moderation
/// / seat state must be real.
class ViewerModel {
  final String userId;
  final String name;
  final bool isMuted; // chat-mute only, never mic/cam
  final bool isGuest;

  /// 1 = host, 2..slotCount = guests, null = regular viewer (not on stage).
  final int? slotNumber;

  const ViewerModel({
    required this.userId,
    required this.name,
    required this.isMuted,
    required this.isGuest,
    this.slotNumber,
  });

  factory ViewerModel.fromJson(Map<String, dynamic> json) {
    final rawSlot = json['slotNumber'];
    final slotNumber = rawSlot is int
        ? rawSlot
        : int.tryParse('$rawSlot');

    return ViewerModel(
      userId: json['userId'] as String,
      name: json['name'] as String,
      isMuted: json['isMuted'] as bool? ?? false,
      isGuest: json['isGuest'] as bool? ?? false,
      slotNumber: slotNumber,
    );
  }
}
