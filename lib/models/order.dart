import 'address.dart';
import 'json_utils.dart';

/// Заказ: N:1 к покупателю, адресу и способу доставки.
class Order {
  final String id;
  final String userId;
  final String userName;
  final String addressId;
  final Address? address;
  final String deliveryMethodId;
  final String deliveryMethodName;
  final String status;
  final String payment;
  final int total;
  final DateTime? orderedAt;
  final String comment;

  const Order({
    required this.id,
    required this.userId,
    this.userName = '',
    required this.addressId,
    this.address,
    required this.deliveryMethodId,
    this.deliveryMethodName = '',
    required this.status,
    required this.payment,
    required this.total,
    this.orderedAt,
    this.comment = '',
  });

  /// Короткий номер для списков: последние 6 символов идентификатора.
  String get number => '№${id.substring(id.length > 6 ? id.length - 6 : 0)}';

  factory Order.fromJson(Map<String, dynamic> j) {
    final addr = jsonExpand(j, 'address');
    return Order(
      id: jsonStr(j, 'id'),
      userId: jsonStr(j, 'user'),
      userName: jsonStr(jsonExpand(j, 'user') ?? {}, 'name'),
      addressId: jsonStr(j, 'address'),
      address: addr == null ? null : Address.fromJson(addr),
      deliveryMethodId: jsonStr(j, 'delivery_method'),
      deliveryMethodName:
          jsonStr(jsonExpand(j, 'delivery_method') ?? {}, 'name'),
      status: jsonStr(j, 'status'),
      payment: jsonStr(j, 'payment'),
      total: jsonInt(j, 'total'),
      orderedAt: jsonDate(j, 'ordered_at'),
      comment: jsonStr(j, 'comment'),
    );
  }
}
