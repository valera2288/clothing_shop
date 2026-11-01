import 'package:clothing_shop/core/api_exceptions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('400 с data — ошибки валидации по полям на русском', () {
    final e = mapHttpError(400, {
      'status': 400,
      'message': 'Failed to create record.',
      'data': {
        'sku': {
          'code': 'validation_not_unique',
          'message': 'Value must be unique.',
        },
        'price': {'code': 'validation_min_number_constraint', 'message': 'x'},
      },
    });
    expect(e, isA<ValidationException>());
    final errors = (e as ValidationException).errors;
    expect(errors['sku'], 'Такое значение уже существует');
    expect(errors['price'], 'Число меньше допустимого');
  });

  test('неизвестный код ошибки показывает текст сервера', () {
    final e = mapHttpError(400, {
      'message': 'Failed to create record.',
      'data': {
        'x': {'code': 'weird', 'message': 'Сообщение сервера'},
      },
    }) as ValidationException;
    expect(e.errors['x'], 'Сообщение сервера');
  });

  test('неверный пароль — 401, а не ошибка валидации', () {
    final e =
        mapHttpError(400, {'message': 'Failed to authenticate.', 'data': {}});
    expect(e, isA<UnauthorizedException>());
  });

  test('отказ правила при создании (400 без data) — нет прав', () {
    final e =
        mapHttpError(400, {'message': 'Failed to create record.', 'data': {}});
    expect(e, isA<ForbiddenException>());
  });

  test('удаление записи, на которую ссылаются, — конфликт, а не «нет прав»',
      () {
    final e = mapHttpError(400, {
      'message': 'Failed to delete record. Make sure that the record is not '
          'part of a required relation reference.',
      'data': {},
    });
    expect(e, isA<ConflictException>());
  });

  test('404, 403, 409 и 5xx', () {
    expect(mapHttpError(404, null), isA<NotFoundException>());
    expect(mapHttpError(403, null), isA<ForbiddenException>());
    expect(
      mapHttpError(409, {'message': 'Нет на складе'}),
      isA<ConflictException>(),
    );
    expect(mapHttpError(503, null), isA<ServerException>());
  });
}
