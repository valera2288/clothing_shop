/// Условия выборки списка: поиск, фильтры, сортировка, страница.
///
/// Те же условия лежат в адресе страницы (`/products?q=джинсы&category=...`),
/// поэтому ссылку на отфильтрованный список можно передать. Сервер выполняет
/// отбор сам: клиент получает только одну страницу.
class ListQuery {
  /// Сортировка по умолчанию в формате PocketBase: `-created` — по убыванию.
  final String defaultSort;
  final String search;

  /// Значения фильтров по имени, например `{'category': 'abc', 'priceFrom': '1000'}`.
  final Map<String, String> filters;
  final String sort;
  final int page;
  final int perPage;
  final bool includeDeleted;

  const ListQuery({
    this.defaultSort = '-created',
    this.search = '',
    this.filters = const {},
    String? sort,
    this.page = 1,
    this.perPage = 10,
    this.includeDeleted = false,
  }) : sort = sort ?? defaultSort;

  String get sortField => sort.startsWith('-') ? sort.substring(1) : sort;
  bool get sortAscending => !sort.startsWith('-');

  String? filter(String key) => filters[key];

  ListQuery copyWith({
    String? search,
    Map<String, String>? filters,
    String? sort,
    int? page,
    int? perPage,
    bool? includeDeleted,
  }) =>
      ListQuery(
        defaultSort: defaultSort,
        search: search ?? this.search,
        filters: filters ?? this.filters,
        sort: sort ?? this.sort,
        // Любое изменение условий возвращает на первую страницу
        page: page ?? 1,
        perPage: perPage ?? this.perPage,
        includeDeleted: includeDeleted ?? this.includeDeleted,
      );

  /// Меняет один фильтр; пустое значение снимает его.
  ListQuery withFilter(String key, String? value) {
    final next = Map<String, String>.from(filters);
    if (value == null || value.isEmpty) {
      next.remove(key);
    } else {
      next[key] = value;
    }
    return copyWith(filters: next);
  }

  ListQuery withPage(int newPage) => ListQuery(
        defaultSort: defaultSort,
        search: search,
        filters: filters,
        sort: sort,
        page: newPage,
        perPage: perPage,
        includeDeleted: includeDeleted,
      );

  ListQuery withSortField(String field) {
    final asc = field == sortField ? !sortAscending : true;
    return copyWith(sort: asc ? field : '-$field');
  }

  bool get hasConditions =>
      search.isNotEmpty || filters.isNotEmpty || includeDeleted;

  /// Параметры адресной строки. Значения по умолчанию в адрес не попадают.
  Map<String, String> toQueryParameters() => {
        if (search.isNotEmpty) 'q': search,
        ...filters,
        if (sort != defaultSort) 'sort': sort,
        if (page != 1) 'page': '$page',
        if (perPage != 10) 'perPage': '$perPage',
        if (includeDeleted) 'deleted': '1',
      };

  /// Разбор адреса. Из него берутся только перечисленные [filterKeys]:
  /// посторонние параметры не попадут в запрос к серверу.
  factory ListQuery.fromUri(
    Uri uri, {
    required Set<String> filterKeys,
    String defaultSort = '-created',
    Set<String> sortFields = const {},
  }) {
    final p = uri.queryParameters;
    var sort = p['sort'] ?? defaultSort;
    final field = sort.startsWith('-') ? sort.substring(1) : sort;
    // Сортировать можно только по известным полям
    if (sortFields.isNotEmpty && !sortFields.contains(field)) {
      sort = defaultSort;
    }
    final perPage = int.tryParse(p['perPage'] ?? '') ?? 10;
    return ListQuery(
      defaultSort: defaultSort,
      search: p['q'] ?? '',
      filters: {
        for (final k in filterKeys)
          if ((p[k] ?? '').isNotEmpty) k: p[k]!,
      },
      sort: sort,
      page: (int.tryParse(p['page'] ?? '') ?? 1).clamp(1, 100000),
      perPage: const [10, 25, 50].contains(perPage) ? perPage : 10,
      includeDeleted: p['deleted'] == '1',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ListQuery &&
      search == other.search &&
      sort == other.sort &&
      page == other.page &&
      perPage == other.perPage &&
      includeDeleted == other.includeDeleted &&
      _sameMap(filters, other.filters);

  static bool _sameMap(Map<String, String> a, Map<String, String> b) =>
      a.length == b.length && a.entries.every((e) => b[e.key] == e.value);

  @override
  int get hashCode => Object.hash(
        search,
        sort,
        page,
        perPage,
        includeDeleted,
        Object.hashAllUnordered(
            filters.entries.map((e) => '${e.key}=${e.value}')),
      );
}
