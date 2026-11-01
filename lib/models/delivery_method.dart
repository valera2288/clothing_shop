import 'json_utils.dart';

class DeliveryMethod {
  final String id;
  final String name;
  final int price;
  final int days;
  final String description;
  final bool deleted;

  const DeliveryMethod({
    required this.id,
    required this.name,
    required this.price,
    required this.days,
    this.description = '',
    this.deleted = false,
  });

  factory DeliveryMethod.fromJson(Map<String, dynamic> j) => DeliveryMethod(
        id: jsonStr(j, 'id'),
        name: jsonStr(j, 'name'),
        price: jsonInt(j, 'price'),
        days: jsonInt(j, 'days'),
        description: jsonStr(j, 'description'),
        deleted: jsonBool(j, 'deleted'),
      );
}
