import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/breakpoints.dart';
import '../../core/permissions.dart';
import '../../entities/entity_def.dart';
import '../../models/list_query.dart';
import '../../state/auth_notifier.dart';
import '../../state/connection_notifier.dart';
import '../../state/list_notifier.dart';
import '../../state/load_status.dart';
import '../../state/lookup_service.dart';
import '../../widgets/action_runner.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/entity_card_list.dart';
import '../../widgets/entity_table.dart';
import '../../widgets/filters/filter_panel.dart';
import '../../widgets/pagination.dart';
import '../../widgets/state_views.dart';

/// Общий экран списка. Показывает поиск, фильтры, сортировку и страницы
/// любой сущности по её описанию [EntityDef]; условия лежат в адресе страницы.
class EntityListScreen<T> extends StatefulWidget {
  final EntityDef<T> def;
  const EntityListScreen({super.key, required this.def});

  @override
  State<EntityListScreen<T>> createState() => _EntityListScreenState<T>();
}

class _EntityListScreenState<T> extends State<EntityListScreen<T>> {
  late final ListNotifier<T> _notifier;
  late final LookupService _lookup;
  int _seenRestored = 0;

  EntityDef<T> get def => widget.def;

  ListQuery _queryFromUri(Uri uri) => ListQuery.fromUri(
        uri,
        filterKeys: def.filterKeys,
        defaultSort: def.defaultSort,
        sortFields: def.sortFields,
      );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Адрес читается здесь, а не в initState: GoRouterState зависит
    // от InheritedWidget, который в initState ещё недоступен
    final fromUrl = _queryFromUri(GoRouterState.of(context).uri);
    if (!_started) {
      _started = true;
      _lookup = context.read<LookupService>()..addListener(_onDataChanged);
      _notifier = ListNotifier<T>(
        def.repo(context),
        idOf: def.id,
        initial: fromUrl,
        onMutated: _lookup.invalidate,
      )..load();
      _seenRestored = context.read<ConnectionNotifier>().restoredCount;
    } else if (_notifier.query != fromUrl) {
      // Адрес изменился (кнопка «назад», переданная ссылка): список следует за ним
      Future.microtask(() => _notifier.applyQuery(fromUrl));
    }
  }

  /// Данные изменили на другом экране (форма, оформление заказа): перечитываем.
  void _onDataChanged() {
    if (mounted) _notifier.load();
  }

  @override
  void dispose() {
    _lookup.removeListener(_onDataChanged);
    _notifier.dispose();
    super.dispose();
  }

  bool _can(Permission? p) => p != null && context.read<AuthNotifier>().can(p);

  void _applyQuery(ListQuery next) {
    _notifier.applyQuery(next);
    final qs = Uri(queryParameters: next.toQueryParameters()).query;
    context.go(qs.isEmpty ? def.path : '${def.path}?$qs');
  }

  Future<void> _deleteSelected() async {
    // Записи, которые удалять нельзя (например, свою учётную запись), пропускаются
    for (final item in _notifier.result.items) {
      if (!def.deletable(context, item)) _notifier.deselect(def.id(item));
    }
    final count = _notifier.selected.length;
    if (count == 0) return;
    final ok = await confirmDialog(
      context,
      title: 'Удалить выбранные?',
      message: def.softDelete
          ? 'Выбрано записей: $count. Они будут помечены как удалённые.'
          : 'Выбрано записей: $count. Удаление необратимо.',
    );
    if (!ok || !mounted) return;
    final deleted = await runAction(context, _notifier.deleteSelected);
    if (mounted && deleted != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Удалено: $deleted')));
    }
  }

  Future<void> _delete(T item) async {
    final ok = await confirmDialog(
      context,
      title: 'Удалить запись?',
      message: def.softDelete
          ? '«${def.itemTitle(item)}» будет помечена как удалённая.'
          : '«${def.itemTitle(item)}» будет удалена без возможности восстановления.',
    );
    if (!ok || !mounted) return;
    await runAction(
      context,
      () => def.softDelete
          ? _notifier.softDelete(def.id(item))
          : _notifier.hardDelete(def.id(item)),
    );
  }

  Future<void> _hardDelete(T item) async {
    final ok = await confirmDialog(
      context,
      title: 'Удалить навсегда?',
      message: '«${def.itemTitle(item)}» будет стёрта полностью.',
      danger: true,
    );
    if (!ok || !mounted) return;
    await runAction(context, () => _notifier.hardDelete(def.id(item)));
  }

  List<Widget> _rowActions(T item) {
    final manage = _can(def.manage);
    final deleted = def.isDeleted?.call(item) ?? false;
    if (deleted) {
      return [
        if (_can(Permission.restore))
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: 'Восстановить',
            onPressed: () => runAction(
              context,
              () => _notifier.restore(def.id(item)),
            ),
          ),
        if (_can(Permission.hardDelete))
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: 'Удалить навсегда',
            color: Theme.of(context).colorScheme.error,
            onPressed: () => _hardDelete(item),
          ),
      ];
    }
    return [
      if (manage && def.fields.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.edit),
          tooltip: 'Редактировать',
          onPressed: () => context.go('${def.path}/${def.id(item)}/edit'),
        ),
      if (manage && def.canDeleteWithManage && def.deletable(context, item))
        IconButton(
          icon: const Icon(Icons.delete),
          tooltip: 'Удалить',
          onPressed: () => _delete(item),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Связь с сервером вернулась: упавший список загружается заново
    final restored =
        context.select<ConnectionNotifier, int>((c) => c.restoredCount);
    if (restored != _seenRestored) {
      _seenRestored = restored;
      if (_notifier.status == LoadStatus.error) {
        Future.microtask(_notifier.load);
      }
    }
    context.watch<AuthNotifier>();

    return ChangeNotifierProvider<ListNotifier<T>>.value(
      value: _notifier,
      child: Consumer<ListNotifier<T>>(
        builder: (context, notifier, _) => AppScaffold(
          child: Scaffold(
            appBar: AppBar(
              title: Text(def.title),
              actions: [
                if (_can(def.manage) && def.fields.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: def.createTitle,
                    onPressed: () => context.go('${def.path}/new'),
                  ),
                if (notifier.hasSelection && _can(def.manage)) ...[
                  Center(child: Text('Выбрано: ${notifier.selected.length}')),
                  IconButton(
                    icon: const Icon(Icons.clear_all),
                    tooltip: 'Снять выделение',
                    onPressed: notifier.clearSelection,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_sweep),
                    tooltip: 'Удалить выбранные',
                    onPressed: _deleteSelected,
                  ),
                ],
              ],
            ),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilterPanel(
                    searchHint: def.searchHint,
                    filters: def.filters,
                    sorts: def.sorts,
                    query: notifier.query,
                    hiddenKeys: def.hiddenFilters,
                    onChanged: _applyQuery,
                    showDeletedToggle:
                        def.softDelete && _can(Permission.restore),
                  ),
                ),
                Expanded(
                  child: StatusBody(
                    status: notifier.status,
                    error: notifier.error,
                    isEmpty: notifier.result.items.isEmpty,
                    onRetry: notifier.load,
                    emptyMessage: notifier.query.hasConditions
                        ? 'По вашему запросу ничего не найдено'
                        : 'Здесь пока нет записей',
                    emptyAction: notifier.query.hasConditions
                        ? TextButton(
                            onPressed: () => _applyQuery(ListQuery(
                              defaultSort: def.defaultSort,
                              perPage: notifier.query.perPage,
                              filters: {
                                for (final e in notifier.query.filters.entries)
                                  if (def.hiddenFilters.contains(e.key))
                                    e.key: e.value,
                              },
                            )),
                            child: const Text('Сбросить условия'),
                          )
                        : null,
                    builder: (_) => _content(notifier),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(ListNotifier<T> notifier) {
    final size = screenSizeOf(context);
    final items = notifier.result.items;
    final manage = _can(def.manage);

    final Widget list;
    if (def.gridCard != null && !manage) {
      list = GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 280,
          mainAxisExtent: 250,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemCount: items.length,
        itemBuilder: (context, i) => def.gridCard!(context, items[i]),
      );
    } else if (size == ScreenSize.compact) {
      list = ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, i) {
          final item = items[i];
          final lines = def.cardLines(item);
          return EntityCardItem<T>(
            item: item,
            id: def.id(item),
            title: def.itemTitle(item),
            subtitle: def.itemSubtitle?.call(item),
            selectable: manage && def.canDeleteWithManage,
            selected: notifier.selected.contains(def.id(item)),
            onToggleSelect: () => notifier.toggleSelection(def.id(item)),
            onTap: () => context.go('${def.path}/${def.id(item)}'),
            fields: [for (final l in lines) Text(l)],
            actions: _rowActions(item),
          );
        },
      );
    } else {
      final columns = [
        for (final c in def.columns)
          if (!c.wideOnly || size == ScreenSize.expanded) c,
      ];
      list = EntityTable<T>(
        columns: columns,
        items: items,
        idOf: def.id,
        selected: notifier.selected,
        onToggleSelect:
            manage && def.canDeleteWithManage ? notifier.toggleSelection : null,
        sortField: notifier.query.sortField,
        sortAscending: notifier.query.sortAscending,
        onSort: (field) => _applyQuery(notifier.query.withSortField(field)),
        actions: _rowActions,
      );
    }

    return Column(
      children: [
        Expanded(child: list),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Pagination(
            currentPage: notifier.result.page,
            totalPages: notifier.result.totalPages,
            totalItems: notifier.result.totalItems,
            pageSize: notifier.query.perPage,
            onPageChanged: (p) => _applyQuery(notifier.query.withPage(p)),
            onPageSizeChanged: (s) =>
                _applyQuery(notifier.query.copyWith(perPage: s)),
          ),
        ),
      ],
    );
  }
}
