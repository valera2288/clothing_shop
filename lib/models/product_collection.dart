import 'json_utils.dart';

/// Коллекция (сезонная подборка). Связь с товарами «многие ко многим»:
/// идентификаторы товаров хранятся в поле `products`.
class ProductCollection {
  final String id;
  final String title;
  final String season;
  final int year;
  final String description;
  final List<String> productIds;
  final bool deleted;

  const ProductCollection({
    required this.id,
    required this.title,
    required this.season,
    required this.year,
    this.description = '',
    this.productIds = const [],
    this.deleted = false,
  });

  factory ProductCollection.fromJson(Map<String, dynamic> j) =>
      ProductCollection(
        id: jsonStr(j, 'id'),
        title: jsonStr(j, 'title'),
        season: jsonStr(j, 'season'),
        year: jsonInt(j, 'year'),
        description: jsonStr(j, 'description'),
        productIds: jsonIds(j, 'products'),
        deleted: jsonBool(j, 'deleted'),
      );
}
