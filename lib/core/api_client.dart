import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'; // kDebugMode, debugPrint

import 'api_exceptions.dart';
import 'config.dart';

/// Сколько раз повторять запрос на чтение при сетевом сбое.
const _maxRetries = 3;

/// [onUnauthorized] обновляет токен после ответа 401 и сообщает, удалось ли.
Dio buildDio({
  String? Function()? tokenProvider,
  Future<bool> Function()? onUnauthorized,
  String? baseUrl,
  void Function(bool offline)? onConnection,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl ?? apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
      // Не бросать исключение на кодах 4xx — разберём их сами
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = tokenProvider?.call();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        options.extra['startedAt'] = DateTime.now();
        return handler.next(options);
      },
      onResponse: (response, handler) {
        _log(response.requestOptions, response.statusCode);
        // Любой ответ сервера, даже 4xx, означает: связь есть
        onConnection?.call(false);
        // Коды 4xx попадают сюда, а не в onError, из-за validateStatus.
        final status = response.statusCode ?? 0;
        if (status >= 400) {
          // Просто бросить mapHttpError(...) нельзя: dio завернёт исключение
          // в DioException с типом unknown. Отправляем ответ по ветке ошибок
          // сами, приложив уже разобранное исключение.
          return handler.reject(
            DioException(
              requestOptions: response.requestOptions,
              response: response,
              type: DioExceptionType.badResponse,
              error: mapHttpError(status, response.data),
            ),
            true,
          );
        }
        return handler.next(response);
      },
      onError: (error, handler) async {
        // Сюда приходят сетевые сбои, таймауты, коды 5xx
        // и всё, что отклонил обработчик выше.
        final options = error.requestOptions;
        _log(options, error.response?.statusCode, error: error.type.name);
        if (error.response != null) {
          onConnection?.call(false);
        } else if (_isNetworkFailure(error)) {
          onConnection?.call(true);
        }

        // Токен истёк: обновляем его и прозрачно повторяем запрос.
        // Запросы auth-with-password / auth-refresh не трогаем: неверный пароль, и попытка
        // обновить токен ради него зациклилась бы. Повтор — только один раз.
        if (error.response?.statusCode == 401 &&
            onUnauthorized != null &&
            !options.path.contains('/auth-') &&
            options.extra['authRetried'] != true) {
          options.extra['authRetried'] = true;
          if (await onUnauthorized()) {
            try {
              // Повтор снова пройдёт через onRequest и получит новый токен
              return handler.resolve(await dio.fetch(options));
            } on DioException catch (e) {
              return handler.next(e);
            }
          }
        }

        if (_shouldRetry(error)) {
          final attempt = (options.extra['retry'] as int? ?? 0) + 1;
          options.extra['retry'] = attempt;
          // Пауза растёт: 300 мс, 600 мс, 1200 мс
          final pause = Duration(milliseconds: 300 * (1 << (attempt - 1)));
          if (kDebugMode) {
            debugPrint(
              '[API] повтор $attempt из $_maxRetries через ${pause.inMilliseconds} мс',
            );
          }
          await Future.delayed(pause);
          try {
            return handler.resolve(await dio.fetch(options));
          } on DioException catch (e) {
            return handler.next(e);
          }
        }
        return handler.next(error);
      },
    ),
  );
  return dio;
}

bool _isNetworkFailure(DioException e) => switch (e.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout =>
        true,
      DioExceptionType.unknown => e.response == null,
      _ => false,
    };

/// Повторяются только операции чтения: повторный POST создал бы вторую запись.
/// И только при сбое сети — ответ 4xx от повтора не изменится.
bool _shouldRetry(DioException e) {
  final options = e.requestOptions;
  if (options.method.toUpperCase() != 'GET') return false;
  if ((options.extra['retry'] as int? ?? 0) >= _maxRetries) return false;
  return switch (e.type) {
    DioExceptionType.connectionError ||
    DioExceptionType.connectionTimeout ||
    DioExceptionType.receiveTimeout =>
      true,
    DioExceptionType.unknown => e.response == null,
    _ => false,
  };
}

void _log(RequestOptions options, int? status, {String? error}) {
  if (!kDebugMode) return;
  final started = options.extra['startedAt'] as DateTime?;
  final ms = started == null
      ? ''
      : ' ${DateTime.now().difference(started).inMilliseconds} мс';
  debugPrint(
    '[API] ${options.method} ${options.uri} → ${status ?? error ?? '?'}$ms',
  );
}
