import 'package:dio/dio.dart';

import '../../core/api_exceptions.dart';
import '../../models/address.dart';
import '../../models/app_user.dart';
import '../../models/brand.dart';
import '../../models/category.dart';
import '../../models/delivery.dart';
import '../../models/delivery_method.dart';
import '../../models/list_query.dart';
import '../../models/loyalty_card.dart';
import '../../models/order.dart';
import '../../models/order_item.dart';
import '../../models/product.dart';
import '../../models/product_collection.dart';
import '../../models/product_variant.dart';
import '../entity_repository.dart';
import 'pb_repository.dart';

/// Условие «поле равно значению» из фильтра, если фильтр задан.
String? _eq(ListQuery q, String key, String field) =>
    q.filter(key) == null ? null : '$field = ${pbQuote(q.filter(key)!)}';

/// Число из фильтра; нечисловое значение игнорируется.
num? _num(ListQuery q, String key) => num.tryParse(q.filter(key) ?? '');

/// Дата из фильтра (`2026-10-31`) в формате PocketBase.
String? _date(ListQuery q, String key, {bool endOfDay = false}) {
  final v = q.filter(key);
  if (v == null || DateTime.tryParse(v) == null) return null;
  return '${v.substring(0, 10)} ${endOfDay ? '23:59:59' : '00:00:00'}';
}

class PbUserRepository extends PbRepository<AppUser> implements UserRepository {
  PbUserRepository(super.dio);
  @override
  String get collection => 'users';
  @override
  List<String> get searchFields => const ['name', 'email'];
  @override
  AppUser fromJson(Map<String, dynamic> json) => AppUser.fromJson(json);
  @override
  String get defaultSort => 'name';
  @override
  List<String> filterParts(ListQuery q) => [
        if (_eq(q, 'role', 'role') case final s?) s,
      ];
}

class PbLoyaltyCardRepository extends PbRepository<LoyaltyCard>
    implements LoyaltyCardRepository {
  PbLoyaltyCardRepository(super.dio);
  @override
  String get collection => 'loyalty_cards';
  @override
  String get expand => 'user';
  @override
  List<String> get searchFields => const ['number', 'user.name', 'user.email'];
  @override
  LoyaltyCard fromJson(Map<String, dynamic> json) => LoyaltyCard.fromJson(json);
  @override
  List<String> filterParts(ListQuery q) => [
        if (_eq(q, 'tier', 'tier') case final s?) s,
        if (_num(q, 'pointsFrom') case final n?) 'points >= $n',
      ];

  @override
  Future<LoyaltyCard?> findByUser(String userId) async {
    final list = await findWhere('user = ${pbQuote(userId)}');
    return list.isEmpty ? null : list.first;
  }
}

class PbAddressRepository extends PbRepository<Address>
    implements AddressRepository {
  PbAddressRepository(super.dio);
  @override
  String get collection => 'addresses';
  @override
  String get expand => 'user';
  @override
  List<String> get searchFields => const ['city', 'street', 'postal_code'];
  @override
  Address fromJson(Map<String, dynamic> json) => Address.fromJson(json);
  @override
  List<String> filterParts(ListQuery q) => [
        if (_eq(q, 'city', 'city') case final s?) s,
        if (_eq(q, 'user', 'user') case final s?) s,
      ];
}

class PbCategoryRepository extends PbRepository<Category>
    implements CategoryRepository {
  PbCategoryRepository(super.dio);
  @override
  String get collection => 'categories';
  @override
  bool get hasSoftDelete => true;
  @override
  List<String> get searchFields => const ['name', 'slug'];
  @override
  String get defaultSort => 'name';
  @override
  Category fromJson(Map<String, dynamic> json) => Category.fromJson(json);
}

class PbBrandRepository extends PbRepository<Brand> implements BrandRepository {
  PbBrandRepository(super.dio);
  @override
  String get collection => 'brands';
  @override
  bool get hasSoftDelete => true;
  @override
  List<String> get searchFields => const ['name', 'country'];
  @override
  String get defaultSort => 'name';
  @override
  Brand fromJson(Map<String, dynamic> json) => Brand.fromJson(json);
  @override
  List<String> filterParts(ListQuery q) => [
        if (_eq(q, 'country', 'country') case final s?) s,
      ];
}

class PbProductRepository extends PbRepository<Product>
    implements ProductRepository {
  PbProductRepository(super.dio);
  @override
  String get collection => 'products';
  @override
  String get expand => 'category,brand';
  @override
  bool get hasSoftDelete => true;
  @override
  List<String> get searchFields => const ['name', 'sku', 'material'];
  @override
  String get defaultSort => 'name';
  @override
  Product fromJson(Map<String, dynamic> json) => Product.fromJson(json);

  /// Фильтры каталога выполняет сервер. Размер, цвет и наличие берутся из
  /// связанных вариантов через обратную связь `product_variants_via_product`,
  /// принадлежность коллекции — через `collections_via_products`.
  @override
  List<String> filterParts(ListQuery q) => [
        if (_eq(q, 'category', 'category') case final s?) s,
        if (_eq(q, 'brand', 'brand') case final s?) s,
        if (_eq(q, 'gender', 'gender') case final s?) s,
        if (_num(q, 'priceFrom') case final n?) 'price >= $n',
        if (_num(q, 'priceTo') case final n?) 'price <= $n',
        if (_eq(q, 'size', 'product_variants_via_product.size') case final s?)
          s.replaceFirst(' = ', ' ?= '),
        if (_eq(q, 'color', 'product_variants_via_product.color') case final s?)
          s.replaceFirst(' = ', ' ?= '),
        if (_eq(q, 'collection', 'collections_via_products.id') case final s?)
          s.replaceFirst(' = ', ' ?= '),
        if (q.filter('inStock') == '1')
          'product_variants_via_product.stock ?> 0',
      ];
}

class PbCollectionRepository extends PbRepository<ProductCollection>
    implements CollectionRepository {
  PbCollectionRepository(super.dio);
  @override
  String get collection => 'collections';
  @override
  bool get hasSoftDelete => true;
  @override
  List<String> get searchFields => const ['title', 'description'];
  @override
  String get defaultSort => '-year';
  @override
  ProductCollection fromJson(Map<String, dynamic> json) =>
      ProductCollection.fromJson(json);
  @override
  List<String> filterParts(ListQuery q) => [
        if (_eq(q, 'season', 'season') case final s?) s,
        if (_num(q, 'year') case final n?) 'year = $n',
      ];
}

class PbProductVariantRepository extends PbRepository<ProductVariant>
    implements ProductVariantRepository {
  PbProductVariantRepository(super.dio);
  @override
  String get collection => 'product_variants';
  @override
  String get expand => 'product';
  @override
  bool get hasSoftDelete => true;
  @override
  List<String> get searchFields => const ['color', 'product.name'];
  @override
  String get defaultSort => '-created';
  @override
  ProductVariant fromJson(Map<String, dynamic> json) =>
      ProductVariant.fromJson(json);
  @override
  List<String> filterParts(ListQuery q) => [
        if (_eq(q, 'product', 'product') case final s?) s,
        if (_eq(q, 'size', 'size') case final s?) s,
        if (q.filter('stock') == 'none') 'stock = 0',
        if (q.filter('stock') == 'low') '(stock > 0 && stock <= 5)',
      ];

  @override
  Future<List<ProductVariant>> findByProduct(String productId) =>
      findWhere('product = ${pbQuote(productId)} && deleted = false',
          sort: 'color,size');

  @override
  Future<List<ProductVariant>> findByIds(List<String> ids) {
    if (ids.isEmpty) return Future.value(const []);
    return findWhere(ids.map((id) => 'id = ${pbQuote(id)}').join(' || '));
  }
}

class PbDeliveryMethodRepository extends PbRepository<DeliveryMethod>
    implements DeliveryMethodRepository {
  PbDeliveryMethodRepository(super.dio);
  @override
  String get collection => 'delivery_methods';
  @override
  bool get hasSoftDelete => true;
  @override
  List<String> get searchFields => const ['name', 'description'];
  @override
  String get defaultSort => 'price';
  @override
  DeliveryMethod fromJson(Map<String, dynamic> json) =>
      DeliveryMethod.fromJson(json);
}

class PbOrderRepository extends PbRepository<Order> implements OrderRepository {
  PbOrderRepository(super.dio);
  @override
  String get collection => 'orders';
  @override
  String get expand => 'user,address,delivery_method';
  @override
  List<String> get searchFields =>
      const ['id', 'user.name', 'user.email', 'comment'];
  @override
  String get defaultSort => '-ordered_at';
  @override
  Order fromJson(Map<String, dynamic> json) => Order.fromJson(json);

  /// Отбор заказов: статус, способ доставки, клиент и период оформления.
  @override
  List<String> filterParts(ListQuery q) => [
        if (_eq(q, 'status', 'status') case final s?) s,
        if (_eq(q, 'method', 'delivery_method') case final s?) s,
        if (_eq(q, 'customer', 'user') case final s?) s,
        if (_date(q, 'dateFrom') case final d?) 'ordered_at >= ${pbQuote(d)}',
        if (_date(q, 'dateTo', endOfDay: true) case final d?)
          'ordered_at <= ${pbQuote(d)}',
      ];

  @override
  Future<List<OrderItem>> itemsOf(String orderId) => guard(() async {
        final response = await dio.get<Map<String, dynamic>>(
          '/collections/order_items/records',
          queryParameters: {
            'perPage': 200,
            'filter': 'order = ${pbQuote(orderId)}',
            'expand': 'variant.product',
          },
        );
        return ((response.data?['items'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(OrderItem.fromJson)
            .toList();
      });

  /// При отмене товары возвращаются на склад. Правила сервера разрешают это
  /// только менеджеру: у покупателя возврат остатка отклоняется, и отмена
  /// остаётся без возврата (менеджер вернёт остаток вручную).
  @override
  Future<Order> changeStatus(String id, String status) async {
    final order = await update(id, {'status': status});
    if (status == 'cancelled') {
      for (final item in await itemsOf(id)) {
        try {
          final v = await guard(() => dio.get<Map<String, dynamic>>(
              '/collections/product_variants/records/${item.variantId}'));
          final stock = (v.data?['stock'] as num?)?.toInt() ?? 0;
          await guard(() => dio.patch(
                '/collections/product_variants/records/${item.variantId}',
                data: {'stock': stock + item.quantity},
              ));
        } on ApiException {
          // Нет прав вернуть остаток: заказ при этом уже отменён
        }
      }
    }
    return order;
  }

  @override
  Future<Order> place(OrderDraft draft) async {
    // 1. Остатки перечитываются непосредственно перед оформлением:
    //    корзина могла устареть
    final variants = await guard(() async {
      final filter =
          draft.lines.map((l) => 'id = ${pbQuote(l.variantId)}').join(' || ');
      final r = await dio.get<Map<String, dynamic>>(
        '/collections/product_variants/records',
        queryParameters: {'perPage': 200, 'filter': filter},
      );
      return {
        for (final v in (r.data?['items'] as List? ?? const []))
          (v as Map)['id'] as String: (v['stock'] as num).toInt(),
      };
    });
    for (final l in draft.lines) {
      final stock = variants[l.variantId];
      if (stock == null || stock < l.quantity) {
        throw const ConflictException(
            'Некоторых товаров нет в нужном количестве. Обновите корзину.');
      }
    }

    // 2. Заказ и позиции. Если позиция не создалась, заказ отменяется,
    //    чтобы в системе не осталось пустого заказа
    final order = await create({
      'user': draft.userId,
      'address': draft.addressId,
      'delivery_method': draft.deliveryMethodId,
      'status': 'new',
      'payment': draft.payment,
      'total': draft.total,
      'comment': draft.comment,
      'ordered_at': DateTime.now().toUtc().toIso8601String(),
    });
    try {
      for (final l in draft.lines) {
        await guard(() => dio.post(
              '/collections/order_items/records',
              data: {
                'order': order.id,
                'variant': l.variantId,
                'quantity': l.quantity,
                'price': l.price,
              },
            ));
        await guard(() => dio.patch(
              '/collections/product_variants/records/${l.variantId}',
              data: {'stock': variants[l.variantId]! - l.quantity},
            ));
      }
    } on ApiException {
      await update(order.id, {'status': 'cancelled'})
          .then((_) {}, onError: (_) {});
      rethrow;
    }
    return order;
  }
}

class PbOrderItemRepository extends PbRepository<OrderItem>
    implements OrderItemRepository {
  PbOrderItemRepository(super.dio);
  @override
  String get collection => 'order_items';
  @override
  String get expand => 'variant.product';
  @override
  List<String> get searchFields => const ['variant.product.name'];
  @override
  OrderItem fromJson(Map<String, dynamic> json) => OrderItem.fromJson(json);
  @override
  List<String> filterParts(ListQuery q) => [
        if (_eq(q, 'order', 'order') case final s?) s,
      ];
}

class PbDeliveryRepository extends PbRepository<Delivery>
    implements DeliveryRepository {
  PbDeliveryRepository(super.dio);
  @override
  String get collection => 'deliveries';
  @override
  String get expand => 'order';
  @override
  List<String> get searchFields =>
      const ['track_number', 'order.id', 'order.user.name'];
  @override
  Delivery fromJson(Map<String, dynamic> json) => Delivery.fromJson(json);
  @override
  List<String> filterParts(ListQuery q) => [
        if (_eq(q, 'status', 'status') case final s?) s,
        if (_eq(q, 'carrier', 'carrier') case final s?) s,
        if (_date(q, 'etaTo', endOfDay: true) case final d?)
          'eta <= ${pbQuote(d)}',
      ];

  @override
  Future<Delivery?> findByOrder(String orderId) async {
    final list = await findWhere('order = ${pbQuote(orderId)}');
    return list.isEmpty ? null : list.first;
  }
}

class PbStatsRepository implements StatsRepository {
  final Dio dio;
  PbStatsRepository(this.dio);

  Future<int> _count(String collection, [String? filter]) => guard(() async {
        final r = await dio.get<Map<String, dynamic>>(
          '/collections/$collection/records',
          queryParameters: {
            'page': 1,
            'perPage': 1,
            if (filter != null) 'filter': filter,
          },
        );
        return (r.data?['totalItems'] as num?)?.toInt() ?? 0;
      });

  /// Сумма заказов по фильтру. PocketBase не умеет агрегировать,
  /// поэтому читаем только поле `total` и складываем на клиенте.
  Future<int> _sum(String filter) => guard(() async {
        var sum = 0;
        var page = 1;
        while (true) {
          final r = await dio.get<Map<String, dynamic>>(
            '/collections/orders/records',
            queryParameters: {
              'page': page,
              'perPage': 500,
              'filter': filter,
              'fields': 'total',
            },
          );
          for (final i in (r.data?['items'] as List? ?? const [])) {
            sum += ((i as Map)['total'] as num).toInt();
          }
          if (page >= ((r.data?['totalPages'] as num?)?.toInt() ?? 1)) {
            return sum;
          }
          page++;
        }
      });

  @override
  Future<ShopStats> load() async {
    const statuses = [
      'new',
      'paid',
      'packed',
      'shipped',
      'delivered',
      'cancelled'
    ];
    final month = DateTime.now().subtract(const Duration(days: 30));
    final since = month.toUtc().toIso8601String().substring(0, 10);
    final counts = await Future.wait([
      for (final s in statuses) _count('orders', 'status = "$s"'),
    ]);
    final roles = await Future.wait([
      for (final r in const ['customer', 'manager', 'admin'])
        _count('users', 'role = "$r"'),
    ]);
    final results = await Future.wait([
      _sum('status != "cancelled"'),
      _sum('status != "cancelled" && ordered_at >= "$since 00:00:00"'),
      _count('products', 'deleted = false'),
      _count('product_variants', 'deleted = false && stock <= 5'),
    ]);
    return ShopStats(
      ordersByStatus: {
        for (var i = 0; i < statuses.length; i++) statuses[i]: counts[i]
      },
      revenue: results[0],
      revenueMonth: results[1],
      products: results[2],
      lowStock: results[3],
      usersByRole: {
        'customer': roles[0],
        'manager': roles[1],
        'admin': roles[2],
      },
    );
  }
}
