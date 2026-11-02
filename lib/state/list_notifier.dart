import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../models/list_query.dart';
import '../models/page_result.dart';
import '../repositories/entity_repository.dart';
import 'load_status.dart';

/// Состояние списка любой сущности: условия выборки, текущая страница,
/// статус загрузки и выбранные строки. Все данные берутся у сервера.
class ListNotifier<T> extends ChangeNotifier {
  final EntityRepository<T> _repository;
  final String Function(T item) idOf;

  /// Вызывается после изменения данных: сбрасывает кэш выпадающих списков.
  final VoidCallback? onMutated;

  ListNotifier(
    this._repository, {
    required this.idOf,
    required ListQuery initial,
    this.onMutated,
  }) : _query = initial;

  ListQuery _query;
  PageResult<T> _result = PageResult<T>.empty();
  LoadStatus _status = LoadStatus.idle;
  String? _error;
  final Set<String> _selected = {};
  bool _disposed = false;

  /// Номер последнего запроса. Если пользователь успел сменить условия,
  /// пока шла загрузка, ответ на устаревший запрос отбрасывается.
  int _loadSeq = 0;

  ListQuery get query => _query;
  PageResult<T> get result => _result;
  LoadStatus get status => _status;
  String? get error => _error;
  Set<String> get selected => UnmodifiableSetView(_selected);
  bool get hasSelection => _selected.isNotEmpty;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    final seq = ++_loadSeq;
    _status = LoadStatus.loading;
    _error = null;
    _safeNotify();
    try {
      final result = await _repository.find(_query);
      if (seq != _loadSeq) return;
      // Удалили последнюю запись на странице: переходим на предыдущую
      if (result.items.isEmpty && _query.page > 1 && result.totalItems > 0) {
        _query = _query.withPage(result.totalPages);
        return await load();
      }
      _result = result;
      _status = LoadStatus.success;
    } catch (e) {
      if (seq != _loadSeq) return;
      _error = '$e';
      _status = LoadStatus.error;
    }
    _safeNotify();
  }

  Future<void> applyQuery(ListQuery next) async {
    if (_query == next) return;
    _query = next;
    _selected.clear();
    await load();
  }

  void toggleSelection(String id) {
    _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
    _safeNotify();
  }

  void deselect(String id) {
    if (_selected.remove(id)) _safeNotify();
  }

  void clearSelection() {
    if (_selected.isEmpty) return;
    _selected.clear();
    _safeNotify();
  }

  Future<int> deleteSelected() async {
    final count = await _repository.deleteMany(_selected.toList());
    _selected.clear();
    onMutated?.call();
    await load();
    return count;
  }

  Future<void> softDelete(String id) async {
    await _repository.softDelete(id);
    _selected.remove(id);
    onMutated?.call();
    await load();
  }

  Future<void> hardDelete(String id) async {
    await _repository.hardDelete(id);
    _selected.remove(id);
    onMutated?.call();
    await load();
  }

  Future<void> restore(String id) async {
    await _repository.restore(id);
    onMutated?.call();
    await load();
  }
}
