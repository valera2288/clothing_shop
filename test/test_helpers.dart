import 'package:clothing_shop/core/permissions.dart';
import 'package:clothing_shop/models/app_user.dart';
import 'package:clothing_shop/models/list_query.dart';
import 'package:clothing_shop/models/page_result.dart';
import 'package:clothing_shop/models/product.dart';
import 'package:clothing_shop/repositories/auth_repository.dart';
import 'package:clothing_shop/repositories/entity_repository.dart';
import 'package:clothing_shop/state/auth_notifier.dart';
import 'package:flutter_test/flutter_test.dart' show addTearDown;
import 'package:shared_preferences/shared_preferences.dart';

/// Репозиторий товаров для тестов экранов: ответ задаёт тест.
class FakeProducts implements ProductRepository {
  Future<PageResult<Product>> Function(ListQuery query) onFind;
  final List<ListQuery> queries = [];

  FakeProducts(this.onFind);

  @override
  Future<PageResult<Product>> find(ListQuery query) {
    queries.add(query);
    return onFind(query);
  }

  @override
  Future<List<Product>> findAll() async => const [];
  @override
  Future<Product?> findById(String id) async => null;
  @override
  Future<Product> create(Map<String, dynamic> body) =>
      throw UnimplementedError();
  @override
  Future<Product> update(String id, Map<String, dynamic> body) =>
      throw UnimplementedError();
  @override
  Future<void> softDelete(String id) async {}
  @override
  Future<void> hardDelete(String id) async {}
  @override
  Future<void> restore(String id) async {}
  @override
  Future<int> deleteMany(List<String> ids) async => ids.length;
}

Product product(String id, String name, {int price = 1000}) => Product(
      id: id,
      name: name,
      sku: 'TS-$id',
      price: price,
      categoryId: 'c',
      categoryName: 'Футболки',
      brandId: 'b',
      brandName: 'Urban Line',
      gender: 'unisex',
      active: true,
    );

PageResult<Product> pageOf(List<Product> items) => PageResult(
      items: items,
      page: 1,
      perPage: 10,
      totalItems: items.length,
    );

/// Вход без сервера: репозиторий авторизации возвращает пользователя с ролью.
class FakeAuthRepository implements AuthRepository {
  final Role role;
  final Object? failWith;
  FakeAuthRepository(this.role, {this.failWith});

  AuthResult _result() => AuthResult(
        'token',
        AppUser(id: 'u1', email: 'a@shop.test', name: 'Тест', role: role),
      );

  @override
  Future<AuthResult> login(String email, String password) async {
    if (failWith != null) throw failWith!;
    return _result();
  }

  @override
  Future<AppUser> register({
    required String email,
    required String password,
    required String name,
    String phone = '',
  }) async =>
      _result().user;

  @override
  Future<AuthResult> refresh(String token) async => _result();

  @override
  Future<void> logout(String token) async {}
}

Future<AuthNotifier> signedIn(Role? role, {Object? failWith}) async {
  SharedPreferences.setMockInitialValues({});
  final auth = AuthNotifier(await SharedPreferences.getInstance())
    ..sessionTimerEnabled = false;
  auth.repository =
      FakeAuthRepository(role ?? Role.customer, failWith: failWith);
  if (role != null) await auth.login('a@shop.test', 'x');
  addTearDown(auth.dispose);
  return auth;
}
