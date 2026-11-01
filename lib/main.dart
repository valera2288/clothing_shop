import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/api_client.dart';
import 'core/labels.dart';
import 'core/router.dart';
import 'models/list_query.dart';
import 'repositories/auth_repository.dart';
import 'repositories/entity_repository.dart';
import 'repositories/pb/pb_repositories.dart';
import 'state/auth_notifier.dart';
import 'state/cart_notifier.dart';
import 'state/connection_notifier.dart';
import 'state/lookup_service.dart';
import 'widgets/inactivity_watcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  final prefs = await SharedPreferences.getInstance();
  final auth = AuthNotifier(prefs);
  final connection = ConnectionNotifier();
  // Адрес сервера задаётся при сборке (--dart-define=API_BASE_URL=...).
  // При ответе 401 токен обновляется и запрос повторяется прозрачно
  final dio = buildDio(
    onConnection: (offline) => connection.report(offline: offline),
    tokenProvider: () => auth.accessToken,
    onUnauthorized: auth.refreshTokens,
  );
  connection.dio = dio;
  auth.repository = PbAuthRepository(dio);
  // Сессия восстанавливается до построения дерева виджетов,
  // иначе после перезагрузки мелькнул бы экран входа
  await auth.restore();

  runApp(ShopApp(
      auth: auth,
      connection: connection,
      prefs: prefs,
      deps: ShopDeps.pb(dio)));
}

/// Все репозитории приложения. Смена сервера сводится к замене этого набора:
/// экраны и состояние работают с интерфейсами.
class ShopDeps {
  final UserRepository users;
  final LoyaltyCardRepository loyalty;
  final AddressRepository addresses;
  final CategoryRepository categories;
  final BrandRepository brands;
  final ProductRepository products;
  final CollectionRepository collections;
  final ProductVariantRepository variants;
  final DeliveryMethodRepository deliveryMethods;
  final OrderRepository orders;
  final OrderItemRepository orderItems;
  final DeliveryRepository deliveries;
  final StatsRepository stats;

  const ShopDeps({
    required this.users,
    required this.loyalty,
    required this.addresses,
    required this.categories,
    required this.brands,
    required this.products,
    required this.collections,
    required this.variants,
    required this.deliveryMethods,
    required this.orders,
    required this.orderItems,
    required this.deliveries,
    required this.stats,
  });

  factory ShopDeps.pb(Dio dio) => ShopDeps(
        users: PbUserRepository(dio),
        loyalty: PbLoyaltyCardRepository(dio),
        addresses: PbAddressRepository(dio),
        categories: PbCategoryRepository(dio),
        brands: PbBrandRepository(dio),
        products: PbProductRepository(dio),
        collections: PbCollectionRepository(dio),
        variants: PbProductVariantRepository(dio),
        deliveryMethods: PbDeliveryMethodRepository(dio),
        orders: PbOrderRepository(dio),
        orderItems: PbOrderItemRepository(dio),
        deliveries: PbDeliveryRepository(dio),
        stats: PbStatsRepository(dio),
      );

  /// Справочные списки для выпадающих списков, фильтров и множественного выбора.
  LookupService lookups() => LookupService({
        'categories': () async => [
              for (final x in await categories.findAll()) Option(x.id, x.name),
            ],
        'brands': () async => [
              for (final x in await brands.findAll()) Option(x.id, x.name),
            ],
        'collections': () async => [
              for (final x in await collections.findAll())
                Option(x.id, x.title),
            ],
        'products': () async => [
              for (final x in await products.findAll())
                Option(x.id, '${x.name} (${x.sku})'),
            ],
        'deliveryMethods': () async => [
              for (final x in await deliveryMethods.findAll())
                Option(x.id, '${x.name} — ${rub(x.price)}'),
            ],
        'customers': () async => [
              for (final x in (await users.find(ListQuery(
                defaultSort: 'name',
                perPage: 200,
                filters: const {'role': 'customer'},
              )))
                  .items)
                Option(x.id, '${x.name} (${x.email})'),
            ],
        'addresses': () async => [
              for (final x in await addresses.findAll())
                Option(x.id, '${x.userName}: ${x.full}'),
            ],
        'orders': () async => [
              for (final x in await orders.findAll())
                Option(x.id,
                    '${x.number} · ${x.userName} · ${dateText(x.orderedAt)}'),
            ],
        'variants': () async => [
              for (final x in await variants.findAll())
                Option(x.id, '${x.productName}: ${x.label}'),
            ],
      });
}

class ShopApp extends StatefulWidget {
  final AuthNotifier auth;
  final ConnectionNotifier connection;
  final SharedPreferences prefs;
  final ShopDeps deps;

  const ShopApp({
    super.key,
    required this.auth,
    required this.connection,
    required this.prefs,
    required this.deps,
  });

  @override
  State<ShopApp> createState() => _ShopAppState();
}

class _ShopAppState extends State<ShopApp> {
  // Маршрутизатор создаётся один раз: его redirect читает AuthNotifier
  late final _router = buildRouter(widget.auth);
  late final _lookups = widget.deps.lookups();

  @override
  void initState() {
    super.initState();
    // Справочники зависят от прав пользователя: при входе и выходе кэш сбрасывается
    widget.auth.addListener(_lookups.invalidate);
  }

  @override
  void dispose() {
    widget.auth.removeListener(_lookups.invalidate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final d = w.deps;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthNotifier>.value(value: w.auth),
        ChangeNotifierProvider<ConnectionNotifier>.value(value: w.connection),
        ChangeNotifierProvider<LookupService>.value(value: _lookups),
        Provider<UserRepository>.value(value: d.users),
        Provider<LoyaltyCardRepository>.value(value: d.loyalty),
        Provider<AddressRepository>.value(value: d.addresses),
        Provider<CategoryRepository>.value(value: d.categories),
        Provider<BrandRepository>.value(value: d.brands),
        Provider<ProductRepository>.value(value: d.products),
        Provider<CollectionRepository>.value(value: d.collections),
        Provider<ProductVariantRepository>.value(value: d.variants),
        Provider<DeliveryMethodRepository>.value(value: d.deliveryMethods),
        Provider<OrderRepository>.value(value: d.orders),
        Provider<OrderItemRepository>.value(value: d.orderItems),
        Provider<DeliveryRepository>.value(value: d.deliveries),
        Provider<StatsRepository>.value(value: d.stats),
      ],
      child: MaterialApp.router(
        title: 'Магазин одежды',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5E35B1)),
          useMaterial3: true,
        ),
        routerConfig: _router,
        builder: (context, child) => ListenableBuilder(
          listenable: w.auth,
          builder: (context, _) => KeyedSubtree(
            // Состояние принадлежит пользователю: при входе и выходе оно
            // создаётся заново, и следующий пользователь не увидит чужую
            // корзину и кэш справочников
            key: ValueKey(w.auth.user?.id),
            child: ChangeNotifierProvider(
              create: (_) => CartNotifier(w.prefs, w.auth.user?.id ?? 'guest'),
              // Неактивность отслеживается над всеми экранами сразу
              child: InactivityWatcher(
                enabled: w.auth.isAuthenticated,
                timeout: AuthNotifier.inactivityTimeout,
                warning: AuthNotifier.inactivityWarning,
                onActivity: w.auth.markActivity,
                onTimeout: () => w.auth
                    .logout(reason: 'Сессия завершена из-за неактивности.'),
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
