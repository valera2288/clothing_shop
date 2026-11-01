import 'package:clothing_shop/core/api_exceptions.dart';
import 'package:clothing_shop/entities/entity_def.dart';
import 'package:clothing_shop/models/list_query.dart';
import 'package:clothing_shop/state/load_status.dart';
import 'package:clothing_shop/widgets/entity_form.dart';
import 'package:clothing_shop/widgets/filters/filter_panel.dart';
import 'package:clothing_shop/widgets/pagination.dart';
import 'package:clothing_shop/widgets/state_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

Widget _routed(Widget child) => MaterialApp.router(
      routerConfig: GoRouter(routes: [
        GoRoute(path: '/', builder: (c, s) => child),
      ]),
    );

void main() {
  group('четыре состояния экрана', () {
    Widget body(LoadStatus status, {bool empty = false}) => _wrap(StatusBody(
          status: status,
          error: 'Сервер недоступен',
          isEmpty: empty,
          onRetry: () {},
          builder: (_) => const Text('данные'),
        ));

    testWidgets('загрузка: индикатор, данных и ошибки нет', (tester) async {
      await tester.pumpWidget(body(LoadStatus.loading));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('данные'), findsNothing);
    });

    testWidgets('данные', (tester) async {
      await tester.pumpWidget(body(LoadStatus.success));
      expect(find.text('данные'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('пустой результат — не индикатор и не ошибка', (tester) async {
      await tester.pumpWidget(body(LoadStatus.success, empty: true));
      expect(find.text('Ничего не найдено'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Повторить'), findsNothing);
    });

    testWidgets('ошибка с кнопкой «Повторить»', (tester) async {
      var retried = 0;
      await tester.pumpWidget(_wrap(StatusBody(
        status: LoadStatus.error,
        error: 'Сервер недоступен',
        isEmpty: false,
        onRetry: () => retried++,
        builder: (_) => const Text('данные'),
      )));
      expect(find.text('Сервер недоступен'), findsOneWidget);
      await tester.tap(find.text('Повторить'));
      expect(retried, 1);
    });
  });

  testWidgets('пагинация: переход на следующую страницу и смена размера',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    int? page;
    int? size;
    await tester.pumpWidget(_wrap(Pagination(
      currentPage: 1,
      totalPages: 3,
      totalItems: 25,
      pageSize: 10,
      onPageChanged: (p) => page = p,
      onPageSizeChanged: (s) => size = s,
    )));
    expect(find.text('Всего записей: 25'), findsOneWidget);
    await tester.tap(find.byTooltip('Следующая'));
    expect(page, 2);
    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('25 на стр.').last);
    expect(size, 25);
  });

  testWidgets(
      'панель фильтров: выбор значения даёт новый запрос, «Сбросить» очищает',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var query = const ListQuery(defaultSort: 'name');
    await tester.pumpWidget(StatefulBuilder(
      builder: (context, setState) => _wrap(FilterPanel(
        searchHint: 'Поиск',
        filters: const [
          FilterSpec('gender', 'Для кого', FilterKind.select,
              options: {'men': 'Мужская', 'women': 'Женская'}),
        ],
        sorts: const [SortSpec('name', 'По названию')],
        query: query,
        onChanged: (q) => setState(() => query = q),
      )),
    ));
    expect(find.text('Сбросить'), findsNothing);

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Женская').last);
    await tester.pumpAndSettle();
    expect(query.filter('gender'), 'women');

    await tester.tap(find.text('Сбросить'));
    await tester.pumpAndSettle();
    expect(query.filters, isEmpty);
  });

  group('форма', () {
    const spec = FieldSpec('sku', 'Артикул', FieldKind.text,
        required: true, minLength: 3, maxLength: 10);

    testWidgets('клиентская проверка показывает ошибку у поля и не отправляет',
        (tester) async {
      var sent = 0;
      await tester.pumpWidget(_routed(EntityForm(
        title: 'Товар',
        fields: [
          EntityFormField(
            name: 'sku',
            build: (_) => TextFormField(
              decoration: const InputDecoration(labelText: 'Артикул'),
              validator: spec.validator,
            ),
          ),
        ],
        onSubmit: () async => sent++,
      )));
      await tester.tap(find.text('Создать'));
      await tester.pump();
      expect(find.text('Поле обязательно'), findsOneWidget);
      expect(sent, 0);

      await tester.enterText(find.byType(TextFormField), 'ab');
      await tester.tap(find.text('Создать'));
      await tester.pump();
      expect(find.textContaining('Не короче 3'), findsOneWidget);
      expect(sent, 0);
    });

    testWidgets('ошибка сервера показывается под нужным полем', (tester) async {
      await tester.pumpWidget(_routed(EntityForm(
        title: 'Товар',
        fields: [
          EntityFormField(
            name: 'sku',
            build: (_) => TextFormField(
              decoration: const InputDecoration(labelText: 'Артикул'),
              validator: spec.validator,
            ),
          ),
        ],
        onSubmit: () async => throw const ValidationException(
          'Сервер отклонил данные',
          {'sku': 'Такое значение уже существует'},
        ),
      )));
      await tester.enterText(find.byType(TextFormField), 'TS-1001');
      await tester.tap(find.text('Создать'));
      await tester.pumpAndSettle();
      expect(find.text('Такое значение уже существует'), findsOneWidget);
    });
  });

  test('поле формы собирает проверки из описания', () {
    const f = FieldSpec('price', 'Цена', FieldKind.integer,
        required: true, min: 1, max: 1000);
    expect(f.validator(''), isNotNull);
    expect(f.validator('0'), isNotNull);
    expect(f.validator('1001'), isNotNull);
    expect(f.validator('500'), isNull);
    const optional =
        FieldSpec('flat', 'Квартира', FieldKind.text, maxLength: 3);
    expect(optional.validator(''), isNull);
    expect(optional.validator('12345'), isNotNull);
  });
}
