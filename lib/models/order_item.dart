import 'json_utils.dart';

/// Позиция заказа: связь «многие ко многим» между заказом и вариантом товара
/// с атрибутами «количество» и «цена на момент покупки».
class OrderItem {
  final String id;
  final String orderId;
  final String variantId;
  final String productName;
  final String variantLabel;
  final int quantity;
  final int price;

  const OrderItem({
    required this.id,
    required this.orderId,
    required this.variantId,
    this.productName = '',
    this.variantLabel = '',
    required this.quantity,
    required this.price,
  });

  int get sum => quantity * price;

  factory OrderItem.fromJson(Map<String, dynamic> j) {
    final variant = jsonExpand(j, 'variant') ?? {};
    final product = jsonExpand(variant, 'product') ?? {};
    final size = jsonStr(variant, 'size');
    final color = jsonStr(variant, 'color');
    return OrderItem(
      id: jsonStr(j, 'id'),
      orderId: jsonStr(j, 'order'),
      variantId: jsonStr(j, 'variant'),
      productName: jsonStr(product, 'name'),
      variantLabel: size.isEmpty ? '' : '$size, $color',
      quantity: jsonInt(j, 'quantity'),
      price: jsonInt(j, 'price'),
    );
  }
}
