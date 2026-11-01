import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/labels.dart';
import '../../entities/entity_defs.dart';
import '../../models/delivery.dart';
import '../../models/order.dart';
import '../../models/order_item.dart';
import '../../repositories/entity_repository.dart';
import '../../state/lookup_service.dart';
import '../../widgets/action_runner.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/state_views.dart';

/// Содержимое карточки заказа: позиции, доставка и действия над статусом.
/// Менеджер ([staff] = true) переводит заказ по статусам и ведёт доставку,
/// покупатель следит за доставкой и может отменить новый заказ.
class OrderPanel extends StatefulWidget {
  final Order order;
  final bool staff;
  const OrderPanel({super.key, required this.order, required this.staff});

  @override
  State<OrderPanel> createState() => _OrderPanelState();
}

class _OrderPanelState extends State<OrderPanel> {
  late Future<List<OrderItem>> _items;
  late Future<Delivery?> _delivery;

  Order get order => widget.order;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(OrderPanel old) {
    super.didUpdateWidget(old);
    if (old.order.status != order.status) _load();
  }

  void _load() {
    _items = context.read<OrderRepository>().itemsOf(order.id);
    _delivery = context.read<DeliveryRepository>().findByOrder(order.id);
  }

  Future<void> _setStatus(String status) async {
    final lookup = context.read<LookupService>();
    if (status == 'cancelled') {
      final ok = await confirmDialog(
        context,
        title: 'Отменить заказ?',
        message: 'Заказ ${order.number} будет отменён.',
        confirmLabel: 'Отменить заказ',
        danger: true,
      );
      if (!ok || !mounted) return;
    }
    await runAction(
      context,
      () => context.read<OrderRepository>().changeStatus(order.id, status),
    );
    lookup.invalidate();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final next = widget.staff
        ? (orderNextStatuses[order.status] ?? const <String>[])
        : (order.status == 'new' ? const ['cancelled'] : const <String>[]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (next.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(widget.staff
                      ? 'Перевести в статус:'
                      : 'Заказ ещё не оплачен.'),
                  for (final s in next)
                    s == 'cancelled'
                        ? OutlinedButton.icon(
                            onPressed: () => _setStatus(s),
                            icon: const Icon(Icons.cancel_outlined),
                            label: const Text('Отменить заказ'),
                          )
                        : FilledButton(
                            onPressed: () => _setStatus(s),
                            child: Text(label(orderStatusLabels, s)),
                          ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Состав заказа',
                          style: theme.textTheme.titleMedium),
                    ),
                    if (widget.staff)
                      TextButton.icon(
                        onPressed: () =>
                            context.go('/order-items?order=${order.id}'),
                        icon: const Icon(Icons.edit_note),
                        label: const Text('Позиции'),
                      ),
                  ],
                ),
                FutureBuilder<List<OrderItem>>(
                  future: _items,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const SizedBox(height: 80, child: LoadingView());
                    }
                    if (snapshot.hasError) {
                      return SizedBox(
                        height: 160,
                        child: ErrorView(
                          message: '${snapshot.error}',
                          onRetry: () => setState(_load),
                        ),
                      );
                    }
                    final items = snapshot.data!;
                    if (items.isEmpty) {
                      return const SizedBox(
                        height: 100,
                        child: EmptyView(
                          message: 'В заказе нет позиций',
                          icon: Icons.inventory_2_outlined,
                        ),
                      );
                    }
                    return Column(
                      children: [
                        for (final i in items)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(i.productName),
                            subtitle: Text(i.variantLabel),
                            trailing: Text(
                                '${i.quantity} × ${rub(i.price)} = ${rub(i.sum)}'),
                          ),
                        const Divider(),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text('Итого: ${rub(order.total)}',
                              style: theme.textTheme.titleMedium),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Доставка', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                FutureBuilder<Delivery?>(
                  future: _delivery,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const SizedBox(height: 60, child: LoadingView());
                    }
                    if (snapshot.hasError) {
                      return SizedBox(
                        height: 160,
                        child: ErrorView(
                          message: '${snapshot.error}',
                          onRetry: () => setState(_load),
                        ),
                      );
                    }
                    final d = snapshot.data;
                    if (d == null) {
                      return Row(
                        children: [
                          const Expanded(
                            child: Text('Доставка ещё не оформлена: '
                                'трек-номер появится после отправки.'),
                          ),
                          if (widget.staff)
                            FilledButton(
                              onPressed: () => context.go('/deliveries/new'),
                              child: const Text('Создать'),
                            ),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            statusChip(label(deliveryStatusLabels, d.status),
                                d.status),
                            Text(label(carrierLabels, d.carrier)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                            'Трек-номер: ${d.trackNumber.isEmpty ? '—' : d.trackNumber}'),
                        Text('Отправлен: ${dateText(d.shippedAt)}'),
                        Text('Ожидаемая дата: ${dateText(d.eta)}'),
                        if (widget.staff)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () =>
                                  context.go('/deliveries/${d.id}/edit'),
                              icon: const Icon(Icons.edit),
                              label: const Text('Изменить'),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
