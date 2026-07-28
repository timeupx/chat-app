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

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'coinCost': coinCost,
      };

  factory GiftModel.fromJson(Map<String, dynamic> json) {
    return GiftModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Gift',
      emoji: json['emoji'] as String? ?? '🎁',
      coinCost: (json['coinCost'] as num?)?.toInt() ?? 0,
    );
  }

  static const List<GiftModel> mockGifts = [
    GiftModel(id: 'g1', name: 'Heart', emoji: '❤️', coinCost: 10),
    GiftModel(id: 'g2', name: 'Rose', emoji: '🌹', coinCost: 50),
    GiftModel(id: 'g3', name: 'Kiss', emoji: '💋', coinCost: 99),
    GiftModel(id: 'g4', name: 'Diamond', emoji: '💎', coinCost: 500),
    GiftModel(id: 'g5', name: 'Crown', emoji: '👑', coinCost: 1200),
    GiftModel(id: 'g6', name: 'Car', emoji: '🚗', coinCost: 5000),
  ];
}
