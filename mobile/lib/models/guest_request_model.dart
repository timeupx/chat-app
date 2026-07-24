/// A pending "request to be guest" from a viewer, shown in the host's
/// Guest Requests panel. Comes from the `guest:requestListUpdated` socket
/// event.
class GuestRequestModel {
  final String userId;
  final String name;

  const GuestRequestModel({required this.userId, required this.name});

  factory GuestRequestModel.fromJson(Map<String, dynamic> json) {
    return GuestRequestModel(
      userId: json['userId'] as String,
      name: json['name'] as String,
    );
  }
}
