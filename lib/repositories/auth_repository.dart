import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';
import '../models/app_user.dart';

/// Ответ входа и обновления токена: токен PocketBase и запись пользователя.
class AuthResult {
  final String token;
  final AppUser user;
  const AuthResult(this.token, this.user);

  /// У PocketBase один токен: обновляется он им же, пока не истёк.
  String get accessToken => token;
  String get refreshToken => token;

  factory AuthResult.fromJson(Map<String, dynamic> j) => AuthResult(
        j['token'] as String,
        AppUser.fromJson(j['record'] as Map<String, dynamic>),
      );
}

abstract interface class AuthRepository {
  Future<AuthResult> login(String email, String password);
  Future<AppUser> register({
    required String email,
    required String password,
    required String name,
    String phone,
  });
  Future<AuthResult> refresh(String token);
  Future<void> logout(String token);
}

class PbAuthRepository implements AuthRepository {
  final Dio _dio;
  PbAuthRepository(this._dio);

  @override
  Future<AuthResult> login(String email, String password) => guard(() async {
        final r = await _dio.post<Map<String, dynamic>>(
          '/collections/users/auth-with-password',
          data: {'identity': email, 'password': password},
        );
        return AuthResult.fromJson(r.data!);
      });

  /// Пароль уходит как есть: хеширует его сервер. Роль всегда `customer`,
  /// правило создания на сервере другой роли не допустит.
  @override
  Future<AppUser> register({
    required String email,
    required String password,
    required String name,
    String phone = '',
  }) =>
      guard(() async {
        final r = await _dio.post<Map<String, dynamic>>(
          '/collections/users/records',
          data: {
            'email': email,
            'password': password,
            'passwordConfirm': password,
            'name': name,
            'phone': phone,
            'role': 'customer',
            'emailVisibility': true,
          },
        );
        return AppUser.fromJson(r.data!);
      });

  /// Продлевает токен и заодно возвращает актуальную запись пользователя:
  /// роль, изменённая в базе, подхватывается без повторного входа.
  @override
  Future<AuthResult> refresh(String token) => guard(() async {
        final r = await _dio.post<Map<String, dynamic>>(
          '/collections/users/auth-refresh',
          options: Options(headers: {'Authorization': token}),
        );
        return AuthResult.fromJson(r.data!);
      });

  /// У PocketBase токены без состояния: на сервере нечего аннулировать,
  /// выход выполняется удалением токена в браузере.
  @override
  Future<void> logout(String token) async {}
}
