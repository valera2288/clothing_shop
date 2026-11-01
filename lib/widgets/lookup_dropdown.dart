import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/connection_notifier.dart';
import '../state/lookup_service.dart';

/// Выпадающий список записей другой сущности (связь «многие к одному»).
/// Варианты берутся у сервера через [LookupService] и кэшируются.
class LookupDropdown extends StatefulWidget {
  final String lookup;
  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;

  /// Для фильтра: первый пункт «Все», выбор можно снять.
  final bool allowAll;
  final String? Function(String?)? validator;
  final bool dense;

  const LookupDropdown({
    super.key,
    required this.lookup,
    required this.label,
    required this.value,
    required this.onChanged,
    this.allowAll = false,
    this.validator,
    this.dense = false,
  });

  @override
  State<LookupDropdown> createState() => _LookupDropdownState();
}

class _LookupDropdownState extends State<LookupDropdown> {
  late Future<List<Option>> _future;
  bool _failed = false;
  int _seenRestored = 0;

  @override
  void initState() {
    super.initState();
    _seenRestored = context.read<ConnectionNotifier>().restoredCount;
    _future = _load();
  }

  Future<List<Option>> _load() {
    _failed = false;
    return context
        .read<LookupService>()
        .load(widget.lookup)
        .catchError((Object e) {
      _failed = true;
      throw e;
    });
  }

  void _retry() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    // Связь с сервером вернулась: список, который не загрузился, запрашивается снова
    final restored =
        context.select<ConnectionNotifier, int>((c) => c.restoredCount);
    if (restored != _seenRestored) {
      _seenRestored = restored;
      if (_failed) Future.microtask(_retry);
    }
    final decoration = InputDecoration(
      labelText: widget.label,
      border: const OutlineInputBorder(),
      isDense: widget.dense,
    );
    return FutureBuilder<List<Option>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return InputDecorator(
            decoration: decoration.copyWith(errorText: 'Не удалось загрузить'),
            child: Align(
              alignment: Alignment.centerLeft,
              child:
                  TextButton(onPressed: _retry, child: const Text('Повторить')),
            ),
          );
        }
        if (!snapshot.hasData) {
          return InputDecorator(
            decoration: decoration,
            child: const SizedBox(
              height: 20,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Загрузка…'),
              ),
            ),
          );
        }
        final options = snapshot.data!;
        final known = options.any((o) => o.id == widget.value);
        return DropdownButtonFormField<String>(
          // Ключ нужен, чтобы список обновился, когда значение изменили снаружи
          key: ValueKey('${widget.lookup}:${widget.value}'),
          initialValue: known ? widget.value : null,
          isExpanded: true,
          decoration: decoration,
          validator: widget.validator,
          items: [
            if (widget.allowAll)
              const DropdownMenuItem<String>(value: '', child: Text('Все')),
            for (final o in options)
              DropdownMenuItem(
                value: o.id,
                child: Text(o.label, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) => widget.onChanged(v == null || v.isEmpty ? null : v),
        );
      },
    );
  }
}
