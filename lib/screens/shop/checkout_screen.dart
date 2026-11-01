import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api_exceptions.dart';
import '../../core/labels.dart';
import '../../core/pricing.dart';
import '../../models/address.dart';
import '../../models/delivery_method.dart';
import '../../models/loyalty_card.dart';
import '../../repositories/entity_repository.dart';
import '../../state/auth_notifier.dart';
import '../../state/cart_notifier.dart';
import '../../state/lookup_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/state_views.dart';

/// Данные, нужные для оформления: адреса, способы доставки и карта лояльности.
class _CheckoutData {
  final List<Address> addresses;
  final List<DeliveryMethod> methods;
  final LoyaltyCard? card;
  const _CheckoutData(this.addresses, this.methods, this.card);
}

/// Оформление заказа: адрес, доставка, оплата и итог со скидкой по карте.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  late Future<_CheckoutData> _future;
  String? _addressId;
  String? _methodId;
  String _payment = 'card';
  final _comment = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<_CheckoutData> _fetch() async {
    final userId = context.read<AuthNotifier>().user!.id;
    final results = await Future.wait([
      context.read<AddressRepository>().findAll(),
      context.read<DeliveryMethodRepository>().findAll(),
      context.read<LoyaltyCardRepository>().findByUser(userId),
    ]);
    final addresses = results[0] as List<Address>;
    final preferred = addresses.where((a) => a.isDefault);
    _addressId ??= preferred.isNotEmpty
        ? preferred.first.id
        : (addresses.isNotEmpty ? addresses.first.id : null);
    return _CheckoutData(
      addresses,
      results[1] as List<DeliveryMethod>,
      results[2] as LoyaltyCard?,
    );
  }

  Future<void> _submit(_CheckoutData data) async {
    if (_sending || !_formKey.currentState!.validate()) return;
    final cart = context.read<CartNotifier>();
    final method = data.methods.firstWhere((m) => m.id == _methodId);
    final totals = calcTotals(
      subtotal: cart.subtotal,
      deliveryPrice: method.price,
      tier: data.card?.tier,
    );
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final lookup = context.read<LookupService>();
    setState(() => _sending = true);
    try {
      final order = await context.read<OrderRepository>().place(OrderDraft(
            userId: context.read<AuthNotifier>().user!.id,
            addressId: _addressId!,
            deliveryMethodId: method.id,
            payment: _payment,
            comment: _comment.text.trim(),
            total: totals.total,
            lines: [
              for (final l in cart.lines)
                OrderLine(l.variantId, l.quantity, l.price),
            ],
          ));
      cart.clear();
      lookup.invalidate();
      messenger.showSnackBar(
        SnackBar(content: Text('Заказ ${order.number} оформлен')),
      );
      router.go('/my-orders/${order.id}');
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartNotifier>();
    return AppScaffold(
      child: Scaffold(
        appBar: AppBar(title: const Text('Оформление заказа')),
        body: cart.isEmpty && !_sending
            ? EmptyView(
                message: 'Корзина пуста',
                icon: Icons.shopping_cart_outlined,
                action: FilledButton(
                  onPressed: () => context.go('/products'),
                  child: const Text('Перейти в каталог'),
                ),
              )
            : FutureBuilder<_CheckoutData>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const LoadingView();
                  }
                  if (snapshot.hasError) {
                    return ErrorView(
                      message: '${snapshot.error}',
                      onRetry: () => setState(() => _future = _fetch()),
                    );
                  }
                  final data = snapshot.data!;
                  if (data.addresses.isEmpty) {
                    return EmptyView(
                      message: 'Чтобы оформить заказ, добавьте адрес доставки',
                      icon: Icons.location_off,
                      action: FilledButton(
                        onPressed: () => context.go('/addresses/new'),
                        child: const Text('Добавить адрес'),
                      ),
                    );
                  }
                  return _form(context, cart, data);
                },
              ),
      ),
    );
  }

  Widget _form(BuildContext context, CartNotifier cart, _CheckoutData data) {
    final theme = Theme.of(context);
    final method = data.methods.where((m) => m.id == _methodId).firstOrNull;
    final totals = calcTotals(
      subtotal: cart.subtotal,
      deliveryPrice: method?.price ?? 0,
      tier: data.card?.tier,
    );
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<String>(
                initialValue: _addressId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Адрес доставки',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final a in data.addresses)
                    DropdownMenuItem(
                      value: a.id,
                      child: Text(a.full, overflow: TextOverflow.ellipsis),
                    ),
                ],
                validator: (v) => v == null ? 'Выберите адрес' : null,
                onChanged: (v) => setState(() => _addressId = v),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => context.go('/addresses/new'),
                  child: const Text('Добавить новый адрес'),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _methodId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Способ доставки',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final m in data.methods)
                    DropdownMenuItem(
                      value: m.id,
                      child: Text(
                        '${m.name} — ${rub(m.price)}, ${m.days} дн.',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                validator: (v) => v == null ? 'Выберите способ доставки' : null,
                onChanged: (v) => setState(() => _methodId = v),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _payment,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Оплата',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final e in paymentLabels.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => setState(() => _payment = v ?? 'card'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _comment,
                maxLines: 2,
                maxLength: 300,
                decoration: const InputDecoration(
                  labelText: 'Комментарий к заказу',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _row('Товары (${cart.count} шт.)', rub(totals.subtotal)),
                      if (data.card != null)
                        _row(
                          'Скидка по карте (${tierDiscount[data.card!.tier]}%)',
                          '−${rub(totals.discount)}',
                        ),
                      _row('Доставка',
                          method == null ? '—' : rub(totals.delivery)),
                      const Divider(),
                      _row('Итого', rub(totals.total), bold: true),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _sending ? null : () => _submit(data),
                child: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Подтвердить заказ'),
              ),
              if (data.card == null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Карты лояльности у вас пока нет: скидка не применяется.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String name, String value, {bool bold = false}) {
    final style = bold ? Theme.of(context).textTheme.titleMedium : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(name, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
