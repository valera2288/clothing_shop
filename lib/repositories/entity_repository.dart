import '../models/address.dart';
import '../models/app_user.dart';
import '../models/brand.dart';
import '../models/category.dart';
import '../models/delivery.dart';
import '../models/delivery_method.dart';
import '../models/list_query.dart';
import '../models/loyalty_card.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import '../models/page_result.dart';
import '../models/product.dart';
import '../models/product_collection.dart';
import '../models/product_variant.dart';

/// Общий набор операций над любой сущностью. Экраны и notifier'ы знают только
/// этот интерфейс; как именно данные попадают на сервер, решает реализация
/// (сейчас — `PbRepository`, REST API PocketBase).
abstract interface class EntityRepository<T> {
  Future<PageResult<T>> find(ListQuery query);
  Future<T?> findById(String id);
  Future<T> create(Map<String, dynamic> body);
  Future<T> update(String id, Map<String, dynamic> body);
  Future<void> softDelete(String id);
  Future<void> hardDelete(String id);
  Future<void> restore(String id);
  Future<int> deleteMany(List<String> ids);
  Future<List<T>> findAll();
}

abstract interface class UserRepository implements EntityRepository<AppUser> {}

abstract interface class LoyaltyCardRepository
    implements EntityRepository<LoyaltyCard> {
  /// Карта пользователя или null, если её нет (связь 1:1).
  Future<LoyaltyCard?> findByUser(String userId);
}

abstract interface class AddressRepository
    implements EntityRepository<Address> {}

abstract interface class CategoryRepository
    implements EntityRepository<Category> {}

abstract interface class BrandRepository implements EntityRepository<Brand> {}

abstract interface class ProductRepository
    implements EntityRepository<Product> {}

abstract interface class CollectionRepository
    implements EntityRepository<ProductCollection> {}

abstract interface class ProductVariantRepository
    implements EntityRepository<ProductVariant> {
  Future<List<ProductVariant>> findByProduct(String productId);
  Future<List<ProductVariant>> findByIds(List<String> ids);
}

abstract interface class DeliveryMethodRepository
    implements EntityRepository<DeliveryMethod> {}

/// Позиция корзины при оформлении заказа.
class OrderLine {
  final String variantId;
  final int quantity;
  final int price;
  const OrderLine(this.variantId, this.quantity, this.price);
}

/// Данные для оформления заказа.
class OrderDraft {
  final String userId;
  final String addressId;
  final String deliveryMethodId;
  final String payment;
  final String comment;
  final int total;
  final List<OrderLine> lines;
  const OrderDraft({
    required this.userId,
    required this.addressId,
    required this.deliveryMethodId,
    required this.payment,
    this.comment = '',
    required this.total,
    required this.lines,
  });
}

abstract interface class OrderRepository implements EntityRepository<Order> {
  Future<List<OrderItem>> itemsOf(String orderId);
  Future<Order> changeStatus(String id, String status);

  /// Оформление: проверка остатков, заказ, его позиции, списание остатков.
  Future<Order> place(OrderDraft draft);
}

abstract interface class OrderItemRepository
    implements EntityRepository<OrderItem> {}

abstract interface class DeliveryRepository
    implements EntityRepository<Delivery> {
  Future<Delivery?> findByOrder(String orderId);
}

/// Показатели для раздела «Статистика».
class ShopStats {
  final Map<String, int> ordersByStatus;
  final int revenue;
  final int revenueMonth;
  final int products;
  final int lowStock;
  final Map<String, int> usersByRole;
  const ShopStats({
    required this.ordersByStatus,
    required this.revenue,
    required this.revenueMonth,
    required this.products,
    required this.lowStock,
    required this.usersByRole,
  });

  int get orders => ordersByStatus.values.fold(0, (a, b) => a + b);
}

abstract interface class StatsRepository {
  Future<ShopStats> load();
}
