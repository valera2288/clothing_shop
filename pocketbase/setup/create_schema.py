"""Создаёт коллекции магазина одежды в PocketBase и задаёт правила доступа.

Запуск (сервер должен работать на 127.0.0.1:8090):
    python pocketbase/setup/create_schema.py

Скрипт можно запускать повторно: прежние коллекции магазина удаляются
и создаются заново (вместе с данными).
"""
from pb import admin

AUTH = '@request.auth.id != ""'
ADMIN = '@request.auth.role = "admin"'
MANAGER = '@request.auth.role = "manager"'
CUSTOMER = '@request.auth.role = "customer"'
STAFF = f"({ADMIN} || {MANAGER})"
# Каталог: удалённые записи (deleted = true) видит только администратор
CATALOG_VISIBLE = f'{AUTH} && (deleted = false || {ADMIN})'
# Товары: покупатель не видит скрытые (active = false)
PRODUCT_VISIBLE = (f'{AUTH} && ((deleted = false && (active = true || '
                   f'@request.auth.role != "customer")) || {ADMIN})')

ORDER = [
    "order_items", "deliveries", "orders", "product_variants", "collections",
    "products", "delivery_methods", "brands", "categories", "addresses",
    "loyalty_cards",
]


def text(name, required=False, min=0, max=0, pattern=""):
    return {"name": name, "type": "text", "required": required,
            "min": min, "max": max, "pattern": pattern}


def number(name, required=False, min=None, max=None, only_int=True):
    return {"name": name, "type": "number", "required": required,
            "min": min, "max": max, "onlyInt": only_int}


def select(name, values, required=True):
    return {"name": name, "type": "select", "required": required,
            "values": values, "maxSelect": 1}


def boolean(name):
    return {"name": name, "type": "bool", "required": False}


def date(name, required=False):
    return {"name": name, "type": "date", "required": required}


def url(name):
    return {"name": name, "type": "url", "required": False}


def relation(name, collection_id, required=True, cascade=False, multiple=False):
    return {"name": name, "type": "relation", "required": required,
            "collectionId": collection_id, "cascadeDelete": cascade,
            "minSelect": 0, "maxSelect": 500 if multiple else 1}


def unique(table, *cols):
    name = "idx_" + table + "_" + "_".join(cols)
    return f"CREATE UNIQUE INDEX {name} ON {table} ({', '.join(cols)})"


def create(name, fields, indexes=(), **rules):
    # В PocketBase 0.23+ поля created/updated нужно объявлять явно
    fields = fields + [
        {"name": "created", "type": "autodate", "onCreate": True, "onUpdate": False},
        {"name": "updated", "type": "autodate", "onCreate": True, "onUpdate": True},
    ]
    body = {"name": name, "type": "base", "fields": fields,
            "indexes": list(indexes), **rules}
    return admin("POST", "/api/collections", body)["id"]


def main():
    existing = {c["name"]: c["id"] for c in
                admin("GET", "/api/collections?perPage=200")["items"]}
    for name in ORDER:
        if name in existing:
            admin("DELETE", f"/api/collections/{name}")
            print("удалена", name)

    # ---- users (встроенная auth-коллекция) --------------------------------
    users = admin("GET", "/api/collections/users")
    users_id = users["id"]
    fields = [f for f in users["fields"] if f["name"] not in ("role", "phone")]
    for f in fields:
        if f["name"] == "name":
            f.update(required=True, min=2, max=80)
    fields.append(select("role", ["customer", "manager", "admin"]))
    fields.append(text("phone", pattern=r"^\+?[0-9\s\-()]{7,20}$"))
    admin("PATCH", f"/api/collections/{users_id}", {
        "fields": fields,
        # Видят себя; сотрудники видят всех (нужно для имён в заказах)
        "listRule": f'{AUTH} && ({STAFF} || id = @request.auth.id)',
        "viewRule": f'{AUTH} && ({STAFF} || id = @request.auth.id)',
        # Самостоятельно регистрируются только покупатели; роль задаёт админ
        "createRule": f'@request.body.role = "customer" || {ADMIN}',
        # Сменить роль может только администратор
        "updateRule": (f'{ADMIN} || (id = @request.auth.id '
                       f'&& @request.body.role:isset = false)'),
        "deleteRule": f"{ADMIN} && id != @request.auth.id",
        "indexes": [
            "CREATE UNIQUE INDEX `idx_tokenKey_users` ON `users` (`tokenKey`)",
            "CREATE UNIQUE INDEX `idx_email_users` ON `users` (`email`) "
            "WHERE `email` != ''",
        ],
    })
    print("users обновлена")

    # ---- loyalty_cards (1:1 с users) --------------------------------------
    create("loyalty_cards", [
        relation("user", users_id, cascade=True),
        text("number", required=True, pattern=r"^LC-\d{6}$"),
        select("tier", ["bronze", "silver", "gold"]),
        number("points", min=0, max=1000000),
    ], [unique("loyalty_cards", "user"), unique("loyalty_cards", "number")],
        listRule=f"user = @request.auth.id || {STAFF}",
        viewRule=f"user = @request.auth.id || {STAFF}",
        createRule=STAFF, updateRule=STAFF, deleteRule=STAFF)

    # ---- addresses (N:1 users) --------------------------------------------
    addresses = create("addresses", [
        relation("user", users_id, cascade=True),
        text("city", required=True, min=2, max=60),
        text("street", required=True, min=2, max=100),
        text("house", required=True, min=1, max=10),
        text("flat", max=10),
        text("postal_code", required=True, pattern=r"^\d{6}$"),
        boolean("is_default"),
    ],
        listRule=f"user = @request.auth.id || {STAFF}",
        viewRule=f"user = @request.auth.id || {STAFF}",
        createRule=f"{CUSTOMER} && @request.body.user = @request.auth.id",
        updateRule="user = @request.auth.id",
        deleteRule=f"user = @request.auth.id || {ADMIN}")

    # ---- справочники каталога ---------------------------------------------
    catalog_rules = dict(listRule=CATALOG_VISIBLE, viewRule=CATALOG_VISIBLE,
                         createRule=ADMIN, updateRule=ADMIN, deleteRule=ADMIN)
    categories = create("categories", [
        text("name", required=True, min=2, max=50),
        text("slug", required=True, min=2, max=50, pattern=r"^[a-z0-9-]+$"),
        text("description", max=300),
        boolean("deleted"),
    ], [unique("categories", "name"), unique("categories", "slug")],
        **catalog_rules)

    brands = create("brands", [
        text("name", required=True, min=2, max=50),
        text("country", required=True, min=2, max=50),
        text("description", max=500),
        boolean("deleted"),
    ], [unique("brands", "name")], **catalog_rules)

    delivery_methods = create("delivery_methods", [
        text("name", required=True, min=3, max=60),
        number("price", min=0, max=100000),
        number("days", required=True, min=1, max=60),
        text("description", max=300),
        boolean("deleted"),
    ], [unique("delivery_methods", "name")], **catalog_rules)

    # ---- products (N:1 categories, N:1 brands) ----------------------------
    products = create("products", [
        text("name", required=True, min=3, max=120),
        text("sku", required=True, pattern=r"^[A-Z]{2,4}-\d{3,6}$"),
        text("description", max=2000),
        number("price", required=True, min=1, max=1000000),
        relation("category", categories),
        relation("brand", brands),
        select("gender", ["men", "women", "unisex", "kids"]),
        text("material", max=80),
        url("image_url"),
        boolean("active"),
        boolean("deleted"),
    ], [unique("products", "sku")],
        **{**catalog_rules, "listRule": PRODUCT_VISIBLE,
           "viewRule": PRODUCT_VISIBLE})

    # ---- collections (M:N с products) -------------------------------------
    create("collections", [
        text("title", required=True, min=3, max=80),
        select("season", ["spring", "summer", "autumn", "winter"]),
        number("year", required=True, min=2000, max=2100),
        text("description", max=500),
        relation("products", products, required=False, multiple=True),
        boolean("deleted"),
    ], [unique("collections", "title")], **catalog_rules)

    # ---- product_variants (N:1 products) ----------------------------------
    create("product_variants", [
        relation("product", products, cascade=True),
        select("size", ["XS", "S", "M", "L", "XL", "XXL"]),
        text("color", required=True, min=2, max=30),
        number("stock", min=0, max=10000),
        boolean("deleted"),
    ], [unique("product_variants", "product", "size", "color")],
        listRule=CATALOG_VISIBLE, viewRule=CATALOG_VISIBLE,
        createRule=ADMIN, updateRule=ADMIN, deleteRule=ADMIN)
    variants_id = admin("GET", "/api/collections/product_variants")["id"]

    # ---- orders (N:1 users, addresses, delivery_methods) ------------------
    orders = create("orders", [
        relation("user", users_id),
        relation("address", addresses),
        relation("delivery_method", delivery_methods),
        select("status", ["new", "paid", "packed", "shipped", "delivered",
                          "cancelled"]),
        select("payment", ["card", "cash"]),
        date("ordered_at", required=True),
        number("total", min=0, max=10000000),
        text("comment", max=300),
    ],
        listRule=f"user = @request.auth.id || {STAFF}",
        viewRule=f"user = @request.auth.id || {STAFF}",
        createRule=(f'{CUSTOMER} && @request.body.user = @request.auth.id '
                    '&& @request.body.address.user = @request.auth.id '
                    '&& @request.body.status = "new"'),
        # отменённый заказ менеджер не оживляет: остаток уже возвращён на склад
        updateRule=(f'({MANAGER} && status != "cancelled") || (user = @request.auth.id '
                    '&& status = "new" '
                    '&& @request.body.status = "cancelled")'),
        deleteRule=STAFF)

    # ---- order_items (связь заказ <-> вариант: M:N с атрибутами) ----------
    create("order_items", [
        relation("order", orders, cascade=True),
        relation("variant", variants_id),
        number("quantity", required=True, min=1, max=20),
        number("price", min=0, max=1000000),
    ], [unique("order_items", "order", "variant")],
        listRule=f"order.user = @request.auth.id || {STAFF}",
        viewRule=f"order.user = @request.auth.id || {STAFF}",
        # позиции добавляются только в свой новый заказ
        createRule=(f'{CUSTOMER} && @request.body.order.user = '
                    '@request.auth.id && @request.body.order.status = "new"'),
        updateRule=STAFF, deleteRule=STAFF)

    # ---- deliveries (1:1 с orders) ----------------------------------------
    create("deliveries", [
        relation("order", orders, cascade=True),
        select("carrier", ["cdek", "boxberry", "post", "courier"]),
        text("track_number", pattern=r"^[A-Z0-9]{8,20}$"),
        select("status", ["pending", "in_transit", "out_for_delivery",
                          "delivered", "returned"]),
        date("shipped_at"),
        date("eta"),
    ], [unique("deliveries", "order")],
        listRule=f"order.user = @request.auth.id || {STAFF}",
        viewRule=f"order.user = @request.auth.id || {STAFF}",
        createRule=MANAGER, updateRule=MANAGER, deleteRule=MANAGER)

    # Пакетный запрос (/api/batch) выполняется в одной транзакции: заказ с позициями
    admin("PATCH", "/api/settings", {"batch": {"enabled": True, "maxRequests": 50,
                                                "timeout": 3, "maxBodySize": 0}})
    print("схема создана")


if __name__ == "__main__":
    main()
