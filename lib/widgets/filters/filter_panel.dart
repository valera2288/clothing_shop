import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/labels.dart';
import '../../entities/entity_def.dart';
import '../../models/list_query.dart';
import '../lookup_dropdown.dart';
import '../search_field.dart';
import 'filter_bar.dart';

/// Панель поиска, фильтров и сортировки, собранная из описания [FilterSpec].
/// Любое изменение отдаёт новый [ListQuery]; сервер выполняет отбор.
class FilterPanel extends StatelessWidget {
  final String searchHint;
  final List<FilterSpec> filters;
  final List<SortSpec> sorts;
  final ListQuery query;
  final ValueChanged<ListQuery> onChanged;

  /// Показывать переключатель «Удалённые» (мягкое удаление).
  final bool showDeletedToggle;

  /// Фильтры, заданные только ссылкой: «Сбросить» их не снимает.
  final Set<String> hiddenKeys;

  const FilterPanel({
    super.key,
    required this.searchHint,
    required this.filters,
    required this.sorts,
    required this.query,
    required this.onChanged,
    this.showDeletedToggle = false,
    this.hiddenKeys = const {},
  });

  @override
  Widget build(BuildContext context) {
    return FilterBar(
      children: [
        SizedBox(
          width: 280,
          child: SearchField(
            value: query.search,
            hintText: searchHint,
            onChanged: (v) => onChanged(query.copyWith(search: v)),
          ),
        ),
        for (final f in filters) _filter(f),
        if (sorts.isNotEmpty) _sortPicker(),
        if (showDeletedToggle)
          FilterChip(
            label: const Text('Удалённые'),
            selected: query.includeDeleted,
            onSelected: (v) => onChanged(query.copyWith(includeDeleted: v)),
          ),
        if (query.hasConditions)
          TextButton.icon(
            onPressed: () => onChanged(ListQuery(
              defaultSort: query.defaultSort,
              perPage: query.perPage,
              filters: {
                for (final e in query.filters.entries)
                  if (hiddenKeys.contains(e.key)) e.key: e.value,
              },
            )),
            icon: const Icon(Icons.filter_alt_off),
            label: const Text('Сбросить'),
          ),
      ],
    );
  }

  Widget _filter(FilterSpec f) {
    final value = query.filter(f.key);
    switch (f.kind) {
      case FilterKind.select:
        return SizedBox(
          width: 190,
          child: DropdownButtonFormField<String>(
            key: ValueKey('${f.key}:$value'),
            initialValue: value ?? '',
            isExpanded: true,
            decoration: InputDecoration(
              labelText: f.label,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              const DropdownMenuItem(value: '', child: Text('Все')),
              for (final e in f.options.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => onChanged(query.withFilter(f.key, v)),
          ),
        );
      case FilterKind.lookup:
        return SizedBox(
          width: 220,
          child: LookupDropdown(
            lookup: f.lookup!,
            label: f.label,
            value: value,
            allowAll: true,
            dense: true,
            onChanged: (v) => onChanged(query.withFilter(f.key, v)),
          ),
        );
      case FilterKind.text:
      case FilterKind.number:
        return SizedBox(
          width: f.kind == FilterKind.number ? 130 : 160,
          child: _DebouncedField(
            label: f.label,
            value: value ?? '',
            numeric: f.kind == FilterKind.number,
            onChanged: (v) => onChanged(query.withFilter(f.key, v.trim())),
          ),
        );
      case FilterKind.date:
        return _DateFilter(
          label: f.label,
          value: value,
          onChanged: (v) => onChanged(query.withFilter(f.key, v)),
        );
      case FilterKind.toggle:
        return FilterChip(
          label: Text(f.label),
          selected: value == '1',
          onSelected: (v) => onChanged(query.withFilter(f.key, v ? '1' : null)),
        );
    }
  }

  Widget _sortPicker() {
    final known = sorts.any((s) => s.field == query.sort);
    return SizedBox(
      width: 210,
      child: DropdownButtonFormField<String>(
        key: ValueKey('sort:${query.sort}'),
        initialValue: known ? query.sort : null,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Сортировка',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        items: [
          for (final s in sorts)
            DropdownMenuItem(value: s.field, child: Text(s.label)),
        ],
        onChanged: (v) {
          if (v != null) onChanged(query.copyWith(sort: v));
        },
      ),
    );
  }
}

/// Поле, которое отправляет значение через 400 мс после последнего символа,
/// чтобы не запрашивать сервер на каждую цифру.
class _DebouncedField extends StatefulWidget {
  final String label;
  final String value;
  final bool numeric;
  final ValueChanged<String> onChanged;

  const _DebouncedField({
    required this.label,
    required this.value,
    required this.numeric,
    required this.onChanged,
  });

  @override
  State<_DebouncedField> createState() => _DebouncedFieldState();
}

class _DebouncedFieldState extends State<_DebouncedField> {
  late final _controller = TextEditingController(text: widget.value);
  Timer? _timer;

  @override
  void didUpdateWidget(_DebouncedField old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _controller,
        keyboardType:
            widget.numeric ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: widget.label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (v) {
          _timer?.cancel();
          _timer = Timer(
            const Duration(milliseconds: 400),
            () => widget.onChanged(v),
          );
        },
      );
}

class _DateFilter extends StatelessWidget {
  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;

  const _DateFilter({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final date = value == null ? null : DateTime.tryParse(value!);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.event, size: 18),
          label: Text(date == null ? label : '$label: ${dateText(date)}'),
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              String two(int n) => n.toString().padLeft(2, '0');
              onChanged(
                '${picked.year}-${two(picked.month)}-${two(picked.day)}',
              );
            }
          },
        ),
        if (date != null)
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Сбросить дату',
            onPressed: () => onChanged(null),
          ),
      ],
    );
  }
}
