import 'package:clothing_shop/core/labels.dart';
import 'package:clothing_shop/core/pricing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('calcTotals', () {
    test('без карты скидки нет', () {
      final t = calcTotals(subtotal: 10000, deliveryPrice: 350);
      expect(t.discount, 0);
      expect(t.total, 10350);
    });

    test('скидка зависит от уровня карты и считается от товаров', () {
      expect(
        calcTotals(subtotal: 10000, deliveryPrice: 300, tier: 'bronze').total,
        10000,
      );
      expect(
        calcTotals(subtotal: 10000, deliveryPrice: 300, tier: 'silver')
            .discount,
        500,
      );
      expect(
        calcTotals(subtotal: 10000, deliveryPrice: 300, tier: 'gold').total,
        9600,
      );
    });

    test('скидка округляется вниз до рубля', () {
      expect(
        calcTotals(subtotal: 1990, deliveryPrice: 0, tier: 'bronze').discount,
        59,
      );
    });
  });

  test('rub разделяет разряды неразрывным пробелом', () {
    expect(rub(12990), '12 990 ₽');
    expect(rub(990), '990 ₽');
  });

  test('заказ нельзя вернуть в прошлый статус', () {
    expect(orderNextStatuses['new'], contains('paid'));
    expect(orderNextStatuses['delivered'], isEmpty);
    expect(orderNextStatuses['shipped'], isNot(contains('cancelled')));
  });
}
