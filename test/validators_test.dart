import 'package:clothing_shop/core/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('V.required / V.length', () {
    test('пустая и пробельная строка не проходит', () {
      expect(V.required()(''), isNotNull);
      expect(V.required()('   '), isNotNull);
      expect(V.required()('Куртка'), isNull);
    });

    test('длина проверяется после обрезки пробелов', () {
      final v = V.length(min: 3, max: 5);
      expect(v('ab'), contains('3'));
      expect(v('  abcdef '), contains('5'));
      expect(v(' abc '), isNull);
    });
  });

  group('V.integer', () {
    test('нечисло, дробь и пустое значение отклоняются', () {
      final v = V.integer(min: 1, max: 20);
      expect(v(''), isNotNull);
      expect(v('abc'), isNotNull);
      expect(v('1.5'), isNotNull);
    });

    test('границы диапазона включаются', () {
      final v = V.integer(min: 1, max: 20, label: 'Количество');
      expect(v('0'), contains('не меньше 1'));
      expect(v('21'), contains('не больше 20'));
      expect(v('1'), isNull);
      expect(v('20'), isNull);
    });
  });

  group('форматы', () {
    test('почта', () {
      expect(V.email()('ivan@shop.test'), isNull);
      expect(V.email()('ivan@'), isNotNull);
      expect(V.email()('без собаки'), isNotNull);
    });

    test('телефон', () {
      expect(V.phone()('+7 900 123-45-67'), isNull);
      expect(V.phone()('12'), isNotNull);
    });

    test(
        'pattern пропускает пустое значение: обязательность проверяет required',
        () {
      final v = V.pattern(RegExp(r'^\d{6}$'), 'Индекс — шесть цифр');
      expect(v(''), isNull);
      expect(v('12345'), 'Индекс — шесть цифр');
      expect(v('123456'), isNull);
    });
  });

  group('пароль', () {
    test('нужны 8 символов, цифра и спецсимвол', () {
      final v = V.strongPassword();
      expect(v('short1!'), isNotNull);
      expect(v('longpassword!'), contains('цифра'));
      expect(v('longpassword1'), contains('спецсимвол'));
      expect(v('Customer#2026'), isNull);
    });
  });

  test('combine возвращает первую ошибку', () {
    final v = V.combine([V.required('пусто'), V.length(min: 3)]);
    expect(v(''), 'пусто');
    expect(v('ab'), contains('3'));
    expect(v('abc'), isNull);
  });
}
