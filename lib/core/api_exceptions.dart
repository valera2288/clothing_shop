import 'package:dio/dio.dart';

/// Исключения предметной области. Виджеты и notifier'ы знают только о них,
/// про Dio и DioException им знать не нужно.
sealed class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}

/// Нет соединения, таймаут, сервер недоступен, заблокировано CORS
class NetworkException extends ApiException {
  const NetworkException([
    super.message = 'Сервер недоступен. Проверьте соединение.',
  ]);
}

/// Запрос отменён, потому что пользователь уже отправил более новый
class CancelledException extends ApiException {
  const CancelledException([super.message = 'Запрос отменён.']);
}

/// 400 — сервер не смог разобрать запрос
class BadRequestException extends ApiException {
  const BadRequestException([super.message = 'Некорректный запрос.']);
}

/// 401 — не аутентифицирован либо срок действия токена истёк
class UnauthorizedException extends ApiException {
  const UnauthorizedException([super.message = 'Требуется вход в систему.']);
}

/// 403 — роль не позволяет выполнить операцию
class ForbiddenException extends ApiException {
  const ForbiddenException([
    super.message = 'Недостаточно прав для этого действия.',
  ]);
}

/// 404
class NotFoundException extends ApiException {
  const NotFoundException([super.message = 'Запись не найдена.']);
}

/// 409 — нарушено ограничение целостности
class ConflictException extends ApiException {
  const ConflictException(super.message);
}

/// 422 — ошибки валидации по полям
class ValidationException extends ApiException {
  final Map<String, String> errors;
  const ValidationException(super.message, this.errors);
}

/// 5xx
class ServerException extends ApiException {
  const ServerException([
    super.message = 'Ошибка на сервере. Попробуйте позже.',
  ]);
}

/// Русские тексты для кодов ошибок валидации PocketBase
/// (`data.<поле>.code` в ответе 400).
const _fieldErrors = {
  'validation_required': 'Поле обязательно',
  'validation_is_required': 'Поле обязательно',
  'validation_not_unique': 'Такое значение уже существует',
  'validation_invalid_email': 'Некорректный адрес почты',
  'validation_invalid_format': 'Неверный формат значения',
  'validation_values_mismatch': 'Значения не совпадают',
  'validation_length_too_short': 'Слишком короткое значение',
  'validation_length_too_long': 'Слишком длинное значение',
  'validation_min_text_constraint': 'Слишком короткое значение',
  'validation_max_text_constraint': 'Слишком длинное значение',
  'validation_min_number_constraint': 'Число меньше допустимого',
  'validation_max_number_constraint': 'Число больше допустимого',
  'validation_invalid_value': 'Недопустимое значение',
  'validation_missing_rel_records': 'Связанная запись не найдена',
  'validation_invalid_url': 'Некорректная ссылка',
  'validation_invalid_date': 'Некорректная дата',
};

String _fieldError(Object? value) {
  if (value is Map) {
    final code = value['code'];
    final message = value['message'];
    return _fieldErrors[code] ?? (message is String ? message : 'Ошибка');
  }
  return '$value';
}

/// Разбор ответа PocketBase: `{status, message, data: {поле: {code, message}}}`.
///
/// Особенности PocketBase: ошибки валидации приходят с кодом 400 и полем
/// `data`; отказ правила доступа при создании — тоже 400, но с пустым `data`,
/// а при изменении и удалении — 404.
ApiException mapHttpError(int status, dynamic body) {
  final message = (body is Map && body['message'] is String)
      ? body['message'] as String
      : null;
  final data = (body is Map && body['data'] is Map) ? body['data'] as Map : {};
  // Пакетный запрос откатывается целиком: причина лежит в data.requests.<номер>
  if (status == 400 && data['requests'] is Map) {
    for (final r in (data['requests'] as Map).values) {
      final inner =
          (r is Map && r['response'] is Map) ? r['response'] as Map : const {};
      final text = inner['message'];
      if (text is String && text.contains('склад')) {
        return ConflictException(text);
      }
      final fields = inner['data'];
      if (fields is Map && fields.isNotEmpty) {
        return ValidationException(
          'Сервер отклонил данные',
          fields.map((k, v) => MapEntry('$k', _fieldError(v))),
        );
      }
    }
    return const ForbiddenException(
      'Сервер отклонил операцию: недостаточно прав или данные неверны.',
    );
  }
  return switch (status) {
    400 when data.isNotEmpty => ValidationException(
        'Сервер отклонил данные',
        data.map((k, v) => MapEntry('$k', _fieldError(v))),
      ),
    400 when message != null && message.contains('required relation') =>
      const ConflictException(
        'Нельзя удалить: на запись ссылаются другие данные, например заказы.',
      ),
    400 when message == 'Failed to authenticate.' =>
      const UnauthorizedException('Неверная почта или пароль'),
    400 when message != null && message.startsWith('Failed to ') =>
      const ForbiddenException(
        'Сервер отклонил операцию: недостаточно прав для этого действия.',
      ),
    400 => BadRequestException(message ?? 'Некорректный запрос.'),
    401 => UnauthorizedException(message ?? 'Требуется вход в систему.'),
    403 => ForbiddenException(
        message ?? 'Недостаточно прав для этого действия.',
      ),
    404 => NotFoundException(message ?? 'Запись не найдена.'),
    409 => ConflictException(message ?? 'Операция невозможна.'),
    422 => ValidationException(
        message ?? 'Ошибка валидации',
        data.map((k, v) => MapEntry('$k', _fieldError(v))),
      ),
    429 => const ConflictException('Слишком много запросов. Подождите.'),
    _ => ServerException(message ?? 'Неизвестная ошибка (код $status).'),
  };
}

ApiException mapDioError(DioException e) {
  // Если исключение уже разобрал интерсептор, повторно его не разбираем.
  // Без этой проверки ошибка 422 придёт в приложение как ServerException.
  final existing = e.error;
  if (existing is ApiException) return existing;

  return switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout =>
      const NetworkException(
        'Сервер не ответил вовремя.',
      ),
    DioExceptionType.connectionError => const NetworkException(
        'Не удалось соединиться с сервером. Проверьте подключение и повторите попытку.',
      ),
    DioExceptionType.cancel => const CancelledException(),
    // Коды 5xx: validateStatus их не пропускает, и dio бросает badResponse
    DioExceptionType.badResponse when e.response != null => mapHttpError(
        e.response!.statusCode ?? 500,
        e.response!.data,
      ),
    // На web обрыв соединения и CORS иногда приходят как unknown
    DioExceptionType.unknown when e.response == null => const NetworkException(
        'Не удалось соединиться с сервером. Проверьте подключение и повторите попытку.',
      ),
    _ => const ServerException(),
  };
}

/// Обёртка для каждого сетевого вызова: наружу не выходит ни один DioException.
Future<T> guard<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on DioException catch (e) {
    throw mapDioError(e);
  }
}
