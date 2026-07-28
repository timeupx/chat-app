/// A user currently banned from a room, as seen by the host's Banned Users
/// panel. Comes from the `room:joined` snapshot (isHost) and the
/// `room:bannedListUpdated` socket event after any ban/unban.
class BannedUserModel {
  final String userId;
  final String name;
  final String? reason;
  final DateTime bannedAt;

  const BannedUserModel({
    required this.userId,
    required this.name,
    required this.reason,
    required this.bannedAt,
  });

  factory BannedUserModel.fromJson(Map<String, dynamic> json) {
    return BannedUserModel(
      userId: json['userId'] as String,
      name: json['name'] as String,
      reason: json['reason'] as String?,
      bannedAt: DateTime.tryParse(json['bannedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
