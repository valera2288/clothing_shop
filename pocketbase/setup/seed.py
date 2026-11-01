"""Наполняет базу тестовыми данными: три роли, каталог, заказы, доставки.

Запуск после create_schema.py:
    python pocketbase/setup/seed.py
"""
import random
from datetime import datetime, timedelta, timezone

from pb import admin

random.seed(42)

USERS = [
    ("admin@shop.test", "Admin#2026", "Администратор Магазина", "admin", "+7 900 100-00-01"),
    ("manager@shop.test", "Manager#2026", "Мария Соколова", "manager", "+7 900 100-00-02"),
    ("customer@shop.test", "Customer#2026", "Иван Петров", "customer", "+7 900 200-00-01"),
    ("anna@shop.test", "Customer#2026", "Анна Кузнецова", "customer", "+7 900 200-00-02"),
    ("dmitry@shop.test", "Customer#2026", "Дмитрий Орлов", "customer", "+7 900 200-00-03"),
    ("elena@shop.test", "Customer#2026", "Елена Волкова", "customer", "+7 900 200-00-04"),
    ("sergey@shop.test", "Customer#2026", "Сергей Морозов", "customer", "+7 900 200-00-05"),
    ("olga@shop.test", "Customer#2026", "Ольга Белова", "customer", "+7 900 200-00-06"),
]

CATEGORIES = [
    ("Футболки", "t-shirts", "Базовые и принтованные футболки"),
    ("Джинсы", "jeans", "Джинсы и джинсовые брюки"),
    ("Куртки", "jackets", "Демисезонные и зимние куртки"),
    ("Платья", "dresses", "Платья на каждый день и на выход"),
    ("Худи и свитшоты", "hoodies", "Тёплый трикотаж"),
    ("Аксессуары", "accessories", "Шарфы, кепки, ремни"),
]

BRANDS = [
    ("Nordic Wear", "Швеция", "Скандинавская одежда для холодной погоды"),
    ("Urban Line", "Россия", "Городская повседневная одежда"),
    ("Denim Co", "США", "Классический деним"),
    ("Alpine", "Италия", "Верхняя одежда и трикотаж"),
    ("Sakura", "Япония", "Минималистичный крой"),
    ("Moscow Style", "Россия", "Коллекции от российских дизайнеров"),
]

# название, артикул, категория(idx), бренд(idx), пол, цена, материал
PRODUCTS = [
    ("Футболка базовая белая", "TS-1001", 0, 1, "unisex", 990, "Хлопок 100%"),
    ("Футболка оверсайз чёрная", "TS-1002", 0, 4, "unisex", 1490, "Хлопок 100%"),
    ("Футболка с принтом «Город»", "TS-1003", 0, 5, "men", 1290, "Хлопок 95%, эластан 5%"),
    ("Футболка поло классическая", "TS-1004", 0, 3, "men", 2190, "Пике"),
    ("Футболка женская приталенная", "TS-1005", 0, 1, "women", 1090, "Хлопок 100%"),
    ("Футболка детская «Динозавр»", "TS-1006", 0, 5, "kids", 790, "Хлопок 100%"),
    ("Джинсы прямые синие", "JN-2001", 1, 2, "men", 4290, "Деним 100%"),
    ("Джинсы скинни женские", "JN-2002", 1, 2, "women", 3990, "Деним, эластан"),
    ("Джинсы мом светлые", "JN-2003", 1, 2, "women", 4590, "Деним 100%"),
    ("Джинсы широкие чёрные", "JN-2004", 1, 4, "unisex", 4990, "Деним 100%"),
    ("Джинсы зауженные тёмные", "JN-2005", 1, 5, "men", 3790, "Деним, эластан"),
    ("Куртка пуховая зимняя", "JK-3001", 2, 0, "unisex", 12990, "Пух, полиэстер"),
    ("Куртка-бомбер", "JK-3002", 2, 1, "men", 6490, "Нейлон"),
    ("Ветровка лёгкая", "JK-3003", 2, 3, "women", 5290, "Полиэстер"),
    ("Парка с капюшоном", "JK-3004", 2, 0, "men", 9990, "Хлопок, мех"),
    ("Пальто шерстяное", "JK-3005", 2, 3, "women", 15990, "Шерсть 70%"),
    ("Куртка джинсовая", "JK-3006", 2, 2, "unisex", 5490, "Деним 100%"),
    ("Платье миди чёрное", "DR-4001", 3, 5, "women", 5990, "Вискоза"),
    ("Платье летнее в цветок", "DR-4002", 3, 4, "women", 3490, "Хлопок"),
    ("Платье-рубашка", "DR-4003", 3, 1, "women", 4290, "Лён"),
    ("Платье вечернее", "DR-4004", 3, 3, "women", 8990, "Атлас"),
    ("Худи на молнии серое", "HD-5001", 4, 1, "unisex", 3990, "Футер, хлопок"),
    ("Худи оверсайз бежевое", "HD-5002", 4, 4, "unisex", 4290, "Футер 3-нитка"),
    ("Свитшот базовый", "HD-5003", 4, 5, "men", 2990, "Хлопок 100%"),
    ("Свитшот с вышивкой", "HD-5004", 4, 5, "women", 3490, "Хлопок 100%"),
    ("Худи детское", "HD-5005", 4, 1, "kids", 2490, "Хлопок 100%"),
    ("Шарф шерстяной", "AC-6001", 5, 0, "unisex", 1990, "Шерсть"),
    ("Кепка с логотипом", "AC-6002", 5, 1, "unisex", 1190, "Хлопок"),
    ("Ремень кожаный", "AC-6003", 5, 3, "men", 2290, "Кожа"),
    ("Шапка вязаная", "AC-6004", 5, 0, "unisex", 1490, "Акрил, шерсть"),
    ("Перчатки кожаные", "AC-6005", 5, 3, "women", 2790, "Кожа"),
    ("Рубашка льняная", "TS-1007", 0, 4, "men", 3290, "Лён 100%"),
    ("Свитер вязаный", "HD-5006", 4, 0, "unisex", 5490, "Шерсть 50%"),
]

COLORS = ["Чёрный", "Белый", "Синий", "Серый", "Бежевый", "Зелёный", "Красный"]
SIZES = ["XS", "S", "M", "L", "XL", "XXL"]

COLLECTIONS = [
    ("Весна 2026", "spring", 2026, "Лёгкие слои и светлые тона"),
    ("Лето 2026", "summer", 2026, "Дышащие ткани и яркие принты"),
    ("Осень 2026", "autumn", 2026, "Тёплые оттенки и плотный трикотаж"),
    ("Зима 2026", "winter", 2026, "Пуховики, шерсть и аксессуары"),
]

DELIVERY = [
    ("Самовывоз из магазина", 0, 1, "Бесплатно, готовность в день заказа"),
    ("Курьер по городу", 350, 2, "Доставка до двери"),
    ("СДЭК — пункт выдачи", 250, 4, "Доставка в пункт выдачи"),
    ("Почта России", 200, 9, "Доставка в почтовое отделение"),
]

CITIES = [("Москва", "ул. Тверская", "101000"), ("Санкт-Петербург", "Невский пр.", "190000"),
          ("Казань", "ул. Баумана", "420000"), ("Екатеринбург", "ул. Ленина", "620000")]

STATUS_FLOW = ["new", "paid", "packed", "shipped", "delivered", "cancelled"]


def rec(collection, body):
    return admin("POST", f"/api/collections/{collection}/records", body)


def main():
    # очистка: пользователи тестовых доменов и все данные магазина
    for coll in ["deliveries", "order_items", "orders", "product_variants",
                 "collections", "products", "delivery_methods", "brands",
                 "categories", "addresses", "loyalty_cards"]:
        for r in admin("GET", f"/api/collections/{coll}/records?perPage=500&fields=id")["items"]:
            admin("DELETE", f"/api/collections/{coll}/records/{r['id']}")
    for r in admin("GET", "/api/collections/users/records?perPage=500&fields=id")["items"]:
        admin("DELETE", f"/api/collections/users/records/{r['id']}")

    users = []
    for email, password, name, role, phone in USERS:
        u = rec("users", {"email": email, "password": password, "passwordConfirm": password,
                          "name": name, "role": role, "phone": phone, "verified": True,
                          "emailVisibility": True})
        users.append(u)
    customers = [u for u in users if u["role"] == "customer"]

    for i, c in enumerate(customers):
        rec("loyalty_cards", {"user": c["id"], "number": f"LC-{100001 + i}",
                              "tier": ["bronze", "silver", "gold"][i % 3],
                              "points": random.randint(0, 5000)})

    addresses = {}
    for i, c in enumerate(customers):
        addresses[c["id"]] = []
        for k in range(1 + (i % 2)):
            city, street, postal = CITIES[(i + k) % len(CITIES)]
            a = rec("addresses", {"user": c["id"], "city": city, "street": street,
                                  "house": str(5 + i * 3 + k), "flat": str(10 + i + k * 7),
                                  "postal_code": postal, "is_default": k == 0})
            addresses[c["id"]].append(a)

    cats = [rec("categories", {"name": n, "slug": s, "description": d}) for n, s, d in CATEGORIES]
    brands = [rec("brands", {"name": n, "country": c, "description": d}) for n, c, d in BRANDS]
    methods = [rec("delivery_methods", {"name": n, "price": p, "days": d, "description": ds})
               for n, p, d, ds in DELIVERY]

    products, variants = [], []
    for name, sku, ci, bi, gender, price, material in PRODUCTS:
        p = rec("products", {"name": name, "sku": sku, "price": price,
                             "description": f"{name}. Материал: {material}.",
                             "category": cats[ci]["id"], "brand": brands[bi]["id"],
                             "gender": gender, "material": material, "active": True})
        products.append(p)
        for color in random.sample(COLORS, 2):
            for size in random.sample(SIZES, 4):
                variants.append(rec("product_variants", {
                    "product": p["id"], "size": size, "color": color,
                    "stock": random.choice([0, 2, 5, 8, 15, 30])}))
    # один товар снят с витрины (мягкое удаление) и один «неактивный»
    admin("PATCH", f"/api/collections/products/records/{products[-1]['id']}", {"deleted": True})
    admin("PATCH", f"/api/collections/products/records/{products[-2]['id']}", {"active": False})

    for i, (title, season, year, desc) in enumerate(COLLECTIONS):
        pool = [p["id"] for j, p in enumerate(products) if j % 4 == i or j % 7 == i]
        rec("collections", {"title": title, "season": season, "year": year,
                            "description": desc, "products": pool})

    now = datetime.now(timezone.utc)
    prod_price = {p["id"]: p["price"] for p in products}
    track_n = 1
    for n in range(36):
        c = customers[n % len(customers)] if n >= 6 else customers[0]
        addr = random.choice(addresses[c["id"]])
        method = random.choice(methods)
        status = random.choices(STATUS_FLOW, weights=[3, 3, 3, 4, 8, 2])[0]
        created = now - timedelta(days=random.randint(1, 120), hours=random.randint(0, 20))
        picked = random.sample(variants, random.randint(1, 3))
        items = [(v, random.randint(1, 3)) for v in picked]
        total = sum(prod_price[v["product"]] * q for v, q in items) + method["price"]
        order = rec("orders", {"user": c["id"], "address": addr["id"],
                               "delivery_method": method["id"], "status": status,
                               "payment": random.choice(["card", "cash"]), "total": total,
                               "comment": random.choice(["", "", "Позвонить за час", "Оставить у двери"]),
                               "ordered_at": created.strftime("%Y-%m-%d %H:%M:%S.000Z")})
        for v, q in items:
            rec("order_items", {"order": order["id"], "variant": v["id"], "quantity": q,
                                "price": prod_price[v["product"]]})
        if status in ("packed", "shipped", "delivered"):
            dstatus = {"packed": "pending", "shipped": "in_transit", "delivered": "delivered"}[status]
            shipped = created + timedelta(days=1)
            rec("deliveries", {
                "order": order["id"],
                "carrier": random.choice(["cdek", "boxberry", "post", "courier"]),
                "track_number": f"TRK{track_n:08d}" if status != "packed" else "",
                "status": dstatus,
                "shipped_at": shipped.strftime("%Y-%m-%d 00:00:00.000Z") if status != "packed" else "",
                "eta": (shipped + timedelta(days=method["days"])).strftime("%Y-%m-%d 00:00:00.000Z"),
            })
            track_n += 1
    print("данные загружены")


if __name__ == "__main__":
    main()
