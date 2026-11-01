import 'labels.dart';

/// Итог заказа: сумма товаров за вычетом скидки по карте лояльности
/// плюс стоимость доставки.
class OrderTotals {
  final int subtotal;
  final int discount;
  final int delivery;
  const OrderTotals(this.subtotal, this.discount, this.delivery);

  int get total => subtotal - discount + delivery;
}

/// [tier] — уровень карты (`bronze`, `silver`, `gold`) или null, если карты нет.
/// Скидка округляется вниз до целого рубля.
OrderTotals calcTotals({
  required int subtotal,
  required int deliveryPrice,
  String? tier,
}) {
  final percent = tier == null ? 0 : (tierDiscount[tier] ?? 0);
  return OrderTotals(subtotal, subtotal * percent ~/ 100, deliveryPrice);
}
