import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/breakpoints.dart';
import '../core/permissions.dart';
import '../state/auth_notifier.dart';
import '../state/cart_notifier.dart';
import 'connection_banner.dart';

class AppScaffold extends StatelessWidget {
  final Widget child;

  const AppScaffold({super.key, required this.child});

  /// Предельная ширина содержимого: на мониторе 1920 px текст и таблицы
  /// не растягиваются на весь экран.
  static const maxContentWidth = 1440.0;

  /// Пункты меню и право, при котором пункт виден. Состав меню зависит
  /// от роли: у каждой роли есть пункты, которых нет у остальных.
  static const _all = [
    (icon: Icons.home, label: 'Главная', path: '/', need: null),
    (
      icon: Icons.checkroom,
      label: 'Каталог',
      path: '/products',
      need: Permission.viewCatalog,
    ),
    (
      icon: Icons.shopping_cart,
      label: 'Корзина',
      path: '/cart',
      need: Permission.useCart,
    ),
    (
      icon: Icons.receipt_long,
      label: 'Мои заказы',
      path: '/my-orders',
      need: Permission.viewOwnOrders,
    ),
    (
      icon: Icons.location_on,
      label: 'Адреса',
      path: '/addresses',
      need: Permission.manageAddresses,
    ),
    (
      icon: Icons.receipt_long,
      label: 'Заказы',
      path: '/orders',
      need: Permission.manageOrders,
    ),
    (
      icon: Icons.local_shipping,
      label: 'Доставки',
      path: '/deliveries',
      need: Permission.manageDeliveries,
    ),
    (
      icon: Icons.card_membership,
      label: 'Карты',
      path: '/loyalty',
      need: Permission.manageLoyalty,
    ),
    (
      icon: Icons.category,
      label: 'Категории',
      path: '/categories',
      need: Permission.manageCatalog,
    ),
    (
      icon: Icons.sell,
      label: 'Бренды',
      path: '/brands',
      need: Permission.manageCatalog,
    ),
    (
      icon: Icons.collections_bookmark,
      label: 'Коллекции',
      path: '/collections',
      need: Permission.manageCatalog,
    ),
    (
      icon: Icons.straighten,
      label: 'Варианты',
      path: '/variants',
      need: Permission.manageCatalog,
    ),
    (
      icon: Icons.local_shipping_outlined,
      label: 'Способы доставки',
      path: '/delivery-methods',
      need: Permission.manageCatalog,
    ),
    (
      icon: Icons.admin_panel_settings,
      label: 'Пользователи',
      path: '/admin/users',
      need: Permission.manageUsers,
    ),
    (
      icon: Icons.bar_chart,
      label: 'Статистика',
      path: '/admin/stats',
      need: Permission.viewStats,
    ),
  ];

  /// Значок пункта меню; у корзины — число товаров.
  Widget _icon(BuildContext context, String path, IconData icon) {
    if (path != '/cart') return Icon(icon);
    final count = context.watch<CartNotifier>().count;
    return Badge(
      isLabelVisible: count > 0,
      label: Text('$count'),
      child: Icon(icon),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final destinations =
        _all.where((d) => d.need == null || auth.can(d.need!)).toList();
    final path = GoRouterState.of(context).uri.path;
    // Самый длинный совпавший префикс: «/» не должен перекрывать «/books»
    var selected = 0;
    for (var i = 0; i < destinations.length; i++) {
      final p = destinations[i].path;
      if (p != '/' && path.startsWith(p)) selected = i;
    }
    final size = screenSizeOf(context);
    final content = Column(
      children: [
        const _Header(),
        const ConnectionBanner(),
        // На широком экране содержимое не растягивается на всё окно
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: maxContentWidth),
              child: child,
            ),
          ),
        ),
      ],
    );

    if (size == ScreenSize.compact) {
      // На узком экране в нижней панели помещается не больше пяти пунктов,
      // остальные остаются доступны с главного экрана
      final bottom = destinations.take(5).toList();
      // Открытый раздел не попал в первые пять: показываем его на месте
      // последнего, чтобы подсвечивался именно он, а не «Главная»
      if (selected >= bottom.length) {
        bottom[bottom.length - 1] = destinations[selected];
      }
      return Scaffold(
        body: content,
        bottomNavigationBar: NavigationBar(
          selectedIndex:
              selected < bottom.length ? selected : bottom.length - 1,
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          onDestinationSelected: (i) => context.go(bottom[i].path),
          destinations: [
            for (final d in bottom)
              NavigationDestination(
                icon: _icon(context, d.path, d.icon),
                label: d.label,
                tooltip: d.label,
              ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          // Пунктов может быть больше, чем помещается по высоте: рейка прокручивается
          LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: IntrinsicHeight(
                  child: NavigationRail(
                    selectedIndex: selected,
                    onDestinationSelected: (i) =>
                        context.go(destinations[i].path),
                    extended: size == ScreenSize.expanded,
                    labelType: size == ScreenSize.expanded
                        ? NavigationRailLabelType.none
                        : NavigationRailLabelType.all,
                    destinations: [
                      for (final d in destinations)
                        NavigationRailDestination(
                          icon: _icon(context, d.path, d.icon),
                          label: Text(d.label),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: content),
        ],
      ),
    );
  }
}

/// Шапка: название приложения, имя и роль пользователя, выход.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final user = auth.user;
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primaryContainer,
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(
              Icons.local_library,
              size: 20,
              color: theme.colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 8),
            Text('Магазин одежды', style: theme.textTheme.titleSmall),
            const Spacer(),
            if (user != null) ...[
              Flexible(
                child: Text(
                  '${user.name} · ${user.role.title}',
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Выйти',
                icon: const Icon(Icons.logout, size: 20),
                onPressed: () => auth.logout(),
              ),
            ],
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
