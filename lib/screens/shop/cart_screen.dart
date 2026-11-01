import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/labels.dart';
import '../../state/cart_notifier.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/state_views.dart';

/// Корзина покупателя. Данные хранятся в браузере, сервер подключается
/// только при оформлении заказа.
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartNotifier>();
    final theme = Theme.of(context);
    return AppScaffold(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Корзина'),
          actions: [
            if (!cart.isEmpty)
              TextButton.icon(
                onPressed: cart.clear,
                icon: const Icon(Icons.delete_sweep),
                label: const Text('Очистить'),
              ),
          ],
        ),
        body: cart.isEmpty
            ? EmptyView(
                message: 'Корзина пуста',
                icon: Icons.shopping_cart_outlined,
                action: FilledButton(
                  onPressed: () => context.go('/products'),
                  child: const Text('Перейти в каталог'),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final line in cart.lines)
                    Card(
                      child: ListTile(
                        title: Text(line.productName),
                        subtitle: Text(
                          '${line.size} · ${line.color} · ${rub(line.price)}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              tooltip: 'Меньше',
                              onPressed: () => cart.setQuantity(
                                  line.variantId, line.quantity - 1),
                            ),
                            Text('${line.quantity}'),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              tooltip: 'Больше',
                              onPressed: line.quantity >= line.stock ||
                                      line.quantity >= CartNotifier.maxQuantity
                                  ? null
                                  : () => cart.setQuantity(
                                      line.variantId, line.quantity + 1),
                            ),
                            SizedBox(
                              width: 90,
                              child: Text(
                                rub(line.sum),
                                textAlign: TextAlign.right,
                                style: theme.textTheme.titleSmall,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              tooltip: 'Убрать',
                              onPressed: () => cart.remove(line.variantId),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Товары: ${rub(cart.subtotal)}',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: () => context.go('/checkout'),
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Оформить заказ'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
