import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/permissions.dart';
import '../state/auth_notifier.dart';
import '../widgets/app_scaffold.dart';

/// Разделы главного экрана. Каждый виден только при нужном праве,
/// поэтому у покупателя, менеджера и администратора разный набор плиток.
const _sections = [
  (
    Permission.viewCatalog,
    Icons.checkroom,
    'Каталог',
    'Поиск, фильтры и сортировка товаров',
    '/products',
  ),
  (
    Permission.useCart,
    Icons.shopping_cart,
    'Корзина',
    'Выбранные товары и оформление',
    '/cart',
  ),
  (
    Permission.viewOwnOrders,
    Icons.receipt_long,
    'Мои заказы',
    'Статус заказов и отслеживание доставки',
    '/my-orders',
  ),
  (
    Permission.manageAddresses,
    Icons.location_on,
    'Мои адреса',
    'Адреса доставки',
    '/addresses',
  ),
  (
    Permission.manageOrders,
    Icons.receipt_long,
    'Заказы',
    'Все заказы и смена статусов',
    '/orders',
  ),
  (
    Permission.manageDeliveries,
    Icons.local_shipping,
    'Доставки',
    'Трек-номера, статусы и сроки',
    '/deliveries',
  ),
  (
    Permission.manageLoyalty,
    Icons.card_membership,
    'Карты лояльности',
    'Карты и баллы покупателей',
    '/loyalty',
  ),
  (
    Permission.manageCatalog,
    Icons.category,
    'Категории',
    'Справочник категорий',
    '/categories',
  ),
  (
    Permission.manageCatalog,
    Icons.sell,
    'Бренды',
    'Справочник брендов',
    '/brands',
  ),
  (
    Permission.manageCatalog,
    Icons.collections_bookmark,
    'Коллекции',
    'Сезонные подборки товаров',
    '/collections',
  ),
  (
    Permission.manageCatalog,
    Icons.straighten,
    'Варианты товаров',
    'Размеры, цвета и остатки',
    '/variants',
  ),
  (
    Permission.manageCatalog,
    Icons.local_shipping_outlined,
    'Способы доставки',
    'Стоимость и сроки',
    '/delivery-methods',
  ),
  (
    Permission.manageUsers,
    Icons.admin_panel_settings,
    'Пользователи',
    'Учётные записи и роли',
    '/admin/users',
  ),
  (
    Permission.viewStats,
    Icons.bar_chart,
    'Статистика',
    'Сводка по магазину',
    '/admin/stats',
  ),
];

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final user = auth.user;
    final theme = Theme.of(context);
    final visible = _sections.where((s) => auth.can(s.$1)).toList();

    return AppScaffold(
      child: Scaffold(
        appBar: AppBar(title: const Text('Главная')),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Здравствуйте, ${user?.name ?? ''}!',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Роль: ${user?.role.title ?? '—'}',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (final (_, icon, title, subtitle, path) in visible)
                      SizedBox(
                        width: 280,
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: Icon(
                              icon,
                              size: 32,
                              color: theme.colorScheme.primary,
                            ),
                            title: Text(title),
                            subtitle: Text(subtitle),
                            onTap: () => context.go(path),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
