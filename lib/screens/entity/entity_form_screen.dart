import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../entities/entity_def.dart';
import '../../state/lookup_service.dart';
import '../../widgets/entity_form.dart';
import '../../widgets/lookup_dropdown.dart';
import '../../widgets/multi_select_field.dart';
import '../../widgets/state_views.dart';

/// Общая форма создания и редактирования. Поля, проверка и тело запроса
/// строятся по [FieldSpec]; ошибки сервера (400 с `data`) показываются под
/// теми же полями по имени.
class EntityFormScreen<T> extends StatefulWidget {
  final EntityDef<T> def;
  final String? id;
  const EntityFormScreen({super.key, required this.def, this.id});

  @override
  State<EntityFormScreen<T>> createState() => _EntityFormScreenState<T>();
}

class _EntityFormScreenState<T> extends State<EntityFormScreen<T>> {
  final _values = <String, dynamic>{};
  String _password = '';
  Future<T?>? _loading;

  EntityDef<T> get def => widget.def;
  bool get _editing => widget.id != null;

  @override
  void initState() {
    super.initState();
    if (_editing) {
      _loading = def.repo(context).findById(widget.id!).then((item) {
        if (item != null) _values.addAll(def.initialValues(item));
        return item;
      });
    } else {
      for (final f in def.fields) {
        if (f.initial != null) _values[f.name] = f.initial;
      }
    }
  }

  /// Тело запроса из введённых значений: числа — числами, пустые связи — `''`.
  Map<String, dynamic> _body() {
    final body = <String, dynamic>{};
    for (final f in def.fields) {
      if (f.createOnly && _editing) continue;
      final v = _values[f.name];
      switch (f.kind) {
        case FieldKind.integer:
          body[f.name] = int.tryParse('${v ?? ''}'.trim()) ?? 0;
        case FieldKind.boolean:
          body[f.name] = v == true;
        case FieldKind.multiRelation:
          body[f.name] = List<String>.from((v as List?) ?? const []);
        case FieldKind.date:
          final text = '${v ?? ''}';
          body[f.name] = text.isEmpty ? '' : '$text 00:00:00.000Z';
        case FieldKind.password:
          body[f.name] = _password;
          body['${f.name}Confirm'] = _password;
        default:
          body[f.name] = '${v ?? ''}'.trim();
      }
    }
    return body;
  }

  Future<void> _submit() async {
    final repo = def.repo(context);
    final lookup = context.read<LookupService>();
    final body = _body();
    if (_editing) {
      await repo.update(widget.id!, body);
    } else {
      await repo.create({...?def.createExtras?.call(context), ...body});
    }
    lookup.invalidate();
  }

  @override
  Widget build(BuildContext context) {
    final title = _editing ? def.editTitle : def.createTitle;
    if (_loading == null) return _form(title);
    return FutureBuilder<T?>(
      future: _loading,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(title: Text(title)),
            body: const LoadingView(),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(title: Text(title)),
            body: snapshot.hasError
                ? ErrorView(
                    message: '${snapshot.error}',
                    onRetry: () => setState(initState),
                  )
                : const EmptyView(
                    message: 'Запись не найдена',
                    icon: Icons.search_off,
                  ),
          );
        }
        return _form(title);
      },
    );
  }

  Widget _form(String title) => EntityForm(
        title: title,
        isEditing: _editing,
        onSubmit: _submit,
        fields: [
          for (final f in def.fields)
            if (!(f.createOnly && _editing))
              EntityFormField(name: f.name, build: (_) => _field(f)),
        ],
      );

  Widget _field(FieldSpec f) {
    const border = OutlineInputBorder();
    switch (f.kind) {
      case FieldKind.select:
        return DropdownButtonFormField<String>(
          initialValue: f.options.containsKey(_values[f.name])
              ? _values[f.name] as String
              : null,
          isExpanded: true,
          decoration: InputDecoration(labelText: f.label, border: border),
          items: [
            for (final e in f.options.entries)
              DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          validator:
              f.required ? (v) => v == null ? 'Выберите значение' : null : null,
          onChanged: (v) => _values[f.name] = v,
        );
      case FieldKind.relation:
        return LookupDropdown(
          lookup: f.lookup!,
          label: f.label,
          value: _values[f.name] as String?,
          validator:
              f.required ? (v) => v == null ? 'Выберите значение' : null : null,
          onChanged: (v) => _values[f.name] = v,
        );
      case FieldKind.multiRelation:
        return _MultiRelation(
          spec: f,
          selected: List<String>.from((_values[f.name] as List?) ?? const []),
          onChanged: (ids) => _values[f.name] = ids,
        );
      case FieldKind.boolean:
        return FormField<bool>(
          initialValue: _values[f.name] == true,
          builder: (state) => SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(f.label),
            value: state.value ?? false,
            onChanged: (v) {
              _values[f.name] = v;
              state.didChange(v);
            },
          ),
        );
      case FieldKind.date:
        return _DateField(
          label: f.label,
          value: _values[f.name] as String?,
          onChanged: (v) => _values[f.name] = v,
        );
      case FieldKind.password:
        return Column(
          children: [
            TextFormField(
              obscureText: true,
              decoration: InputDecoration(labelText: f.label, border: border),
              validator: f.validator,
              onChanged: (v) => _password = v,
            ),
            const SizedBox(height: 16),
            TextFormField(
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Повтор пароля',
                border: border,
              ),
              validator: (v) => v != _password ? 'Пароли не совпадают' : null,
            ),
          ],
        );
      case FieldKind.integer:
      case FieldKind.text:
      case FieldKind.multiline:
      case FieldKind.email:
      case FieldKind.phone:
        return TextFormField(
          initialValue: '${_values[f.name] ?? ''}',
          maxLines: f.kind == FieldKind.multiline ? 4 : 1,
          keyboardType: switch (f.kind) {
            FieldKind.integer => TextInputType.number,
            FieldKind.email => TextInputType.emailAddress,
            FieldKind.phone => TextInputType.phone,
            _ => TextInputType.text,
          },
          decoration: InputDecoration(
            labelText: f.required ? '${f.label} *' : f.label,
            helperText: f.hint,
            border: border,
          ),
          validator: f.validator,
          onChanged: (v) => _values[f.name] = v,
        );
    }
  }
}

/// Множественный выбор для связи «многие ко многим».
class _MultiRelation extends StatelessWidget {
  final FieldSpec spec;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  const _MultiRelation({
    required this.spec,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Option>>(
      future: context.read<LookupService>().load(spec.lookup!),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Не удалось загрузить: «${spec.label}»');
        }
        if (!snapshot.hasData) return const LinearProgressIndicator();
        return MultiSelectField<Option>(
          initialValue: [
            for (final o in snapshot.data!)
              if (selected.contains(o.id)) o,
          ],
          label: spec.label,
          options: snapshot.data!,
          labelOf: (o) => o.label,
          chipBuilder: (o, isSelected, toggle) => FilterChip(
            label: Text(o.label),
            selected: isSelected,
            onSelected: (_) => toggle(),
          ),
          onChanged: (items) => onChanged([for (final o in items) o.id]),
        );
      },
    );
  }
}

class _DateField extends StatefulWidget {
  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;

  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_DateField> createState() => _DateFieldState();
}

class _DateFieldState extends State<_DateField> {
  late final _controller = TextEditingController(text: _shown(widget.value));

  /// Из ответа сервера (`2026-10-31 00:00:00.000Z`) берём только дату.
  static String _shown(String? v) =>
      (v == null || v.length < 10) ? '' : v.substring(0, 10);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: _controller,
        readOnly: true,
        decoration: InputDecoration(
          labelText: widget.label,
          border: const OutlineInputBorder(),
          suffixIcon: _controller.text.isEmpty
              ? const Icon(Icons.event)
              : IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Очистить',
                  onPressed: () {
                    setState(_controller.clear);
                    widget.onChanged('');
                  },
                ),
        ),
        onTap: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: DateTime.tryParse(_controller.text) ?? now,
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
          );
          if (picked == null) return;
          String two(int n) => n.toString().padLeft(2, '0');
          final text = '${picked.year}-${two(picked.month)}-${two(picked.day)}';
          setState(() => _controller.text = text);
          widget.onChanged(text);
        },
      );
}
