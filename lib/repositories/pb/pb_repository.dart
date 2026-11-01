import 'package:dio/dio.dart';

import '../../core/api_exceptions.dart';
import '../../models/list_query.dart';
import '../../models/page_result.dart';
import '../entity_repository.dart';

/// Экранирование строки для языка фильтров PocketBase: `"текст"`.
String pbQuote(String value) =>
    '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';

/// Общая реализация [EntityRepository] поверх REST API PocketBase.
///
/// Все сущности используют одни и те же адреса
/// (`/collections/<имя>/records`), поэтому код CRUD написан один раз,
/// а наследники задают коллекцию, разбор записи, поля поиска и фильтры.
abstract class PbRepository<T> implements EntityRepository<T> {
  final Dio dio;
  PbRepository(this.dio);

  /// Имя коллекции в PocketBase.
  String get collection;

  /// Связи, которые сервер подставляет в ответ (`expand=category,brand`).
  String get expand => '';

  /// Есть ли у сущности поле `deleted` (мягкое удаление).
  bool get hasSoftDelete => false;

  /// Поля, по которым работает строка поиска.
  List<String> get searchFields => const [];

  T fromJson(Map<String, dynamic> json);

  /// Условия фильтров этой сущности по значениям из [ListQuery.filters].
  List<String> filterParts(ListQuery q) => const [];

  String get _path => '/collections/$collection/records';

  /// Токен последнего запроса списка. Новый запрос отменяет предыдущий:
  /// иначе ответ на «ко» мог бы прийти после ответа на «кофта» и затереть его.
  CancelToken? _pageToken;

  /// Фильтр PocketBase по условиям запроса; null, если условий нет.
  String? buildFilter(ListQuery q) {
    final parts = <String>[
      if (hasSoftDelete && !q.includeDeleted) 'deleted = false',
      if (q.search.trim().isNotEmpty)
        '(${searchFields.map((f) => '$f ~ ${pbQuote(q.search.trim())}').join(' || ')})',
      ...filterParts(q),
    ];
    return parts.isEmpty ? null : parts.join(' && ');
  }

  Map<String, dynamic> _params(ListQuery q) => {
        'page': q.page,
        'perPage': q.perPage,
        'sort': q.sort,
        if (buildFilter(q) != null) 'filter': buildFilter(q),
        if (expand.isNotEmpty) 'expand': expand,
      };

  @override
  Future<PageResult<T>> find(ListQuery query) {
    _pageToken?.cancel('Запрос устарел');
    final token = _pageToken = CancelToken();
    return guard(() async {
      final response = await dio.get<Map<String, dynamic>>(
        _path,
        queryParameters: _params(query),
        cancelToken: token,
      );
      return parsePage(response.data);
    });
  }

  PageResult<T> parsePage(Map<String, dynamic>? data) {
    if (data == null) {
      throw const ServerException('Сервер вернул пустой ответ.');
    }
    return PageResult(
      items: ((data['items'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(fromJson)
          .toList(),
      page: (data['page'] as num?)?.toInt() ?? 1,
      perPage: (data['perPage'] as num?)?.toInt() ?? 10,
      totalItems: (data['totalItems'] as num?)?.toInt() ?? 0,
    );
  }

  /// Все записи, подходящие под [filter], — для выпадающих списков.
  Future<List<T>> findWhere(String? filter, {String sort = '-created'}) =>
      guard(() async {
        final items = <T>[];
        var page = 1;
        while (true) {
          final response = await dio.get<Map<String, dynamic>>(
            _path,
            queryParameters: {
              'page': page,
              'perPage': 200,
              'sort': sort,
              if (filter != null) 'filter': filter,
              if (expand.isNotEmpty) 'expand': expand,
            },
          );
          final result = parsePage(response.data);
          items.addAll(result.items);
          if (!result.hasNext) return items;
          page++;
        }
      });

  @override
  Future<List<T>> findAll() =>
      findWhere(hasSoftDelete ? 'deleted = false' : null, sort: defaultSort);

  /// Порядок для выпадающих списков.
  String get defaultSort => '-created';

  /// Число записей по фильтру без загрузки самих записей.
  Future<int> count([String? filter]) => guard(() async {
        final response = await dio.get<Map<String, dynamic>>(
          _path,
          queryParameters: {
            'page': 1,
            'perPage': 1,
            if (filter != null) 'filter': filter,
          },
        );
        return (response.data?['totalItems'] as num?)?.toInt() ?? 0;
      });

  @override
  Future<T?> findById(String id) async {
    try {
      return await guard(() async {
        final response = await dio.get<Map<String, dynamic>>(
          '$_path/$id',
          queryParameters: {if (expand.isNotEmpty) 'expand': expand},
        );
        return fromJson(response.data!);
      });
    } on NotFoundException {
      return null;
    }
  }

  @override
  Future<T> create(Map<String, dynamic> body) => guard(() async {
        final response = await dio.post<Map<String, dynamic>>(
          _path,
          data: body,
          queryParameters: {if (expand.isNotEmpty) 'expand': expand},
        );
        return fromJson(response.data!);
      });

  @override
  Future<T> update(String id, Map<String, dynamic> body) => guard(() async {
        final response = await dio.patch<Map<String, dynamic>>(
          '$_path/$id',
          data: body,
          queryParameters: {if (expand.isNotEmpty) 'expand': expand},
        );
        return fromJson(response.data!);
      });

  /// Мягкое удаление ставит `deleted = true`. У сущностей без этого поля
  /// «удалить» сразу означает физическое удаление записи.
  @override
  Future<void> softDelete(String id) async {
    if (!hasSoftDelete) return hardDelete(id);
    await update(id, {'deleted': true});
  }

  @override
  Future<void> hardDelete(String id) => guard(() => dio.delete('$_path/$id'));

  @override
  Future<void> restore(String id) async {
    await update(id, {'deleted': false});
  }

  /// PocketBase не удаляет списком, поэтому удаляем по одной записи
  /// и возвращаем число удалённых. Отказ сервера на одной записи
  /// (например, нет прав) прерывает операцию исключением.
  @override
  Future<int> deleteMany(List<String> ids) async {
    var done = 0;
    for (final id in ids) {
      await softDelete(id);
      done++;
    }
    return done;
  }
}
