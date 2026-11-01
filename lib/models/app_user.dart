import '../core/permissions.dart';
import 'json_utils.dart';

/// Пользователь системы (коллекция users).
class AppUser {
  final String id;
  final String email;
  final String name;
  final String phone;
  final Role role;

  const AppUser({
    required this.id,
    this.email = '',
    required this.name,
    this.phone = '',
    required this.role,
  });

  bool can(Permission permission) => roleCan(role, permission);

  /// Для сохранения сессии в браузере. Права из него не берутся:
  /// их проверяет сервер по токену.
  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'phone': phone,
        'role': role.name,
      };

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: jsonStr(j, 'id'),
        email: jsonStr(j, 'email'),
        name: jsonStr(j, 'name'),
        phone: jsonStr(j, 'phone'),
        role: Role.fromCode(j['role'] as String?),
      );
}
