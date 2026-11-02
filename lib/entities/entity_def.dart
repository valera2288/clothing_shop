import 'package:flutter/material.dart';

import '../core/permissions.dart';
import '../core/validators.dart';
import '../repositories/entity_repository.dart';
import '../widgets/entity_table.dart';

enum FieldKind {
  text,
  multiline,
  integer,
  select,
  relation,
  multiRelation,
  boolean,
  date,
  email,
  phone,
  password,
}

/// Описание поля формы. По нему общий экран строит виджет, клиентскую
/// проверку и тело запроса; ошибки сервера привязываются по [name].
class FieldSpec {
  /// Имя поля в PocketBase: ключ в теле запроса и в ошибках валидации.
  final String name;
  final String label;
  final FieldKind kind;
  final bool required;
  final int? minLength;
  final int? maxLength;
  final num? min;
  final num? max;
  final RegExp? pattern;
  final String? patternMessage;

  /// Значения списка выбора: код на сервере → подпись.
  final Map<String, String> options;

  /// Ключ справочника для связей (см. LookupService).
  final String? lookup;
  final String? hint;

  /// Поле показывается только при создании (пароль).
  final bool createOnly;

  /// Значение новой записи по умолчанию.
  final Object? initial;

  const FieldSpec(
    this.name,
    this.label,
    this.kind, {
    this.required = false,
    this.minLength,
    this.maxLength,
    this.min,
    this.max,
    this.pattern,
    this.patternMessage,
    this.options = const {},
    this.lookup,
    this.hint,
    this.createOnly = false,
    this.initial,
  });

  /// Клиентская проверка. Те же правила заданы на сервере: проверка в форме
  /// только экономит запрос, а решает всегда сервер.
  String? Function(String?) get validator {
    final rules = <String? Function(String?)>[
      if (required) V.required('Поле обязательно'),
      if (kind == FieldKind.email)
        V.pattern(_email, 'Некорректный адрес почты'),
      if (kind == FieldKind.phone)
        V.pattern(_phone, 'Некорректный номер телефона'),
      if (minLength != null || maxLength != null)
        V.length(min: minLength ?? 0, max: maxLength ?? 1000),
      if (pattern != null)
        V.pattern(pattern!, patternMessage ?? 'Неверный формат'),
      if (kind == FieldKind.integer)
        (v) => (v ?? '').trim().isEmpty && !required
            ? null
            : V.integer(min: min?.toInt(), max: max?.toInt(), label: label)(v),
      if (kind == FieldKind.password) V.strongPassword(),
    ];
    return V.combine(rules);
  }

  static final _email = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
  static final _phone = RegExp(r'^\+?[\d\s\-()]{7,20}$');
}

enum FilterKind { select, lookup, text, number, date, toggle }

/// Описание фильтра списка. Значение хранится в адресе страницы под ключом [key].
class FilterSpec {
  final String key;
  final String label;
  final FilterKind kind;
  final Map<String, String> options;
  final String? lookup;

  const FilterSpec(
    this.key,
    this.label,
    this.kind, {
    this.options = const {},
    this.lookup,
  });
}

/// Поле сортировки: код на сервере и подпись.
class SortSpec {
  final String field;
  final String label;
  const SortSpec(this.field, this.label);
}

/// Всё, чем сущности отличаются друг от друга. Три общих экрана — список,
/// карточка и форма — работают по этому описанию, поэтому экран на каждую
/// сущность не копируется.
class EntityDef<T> {
  /// Адрес раздела: `/products`; карточка — `/products/:id`.
  final String path;
  final String title;
  final String createTitle;
  final String editTitle;
  final IconData icon;

  /// Право на просмотр и право на изменение.
  final Permission view;
  final Permission? manage;
  final bool canDeleteWithManage;

  /// Можно ли удалить конкретную запись (администратор не удаляет себя).
  final bool Function(BuildContext context, T item)? canDeleteItem;

  final EntityRepository<T> Function(BuildContext context) repo;
  final String Function(T item) id;
  final String Function(T item) itemTitle;
  final String? Function(T item)? itemSubtitle;
  final bool Function(T item)? isDeleted;

  /// У сущности есть мягкое удаление (поле `deleted`).
  final bool softDelete;

  final String defaultSort;
  final List<SortSpec> sorts;
  final List<FilterSpec> filters;
  final String searchHint;

  final List<TableColumnSpec<T>> columns;

  /// Короткие строки для карточки в списке на узком экране.
  final List<String> Function(T item) cardLines;

  /// Строки карточки записи: подпись → значение.
  final List<(String, String)> Function(T item) details;

  final List<FieldSpec> fields;
  final Map<String, dynamic> Function(T item) initialValues;

  /// Значения, которые подставляет приложение, а не пользователь
  /// (например, владелец адреса — текущий пользователь).
  final Map<String, dynamic> Function(BuildContext context)? createExtras;

  /// Дополнение к карточке записи (варианты товара, позиции заказа…).
  final Widget Function(BuildContext context, T item)? detailExtra;

  /// Плитка товара для витрины покупателя.
  final Widget Function(BuildContext context, T item)? gridCard;

  /// Какие фильтры можно задать ссылкой, но в панели их нет
  /// (например, `order` в списке позиций заказа).
  final Set<String> hiddenFilters;

  const EntityDef({
    required this.path,
    required this.title,
    required this.createTitle,
    required this.editTitle,
    required this.icon,
    required this.view,
    required this.manage,
    required this.repo,
    required this.id,
    required this.itemTitle,
    this.itemSubtitle,
    this.isDeleted,
    this.softDelete = false,
    this.defaultSort = '-created',
    this.sorts = const [],
    this.filters = const [],
    this.searchHint = 'Поиск',
    required this.columns,
    required this.cardLines,
    required this.details,
    this.fields = const [],
    required this.initialValues,
    this.createExtras,
    this.detailExtra,
    this.gridCard,
    this.hiddenFilters = const {},
    this.canDeleteWithManage = true,
    this.canDeleteItem,
  });

  bool deletable(BuildContext context, T item) =>
      canDeleteItem?.call(context, item) ?? true;

  Set<String> get filterKeys =>
      {...filters.map((f) => f.key), ...hiddenFilters};

  Set<String> get sortFields =>
      sorts.map((s) => s.field.replaceFirst('-', '')).toSet();

  /// Можно ли менять записи этого раздела.
  bool get editable => manage != null && fields.isNotEmpty;
}
