import 'package:clothing_shop/models/list_query.dart';
import 'package:flutter_test/flutter_test.dart';

const _keys = {'category', 'priceFrom', 'size'};

void main() {
  test('адрес разбирается в условия выборки', () {
    final q = ListQuery.fromUri(
      Uri.parse(
        '/products?q=джинсы&category=c1&priceFrom=3000&sort=-price&page=2&perPage=25',
      ),
      filterKeys: _keys,
      defaultSort: 'name',
    );
    expect(q.search, 'джинсы');
    expect(q.filters, {'category': 'c1', 'priceFrom': '3000'});
    expect(q.sortField, 'price');
    expect(q.sortAscending, isFalse);
    expect(q.page, 2);
    expect(q.perPage, 25);
  });

  test('значения по умолчанию в адрес не попадают', () {
    const q = ListQuery(defaultSort: 'name');
    expect(q.toQueryParameters(), isEmpty);
  });

  test('адрес и запрос обратимы: ссылку можно передать', () {
    final original = const ListQuery(defaultSort: 'name')
        .copyWith(search: 'куртка')
        .withFilter('size', 'M')
        .withFilter('priceFrom', '1000')
        .copyWith(sort: '-price');
    final uri =
        Uri(path: '/products', queryParameters: original.toQueryParameters());
    final restored =
        ListQuery.fromUri(uri, filterKeys: _keys, defaultSort: 'name');
    expect(restored, original);
  });

  test('посторонние параметры и неизвестная сортировка отбрасываются', () {
    final q = ListQuery.fromUri(
      Uri.parse('/products?evil=1&sort=password&perPage=9999'),
      filterKeys: _keys,
      defaultSort: 'name',
      sortFields: {'name', 'price'},
    );
    expect(q.filters, isEmpty);
    expect(q.sort, 'name');
    expect(q.perPage, 10);
  });

  test('смена условий возвращает на первую страницу', () {
    final q = const ListQuery(defaultSort: 'name').withPage(4);
    expect(q.page, 4);
    expect(q.withFilter('size', 'L').page, 1);
    expect(q.copyWith(search: 'x').page, 1);
  });

  test('пустое значение снимает фильтр', () {
    final q = const ListQuery().withFilter('size', 'M').withFilter('size', '');
    expect(q.filters, isEmpty);
  });

  test('повторный клик по колонке меняет направление сортировки', () {
    const q = ListQuery(defaultSort: 'name');
    final desc = q.withSortField('name');
    expect(desc.sort, '-name');
    expect(desc.withSortField('name').sort, 'name');
  });
}
