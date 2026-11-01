import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/labels.dart';
import '../../entities/entity_defs.dart';
import '../../repositories/entity_repository.dart';
import '../../state/stats_notifier.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/state_views.dart';

/// Статистика магазина (только администратор): заказы по статусам, выручка,
/// остатки и пользователи. Показатели считает клиент по запросам с фильтрами.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (c) => StatsNotifier(c.read<StatsRepository>())..load(),
      child: AppScaffold(
        child: Scaffold(
          appBar: AppBar(title: const Text('Статистика')),
          body: Consumer<StatsNotifier>(
            builder: (context, n, _) => StatusBody(
              status: n.status,
              error: n.error,
              isEmpty: n.stats != null && n.stats!.orders == 0,
              emptyMessage:
                  'Заказов пока нет — статистика появится после первых продаж',
              onRetry: n.load,
              builder: (_) => _Body(stats: n.stats!),
            ),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final ShopStats stats;
  const _Body({required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxCount =
        stats.ordersByStatus.values.fold(1, (a, b) => a > b ? a : b);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _tile(context, 'Заказов', '${stats.orders}', Icons.receipt_long),
            _tile(context, 'Выручка', rub(stats.revenue), Icons.payments),
            _tile(context, 'Выручка за 30 дней', rub(stats.revenueMonth),
                Icons.trending_up),
            _tile(context, 'Товаров в каталоге', '${stats.products}',
                Icons.checkroom),
            _tile(context, 'Вариантов с остатком ≤ 5', '${stats.lowStock}',
                Icons.warning_amber),
          ],
        ),
        const SizedBox(height: 24),
        Text('Заказы по статусам', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final e in stats.ordersByStatus.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  child: Text(label(orderStatusLabels, e.key)),
                ),
                Expanded(
                  child: LinearProgressIndicator(
                    value: e.value / maxCount,
                    minHeight: 14,
                    color: statusColor(e.key),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text('${e.value}', textAlign: TextAlign.right),
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        Text('Пользователи', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final e in stats.usersByRole.entries)
          ListTile(
            dense: true,
            title: Text(label(roleLabels, e.key)),
            trailing: Text('${e.value}'),
          ),
      ],
    );
  }

  Widget _tile(
      BuildContext context, String title, String value, IconData icon) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 240,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 32, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.bodySmall),
                    Text(value, style: theme.textTheme.titleLarge),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
