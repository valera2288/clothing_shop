/// Страница списка в формате PocketBase: `page`, `perPage`, `totalItems`.
class PageResult<T> {
  final List<T> items;
  final int page;
  final int perPage;
  final int totalItems;

  const PageResult({
    required this.items,
    required this.page,
    required this.perPage,
    required this.totalItems,
  });

  int get totalPages => totalItems == 0 ? 1 : (totalItems / perPage).ceil();
  bool get hasPrevious => page > 1;
  bool get hasNext => page < totalPages;

  PageResult.empty()
      : items = <T>[],
        page = 1,
        perPage = 10,
        totalItems = 0;
}
