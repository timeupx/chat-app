/// A user currently banned from a live room, as shown in the host's
/// Banned Users panel. Comes from the `room:bannedListUpdated` socket
/// event (and the host snapshot on `room:joined`).
class BannedUserModel {
  final String userId;
  final String name;
  final String? reason;
  final DateTime? createdAt;

  const BannedUserModel({
    required this.userId,
    required this.name,
    this.reason,
    this.createdAt,
  });

  factory BannedUserModel.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['createdAt'] as String?;
    return BannedUserModel(
      userId: json['userId'] as String,
      name: json['name'] as String? ?? 'Unknown',
      reason: json['reason'] as String?,
      createdAt: createdAtRaw != null ? DateTime.tryParse(createdAtRaw) : null,
    );
  }
}
