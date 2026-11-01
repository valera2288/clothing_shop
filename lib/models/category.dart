import 'json_utils.dart';

class Category {
  final String id;
  final String name;
  final String slug;
  final String description;
  final bool deleted;

  const Category({
    required this.id,
    required this.name,
    required this.slug,
    this.description = '',
    this.deleted = false,
  });

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: jsonStr(j, 'id'),
        name: jsonStr(j, 'name'),
        slug: jsonStr(j, 'slug'),
        description: jsonStr(j, 'description'),
        deleted: jsonBool(j, 'deleted'),
      );
}
