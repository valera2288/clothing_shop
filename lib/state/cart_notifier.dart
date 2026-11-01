import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/product.dart';
import '../models/product_variant.dart';

/// Строка корзины: вариант товара и количество.
class CartLine {
  final String variantId;
  final String productId;
  final String productName;
  final String size;
  final String color;
  final int price;
  final int stock;
  final int quantity;

  const CartLine({
    required this.variantId,
    required this.productId,
    required this.productName,
    required this.size,
    required this.color,
    required this.price,
    required this.stock,
    required this.quantity,
  });

  int get sum => price * quantity;

  CartLine withQuantity(int q) => CartLine(
        variantId: variantId,
        productId: productId,
        productName: productName,
        size: size,
        color: color,
        price: price,
        stock: stock,
        quantity: q,
      );

  Map<String, dynamic> toJson() => {
        'variantId': variantId,
        'productId': productId,
        'productName': productName,
        'size': size,
        'color': color,
        'price': price,
        'stock': stock,
        'quantity': quantity,
      };

  factory CartLine.fromJson(Map<String, dynamic> j) => CartLine(
        variantId: j['variantId'] as String,
        productId: j['productId'] as String,
        productName: j['productName'] as String,
        size: j['size'] as String,
        color: j['color'] as String,
        price: (j['price'] as num).toInt(),
        stock: (j['stock'] as num).toInt(),
        quantity: (j['quantity'] as num).toInt(),
      );
}

/// Корзина покупателя. Хранится в браузере отдельно для каждого пользователя,
/// поэтому переживает перезагрузку страницы. Серверу она не нужна: данные
/// уходят на сервер только при оформлении заказа.
class CartNotifier extends ChangeNotifier {
  /// Предел количества одной позиции; совпадает с ограничением поля
  /// `order_items.quantity` на сервере.
  static const maxQuantity = 20;

  final SharedPreferences _prefs;
  final String _key;
  final List<CartLine> _lines = [];

  CartNotifier(this._prefs, String userId) : _key = 'cart_$userId' {
    _restore();
  }

  List<CartLine> get lines => List.unmodifiable(_lines);
  bool get isEmpty => _lines.isEmpty;
  int get count => _lines.fold(0, (a, l) => a + l.quantity);
  int get subtotal => _lines.fold(0, (a, l) => a + l.sum);

  void _restore() {
    try {
      final raw = _prefs.getString(_key);
      if (raw == null) return;
      for (final item in jsonDecode(raw) as List) {
        _lines.add(CartLine.fromJson(item as Map<String, dynamic>));
      }
    } catch (_) {
      // Повреждённая запись: начинаем с пустой корзины
      _lines.clear();
    }
  }

  void _save() {
    _prefs.setString(_key, jsonEncode(_lines.map((l) => l.toJson()).toList()));
    notifyListeners();
  }

  /// Добавляет вариант. Возвращает false, если на складе больше нет.
  bool add(Product product, ProductVariant variant, {int quantity = 1}) {
    final i = _lines.indexWhere((l) => l.variantId == variant.id);
    final current = i < 0 ? 0 : _lines[i].quantity;
    final limit = variant.stock < maxQuantity ? variant.stock : maxQuantity;
    if (current + quantity > limit) return false;
    if (i >= 0) {
      _lines[i] = _lines[i].withQuantity(current + quantity);
    } else {
      _lines.add(CartLine(
        variantId: variant.id,
        productId: product.id,
        productName: product.name,
        size: variant.size,
        color: variant.color,
        price: product.price,
        stock: variant.stock,
        quantity: quantity,
      ));
    }
    _save();
    return true;
  }

  void setQuantity(String variantId, int quantity) {
    final i = _lines.indexWhere((l) => l.variantId == variantId);
    if (i < 0) return;
    final line = _lines[i];
    final limit = line.stock < maxQuantity ? line.stock : maxQuantity;
    if (quantity <= 0) {
      _lines.removeAt(i);
    } else {
      _lines[i] = line.withQuantity(quantity > limit ? limit : quantity);
    }
    _save();
  }

  void remove(String variantId) => setQuantity(variantId, 0);

  void clear() {
    _lines.clear();
    _save();
  }
}
