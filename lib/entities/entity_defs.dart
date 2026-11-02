import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/labels.dart';
import '../core/permissions.dart';
import '../models/address.dart';
import '../models/app_user.dart';
import '../models/brand.dart';
import '../models/category.dart';
import '../models/delivery.dart';
import '../models/delivery_method.dart';
import '../models/loyalty_card.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import '../models/product.dart';
import '../models/product_collection.dart';
import '../models/product_variant.dart';
import '../repositories/entity_repository.dart';
import '../screens/shop/order_panel.dart';
import '../screens/shop/product_card.dart';
import '../screens/shop/variants_panel.dart';
import '../state/auth_notifier.dart';
import '../widgets/entity_table.dart';
import 'entity_def.dart';

String _ymd(DateTime? d) {
  if (d == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

/// Ячейка-ссылка на карточку записи.
Widget _link(String path, String text, {bool deleted = false}) => Builder(
      builder: (context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => context.go(path),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: deleted
                    ? Colors.grey
                    : Theme.of(context).colorScheme.primary,
                decoration: deleted ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ),
      ),
    );

Widget _text(String text, {int maxWidth = 260}) => ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth.toDouble()),
      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
    );

/// Цвет подписи статуса заказа и доставки.
Color statusColor(String status) => switch (status) {
      'new' || 'pending' => Colors.blueGrey,
      'paid' || 'packed' || 'in_transit' => Colors.blue,
      'shipped' || 'out_for_delivery' => Colors.orange,
      'delivered' => Colors.green,
      'cancelled' || 'returned' => Colors.red,
      _ => Colors.grey,
    };

Widget statusChip(String text, String status) {
  final c = statusColor(status);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: c.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(text, style: TextStyle(color: c, fontSize: 12)),
  );
}

/// Описания всех сущностей. Каждое — вход для общих экранов списка,
/// карточки и формы.
class Entities {
  Entities._();

  static const _stockOptions = {'none': 'Нет в наличии', 'low': 'Мало (до 5)'};

  // ---- Пользователи (администратор) --------------------------------------
  static final users = EntityDef<AppUser>(
    path: '/admin/users',
    title: 'Пользователи',
    createTitle: 'Новый пользователь',
    editTitle: 'Изменение пользователя',
    icon: Icons.admin_panel_settings,
    view: Permission.manageUsers,
    manage: Permission.manageUsers,
    repo: (c) => c.read<UserRepository>(),
    id: (u) => u.id,
    itemTitle: (u) => u.name,
    itemSubtitle: (u) => u.email,
    defaultSort: 'name',
    searchHint: 'Имя или почта',
    sorts: const [
      SortSpec('name', 'По имени'),
      SortSpec('email', 'По почте'),
      SortSpec('role', 'По роли'),
      SortSpec('-created', 'Сначала новые'),
    ],
    filters: [
      FilterSpec('role', 'Роль', FilterKind.select, options: roleLabels),
    ],
    columns: [
      TableColumnSpec<AppUser>(
        label: 'Имя',
        sortField: 'name',
        build: (u) => _link('/admin/users/${u.id}', u.name),
      ),
      TableColumnSpec<AppUser>(
        label: 'Почта',
        sortField: 'email',
        build: (u) => Text(u.email),
      ),
      TableColumnSpec<AppUser>(
        label: 'Телефон',
        wideOnly: true,
        build: (u) => Text(u.phone),
      ),
      TableColumnSpec<AppUser>(
        label: 'Роль',
        sortField: 'role',
        build: (u) => Text(u.role.title),
      ),
    ],
    cardLines: (u) => [u.role.title, if (u.phone.isNotEmpty) u.phone],
    details: (u) => [
      ('Имя', u.name),
      ('Почта', u.email),
      ('Телефон', u.phone),
      ('Роль', u.role.title),
    ],
    fields: const [
      FieldSpec('name', 'Имя', FieldKind.text,
          required: true, minLength: 2, maxLength: 80),
      FieldSpec('email', 'Почта', FieldKind.email, required: true),
      FieldSpec('password', 'Пароль', FieldKind.password,
          required: true, createOnly: true),
      FieldSpec('phone', 'Телефон', FieldKind.phone,
          hint: 'Например, +7 900 123-45-67'),
      FieldSpec('role', 'Роль', FieldKind.select,
          required: true, options: roleLabels, initial: 'customer'),
    ],
    canDeleteItem: (c, u) => u.id != c.read<AuthNotifier>().user?.id,
    initialValues: (u) => {
      'name': u.name,
      'email': u.email,
      'phone': u.phone,
      'role': u.role.name,
    },
  );

  // ---- Карты лояльности (менеджер) ---------------------------------------
  static final loyalty = EntityDef<LoyaltyCard>(
    path: '/loyalty',
    title: 'Карты лояльности',
    createTitle: 'Новая карта',
    editTitle: 'Изменение карты',
    icon: Icons.card_membership,
    view: Permission.manageLoyalty,
    manage: Permission.manageLoyalty,
    repo: (c) => c.read<LoyaltyCardRepository>(),
    id: (x) => x.id,
    itemTitle: (x) => x.number,
    itemSubtitle: (x) => x.userName,
    defaultSort: 'number',
    searchHint: 'Номер или клиент',
    sorts: const [
      SortSpec('number', 'По номеру'),
      SortSpec('-points', 'Больше баллов'),
      SortSpec('points', 'Меньше баллов'),
    ],
    filters: [
      FilterSpec('tier', 'Уровень', FilterKind.select, options: tierLabels),
      const FilterSpec('pointsFrom', 'Баллы от', FilterKind.number),
    ],
    columns: [
      TableColumnSpec<LoyaltyCard>(
        label: 'Номер',
        sortField: 'number',
        build: (x) => _link('/loyalty/${x.id}', x.number),
      ),
      TableColumnSpec<LoyaltyCard>(
        label: 'Клиент',
        build: (x) => _text(x.userName),
      ),
      TableColumnSpec<LoyaltyCard>(
        label: 'Уровень',
        build: (x) => Text(label(tierLabels, x.tier)),
      ),
      TableColumnSpec<LoyaltyCard>(
        label: 'Баллы',
        sortField: 'points',
        numeric: true,
        build: (x) => Text('${x.points}'),
      ),
    ],
    cardLines: (x) => [label(tierLabels, x.tier), 'Баллов: ${x.points}'],
    details: (x) => [
      ('Номер', x.number),
      ('Клиент', x.userName),
      ('Уровень', label(tierLabels, x.tier)),
      ('Скидка', '${tierDiscount[x.tier] ?? 0}%'),
      ('Баллы', '${x.points}'),
    ],
    fields: [
      const FieldSpec('user', 'Клиент', FieldKind.relation,
          required: true, lookup: 'customers'),
      FieldSpec('number', 'Номер карты', FieldKind.text,
          required: true,
          pattern: RegExp(r'^LC-\d{6}$'),
          patternMessage: 'Формат: LC-123456',
          hint: 'LC- и шесть цифр'),
      const FieldSpec('tier', 'Уровень', FieldKind.select,
          required: true, options: tierLabels, initial: 'bronze'),
      const FieldSpec('points', 'Баллы', FieldKind.integer,
          min: 0, max: 1000000, initial: '0'),
    ],
    initialValues: (x) => {
      'user': x.userId,
      'number': x.number,
      'tier': x.tier,
      'points': '${x.points}',
    },
  );

  // ---- Адреса (покупатель) -----------------------------------------------
  static final addresses = EntityDef<Address>(
    path: '/addresses',
    title: 'Мои адреса',
    createTitle: 'Новый адрес',
    editTitle: 'Изменение адреса',
    icon: Icons.location_on,
    view: Permission.manageAddresses,
    manage: Permission.manageAddresses,
    repo: (c) => c.read<AddressRepository>(),
    id: (a) => a.id,
    itemTitle: (a) => '${a.city}, ${a.street}, ${a.house}',
    itemSubtitle: (a) => a.postalCode,
    defaultSort: '-created',
    searchHint: 'Город, улица или индекс',
    sorts: const [
      SortSpec('city', 'По городу'),
      SortSpec('-created', 'Сначала новые'),
    ],
    filters: const [FilterSpec('city', 'Город', FilterKind.text)],
    columns: [
      TableColumnSpec<Address>(
        label: 'Город',
        sortField: 'city',
        build: (a) => _link('/addresses/${a.id}', a.city),
      ),
      TableColumnSpec<Address>(label: 'Улица', build: (a) => Text(a.street)),
      TableColumnSpec<Address>(label: 'Дом', build: (a) => Text(a.house)),
      TableColumnSpec<Address>(label: 'Кв.', build: (a) => Text(a.flat)),
      TableColumnSpec<Address>(
        label: 'Индекс',
        build: (a) => Text(a.postalCode),
      ),
      TableColumnSpec<Address>(
        label: 'Основной',
        build: (a) => Text(a.isDefault ? 'Да' : ''),
      ),
    ],
    cardLines: (a) => [a.full, if (a.isDefault) 'Основной адрес'],
    details: (a) => [
      ('Город', a.city),
      ('Улица', a.street),
      ('Дом', a.house),
      ('Квартира', a.flat),
      ('Индекс', a.postalCode),
      ('Основной', a.isDefault ? 'Да' : 'Нет'),
    ],
    fields: [
      const FieldSpec('city', 'Город', FieldKind.text,
          required: true, minLength: 2, maxLength: 60),
      const FieldSpec('street', 'Улица', FieldKind.text,
          required: true, minLength: 2, maxLength: 100),
      const FieldSpec('house', 'Дом', FieldKind.text,
          required: true, minLength: 1, maxLength: 10),
      const FieldSpec('flat', 'Квартира', FieldKind.text, maxLength: 10),
      FieldSpec('postal_code', 'Индекс', FieldKind.text,
          required: true,
          pattern: RegExp(r'^\d{6}$'),
          patternMessage: 'Индекс — шесть цифр'),
      const FieldSpec('is_default', 'Основной адрес', FieldKind.boolean),
    ],
    initialValues: (a) => {
      'city': a.city,
      'street': a.street,
      'house': a.house,
      'flat': a.flat,
      'postal_code': a.postalCode,
      'is_default': a.isDefault,
    },
    createExtras: (c) => {'user': c.read<AuthNotifier>().user?.id ?? ''},
  );

  // ---- Категории ---------------------------------------------------------
  static final categories = EntityDef<Category>(
    path: '/categories',
    title: 'Категории',
    createTitle: 'Новая категория',
    editTitle: 'Изменение категории',
    icon: Icons.category,
    view: Permission.manageCatalog,
    manage: Permission.manageCatalog,
    repo: (c) => c.read<CategoryRepository>(),
    id: (x) => x.id,
    itemTitle: (x) => x.name,
    itemSubtitle: (x) => x.slug,
    isDeleted: (x) => x.deleted,
    softDelete: true,
    defaultSort: 'name',
    searchHint: 'Название',
    sorts: const [
      SortSpec('name', 'По названию'),
      SortSpec('-created', 'Сначала новые')
    ],
    columns: [
      TableColumnSpec<Category>(
        label: 'Название',
        sortField: 'name',
        build: (x) => _link('/categories/${x.id}', x.name, deleted: x.deleted),
      ),
      TableColumnSpec<Category>(label: 'Код', build: (x) => Text(x.slug)),
      TableColumnSpec<Category>(
        label: 'Описание',
        wideOnly: true,
        build: (x) => _text(x.description, maxWidth: 400),
      ),
    ],
    cardLines: (x) => [x.slug, if (x.description.isNotEmpty) x.description],
    details: (x) => [
      ('Название', x.name),
      ('Код', x.slug),
      ('Описание', x.description),
    ],
    fields: [
      const FieldSpec('name', 'Название', FieldKind.text,
          required: true, minLength: 2, maxLength: 50),
      FieldSpec('slug', 'Код для адреса', FieldKind.text,
          required: true,
          minLength: 2,
          maxLength: 50,
          pattern: RegExp(r'^[a-z0-9-]+$'),
          patternMessage: 'Только латинские буквы, цифры и дефис'),
      const FieldSpec('description', 'Описание', FieldKind.multiline,
          maxLength: 300),
    ],
    initialValues: (x) =>
        {'name': x.name, 'slug': x.slug, 'description': x.description},
  );

  // ---- Бренды ------------------------------------------------------------
  static final brands = EntityDef<Brand>(
    path: '/brands',
    title: 'Бренды',
    createTitle: 'Новый бренд',
    editTitle: 'Изменение бренда',
    icon: Icons.sell,
    view: Permission.manageCatalog,
    manage: Permission.manageCatalog,
    repo: (c) => c.read<BrandRepository>(),
    id: (x) => x.id,
    itemTitle: (x) => x.name,
    itemSubtitle: (x) => x.country,
    isDeleted: (x) => x.deleted,
    softDelete: true,
    defaultSort: 'name',
    searchHint: 'Название или страна',
    sorts: const [
      SortSpec('name', 'По названию'),
      SortSpec('country', 'По стране')
    ],
    filters: const [FilterSpec('country', 'Страна', FilterKind.text)],
    columns: [
      TableColumnSpec<Brand>(
        label: 'Название',
        sortField: 'name',
        build: (x) => _link('/brands/${x.id}', x.name, deleted: x.deleted),
      ),
      TableColumnSpec<Brand>(
        label: 'Страна',
        sortField: 'country',
        build: (x) => Text(x.country),
      ),
      TableColumnSpec<Brand>(
        label: 'Описание',
        wideOnly: true,
        build: (x) => _text(x.description, maxWidth: 400),
      ),
    ],
    cardLines: (x) => [x.country],
    details: (x) => [
      ('Название', x.name),
      ('Страна', x.country),
      ('Описание', x.description)
    ],
    fields: const [
      FieldSpec('name', 'Название', FieldKind.text,
          required: true, minLength: 2, maxLength: 50),
      FieldSpec('country', 'Страна', FieldKind.text,
          required: true, minLength: 2, maxLength: 50),
      FieldSpec('description', 'Описание', FieldKind.multiline, maxLength: 500),
    ],
    initialValues: (x) =>
        {'name': x.name, 'country': x.country, 'description': x.description},
  );

  // ---- Способы доставки --------------------------------------------------
  static final deliveryMethods = EntityDef<DeliveryMethod>(
    path: '/delivery-methods',
    title: 'Способы доставки',
    createTitle: 'Новый способ доставки',
    editTitle: 'Изменение способа доставки',
    icon: Icons.local_shipping,
    view: Permission.manageCatalog,
    manage: Permission.manageCatalog,
    repo: (c) => c.read<DeliveryMethodRepository>(),
    id: (x) => x.id,
    itemTitle: (x) => x.name,
    itemSubtitle: (x) => '${rub(x.price)}, ${x.days} дн.',
    isDeleted: (x) => x.deleted,
    softDelete: true,
    defaultSort: 'price',
    searchHint: 'Название',
    sorts: const [
      SortSpec('price', 'Дешевле'),
      SortSpec('-price', 'Дороже'),
      SortSpec('days', 'Быстрее'),
    ],
    columns: [
      TableColumnSpec<DeliveryMethod>(
        label: 'Название',
        sortField: 'name',
        build: (x) =>
            _link('/delivery-methods/${x.id}', x.name, deleted: x.deleted),
      ),
      TableColumnSpec<DeliveryMethod>(
        label: 'Цена',
        sortField: 'price',
        numeric: true,
        build: (x) => Text(rub(x.price)),
      ),
      TableColumnSpec<DeliveryMethod>(
        label: 'Срок, дней',
        sortField: 'days',
        numeric: true,
        build: (x) => Text('${x.days}'),
      ),
    ],
    cardLines: (x) => [rub(x.price), 'Срок: ${x.days} дн.'],
    details: (x) => [
      ('Название', x.name),
      ('Цена', rub(x.price)),
      ('Срок', '${x.days} дн.'),
      ('Описание', x.description),
    ],
    fields: const [
      FieldSpec('name', 'Название', FieldKind.text,
          required: true, minLength: 3, maxLength: 60),
      FieldSpec('price', 'Цена, ₽', FieldKind.integer,
          required: true, min: 0, max: 100000),
      FieldSpec('days', 'Срок, дней', FieldKind.integer,
          required: true, min: 1, max: 60),
      FieldSpec('description', 'Описание', FieldKind.multiline, maxLength: 300),
    ],
    initialValues: (x) => {
      'name': x.name,
      'price': '${x.price}',
      'days': '${x.days}',
      'description': x.description,
    },
  );

  // ---- Товары ------------------------------------------------------------
  static final products = EntityDef<Product>(
    path: '/products',
    title: 'Каталог',
    createTitle: 'Новый товар',
    editTitle: 'Изменение товара',
    icon: Icons.checkroom,
    view: Permission.viewCatalog,
    manage: Permission.manageCatalog,
    repo: (c) => c.read<ProductRepository>(),
    id: (x) => x.id,
    itemTitle: (x) => x.name,
    itemSubtitle: (x) => x.sku,
    isDeleted: (x) => x.deleted,
    softDelete: true,
    defaultSort: 'name',
    searchHint: 'Название, артикул или материал',
    sorts: const [
      SortSpec('name', 'По названию'),
      SortSpec('price', 'Сначала дешёвые'),
      SortSpec('-price', 'Сначала дорогие'),
      SortSpec('-created', 'Сначала новые'),
    ],
    filters: [
      const FilterSpec('category', 'Категория', FilterKind.lookup,
          lookup: 'categories'),
      const FilterSpec('brand', 'Бренд', FilterKind.lookup, lookup: 'brands'),
      const FilterSpec('gender', 'Для кого', FilterKind.select,
          options: genderLabels),
      const FilterSpec('collection', 'Коллекция', FilterKind.lookup,
          lookup: 'collections'),
      FilterSpec('size', 'Размер', FilterKind.select,
          options: {for (final s in sizeValues) s: s}),
      const FilterSpec('color', 'Цвет', FilterKind.text),
      const FilterSpec('priceFrom', 'Цена от', FilterKind.number),
      const FilterSpec('priceTo', 'Цена до', FilterKind.number),
      const FilterSpec('inStock', 'В наличии', FilterKind.toggle),
    ],
    gridCard: (c, p) => ProductCard(product: p),
    columns: [
      TableColumnSpec<Product>(
        label: 'Название',
        sortField: 'name',
        build: (x) => _link('/products/${x.id}', x.name, deleted: x.deleted),
      ),
      TableColumnSpec<Product>(
        label: 'Артикул',
        wideOnly: true,
        build: (x) => Text(x.sku),
      ),
      TableColumnSpec<Product>(
        label: 'Категория',
        build: (x) => Text(x.categoryName),
      ),
      TableColumnSpec<Product>(label: 'Бренд', build: (x) => Text(x.brandName)),
      TableColumnSpec<Product>(
        label: 'Для кого',
        wideOnly: true,
        build: (x) => Text(label(genderLabels, x.gender)),
      ),
      TableColumnSpec<Product>(
        label: 'Цена',
        sortField: 'price',
        numeric: true,
        build: (x) => Text(rub(x.price)),
      ),
      TableColumnSpec<Product>(
        label: 'Статус',
        build: (x) => Text(x.active ? 'В продаже' : 'Скрыт'),
      ),
    ],
    cardLines: (x) => [
      '${x.categoryName} · ${x.brandName}',
      rub(x.price),
      if (!x.active) 'Скрыт с витрины',
    ],
    details: (x) => [
      ('Название', x.name),
      ('Артикул', x.sku),
      ('Категория', x.categoryName),
      ('Бренд', x.brandName),
      ('Для кого', label(genderLabels, x.gender)),
      ('Материал', x.material),
      ('Цена', rub(x.price)),
      ('Описание', x.description),
      ('В продаже', x.active ? 'Да' : 'Нет'),
    ],
    fields: [
      const FieldSpec('name', 'Название', FieldKind.text,
          required: true, minLength: 3, maxLength: 120),
      FieldSpec('sku', 'Артикул', FieldKind.text,
          required: true,
          pattern: RegExp(r'^[A-Z]{2,4}-\d{3,6}$'),
          patternMessage: 'Формат: TS-1001',
          hint: '2–4 латинские буквы, дефис, 3–6 цифр'),
      const FieldSpec('category', 'Категория', FieldKind.relation,
          required: true, lookup: 'categories'),
      const FieldSpec('brand', 'Бренд', FieldKind.relation,
          required: true, lookup: 'brands'),
      const FieldSpec('gender', 'Для кого', FieldKind.select,
          required: true, options: genderLabels),
      const FieldSpec('price', 'Цена, ₽', FieldKind.integer,
          required: true, min: 1, max: 1000000),
      const FieldSpec('material', 'Материал', FieldKind.text, maxLength: 80),
      const FieldSpec('description', 'Описание', FieldKind.multiline,
          maxLength: 2000),
      const FieldSpec('active', 'Показывать на витрине', FieldKind.boolean,
          initial: true),
    ],
    initialValues: (x) => {
      'name': x.name,
      'sku': x.sku,
      'category': x.categoryId,
      'brand': x.brandId,
      'gender': x.gender,
      'price': '${x.price}',
      'material': x.material,
      'description': x.description,
      'active': x.active,
    },
    detailExtra: (c, p) => VariantsPanel(product: p),
  );

  // ---- Коллекции ---------------------------------------------------------
  static final collections = EntityDef<ProductCollection>(
    path: '/collections',
    title: 'Коллекции',
    createTitle: 'Новая коллекция',
    editTitle: 'Изменение коллекции',
    icon: Icons.collections_bookmark,
    view: Permission.manageCatalog,
    manage: Permission.manageCatalog,
    repo: (c) => c.read<CollectionRepository>(),
    id: (x) => x.id,
    itemTitle: (x) => x.title,
    itemSubtitle: (x) => '${label(seasonLabels, x.season)} ${x.year}',
    isDeleted: (x) => x.deleted,
    softDelete: true,
    defaultSort: '-year',
    searchHint: 'Название',
    sorts: const [
      SortSpec('-year', 'Сначала новые'),
      SortSpec('title', 'По названию'),
    ],
    filters: const [
      FilterSpec('season', 'Сезон', FilterKind.select, options: seasonLabels),
      FilterSpec('year', 'Год', FilterKind.number),
    ],
    columns: [
      TableColumnSpec<ProductCollection>(
        label: 'Название',
        sortField: 'title',
        build: (x) =>
            _link('/collections/${x.id}', x.title, deleted: x.deleted),
      ),
      TableColumnSpec<ProductCollection>(
        label: 'Сезон',
        build: (x) => Text(label(seasonLabels, x.season)),
      ),
      TableColumnSpec<ProductCollection>(
        label: 'Год',
        sortField: 'year',
        numeric: true,
        build: (x) => Text('${x.year}'),
      ),
      TableColumnSpec<ProductCollection>(
        label: 'Товаров',
        numeric: true,
        build: (x) => Text('${x.productIds.length}'),
      ),
    ],
    cardLines: (x) => ['Товаров: ${x.productIds.length}'],
    details: (x) => [
      ('Название', x.title),
      ('Сезон', label(seasonLabels, x.season)),
      ('Год', '${x.year}'),
      ('Товаров', '${x.productIds.length}'),
      ('Описание', x.description),
    ],
    fields: const [
      FieldSpec('title', 'Название', FieldKind.text,
          required: true, minLength: 3, maxLength: 80),
      FieldSpec('season', 'Сезон', FieldKind.select,
          required: true, options: seasonLabels),
      FieldSpec('year', 'Год', FieldKind.integer,
          required: true, min: 2000, max: 2100),
      FieldSpec('description', 'Описание', FieldKind.multiline, maxLength: 500),
      FieldSpec('products', 'Товары коллекции', FieldKind.multiRelation,
          lookup: 'products'),
    ],
    initialValues: (x) => {
      'title': x.title,
      'season': x.season,
      'year': '${x.year}',
      'description': x.description,
      'products': x.productIds,
    },
  );

  // ---- Варианты товаров --------------------------------------------------
  static final variants = EntityDef<ProductVariant>(
    path: '/variants',
    title: 'Варианты товаров',
    createTitle: 'Новый вариант',
    editTitle: 'Изменение варианта',
    icon: Icons.straighten,
    view: Permission.manageCatalog,
    manage: Permission.manageCatalog,
    repo: (c) => c.read<ProductVariantRepository>(),
    id: (x) => x.id,
    itemTitle: (x) => '${x.productName}: ${x.label}',
    itemSubtitle: (x) => 'Остаток: ${x.stock}',
    isDeleted: (x) => x.deleted,
    softDelete: true,
    defaultSort: '-created',
    searchHint: 'Товар или цвет',
    sorts: const [
      SortSpec('stock', 'Остаток: меньше'),
      SortSpec('-stock', 'Остаток: больше'),
      SortSpec('-created', 'Сначала новые'),
    ],
    filters: [
      const FilterSpec('product', 'Товар', FilterKind.lookup,
          lookup: 'products'),
      FilterSpec('size', 'Размер', FilterKind.select,
          options: {for (final s in sizeValues) s: s}),
      const FilterSpec('stock', 'Остаток', FilterKind.select,
          options: _stockOptions),
    ],
    columns: [
      TableColumnSpec<ProductVariant>(
        label: 'Товар',
        build: (x) =>
            _link('/variants/${x.id}', x.productName, deleted: x.deleted),
      ),
      TableColumnSpec<ProductVariant>(
          label: 'Размер', build: (x) => Text(x.size)),
      TableColumnSpec<ProductVariant>(
          label: 'Цвет', build: (x) => Text(x.color)),
      TableColumnSpec<ProductVariant>(
        label: 'Остаток',
        sortField: 'stock',
        numeric: true,
        build: (x) => Text('${x.stock}'),
      ),
    ],
    cardLines: (x) => [x.label, 'Остаток: ${x.stock}'],
    details: (x) => [
      ('Товар', x.productName),
      ('Размер', x.size),
      ('Цвет', x.color),
      ('Остаток', '${x.stock}'),
    ],
    fields: const [
      FieldSpec('product', 'Товар', FieldKind.relation,
          required: true, lookup: 'products'),
      FieldSpec('size', 'Размер', FieldKind.select, required: true, options: {
        'XS': 'XS',
        'S': 'S',
        'M': 'M',
        'L': 'L',
        'XL': 'XL',
        'XXL': 'XXL'
      }),
      FieldSpec('color', 'Цвет', FieldKind.text,
          required: true, minLength: 2, maxLength: 30),
      FieldSpec('stock', 'Остаток на складе', FieldKind.integer,
          required: true, min: 0, max: 10000),
    ],
    initialValues: (x) => {
      'product': x.productId,
      'size': x.size,
      'color': x.color,
      'stock': '${x.stock}',
    },
  );

  // ---- Заказы: список менеджера и список покупателя ---------------------
  static List<TableColumnSpec<Order>> _orderColumns(String base,
          {required bool withClient}) =>
      [
        TableColumnSpec<Order>(
          label: 'Заказ',
          build: (x) => _link('$base/${x.id}', x.number),
        ),
        if (withClient)
          TableColumnSpec<Order>(
              label: 'Клиент', build: (x) => _text(x.userName)),
        TableColumnSpec<Order>(
          label: 'Дата',
          sortField: 'ordered_at',
          build: (x) => Text(dateText(x.orderedAt)),
        ),
        TableColumnSpec<Order>(
          label: 'Статус',
          sortField: 'status',
          build: (x) =>
              statusChip(label(orderStatusLabels, x.status), x.status),
        ),
        TableColumnSpec<Order>(
          label: 'Доставка',
          wideOnly: true,
          build: (x) => Text(x.deliveryMethodName),
        ),
        TableColumnSpec<Order>(
          label: 'Сумма',
          sortField: 'total',
          numeric: true,
          build: (x) => Text(rub(x.total)),
        ),
      ];

  static const _orderSorts = [
    SortSpec('-ordered_at', 'Сначала новые'),
    SortSpec('ordered_at', 'Сначала старые'),
    SortSpec('-total', 'Сумма: больше'),
    SortSpec('total', 'Сумма: меньше'),
  ];

  static List<(String, String)> _orderDetails(Order x) => [
        ('Заказ', x.number),
        ('Клиент', x.userName),
        ('Дата', dateText(x.orderedAt)),
        ('Статус', label(orderStatusLabels, x.status)),
        ('Оплата', label(paymentLabels, x.payment)),
        ('Доставка', x.deliveryMethodName),
        ('Адрес', x.address?.full ?? ''),
        ('Сумма', rub(x.total)),
        ('Комментарий', x.comment),
      ];

  static final orders = EntityDef<Order>(
    path: '/orders',
    title: 'Заказы',
    createTitle: 'Новый заказ',
    editTitle: 'Изменение заказа',
    icon: Icons.receipt_long,
    view: Permission.manageOrders,
    manage: Permission.manageOrders,
    repo: (c) => c.read<OrderRepository>(),
    id: (x) => x.id,
    itemTitle: (x) => 'Заказ ${x.number}',
    itemSubtitle: (x) => x.userName,
    defaultSort: '-ordered_at',
    searchHint: 'Номер, клиент или комментарий',
    sorts: _orderSorts,
    filters: [
      const FilterSpec('status', 'Статус', FilterKind.select,
          options: orderStatusLabels),
      const FilterSpec('method', 'Доставка', FilterKind.lookup,
          lookup: 'deliveryMethods'),
      const FilterSpec('customer', 'Клиент', FilterKind.lookup,
          lookup: 'customers'),
      const FilterSpec('dateFrom', 'С даты', FilterKind.date),
      const FilterSpec('dateTo', 'По дату', FilterKind.date),
    ],
    columns: _orderColumns('/orders', withClient: true),
    cardLines: (x) => [
      x.userName,
      '${dateText(x.orderedAt)} · ${label(orderStatusLabels, x.status)}',
      rub(x.total),
    ],
    details: _orderDetails,
    fields: const [
      FieldSpec('user', 'Клиент', FieldKind.relation,
          required: true, lookup: 'customers'),
      FieldSpec('address', 'Адрес доставки', FieldKind.relation,
          required: true, lookup: 'addresses'),
      FieldSpec('delivery_method', 'Способ доставки', FieldKind.relation,
          required: true, lookup: 'deliveryMethods'),
      FieldSpec('status', 'Статус', FieldKind.select,
          required: true, options: orderStatusLabels, initial: 'new'),
      FieldSpec('payment', 'Оплата', FieldKind.select,
          required: true, options: paymentLabels, initial: 'card'),
      FieldSpec('total', 'Сумма, ₽', FieldKind.integer,
          required: true, min: 0, max: 10000000),
      FieldSpec('ordered_at', 'Дата заказа', FieldKind.date, required: true),
      FieldSpec('comment', 'Комментарий', FieldKind.multiline, maxLength: 300),
    ],
    initialValues: (x) => {
      'user': x.userId,
      'address': x.addressId,
      'delivery_method': x.deliveryMethodId,
      'status': x.status,
      'payment': x.payment,
      'total': '${x.total}',
      'ordered_at': x.orderedAt?.toUtc().toIso8601String() ?? '',
      'comment': x.comment,
    },
    detailExtra: (c, x) => OrderPanel(order: x, staff: true),
  );

  static final myOrders = EntityDef<Order>(
    path: '/my-orders',
    title: 'Мои заказы',
    createTitle: '',
    editTitle: '',
    icon: Icons.receipt_long,
    view: Permission.viewOwnOrders,
    manage: null,
    repo: (c) => c.read<OrderRepository>(),
    id: (x) => x.id,
    itemTitle: (x) => 'Заказ ${x.number}',
    itemSubtitle: (x) => dateText(x.orderedAt),
    defaultSort: '-ordered_at',
    searchHint: 'Номер заказа',
    sorts: _orderSorts,
    filters: [
      const FilterSpec('status', 'Статус', FilterKind.select,
          options: orderStatusLabels),
      const FilterSpec('method', 'Доставка', FilterKind.lookup,
          lookup: 'deliveryMethods'),
      const FilterSpec('dateFrom', 'С даты', FilterKind.date),
      const FilterSpec('dateTo', 'По дату', FilterKind.date),
    ],
    columns: _orderColumns('/my-orders', withClient: false),
    cardLines: (x) => [
      '${dateText(x.orderedAt)} · ${label(orderStatusLabels, x.status)}',
      rub(x.total),
    ],
    details: _orderDetails,
    initialValues: (x) => const {},
    detailExtra: (c, x) => OrderPanel(order: x, staff: false),
  );

  // ---- Позиции заказа ----------------------------------------------------
  static final orderItems = EntityDef<OrderItem>(
    path: '/order-items',
    title: 'Позиции заказов',
    createTitle: 'Новая позиция',
    editTitle: 'Изменение позиции',
    icon: Icons.list_alt,
    view: Permission.manageOrders,
    manage: Permission.manageOrders,
    repo: (c) => c.read<OrderItemRepository>(),
    id: (x) => x.id,
    itemTitle: (x) => '${x.productName} (${x.variantLabel})',
    itemSubtitle: (x) => 'Заказ №${x.orderId.substring(x.orderId.length - 6)}',
    defaultSort: '-created',
    searchHint: 'Название товара',
    sorts: const [
      SortSpec('-created', 'Сначала новые'),
      SortSpec('-quantity', 'Количество: больше'),
    ],
    filters: const [
      FilterSpec('order', 'Заказ', FilterKind.lookup, lookup: 'orders'),
    ],
    columns: [
      TableColumnSpec<OrderItem>(
        label: 'Заказ',
        build: (x) => _link('/orders/${x.orderId}',
            '№${x.orderId.substring(x.orderId.length - 6)}'),
      ),
      TableColumnSpec<OrderItem>(
          label: 'Товар', build: (x) => _text(x.productName)),
      TableColumnSpec<OrderItem>(
          label: 'Вариант', build: (x) => Text(x.variantLabel)),
      TableColumnSpec<OrderItem>(
        label: 'Кол-во',
        sortField: 'quantity',
        numeric: true,
        build: (x) => Text('${x.quantity}'),
      ),
      TableColumnSpec<OrderItem>(
        label: 'Цена',
        numeric: true,
        build: (x) => Text(rub(x.price)),
      ),
      TableColumnSpec<OrderItem>(
        label: 'Сумма',
        numeric: true,
        build: (x) => Text(rub(x.sum)),
      ),
    ],
    cardLines: (x) => ['${x.quantity} × ${rub(x.price)} = ${rub(x.sum)}'],
    details: (x) => [
      ('Заказ', '№${x.orderId.substring(x.orderId.length - 6)}'),
      ('Товар', x.productName),
      ('Вариант', x.variantLabel),
      ('Количество', '${x.quantity}'),
      ('Цена', rub(x.price)),
      ('Сумма', rub(x.sum)),
    ],
    fields: const [
      FieldSpec('order', 'Заказ', FieldKind.relation,
          required: true, lookup: 'orders', createOnly: true),
      FieldSpec('variant', 'Вариант товара', FieldKind.relation,
          required: true, lookup: 'variants'),
      FieldSpec('quantity', 'Количество', FieldKind.integer,
          required: true, min: 1, max: 20),
      FieldSpec('price', 'Цена, ₽', FieldKind.integer,
          required: true, min: 0, max: 1000000),
    ],
    initialValues: (x) => {
      'order': x.orderId,
      'variant': x.variantId,
      'quantity': '${x.quantity}',
      'price': '${x.price}',
    },
  );

  // ---- Доставки ----------------------------------------------------------
  static final deliveries = EntityDef<Delivery>(
    path: '/deliveries',
    title: 'Доставки',
    createTitle: 'Новая доставка',
    editTitle: 'Изменение доставки',
    icon: Icons.local_shipping,
    view: Permission.manageDeliveries,
    manage: Permission.manageDeliveries,
    repo: (c) => c.read<DeliveryRepository>(),
    id: (x) => x.id,
    itemTitle: (x) =>
        'Доставка заказа №${x.orderId.substring(x.orderId.length - 6)}',
    itemSubtitle: (x) => x.trackNumber,
    defaultSort: '-created',
    searchHint: 'Трек-номер или клиент',
    sorts: const [
      SortSpec('-created', 'Сначала новые'),
      SortSpec('eta', 'Срок: ближайшие'),
      SortSpec('-eta', 'Срок: дальние'),
    ],
    filters: [
      const FilterSpec('status', 'Статус', FilterKind.select,
          options: deliveryStatusLabels),
      const FilterSpec('carrier', 'Перевозчик', FilterKind.select,
          options: carrierLabels),
      const FilterSpec('etaTo', 'Срок до', FilterKind.date),
    ],
    columns: [
      TableColumnSpec<Delivery>(
        label: 'Заказ',
        build: (x) => _link('/deliveries/${x.id}',
            '№${x.orderId.substring(x.orderId.length - 6)}'),
      ),
      TableColumnSpec<Delivery>(
        label: 'Перевозчик',
        build: (x) => Text(label(carrierLabels, x.carrier)),
      ),
      TableColumnSpec<Delivery>(
          label: 'Трек', build: (x) => Text(x.trackNumber)),
      TableColumnSpec<Delivery>(
        label: 'Статус',
        build: (x) =>
            statusChip(label(deliveryStatusLabels, x.status), x.status),
      ),
      TableColumnSpec<Delivery>(
        label: 'Отправлен',
        wideOnly: true,
        build: (x) => Text(dateText(x.shippedAt)),
      ),
      TableColumnSpec<Delivery>(
        label: 'Срок',
        sortField: 'eta',
        build: (x) => Text(dateText(x.eta)),
      ),
    ],
    cardLines: (x) => [
      label(carrierLabels, x.carrier),
      label(deliveryStatusLabels, x.status),
      'Срок: ${dateText(x.eta)}',
    ],
    details: (x) => [
      ('Заказ', '№${x.orderId.substring(x.orderId.length - 6)}'),
      ('Перевозчик', label(carrierLabels, x.carrier)),
      ('Трек-номер', x.trackNumber),
      ('Статус', label(deliveryStatusLabels, x.status)),
      ('Отправлен', dateText(x.shippedAt)),
      ('Срок доставки', dateText(x.eta)),
    ],
    fields: [
      const FieldSpec('order', 'Заказ', FieldKind.relation,
          required: true, lookup: 'orders'),
      const FieldSpec('carrier', 'Перевозчик', FieldKind.select,
          required: true, options: carrierLabels),
      FieldSpec('track_number', 'Трек-номер', FieldKind.text,
          pattern: RegExp(r'^[A-Z0-9]{8,20}$'),
          patternMessage: 'От 8 до 20 заглавных латинских букв и цифр'),
      const FieldSpec('status', 'Статус', FieldKind.select,
          required: true, options: deliveryStatusLabels, initial: 'pending'),
      const FieldSpec('shipped_at', 'Дата отправки', FieldKind.date),
      const FieldSpec('eta', 'Ожидаемая дата доставки', FieldKind.date),
    ],
    initialValues: (x) => {
      'order': x.orderId,
      'carrier': x.carrier,
      'track_number': x.trackNumber,
      'status': x.status,
      'shipped_at': _ymd(x.shippedAt),
      'eta': _ymd(x.eta),
    },
  );
}
