// Серверная логика магазина. Выполняется внутри транзакции запроса,
// поэтому при ошибке откатываются и заказ, и позиции, и остатки.
// Обработчики выполняются в изолированной области, общий код — в shop_lib.js.

// Новая позиция: списать остаток, цену взять из товара (клиент не подставит свою).
onRecordCreate((e) => {
  const lib = require(`${__hooks}/shop_lib.js`);
  const variant = e.app.findRecordById("product_variants", e.record.get("variant"));
  const product = e.app.findRecordById("products", variant.get("product"));
  if (product.get("deleted") || variant.get("deleted")) {
    throw new BadRequestError("Товар снят с продажи: " + product.get("name"));
  }
  lib.changeStock(e.app, variant.id, -e.record.getInt("quantity"));
  e.record.set("price", product.getInt("price"));
  e.next();
}, "order_items");

// Изменение позиции: вернуть прежнее количество, списать новое.
onRecordUpdate((e) => {
  const lib = require(`${__hooks}/shop_lib.js`);
  const was = e.record.original();
  lib.changeStock(e.app, was.get("variant"), was.getInt("quantity"));
  lib.changeStock(e.app, e.record.get("variant"), -e.record.getInt("quantity"));
  // Цена на момент покупки не меняется, пока вариант тот же
  if (e.record.get("variant") === was.get("variant")) {
    e.record.set("price", was.getInt("price"));
  } else {
    const product = e.app.findRecordById("products",
      e.app.findRecordById("product_variants", e.record.get("variant")).get("product"));
    e.record.set("price", product.getInt("price"));
  }
  e.next();
}, "order_items");

onRecordAfterCreateSuccess((e) => {
  require(`${__hooks}/shop_lib.js`).recalcTotal(e.app, e.record.get("order"));
  e.next();
}, "order_items");

onRecordAfterUpdateSuccess((e) => {
  require(`${__hooks}/shop_lib.js`).recalcTotal(e.app, e.record.get("order"));
  e.next();
}, "order_items");

// Удаление позиции возвращает товар на склад (если заказ не отменён) и пересчитывает итог.
// При каскадном удалении вместе с заказом самого заказа уже может не быть.
onRecordAfterDeleteSuccess((e) => {
  const lib = require(`${__hooks}/shop_lib.js`);
  let order = null;
  try { order = e.app.findRecordById("orders", e.record.get("order")); } catch (_) {}
  if (order) {
    if (order.get("status") !== "cancelled") {
      lib.changeStock(e.app, e.record.get("variant"), e.record.getInt("quantity"));
    }
    lib.recalcTotal(e.app, order.id);
  }
  e.next();
}, "order_items");

// Отмена заказа возвращает товары на склад независимо от того, кто отменил.
onRecordAfterUpdateSuccess((e) => {
  const lib = require(`${__hooks}/shop_lib.js`);
  if (e.record.get("status") === "cancelled" && e.record.original().get("status") !== "cancelled") {
    const items = e.app.findRecordsByFilter("order_items", "order = {:o}", "", 0, 0, { o: e.record.id });
    items.forEach((i) => lib.changeStock(e.app, i.get("variant"), i.getInt("quantity")));
  }
  e.next();
}, "orders");
