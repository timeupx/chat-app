/// A virtual gift a viewer can send to a host, shown in the gift bottom sheet.
class GiftModel {
  final String id;
  final String name;
  final String emoji;
  final int coinCost;

  const GiftModel({
    required this.id,
    required this.name,
    required this.emoji,
    required this.coinCost,
  });

  static const List<GiftModel> mockGifts = [
    GiftModel(id: 'g1', name: 'Heart', emoji: '❤️', coinCost: 10),
    GiftModel(id: 'g2', name: 'Rose', emoji: '🌹', coinCost: 50),
    GiftModel(id: 'g3', name: 'Car', emoji: '🚗', coinCost: 5000),
  ];
}
