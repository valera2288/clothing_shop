import 'package:flutter/foundation.dart';

/// Элемент выпадающего списка: идентификатор записи и подпись.
class Option {
  final String id;
  final String label;
  const Option(this.id, this.label);
}

/// Справочные списки для выпадающих списков и фильтров (категории, бренды,
/// клиенты…). Каждый список запрашивается один раз и хранится, пока данные
/// не изменились: форма товара не гоняет сервер при каждом открытии.
class LookupService extends ChangeNotifier {
  final Map<String, Future<List<Option>> Function()> _loaders;
  final Map<String, Future<List<Option>>> _cache = {};

  LookupService(this._loaders);

  Future<List<Option>> load(String key) {
    final loader = _loaders[key];
    if (loader == null) throw ArgumentError('Неизвестный справочник: $key');
    // Неудачный запрос в кэше не остаётся: при следующем обращении повторим
    return _cache[key] ??= loader().catchError((Object e) {
      _cache.remove(key);
      throw e;
    });
  }

  /// Сбрасывает кэш после создания, изменения или удаления записей и сообщает
  /// открытым спискам и карточкам, что данные пора перечитать.
  void invalidate() {
    _cache.clear();
    notifyListeners();
  }
}
