import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/permissions.dart';
import '../../entities/entity_def.dart';
import '../../state/auth_notifier.dart';
import '../../state/lookup_service.dart';
import '../../widgets/action_runner.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/state_views.dart';

/// Общая карточка записи: поля по описанию [EntityDef], действия по правам
/// и дополнительный блок `detailExtra` (варианты, позиции заказа…).
/// Прямая ссылка `/products/<id>` открывается сама: запись берётся с сервера
/// по идентификатору из адреса.
class EntityDetailScreen<T> extends StatefulWidget {
  final EntityDef<T> def;
  final String id;
  const EntityDetailScreen({super.key, required this.def, required this.id});

  @override
  State<EntityDetailScreen<T>> createState() => _EntityDetailScreenState<T>();
}

class _EntityDetailScreenState<T> extends State<EntityDetailScreen<T>> {
  late Future<T?> _future;
  late final LookupService _lookup;

  EntityDef<T> get def => widget.def;

  @override
  void initState() {
    super.initState();
    _lookup = context.read<LookupService>()..addListener(_reload);
    _future = def.repo(context).findById(widget.id);
  }

  @override
  void dispose() {
    _lookup.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (mounted) {
      setState(() => _future = def.repo(context).findById(widget.id));
    }
  }

  bool _can(Permission? p) => p != null && context.read<AuthNotifier>().can(p);

  Future<void> _delete(T item) async {
    final ok = await confirmDialog(
      context,
      title: 'Удалить запись?',
      message: def.softDelete
          ? '«${def.itemTitle(item)}» будет помечена как удалённая.'
          : '«${def.itemTitle(item)}» будет удалена без возможности восстановления.',
    );
    if (!ok || !mounted) return;
    final repo = def.repo(context);
    final done = await runAction(context, () async {
      await (def.softDelete
          ? repo.softDelete(def.id(item))
          : repo.hardDelete(def.id(item)));
      return true;
    });
    if (done == true && mounted) {
      _lookup.invalidate();
      context.go(def.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AuthNotifier>();
    return AppScaffold(
      child: FutureBuilder<T?>(
        future: _future,
        builder: (context, snapshot) {
          final item = snapshot.data;
          final Widget body;
          if (snapshot.connectionState != ConnectionState.done) {
            body = const LoadingView();
          } else if (snapshot.hasError) {
            body = ErrorView(message: '${snapshot.error}', onRetry: _reload);
          } else if (item == null) {
            body = const EmptyView(
              message: 'Запись не найдена или недоступна',
              icon: Icons.search_off,
            );
          } else {
            body = _body(item);
          }
          final deleted = item != null && (def.isDeleted?.call(item) ?? false);
          return Scaffold(
            appBar: AppBar(
              title: Text(item == null ? def.title : def.itemTitle(item)),
              leading: BackButton(onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(def.path);
                }
              }),
              actions: [
                if (item != null && !deleted && _can(def.manage)) ...[
                  if (def.fields.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: 'Редактировать',
                      onPressed: () =>
                          context.go('${def.path}/${def.id(item)}/edit'),
                    ),
                  if (def.canDeleteWithManage)
                    IconButton(
                      icon: const Icon(Icons.delete),
                      tooltip: 'Удалить',
                      onPressed: () => _delete(item),
                    ),
                ],
              ],
            ),
            body: body,
          );
        },
      ),
    );
  }

  Widget _body(T item) {
    final theme = Theme.of(context);
    final deleted = def.isDeleted?.call(item) ?? false;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (deleted)
          Card(
            color: theme.colorScheme.errorContainer,
            child: const ListTile(
              leading: Icon(Icons.delete_outline),
              title: Text('Запись удалена'),
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                for (final (name, value) in def.details(item))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 150,
                          child: Text(name, style: theme.textTheme.bodySmall),
                        ),
                        Expanded(child: Text(value.isEmpty ? '—' : value)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (def.detailExtra != null && !deleted) ...[
          const SizedBox(height: 16),
          def.detailExtra!(context, item),
        ],
      ],
    );
  }
}
