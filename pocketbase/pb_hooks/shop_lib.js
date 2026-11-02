// Общие функции серверных хуков (подключаются через require).

// Итог заказа: сумма позиций минус скидка по карте лояльности плюс доставка.
function recalcTotal(app, orderId) {
  const order = app.findRecordById("orders", orderId);
  const items = app.findRecordsByFilter("order_items", "order = {:o}", "", 0, 0, { o: orderId });
  let sum = 0;
  items.forEach((i) => { sum += i.getInt("price") * i.getInt("quantity"); });
  const DISCOUNT = { bronze: 3, silver: 5, gold: 7 };
  let pct = 0;
  const cards = app.findRecordsByFilter("loyalty_cards", "user = {:u}", "", 1, 0, { u: order.get("user") });
  if (cards.length) pct = DISCOUNT[cards[0].get("tier")] || 0;
  const delivery = app.findRecordById("delivery_methods", order.get("delivery_method"));
  order.set("total", sum - Math.floor(sum * pct / 100) + delivery.getInt("price"));
  app.save(order);
}

// Изменить остаток варианта на delta (отрицательное — списание).
function changeStock(app, variantId, delta) {
  const variant = app.findRecordById("product_variants", variantId);
  const next = variant.getInt("stock") + delta;
  if (next < 0) {
    const product = app.findRecordById("products", variant.get("product"));
    throw new BadRequestError("Недостаточно товара на складе: " + product.get("name"));
  }
  variant.set("stock", next);
  app.save(variant);
}

module.exports = { recalcTotal, changeStock };
