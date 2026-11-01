import 'json_utils.dart';

class Brand {
  final String id;
  final String name;
  final String country;
  final String description;
  final bool deleted;

  const Brand({
    required this.id,
    required this.name,
    required this.country,
    this.description = '',
    this.deleted = false,
  });

  factory Brand.fromJson(Map<String, dynamic> j) => Brand(
        id: jsonStr(j, 'id'),
        name: jsonStr(j, 'name'),
        country: jsonStr(j, 'country'),
        description: jsonStr(j, 'description'),
        deleted: jsonBool(j, 'deleted'),
      );
}
