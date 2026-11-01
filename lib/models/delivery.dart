import 'json_utils.dart';

/// Доставка заказа: у заказа не больше одной (связь 1:1).
class Delivery {
  final String id;
  final String orderId;
  final String carrier;
  final String trackNumber;
  final String status;
  final DateTime? shippedAt;
  final DateTime? eta;

  const Delivery({
    required this.id,
    required this.orderId,
    required this.carrier,
    this.trackNumber = '',
    required this.status,
    this.shippedAt,
    this.eta,
  });

  factory Delivery.fromJson(Map<String, dynamic> j) => Delivery(
        id: jsonStr(j, 'id'),
        orderId: jsonStr(j, 'order'),
        carrier: jsonStr(j, 'carrier'),
        trackNumber: jsonStr(j, 'track_number'),
        status: jsonStr(j, 'status'),
        shippedAt: jsonDate(j, 'shipped_at'),
        eta: jsonDate(j, 'eta'),
      );
}
