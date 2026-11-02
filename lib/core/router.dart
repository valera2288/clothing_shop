import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../entities/entity_def.dart';
import '../entities/entity_defs.dart';
import '../screens/admin/stats_screen.dart' deferred as stats;
import '../screens/dashboard_screen.dart';
import '../screens/entity/entity_detail_screen.dart';
import '../screens/entity/entity_form_screen.dart';
import '../screens/entity/entity_list_screen.dart';
import '../screens/forbidden_screen.dart';
import '../screens/login_screen.dart';
import '../screens/not_found_screen.dart';
import '../screens/register_screen.dart';
import '../screens/shop/cart_screen.dart';
import '../screens/shop/checkout_screen.dart' deferred as checkout;
import '../state/auth_notifier.dart';
import '../widgets/deferred_screen.dart';
import 'permissions.dart';

/// Публичные адреса — доступны без входа.
const publicPaths = {'/login', '/register'};

/// Решение общего redirect: куда отправить пользователя или null,
/// если переход разрешён. Вынесено отдельно, чтобы проверить тестами.
String? authRedirect({
  required bool loggedIn,
  required Uri uri,
  required String matched,
}) {
  final isPublic = publicPaths.contains(matched);
  // Не вошёл и идёт на закрытый экран — на вход, запомнив адрес
  if (!loggedIn && !isPublic) {
    final from = uri.toString();
    return from == '/' ? '/login' : '/login?from=${Uri.encodeComponent(from)}';
  }
  // Уже вошёл и стоит на экране входа: возвращаем туда, откуда его
  // перенаправили, иначе на главную. Принимаются только внутренние адреса,
  // чтобы ссылкой вида ?from=//evil.example нельзя было увести на чужой сайт.
  if (loggedIn && isPublic) {
    final from = uri.queryParameters['from'];
    final safe = from != null &&
        from.startsWith('/') &&
        !from.startsWith('//') &&
        !from.startsWith('/login');
    return safe ? from : '/';
  }
  return null;
}

String _id(GoRouterState s) => s.pathParameters['id'] ?? '';

GoRouter buildRouter(AuthNotifier auth) {
  /// Проверка роли на уровне ветки маршрутов. Срабатывает до построения
  /// экрана, поэтому экран отказа не мелькает и не исчезает.
  GoRouterRedirect need(Permission? p) => (BuildContext c, GoRouterState s) =>
      p != null && auth.can(p) ? null : '/forbidden';

  /// Четыре адреса раздела по описанию сущности: список, `new`, карточка
  /// и `:id/edit`. Права задаёт сама сущность: просмотр — `view`,
  /// создание и правка — `manage`.
  GoRoute crud<T>(EntityDef<T> def) => GoRoute(
        path: def.path,
        redirect: need(def.view),
        pageBuilder: (c, s) =>
            NoTransitionPage(child: EntityListScreen<T>(def: def)),
        routes: [
          GoRoute(
            path: 'new',
            redirect: def.editable ? need(def.manage) : (c, s) => '/forbidden',
            builder: (c, s) => EntityFormScreen<T>(
              def: def,
              prefill: s.uri.queryParameters,
            ),
          ),
          GoRoute(
            path: ':id',
            builder: (c, s) => EntityDetailScreen<T>(def: def, id: _id(s)),
            routes: [
              GoRoute(
                path: 'edit',
                redirect:
                    def.editable ? need(def.manage) : (c, s) => '/forbidden',
                builder: (c, s) => EntityFormScreen<T>(def: def, id: _id(s)),
              ),
            ],
          ),
        ],
      );

  return GoRouter(
    // Маршрутизатор пересчитывает redirect при каждом notifyListeners():
    // после входа уходит с формы, после выхода возвращается на неё
    refreshListenable: auth,
    initialLocation: '/',
    redirect: (context, state) => authRedirect(
      loggedIn: auth.isAuthenticated,
      uri: state.uri,
      matched: state.matchedLocation,
    ),
    routes: [
      GoRoute(
        path: '/login',
        builder: (c, s) => LoginScreen(from: s.uri.queryParameters['from']),
      ),
      GoRoute(path: '/register', builder: (c, s) => const RegisterScreen()),
      GoRoute(
        path: '/',
        pageBuilder: (c, s) => const NoTransitionPage(child: DashboardScreen()),
      ),
      crud(Entities.products),
      crud(Entities.categories),
      crud(Entities.brands),
      crud(Entities.collections),
      crud(Entities.variants),
      crud(Entities.deliveryMethods),
      crud(Entities.addresses),
      crud(Entities.myOrders),
      crud(Entities.orders),
      crud(Entities.orderItems),
      crud(Entities.deliveries),
      crud(Entities.loyalty),
      crud(Entities.users),
      GoRoute(
        path: '/cart',
        redirect: need(Permission.useCart),
        pageBuilder: (c, s) => const NoTransitionPage(child: CartScreen()),
      ),
      GoRoute(
        path: '/checkout',
        redirect: need(Permission.useCart),
        pageBuilder: (c, s) => NoTransitionPage(
          child: DeferredScreen(
            load: checkout.loadLibrary,
            builder: (_) => checkout.CheckoutScreen(),
          ),
        ),
      ),
      GoRoute(
        path: '/admin/stats',
        redirect: need(Permission.viewStats),
        pageBuilder: (c, s) => NoTransitionPage(
          child: DeferredScreen(
            load: stats.loadLibrary,
            builder: (_) => stats.StatsScreen(),
          ),
        ),
      ),
      GoRoute(path: '/forbidden', builder: (c, s) => const ForbiddenScreen()),
    ],
    errorBuilder: (c, s) => NotFoundScreen(location: s.uri.toString()),
  );
}
