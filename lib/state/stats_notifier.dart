import 'package:flutter/foundation.dart';

import '../repositories/entity_repository.dart';
import 'load_status.dart';

/// Состояние экрана «Статистика»: статус загрузки и показатели магазина.
class StatsNotifier extends ChangeNotifier {
  final StatsRepository _repository;
  StatsNotifier(this._repository);

  LoadStatus _status = LoadStatus.idle;
  ShopStats? _stats;
  String? _error;
  bool _disposed = false;

  LoadStatus get status => _status;
  ShopStats? get stats => _stats;
  String? get error => _error;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> load() async {
    _status = LoadStatus.loading;
    _error = null;
    notifyListeners();
    try {
      _stats = await _repository.load();
      _status = LoadStatus.success;
    } catch (e) {
      _error = '$e';
      _status = LoadStatus.error;
    }
    if (!_disposed) notifyListeners();
  }
}
