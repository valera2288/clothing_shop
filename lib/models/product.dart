import 'json_utils.dart';

/// Товар: связан с категорией и брендом (N:1), входит в коллекции (M:N).
class Product {
  final String id;
  final String name;
  final String sku;
  final String description;
  final int price;
  final String categoryId;
  final String categoryName;
  final String brandId;
  final String brandName;
  final String gender;
  final String material;
  final String imageUrl;
  final bool active;
  final bool deleted;

  const Product({
    required this.id,
    required this.name,
    required this.sku,
    this.description = '',
    required this.price,
    required this.categoryId,
    this.categoryName = '',
    required this.brandId,
    this.brandName = '',
    required this.gender,
    this.material = '',
    this.imageUrl = '',
    this.active = true,
    this.deleted = false,
  });

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: jsonStr(j, 'id'),
        name: jsonStr(j, 'name'),
        sku: jsonStr(j, 'sku'),
        description: jsonStr(j, 'description'),
        price: jsonInt(j, 'price'),
        categoryId: jsonStr(j, 'category'),
        categoryName: jsonStr(jsonExpand(j, 'category') ?? {}, 'name'),
        brandId: jsonStr(j, 'brand'),
        brandName: jsonStr(jsonExpand(j, 'brand') ?? {}, 'name'),
        gender: jsonStr(j, 'gender'),
        material: jsonStr(j, 'material'),
        imageUrl: jsonStr(j, 'image_url'),
        active: jsonBool(j, 'active'),
        deleted: jsonBool(j, 'deleted'),
      );
}
