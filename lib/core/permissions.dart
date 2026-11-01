/// Роли пользователей (поле `role` коллекции users).
enum Role {
  customer('покупатель'),
  manager('менеджер'),
  admin('администратор');

  final String title;
  const Role(this.title);

  /// Незнакомая роль трактуется как самая безобидная: опечатка в данных
  /// не должна выдавать права администратора.
  static Role fromCode(String? code) => Role.values
      .firstWhere((r) => r.name == code, orElse: () => Role.customer);
}

/// Операции, доступ к которым различается по ролям.
enum Permission {
  /// Просмотр каталога: товары, категории, бренды, коллекции.
  viewCatalog,

  /// Корзина и оформление заказа.
  useCart,

  /// Свои заказы, отслеживание доставки, свои адреса.
  viewOwnOrders,
  manageAddresses,

  /// Все заказы и смена их статуса.
  manageOrders,

  /// Доставки: трек-номер, статус, срок.
  manageDeliveries,

  /// Карты лояльности покупателей.
  manageLoyalty,

  /// Создание, изменение и логическое удаление товаров и справочников.
  manageCatalog,

  /// Физическое удаление и восстановление записей каталога.
  hardDelete,
  restore,

  /// Управление пользователями и ролями.
  manageUsers,

  /// Статистика магазина.
  viewStats,
}

/// Права по ролям. Наборы различаются по составу функций, а не по объёму:
/// у каждой роли есть раздел, которого нет у остальных
/// (покупатель — корзина и «Мои заказы», менеджер — «Заказы», «Доставки»
/// и «Карты лояльности», администратор — управление каталогом,
/// «Пользователи» и «Статистика»).
const Map<Role, Set<Permission>> rolePermissions = {
  Role.customer: {
    Permission.viewCatalog,
    Permission.useCart,
    Permission.viewOwnOrders,
    Permission.manageAddresses,
  },
  Role.manager: {
    Permission.viewCatalog,
    Permission.manageOrders,
    Permission.manageDeliveries,
    Permission.manageLoyalty,
  },
  Role.admin: {
    Permission.viewCatalog,
    Permission.manageCatalog,
    Permission.hardDelete,
    Permission.restore,
    Permission.manageUsers,
    Permission.viewStats,
  },
};

bool roleCan(Role? role, Permission permission) =>
    role != null && (rolePermissions[role]?.contains(permission) ?? false);
