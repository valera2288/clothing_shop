import 'json_utils.dart';

/// Карта лояльности: у пользователя не больше одной (связь 1:1).
class LoyaltyCard {
  final String id;
  final String userId;
  final String userName;
  final String number;
  final String tier;
  final int points;

  const LoyaltyCard({
    required this.id,
    required this.userId,
    this.userName = '',
    required this.number,
    required this.tier,
    required this.points,
  });

  factory LoyaltyCard.fromJson(Map<String, dynamic> j) => LoyaltyCard(
        id: jsonStr(j, 'id'),
        userId: jsonStr(j, 'user'),
        userName: jsonStr(jsonExpand(j, 'user') ?? {}, 'name'),
        number: jsonStr(j, 'number'),
        tier: jsonStr(j, 'tier'),
        points: jsonInt(j, 'points'),
      );
}
