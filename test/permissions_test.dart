import 'package:clothing_shop/core/permissions.dart';
import 'package:clothing_shop/core/router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('у каждой роли есть право, которого нет у остальных', () {
    for (final role in Role.values) {
      final others = Role.values
          .where((r) => r != role)
          .expand((r) => rolePermissions[r]!)
          .toSet();
      final own = rolePermissions[role]!.difference(others);
      expect(own, isNotEmpty,
          reason: 'у роли ${role.name} нет уникальных прав');
    }
  });

  test('покупатель не управляет каталогом и пользователями', () {
    expect(roleCan(Role.customer, Permission.manageCatalog), isFalse);
    expect(roleCan(Role.customer, Permission.manageUsers), isFalse);
    expect(roleCan(Role.customer, Permission.useCart), isTrue);
  });

  test('менеджер ведёт заказы, но не видит корзину и статистику', () {
    expect(roleCan(Role.manager, Permission.manageOrders), isTrue);
    expect(roleCan(Role.manager, Permission.useCart), isFalse);
    expect(roleCan(Role.manager, Permission.viewStats), isFalse);
  });

  test('администратор не ведёт чужие заказы', () {
    expect(roleCan(Role.admin, Permission.manageOrders), isFalse);
    expect(roleCan(Role.admin, Permission.manageUsers), isTrue);
  });

  test('без роли прав нет, незнакомая роль считается покупателем', () {
    expect(roleCan(null, Permission.viewCatalog), isFalse);
    expect(Role.fromCode('root'), Role.customer);
    expect(Role.fromCode(null), Role.customer);
    expect(Role.fromCode('admin'), Role.admin);
  });

  group('authRedirect', () {
    test('гость уходит на вход с запоминанием адреса', () {
      final r = authRedirect(
        loggedIn: false,
        uri: Uri.parse('/orders?status=new'),
        matched: '/orders',
      );
      expect(r, '/login?from=${Uri.encodeComponent('/orders?status=new')}');
    });

    test('вошедший со страницы входа возвращается на исходный адрес', () {
      final r = authRedirect(
        loggedIn: true,
        uri: Uri.parse('/login?from=%2Fproducts%3Fsize%3DM'),
        matched: '/login',
      );
      expect(r, '/products?size=M');
    });

    test('внешний адрес в from игнорируется', () {
      final r = authRedirect(
        loggedIn: true,
        uri: Uri.parse('/login?from=//evil.example'),
        matched: '/login',
      );
      expect(r, '/');
    });
  });
}
