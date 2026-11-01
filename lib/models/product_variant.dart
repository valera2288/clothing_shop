import 'json_utils.dart';

/// Вариант товара: размер, цвет и остаток на складе.
class ProductVariant {
  final String id;
  final String productId;
  final String productName;
  final int productPrice;
  final String size;
  final String color;
  final int stock;
  final bool deleted;

  const ProductVariant({
    required this.id,
    required this.productId,
    this.productName = '',
    this.productPrice = 0,
    required this.size,
    required this.color,
    required this.stock,
    this.deleted = false,
  });

  String get label => '$size, $color';

  factory ProductVariant.fromJson(Map<String, dynamic> j) {
    final product = jsonExpand(j, 'product') ?? {};
    return ProductVariant(
      id: jsonStr(j, 'id'),
      productId: jsonStr(j, 'product'),
      productName: jsonStr(product, 'name'),
      productPrice: jsonInt(product, 'price'),
      size: jsonStr(j, 'size'),
      color: jsonStr(j, 'color'),
      stock: jsonInt(j, 'stock'),
      deleted: jsonBool(j, 'deleted'),
    );
  }
}
