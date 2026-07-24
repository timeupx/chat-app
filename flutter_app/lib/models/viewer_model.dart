/// A participant in a live room, as seen by the host's moderation panel
/// (viewer list). Comes from the `room:viewerListUpdated` socket event -
/// never mocked, since moderation state must be real.
class ViewerModel {
  final String userId;
  final String name;
  final bool isMuted; // chat-mute only, never mic/cam
  final bool isGuest;

  const ViewerModel({
    required this.userId,
    required this.name,
    required this.isMuted,
    required this.isGuest,
  });

  factory ViewerModel.fromJson(Map<String, dynamic> json) {
    return ViewerModel(
      userId: json['userId'] as String,
      name: json['name'] as String,
      isMuted: json['isMuted'] as bool? ?? false,
      isGuest: json['isGuest'] as bool? ?? false,
    );
  }
}
