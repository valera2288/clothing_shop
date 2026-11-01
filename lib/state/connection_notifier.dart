import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Состояние связи с сервером.
///
/// Dio сообщает сюда о каждом сбое сети и о каждом ответе. Пока связи нет,
/// раз в несколько секунд отправляется проверочный запрос; как только
/// сервер ответил, [offline] сбрасывается и экраны перезагружают данные
/// без перезагрузки страницы.
class ConnectionNotifier extends ChangeNotifier {
  ConnectionNotifier({this.probeEvery = const Duration(seconds: 5)});

  final Duration probeEvery;
  Dio? _dio;
  Timer? _probe;
  bool _offline = false;

  /// Сколько раз связь восстанавливалась. Экраны следят за этим числом.
  int restoredCount = 0;

  bool get offline => _offline;

  /// Dio задаётся после создания: ему самому нужен колбэк отсюда.
  set dio(Dio value) => _dio = value;

  void report({required bool offline}) {
    if (offline == _offline) return;
    _offline = offline;
    if (offline) {
      _probe ??= Timer.periodic(probeEvery, (_) => _ping());
    } else {
      _probe?.cancel();
      _probe = null;
      restoredCount++;
    }
    notifyListeners();
  }

  Future<void> _ping() async {
    final dio = _dio;
    if (dio == null) return;
    try {
      // Подойдёт любой ответ: даже 404 или 401 значит, что сервер жив
      await dio.get('/health');
    } on DioException {
      // Сервер всё ещё недоступен. Сбой уже учтён интерсептором
    }
  }

  @override
  void dispose() {
    _probe?.cancel();
    super.dispose();
  }
}
