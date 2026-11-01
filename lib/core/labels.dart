/// Русские подписи для значений перечислений (на сервере хранятся коды).
const genderLabels = {
  'men': 'Мужская',
  'women': 'Женская',
  'unisex': 'Унисекс',
  'kids': 'Детская',
};

const seasonLabels = {
  'spring': 'Весна',
  'summer': 'Лето',
  'autumn': 'Осень',
  'winter': 'Зима',
};

const tierLabels = {
  'bronze': 'Бронзовая',
  'silver': 'Серебряная',
  'gold': 'Золотая',
};

/// Скидка по карте лояльности, %.
const tierDiscount = {'bronze': 3, 'silver': 5, 'gold': 7};

const orderStatusLabels = {
  'new': 'Новый',
  'paid': 'Оплачен',
  'packed': 'Собран',
  'shipped': 'Отправлен',
  'delivered': 'Доставлен',
  'cancelled': 'Отменён',
};

const paymentLabels = {'card': 'Картой', 'cash': 'Наличными при получении'};

const carrierLabels = {
  'cdek': 'СДЭК',
  'boxberry': 'Boxberry',
  'post': 'Почта России',
  'courier': 'Собственный курьер',
};

const deliveryStatusLabels = {
  'pending': 'Ожидает отправки',
  'in_transit': 'В пути',
  'out_for_delivery': 'Передан курьеру',
  'delivered': 'Вручён',
  'returned': 'Возврат',
};

const roleLabels = {
  'customer': 'Покупатель',
  'manager': 'Менеджер',
  'admin': 'Администратор',
};

const sizeValues = ['XS', 'S', 'M', 'L', 'XL', 'XXL'];

/// В какие статусы менеджер может перевести заказ из текущего.
const orderNextStatuses = {
  'new': ['paid', 'cancelled'],
  'paid': ['packed', 'cancelled'],
  'packed': ['shipped', 'cancelled'],
  'shipped': ['delivered'],
  'delivered': <String>[],
  'cancelled': <String>[],
};

String label(Map<String, String> labels, String code) => labels[code] ?? code;

/// Цена в рублях: `12 990 ₽`.
String rub(num value) {
  final s = value.round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return '$buf ₽';
}

String dateText(DateTime? d) {
  if (d == null) return '—';
  final l = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(l.day)}.${two(l.month)}.${l.year}';
}
