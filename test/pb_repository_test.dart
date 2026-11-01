import 'package:clothing_shop/core/api_client.dart';
import 'package:clothing_shop/core/api_exceptions.dart';
import 'package:clothing_shop/models/list_query.dart';
import 'package:clothing_shop/repositories/pb/pb_repositories.dart';
import 'package:clothing_shop/repositories/pb/pb_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_adapter.dart';

Dio _dio(FakeAdapter adapter) {
  final dio = buildDio(baseUrl: 'http://test/api');
  dio.httpClientAdapter = adapter;
  return dio;
}

Map<String, dynamic> _page(List<Map<String, dynamic>> items, {int total = 0}) =>
    {
      'page': 1,
      'perPage': 10,
      'totalItems': total == 0 ? items.length : total,
      'totalPages': 1,
      'items': items,
    };

void main() {
  test('pbQuote экранирует кавычки: поиск не ломает фильтр', () {
    expect(pbQuote('джинсы'), '"джинсы"');
    expect(pbQuote('a"b'), r'"a\"b"');
    expect(pbQuote(r'a\b'), r'"a\\b"');
  });

  group('фильтры товаров выполняет сервер', () {
    final repo =
        PbProductRepository(_dio(FakeAdapter((_) => FakeAdapter.json({}))));

    test('без условий скрываются только удалённые', () {
      expect(repo.buildFilter(const ListQuery()), 'deleted = false');
    });

    test('поиск, категория, цена, размер и наличие складываются через &&', () {
      final q = const ListQuery()
          .copyWith(search: 'куртка')
          .withFilter('category', 'abc')
          .withFilter('priceFrom', '2000')
          .withFilter('priceTo', '9000')
          .withFilter('size', 'M')
          .withFilter('inStock', '1');
      final f = repo.buildFilter(q)!;
      expect(f, contains('deleted = false'));
      expect(f, contains('name ~ "куртка"'));
      expect(f, contains('category = "abc"'));
      expect(f, contains('price >= 2000'));
      expect(f, contains('price <= 9000'));
      expect(f, contains('product_variants_via_product.size ?= "M"'));
      expect(f, contains('product_variants_via_product.stock ?> 0'));
    });

    test('нечисловая цена игнорируется, а не попадает в запрос', () {
      final f = repo
          .buildFilter(const ListQuery().withFilter('priceFrom', '1;drop'))!;
      expect(f, isNot(contains('price')));
    });

    test('режим «удалённые» показывает и удалённые записи', () {
      expect(repo.buildFilter(const ListQuery(includeDeleted: true)), isNull);
    });
  });

  test('заказы: период, статус и клиент превращаются в фильтр', () {
    final repo =
        PbOrderRepository(_dio(FakeAdapter((_) => FakeAdapter.json({}))));
    final q = const ListQuery()
        .withFilter('status', 'paid')
        .withFilter('customer', 'u1')
        .withFilter('dateFrom', '2026-10-01')
        .withFilter('dateTo', '2026-10-31');
    final f = repo.buildFilter(q)!;
    expect(f, contains('status = "paid"'));
    expect(f, contains('user = "u1"'));
    expect(f, contains('ordered_at >= "2026-10-01 00:00:00"'));
    expect(f, contains('ordered_at <= "2026-10-31 23:59:59"'));
  });

  test(
      'find отправляет page, perPage, sort, filter, expand и читает totalItems',
      () async {
    final adapter = FakeAdapter((o) => FakeAdapter.json(_page([
          {
            'id': 'p1',
            'name': 'Джинсы',
            'price': 3990,
            'category': 'c1',
            'brand': 'b1',
            'expand': {
              'category': {'id': 'c1', 'name': 'Джинсы'},
              'brand': {'id': 'b1', 'name': 'Denim Co'},
            },
          }
        ], total: 25)));
    final repo = PbProductRepository(_dio(adapter));
    final page = await repo.find(
      const ListQuery(defaultSort: 'name')
          .copyWith(sort: '-price', perPage: 25),
    );
    final r = adapter.requests.single;
    expect(r.path, '/collections/products/records');
    expect(r.queryParameters['perPage'], 25);
    expect(r.queryParameters['sort'], '-price');
    expect(r.queryParameters['expand'], 'category,brand');
    expect(page.totalItems, 25);
    expect(page.items.single.brandName, 'Denim Co');
  });

  test('мягкое удаление — PATCH deleted=true, а не DELETE', () async {
    final adapter =
        FakeAdapter((o) => FakeAdapter.json({'id': 'c1', 'deleted': true}));
    await PbCategoryRepository(_dio(adapter)).softDelete('c1');
    expect(adapter.requests.single.method, 'PATCH');
    expect(adapter.requests.single.data, {'deleted': true});
  });

  test('у сущности без поля deleted «удалить» — физическое удаление', () async {
    final adapter = FakeAdapter((o) => ResponseBody.fromString('', 204));
    await PbAddressRepository(_dio(adapter)).softDelete('a1');
    expect(adapter.requests.single.method, 'DELETE');
  });

  test('ошибка валидации сервера приходит как ValidationException', () async {
    final adapter = FakeAdapter((o) => FakeAdapter.json({
          'status': 400,
          'message': 'Failed to create record.',
          'data': {
            'sku': {'code': 'validation_not_unique', 'message': 'dup'},
          },
        }, status: 400));
    final repo = PbProductRepository(_dio(adapter));
    await expectLater(
      repo.create({'sku': 'TS-1001'}),
      throwsA(isA<ValidationException>().having(
        (e) => e.errors['sku'],
        'ошибка поля sku',
        'Такое значение уже существует',
      )),
    );
  });

  test('карточка несуществующей записи — null, а не исключение', () async {
    final adapter = FakeAdapter((o) => FakeAdapter.json(
        {'status': 404, 'message': 'not found', 'data': {}},
        status: 404));
    expect(await PbProductRepository(_dio(adapter)).findById('zzz'), isNull);
  });

  test('недоступный сервер превращается в NetworkException', () async {
    final adapter = FakeAdapter((o) => throw DioException(
          requestOptions: o,
          type: DioExceptionType.connectionError,
        ));
    // повторы чтения замедлили бы тест: проверяем запись
    await expectLater(
      PbProductRepository(_dio(adapter)).create({'name': 'x'}),
      throwsA(isA<NetworkException>()),
    );
  });
}
