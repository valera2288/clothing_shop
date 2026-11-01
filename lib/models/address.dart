import 'json_utils.dart';

/// Адрес доставки покупателя (N:1 к пользователю).
class Address {
  final String id;
  final String userId;
  final String userName;
  final String city;
  final String street;
  final String house;
  final String flat;
  final String postalCode;
  final bool isDefault;

  const Address({
    required this.id,
    required this.userId,
    this.userName = '',
    required this.city,
    required this.street,
    required this.house,
    this.flat = '',
    required this.postalCode,
    this.isDefault = false,
  });

  String get full {
    final base = '$postalCode, $city, $street, д. $house';
    return flat.isEmpty ? base : '$base, кв. $flat';
  }

  factory Address.fromJson(Map<String, dynamic> j) => Address(
        id: jsonStr(j, 'id'),
        userId: jsonStr(j, 'user'),
        userName: jsonStr(jsonExpand(j, 'user') ?? {}, 'name'),
        city: jsonStr(j, 'city'),
        street: jsonStr(j, 'street'),
        house: jsonStr(j, 'house'),
        flat: jsonStr(j, 'flat'),
        postalCode: jsonStr(j, 'postal_code'),
        isDefault: jsonBool(j, 'is_default'),
      );
}
