# Исходные данные для ER-диаграмм (draw.io)

Диаграммы строятся вручную в draw.io по этим таблицам. Файл создан скриптом `docs/tools/make_er_spec.py` из `pocketbase/pb_schema.json`.

## Связи

| Сущность A | Сущность B | Вид | Реализация | Смысл |
|---|---|---|---|---|
| users | loyalty_cards | 1:1 | loyalty_cards.user (уникальный индекс) | У пользователя одна карта лояльности |
| orders | deliveries | 1:1 | deliveries.order (уникальный индекс) | У заказа одна доставка |
| users | addresses | 1:N | addresses.user | У покупателя несколько адресов |
| users | orders | 1:N | orders.user | Покупатель делает много заказов |
| addresses | orders | 1:N | orders.address | На один адрес доставляют много заказов |
| delivery_methods | orders | 1:N | orders.delivery_method | Способ доставки выбирают во многих заказах |
| categories | products | 1:N | products.category | В категории много товаров |
| brands | products | 1:N | products.brand | У бренда много товаров |
| products | product_variants | 1:N | product_variants.product | У товара несколько размеров и цветов |
| collections | products | M:N | collections.products (список идентификаторов) | Товар входит в несколько коллекций |
| orders | product_variants | M:N | order_items (order, variant) с полями quantity и price | Заказ состоит из многих вариантов, вариант встречается во многих заказах |

## Логическая модель: сущности и атрибуты

### Пользователь (`users`)

Учётная запись покупателя, менеджера или администратора; роль хранится в поле role.

| Атрибут | Тип | Ключ | Назначение |
|---|---|---|---|
| id | Текст | PK | Идентификатор записи |
| password | Пароль |  | Хеш пароля (хранит PocketBase) |
| tokenKey | Текст |  | Служебный ключ токенов PocketBase |
| email | Почта |  | Почта, она же логин |
| emailVisibility | Логический |  | Служебный признак PocketBase |
| verified | Логический |  | Служебный признак PocketBase |
| name | Текст |  | Имя пользователя |
| avatar | Файл |  | Служебное поле PocketBase, не используется |
| role | Список значений |  | Роль: customer, manager, admin |
| phone | Текст |  | Телефон |

### Карта лояльности (`loyalty_cards`)

Карта покупателя с уровнем и баллами; у пользователя не больше одной (связь 1:1).

| Атрибут | Тип | Ключ | Назначение |
|---|---|---|---|
| id | Текст | PK | Идентификатор записи |
| user | Связь | FK | Владелец карты (связь 1:1 с users) |
| number | Текст |  | Номер карты в формате LC-123456 |
| tier | Список значений |  | Уровень: bronze, silver, gold; определяет скидку |
| points | Число |  | Накопленные баллы |

### Адрес (`addresses`)

Адрес доставки покупателя; у пользователя их несколько (1:N).

| Атрибут | Тип | Ключ | Назначение |
|---|---|---|---|
| id | Текст | PK | Идентификатор записи |
| user | Связь | FK | Владелец адреса (N:1 к users) |
| city | Текст |  | Город |
| street | Текст |  | Улица |
| house | Текст |  | Номер дома |
| flat | Текст |  | Квартира |
| postal_code | Текст |  | Почтовый индекс из шести цифр |
| is_default | Логический |  | Основной адрес покупателя |

### Категория (`categories`)

Раздел каталога: футболки, джинсы, куртки и т. д.

| Атрибут | Тип | Ключ | Назначение |
|---|---|---|---|
| id | Текст | PK | Идентификатор записи |
| name | Текст |  | Название категории |
| slug | Текст |  | Код латиницей |
| description | Текст |  | Описание |
| deleted | Логический |  | Признак мягкого удаления |

### Бренд (`brands`)

Производитель одежды.

| Атрибут | Тип | Ключ | Назначение |
|---|---|---|---|
| id | Текст | PK | Идентификатор записи |
| name | Текст |  | Название бренда |
| country | Текст |  | Страна бренда |
| description | Текст |  | Описание |
| deleted | Логический |  | Признак мягкого удаления |

### Товар (`products`)

Модель одежды с ценой; принадлежит категории и бренду (N:1).

| Атрибут | Тип | Ключ | Назначение |
|---|---|---|---|
| id | Текст | PK | Идентификатор записи |
| name | Текст |  | Название товара |
| sku | Текст |  | Артикул в формате TS-1001 |
| description | Текст |  | Описание |
| price | Число |  | Цена в рублях |
| category | Связь | FK | Категория (N:1 к categories) |
| brand | Связь | FK | Бренд (N:1 к brands) |
| gender | Список значений |  | Для кого: men, women, unisex, kids |
| material | Текст |  | Материал |
| image_url | Ссылка |  | Ссылка на изображение |
| active | Логический |  | Показывать на витрине покупателям |
| deleted | Логический |  | Признак мягкого удаления |

### Коллекция (`collections`)

Сезонная подборка; один товар может входить в несколько коллекций и наоборот (M:N).

| Атрибут | Тип | Ключ | Назначение |
|---|---|---|---|
| id | Текст | PK | Идентификатор записи |
| title | Текст |  | Название коллекции |
| season | Список значений |  | Сезон: spring, summer, autumn, winter |
| year | Число |  | Год коллекции |
| description | Текст |  | Описание |
| products | Связь |  | Товары коллекции (M:N с products) |
| deleted | Логический |  | Признак мягкого удаления |

### Вариант товара (`product_variants`)

Размер и цвет товара с остатком на складе.

| Атрибут | Тип | Ключ | Назначение |
|---|---|---|---|
| id | Текст | PK | Идентификатор записи |
| product | Связь | FK | Товар (N:1 к products) |
| size | Список значений |  | Размер: XS, S, M, L, XL, XXL |
| color | Текст |  | Цвет |
| stock | Число |  | Остаток на складе, шт. |
| deleted | Логический |  | Признак мягкого удаления |

### Способ доставки (`delivery_methods`)

Вариант доставки со стоимостью и сроком.

| Атрибут | Тип | Ключ | Назначение |
|---|---|---|---|
| id | Текст | PK | Идентификатор записи |
| name | Текст |  | Название способа доставки |
| price | Число |  | Стоимость доставки, ₽ |
| days | Число |  | Срок доставки, дней |
| description | Текст |  | Описание |
| deleted | Логический |  | Признак мягкого удаления |

### Заказ (`orders`)

Заказ покупателя: адрес, способ доставки, оплата, статус, сумма.

| Атрибут | Тип | Ключ | Назначение |
|---|---|---|---|
| id | Текст | PK | Идентификатор записи |
| user | Связь | FK | Покупатель (N:1 к users) |
| address | Связь | FK | Адрес доставки (N:1 к addresses) |
| delivery_method | Связь | FK | Способ доставки (N:1 к delivery_methods) |
| status | Список значений |  | Статус: new, paid, packed, shipped, delivered, cancelled |
| payment | Список значений |  | Оплата: card, cash |
| ordered_at | Дата и время |  | Дата и время оформления |
| total | Число |  | Итоговая сумма заказа, ₽ |
| comment | Текст |  | Комментарий покупателя |

### Позиция заказа (`order_items`)

Связь заказа с вариантом товара (M:N) с количеством и ценой на момент покупки.

| Атрибут | Тип | Ключ | Назначение |
|---|---|---|---|
| id | Текст | PK | Идентификатор записи |
| order | Связь | FK | Заказ (N:1 к orders) |
| variant | Связь | FK | Вариант товара (N:1 к product_variants) |
| quantity | Число |  | Количество, шт. |
| price | Число |  | Цена за штуку на момент покупки, ₽ |

### Доставка (`deliveries`)

Отправление по заказу: перевозчик, трек-номер, статус, срок; у заказа одна (1:1).

| Атрибут | Тип | Ключ | Назначение |
|---|---|---|---|
| id | Текст | PK | Идентификатор записи |
| order | Связь | FK | Заказ (связь 1:1 с orders) |
| carrier | Список значений |  | Перевозчик: cdek, boxberry, post, courier |
| track_number | Текст |  | Трек-номер: 8–20 заглавных латинских букв и цифр |
| status | Список значений |  | Статус: pending, in_transit, out_for_delivery, delivered, returned |
| shipped_at | Дата и время |  | Дата отправки |
| eta | Дата и время |  | Ожидаемая дата доставки |

## Физическая модель: таблицы SQLite

### `users`

| Столбец | Тип SQLite | Ограничения |
|---|---|---|
| id | TEXT | PRIMARY KEY, NOT NULL |
| password | TEXT | NOT NULL;  |
| tokenKey | TEXT | NOT NULL; обязательное; от 30 символов; до 60 символов; уникальное |
| email | TEXT | NOT NULL; обязательное; уникальное |
| emailVisibility | BOOLEAN | NOT NULL; по умолчанию false |
| verified | BOOLEAN | NOT NULL; по умолчанию false |
| name | TEXT | NOT NULL; обязательное; от 2 символов; до 80 символов |
| avatar | TEXT | NOT NULL;  |
| role | TEXT | NOT NULL; обязательное; значения: customer, manager, admin |
| phone | TEXT | NOT NULL; шаблон ^\+?[0-9\s\-()]{7,20}$ |
| created | TEXT | NOT NULL, автодата |
| updated | TEXT | NOT NULL, автодата |

### `loyalty_cards`

| Столбец | Тип SQLite | Ограничения |
|---|---|---|
| id | TEXT | PRIMARY KEY, NOT NULL |
| user | TEXT | NOT NULL; обязательное; внешний ключ → users; каскадное удаление; уникальное |
| number | TEXT | NOT NULL; обязательное; шаблон ^LC-\d{6}$; уникальное |
| tier | TEXT | NOT NULL; обязательное; значения: bronze, silver, gold |
| points | NUMERIC | NOT NULL; от 0; до 1000000; целое |
| created | TEXT | NOT NULL, автодата |
| updated | TEXT | NOT NULL, автодата |

### `addresses`

| Столбец | Тип SQLite | Ограничения |
|---|---|---|
| id | TEXT | PRIMARY KEY, NOT NULL |
| user | TEXT | NOT NULL; обязательное; внешний ключ → users; каскадное удаление |
| city | TEXT | NOT NULL; обязательное; от 2 символов; до 60 символов |
| street | TEXT | NOT NULL; обязательное; от 2 символов; до 100 символов |
| house | TEXT | NOT NULL; обязательное; от 1 символов; до 10 символов |
| flat | TEXT | NOT NULL; до 10 символов |
| postal_code | TEXT | NOT NULL; обязательное; шаблон ^\d{6}$ |
| is_default | BOOLEAN | NOT NULL; по умолчанию false |
| created | TEXT | NOT NULL, автодата |
| updated | TEXT | NOT NULL, автодата |

### `categories`

| Столбец | Тип SQLite | Ограничения |
|---|---|---|
| id | TEXT | PRIMARY KEY, NOT NULL |
| name | TEXT | NOT NULL; обязательное; от 2 символов; до 50 символов; уникальное |
| slug | TEXT | NOT NULL; обязательное; от 2 символов; до 50 символов; шаблон ^[a-z0-9-]+$; уникальное |
| description | TEXT | NOT NULL; до 300 символов |
| deleted | BOOLEAN | NOT NULL; по умолчанию false |
| created | TEXT | NOT NULL, автодата |
| updated | TEXT | NOT NULL, автодата |

### `brands`

| Столбец | Тип SQLite | Ограничения |
|---|---|---|
| id | TEXT | PRIMARY KEY, NOT NULL |
| name | TEXT | NOT NULL; обязательное; от 2 символов; до 50 символов; уникальное |
| country | TEXT | NOT NULL; обязательное; от 2 символов; до 50 символов |
| description | TEXT | NOT NULL; до 500 символов |
| deleted | BOOLEAN | NOT NULL; по умолчанию false |
| created | TEXT | NOT NULL, автодата |
| updated | TEXT | NOT NULL, автодата |

### `products`

| Столбец | Тип SQLite | Ограничения |
|---|---|---|
| id | TEXT | PRIMARY KEY, NOT NULL |
| name | TEXT | NOT NULL; обязательное; от 3 символов; до 120 символов |
| sku | TEXT | NOT NULL; обязательное; шаблон ^[A-Z]{2,4}-\d{3,6}$; уникальное |
| description | TEXT | NOT NULL; до 2000 символов |
| price | NUMERIC | NOT NULL; обязательное, ≠ 0; от 1; до 1000000; целое |
| category | TEXT | NOT NULL; обязательное; внешний ключ → categories |
| brand | TEXT | NOT NULL; обязательное; внешний ключ → brands |
| gender | TEXT | NOT NULL; обязательное; значения: men, women, unisex, kids |
| material | TEXT | NOT NULL; до 80 символов |
| image_url | TEXT | NOT NULL; необязательное |
| active | BOOLEAN | NOT NULL; по умолчанию false |
| deleted | BOOLEAN | NOT NULL; по умолчанию false |
| created | TEXT | NOT NULL, автодата |
| updated | TEXT | NOT NULL, автодата |

### `collections`

| Столбец | Тип SQLite | Ограничения |
|---|---|---|
| id | TEXT | PRIMARY KEY, NOT NULL |
| title | TEXT | NOT NULL; обязательное; от 3 символов; до 80 символов; уникальное |
| season | TEXT | NOT NULL; обязательное; значения: spring, summer, autumn, winter |
| year | NUMERIC | NOT NULL; обязательное, ≠ 0; от 2000; до 2100; целое |
| description | TEXT | NOT NULL; до 500 символов |
| products | TEXT | NOT NULL; необязательное; внешний ключ → products; несколько значений |
| deleted | BOOLEAN | NOT NULL; по умолчанию false |
| created | TEXT | NOT NULL, автодата |
| updated | TEXT | NOT NULL, автодата |

### `product_variants`

| Столбец | Тип SQLite | Ограничения |
|---|---|---|
| id | TEXT | PRIMARY KEY, NOT NULL |
| product | TEXT | NOT NULL; обязательное; внешний ключ → products; каскадное удаление; уникально вместе с: size, color |
| size | TEXT | NOT NULL; обязательное; значения: XS, S, M, L, XL, XXL; уникально вместе с: product, color |
| color | TEXT | NOT NULL; обязательное; от 2 символов; до 30 символов; уникально вместе с: product, size |
| stock | NUMERIC | NOT NULL; от 0; до 10000; целое |
| deleted | BOOLEAN | NOT NULL; по умолчанию false |
| created | TEXT | NOT NULL, автодата |
| updated | TEXT | NOT NULL, автодата |

### `delivery_methods`

| Столбец | Тип SQLite | Ограничения |
|---|---|---|
| id | TEXT | PRIMARY KEY, NOT NULL |
| name | TEXT | NOT NULL; обязательное; от 3 символов; до 60 символов; уникальное |
| price | NUMERIC | NOT NULL; от 0; до 100000; целое |
| days | NUMERIC | NOT NULL; обязательное, ≠ 0; от 1; до 60; целое |
| description | TEXT | NOT NULL; до 300 символов |
| deleted | BOOLEAN | NOT NULL; по умолчанию false |
| created | TEXT | NOT NULL, автодата |
| updated | TEXT | NOT NULL, автодата |

### `orders`

| Столбец | Тип SQLite | Ограничения |
|---|---|---|
| id | TEXT | PRIMARY KEY, NOT NULL |
| user | TEXT | NOT NULL; обязательное; внешний ключ → users |
| address | TEXT | NOT NULL; обязательное; внешний ключ → addresses |
| delivery_method | TEXT | NOT NULL; обязательное; внешний ключ → delivery_methods |
| status | TEXT | NOT NULL; обязательное; значения: new, paid, packed, shipped, delivered, cancelled |
| payment | TEXT | NOT NULL; обязательное; значения: card, cash |
| ordered_at | TEXT | NOT NULL; обязательное |
| total | NUMERIC | NOT NULL; от 0; до 10000000; целое |
| comment | TEXT | NOT NULL; до 300 символов |
| created | TEXT | NOT NULL, автодата |
| updated | TEXT | NOT NULL, автодата |

### `order_items`

| Столбец | Тип SQLite | Ограничения |
|---|---|---|
| id | TEXT | PRIMARY KEY, NOT NULL |
| order | TEXT | NOT NULL; обязательное; внешний ключ → orders; каскадное удаление; уникально вместе с: variant |
| variant | TEXT | NOT NULL; обязательное; внешний ключ → product_variants; уникально вместе с: order |
| quantity | NUMERIC | NOT NULL; обязательное, ≠ 0; от 1; до 20; целое |
| price | NUMERIC | NOT NULL; от 0; до 1000000; целое |
| created | TEXT | NOT NULL, автодата |
| updated | TEXT | NOT NULL, автодата |

### `deliveries`

| Столбец | Тип SQLite | Ограничения |
|---|---|---|
| id | TEXT | PRIMARY KEY, NOT NULL |
| order | TEXT | NOT NULL; обязательное; внешний ключ → orders; каскадное удаление; уникальное |
| carrier | TEXT | NOT NULL; обязательное; значения: cdek, boxberry, post, courier |
| track_number | TEXT | NOT NULL; шаблон ^[A-Z0-9]{8,20}$ |
| status | TEXT | NOT NULL; обязательное; значения: pending, in_transit, out_for_delivery, delivered, returned |
| shipped_at | TEXT | NOT NULL; необязательное |
| eta | TEXT | NOT NULL; необязательное |
| created | TEXT | NOT NULL, автодата |
| updated | TEXT | NOT NULL, автодата |
