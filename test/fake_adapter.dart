import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Подменяет сеть в тестах: возвращает заранее заданные ответы
/// и запоминает отправленные запросы.
class FakeAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final ResponseBody Function(RequestOptions options) handler;

  FakeAdapter(this.handler);

  /// Ответ с JSON-телом и заданным кодом.
  static ResponseBody json(Object body, {int status = 200}) =>
      ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

Dio fakeDio(FakeAdapter adapter) {
  final dio = Dio(BaseOptions(
    baseUrl: 'http://test/api',
    validateStatus: (s) => s != null && s < 500,
  ));
  dio.httpClientAdapter = adapter;
  return dio;
}
