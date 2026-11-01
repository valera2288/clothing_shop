import 'package:clothing_shop/models/app_user.dart';
import 'package:clothing_shop/models/order.dart';
import 'package:clothing_shop/models/order_item.dart';
import 'package:clothing_shop/models/product.dart';
import 'package:clothing_shop/models/product_variant.dart';
import 'package:clothing_shop/state/cart_notifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _product = Product(
  id: 'p1',
  name: 'Куртка',
  sku: 'JK-3001',
  price: 5000,
  categoryId: 'c',
  brandId: 'b',
  gender: 'unisex',
);

ProductVariant _variant(String id, {int stock = 5}) => ProductVariant(
      id: id,
      productId: 'p1',
      size: 'M',
      color: 'Чёрный',
      stock: stock,
    );

void main() {
  group('корзина', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('одинаковый вариант увеличивает количество, а не дублируется', () {
      final cart = CartNotifier(prefs, 'u1');
      cart.add(_product, _variant('v1'));
      cart.add(_product, _variant('v1'));
      expect(cart.lines, hasLength(1));
      expect(cart.count, 2);
      expect(cart.subtotal, 10000);
    });

    test('нельзя положить больше, чем есть на складе', () {
      final cart = CartNotifier(prefs, 'u1');
      expect(cart.add(_product, _variant('v1', stock: 2)), isTrue);
      expect(cart.add(_product, _variant('v1', stock: 2)), isTrue);
      expect(cart.add(_product, _variant('v1', stock: 2)), isFalse);
      expect(cart.count, 2);
    });

    test('количество 0 убирает строку', () {
      final cart = CartNotifier(prefs, 'u1')..add(_product, _variant('v1'));
      cart.setQuantity('v1', 0);
      expect(cart.isEmpty, isTrue);
    });

    test('корзина переживает перезагрузку и принадлежит пользователю', () {
      CartNotifier(prefs, 'u1').add(_product, _variant('v1'));
      expect(CartNotifier(prefs, 'u1').count, 1);
      expect(CartNotifier(prefs, 'u2').isEmpty, isTrue);
    });

    test('повреждённая запись даёт пустую корзину', () async {
      await prefs.setString('cart_u1', '{не json');
      expect(CartNotifier(prefs, 'u1').isEmpty, isTrue);
    });
  });

  group('модели читают ответ PocketBase', () {
    test('товар берёт названия связей из expand', () {
      final p = Product.fromJson({
        'id': 'p1',
        'name': 'Парка',
        'price': 9990,
        'category': 'c1',
        'brand': 'b1',
        'active': true,
        'expand': {
          'category': {'name': 'Куртки'},
          'brand': {'name': 'Nordic Wear'},
        },
      });
      expect(p.categoryName, 'Куртки');
      expect(p.brandName, 'Nordic Wear');
      expect(p.active, isTrue);
    });

    test('без expand названия пустые, приложение не падает', () {
      final p = Product.fromJson({'id': 'p1', 'name': 'Парка', 'price': 1});
      expect(p.categoryName, '');
    });

    test('позиция заказа достаёт товар через variant.product', () {
      final i = OrderItem.fromJson({
        'id': 'i1',
        'order': 'o1',
        'variant': 'v1',
        'quantity': 2,
        'price': 1000,
        'expand': {
          'variant': {
            'size': 'L',
            'color': 'Синий',
            'expand': {
              'product': {'name': 'Джинсы'},
            },
          },
        },
      });
      expect(i.productName, 'Джинсы');
      expect(i.variantLabel, 'L, Синий');
      expect(i.sum, 2000);
    });

    test('заказ: номер — последние 6 символов, дата разбирается', () {
      final o = Order.fromJson({
        'id': 'abcdefghij12345',
        'user': 'u',
        'address': 'a',
        'delivery_method': 'd',
        'status': 'new',
        'payment': 'card',
        'total': 100,
        'ordered_at': '2026-10-21 04:48:49.000Z',
      });
      expect(o.number, '№j12345');
      expect(o.orderedAt!.year, 2026);
    });

    test('незнакомая роль пользователя не даёт повышения прав', () {
      final u =
          AppUser.fromJson({'id': 'u', 'name': 'X', 'role': 'superadmin'});
      expect(u.role.name, 'customer');
    });
  });
}
