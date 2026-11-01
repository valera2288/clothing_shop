import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/permissions.dart';
import '../../models/product.dart';
import '../../models/product_variant.dart';
import '../../repositories/entity_repository.dart';
import '../../state/auth_notifier.dart';
import '../../state/cart_notifier.dart';
import '../../state/lookup_service.dart';
import '../../widgets/state_views.dart';

/// Блок «Размеры и наличие» в карточке товара. Покупатель добавляет вариант
/// в корзину, администратор переходит к управлению вариантами.
class VariantsPanel extends StatefulWidget {
  final Product product;
  const VariantsPanel({super.key, required this.product});

  @override
  State<VariantsPanel> createState() => _VariantsPanelState();
}

class _VariantsPanelState extends State<VariantsPanel> {
  late Future<List<ProductVariant>> _future;
  late final LookupService _lookup;

  @override
  void initState() {
    super.initState();
    _lookup = context.read<LookupService>()..addListener(_reload);
    _future = _fetch();
  }

  @override
  void dispose() {
    _lookup.removeListener(_reload);
    super.dispose();
  }

  Future<List<ProductVariant>> _fetch() =>
      context.read<ProductVariantRepository>().findByProduct(widget.product.id);

  void _reload() {
    if (mounted) setState(() => _future = _fetch());
  }

  void _add(ProductVariant v) {
    final ok = context.read<CartNotifier>().add(widget.product, v);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Добавлено в корзину: ${v.label}'
            : 'Больше ${v.label} добавить нельзя: не хватает на складе'),
        action: ok
            ? SnackBarAction(
                label: 'Корзина',
                onPressed: () => context.go('/cart'),
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Размеры и наличие',
                      style: theme.textTheme.titleMedium),
                ),
                if (auth.can(Permission.manageCatalog)) ...[
                  TextButton.icon(
                    onPressed: () =>
                        context.go('/variants?product=${widget.product.id}'),
                    icon: const Icon(Icons.edit_note),
                    label: const Text('Управление'),
                  ),
                ],
              ],
            ),
            FutureBuilder<List<ProductVariant>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SizedBox(height: 80, child: LoadingView());
                }
                if (snapshot.hasError) {
                  return SizedBox(
                    height: 180,
                    child: ErrorView(
                      message: '${snapshot.error}',
                      onRetry: _reload,
                    ),
                  );
                }
                final variants = snapshot.data!;
                if (variants.isEmpty) {
                  return const SizedBox(
                    height: 120,
                    child: EmptyView(
                      message: 'Для товара пока нет вариантов',
                      icon: Icons.inventory_2_outlined,
                    ),
                  );
                }
                final canBuy = auth.can(Permission.useCart);
                return Column(
                  children: [
                    for (final v in variants)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('${v.size} · ${v.color}'),
                        subtitle: Text(
                          v.stock == 0
                              ? 'Нет в наличии'
                              : 'В наличии: ${v.stock}',
                          style: TextStyle(
                            color:
                                v.stock == 0 ? theme.colorScheme.error : null,
                          ),
                        ),
                        trailing: canBuy
                            ? FilledButton.tonalIcon(
                                onPressed: v.stock == 0 ? null : () => _add(v),
                                icon: const Icon(Icons.add_shopping_cart,
                                    size: 18),
                                label: const Text('В корзину'),
                              )
                            : null,
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
