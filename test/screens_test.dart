import 'dart:async';

import 'package:clothing_shop/core/api_exceptions.dart';
import 'package:clothing_shop/core/permissions.dart';
import 'package:clothing_shop/entities/entity_defs.dart';
import 'package:clothing_shop/models/page_result.dart';
import 'package:clothing_shop/models/product.dart';
import 'package:clothing_shop/repositories/entity_repository.dart';
import 'package:clothing_shop/screens/entity/entity_list_screen.dart';
import 'package:clothing_shop/screens/forbidden_screen.dart';
import 'package:clothing_shop/screens/login_screen.dart';
import 'package:clothing_shop/state/auth_notifier.dart';
import 'package:clothing_shop/state/cart_notifier.dart';
import 'package:clothing_shop/state/connection_notifier.dart';
import 'package:clothing_shop/state/lookup_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

Future<void> _pumpProducts(
  WidgetTester tester, {
  required AuthNotifier auth,
  required FakeProducts repo,
  Size size = const Size(1280, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    initialLocation: '/products',
    routes: [
      GoRoute(
        path: '/products',
        builder: (c, s) => EntityListScreen<Product>(def: Entities.products),
      ),
    ],
  );
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthNotifier>.value(value: auth),
      ChangeNotifierProvider(create: (_) => ConnectionNotifier()),
      ChangeNotifierProvider(create: (_) => CartNotifier(prefs, 'u1')),
      ChangeNotifierProvider(
        create: (_) => LookupService({
          for (final k in const ['categories', 'brands', 'collections'])
            k: () async => <Option>[],
        }),
      ),
      Provider<ProductRepository>.value(value: repo),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
}

void main() {
  group('список товаров', () {
    testWidgets('пока идёт загрузка, виден индикатор', (tester) async {
      final auth = await signedIn(Role.customer);
      final completer = Completer<PageResult<Product>>();
      await _pumpProducts(tester,
          auth: auth, repo: FakeProducts((_) => completer.future));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('данные показываются плитками, условия уходят на сервер',
        (tester) async {
      final auth = await signedIn(Role.customer);
      final repo = FakeProducts((_) async =>
          pageOf([product('1', 'Футболка белая'), product('2', 'Худи серое')]));
      await _pumpProducts(tester, auth: auth, repo: repo);
      await tester.pumpAndSettle();
      expect(find.text('Футболка белая'), findsOneWidget);
      expect(find.text('Худи серое'), findsOneWidget);
      expect(repo.queries.first.sort, 'name');
      expect(find.text('Всего записей: 2'), findsOneWidget);
    });

    testWidgets('пустой результат — сообщение, а не индикатор', (tester) async {
      final auth = await signedIn(Role.customer);
      await _pumpProducts(tester,
          auth: auth, repo: FakeProducts((_) async => pageOf([])));
      await tester.pumpAndSettle();
      expect(find.text('Здесь пока нет записей'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('ошибка сервера — сообщение и повтор', (tester) async {
      final auth = await signedIn(Role.customer);
      var fail = true;
      final repo = FakeProducts((_) async {
        if (fail) throw const NetworkException('Сервер недоступен.');
        return pageOf([product('1', 'Футболка белая')]);
      });
      await _pumpProducts(tester, auth: auth, repo: repo);
      await tester.pumpAndSettle();
      expect(find.text('Сервер недоступен.'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('Повторить'));
      await tester.pumpAndSettle();
      expect(find.text('Футболка белая'), findsOneWidget);
    });

    testWidgets('покупателю не видны кнопки управления, администратору видны',
        (tester) async {
      final repo =
          FakeProducts((_) async => pageOf([product('1', 'Футболка')]));
      await _pumpProducts(tester,
          auth: await signedIn(Role.customer), repo: repo);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Новый товар'), findsNothing);
      expect(find.byTooltip('Удалить'), findsNothing);

      await _pumpProducts(tester, auth: await signedIn(Role.admin), repo: repo);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Новый товар'), findsOneWidget);
      expect(find.byTooltip('Редактировать'), findsOneWidget);
      expect(find.byTooltip('Удалить'), findsOneWidget);
    });

    testWidgets('на телефоне список — карточки с фильтрами в блоке «Фильтры»',
        (tester) async {
      final auth = await signedIn(Role.admin);
      final repo =
          FakeProducts((_) async => pageOf([product('1', 'Футболка')]));
      await _pumpProducts(tester,
          auth: auth, repo: repo, size: const Size(360, 740));
      await tester.pumpAndSettle();
      expect(find.text('Фильтры'), findsOneWidget);
      expect(find.text('Футболка'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('вход', () {
    Future<void> pumpLogin(WidgetTester tester, AuthNotifier auth) async {
      await tester.pumpWidget(ChangeNotifierProvider<AuthNotifier>.value(
        value: auth,
        child: MaterialApp.router(
          routerConfig: GoRouter(routes: [
            GoRoute(path: '/', builder: (c, s) => const LoginScreen()),
          ]),
        ),
      ));
    }

    testWidgets('пустая форма не отправляется, у полей видны ошибки',
        (tester) async {
      final auth = await signedIn(null);
      await pumpLogin(tester, auth);
      await tester.tap(find.text('Войти').last);
      await tester.pump();
      expect(find.text('Введите почту'), findsOneWidget);
      expect(find.text('Введите пароль'), findsOneWidget);
      expect(auth.isAuthenticated, isFalse);
    });

    testWidgets('неверный пароль показывает сообщение', (tester) async {
      final auth = await signedIn(null,
          failWith: const UnauthorizedException('Неверная почта или пароль'));
      await pumpLogin(tester, auth);
      await tester.enterText(find.byType(TextFormField).first, 'a@shop.test');
      await tester.enterText(find.byType(TextFormField).last, 'wrong');
      await tester.tap(find.text('Войти').last);
      await tester.pumpAndSettle();
      expect(find.text('Неверная почта или пароль'), findsOneWidget);
      expect(auth.isAuthenticated, isFalse);
    });

    testWidgets('верные данные открывают сессию', (tester) async {
      final auth = await signedIn(null);
      await pumpLogin(tester, auth);
      await tester.enterText(find.byType(TextFormField).first, 'a@shop.test');
      await tester.enterText(find.byType(TextFormField).last, 'Customer#2026');
      await tester.tap(find.text('Войти').last);
      await tester.pumpAndSettle();
      expect(auth.isAuthenticated, isTrue);
      expect(auth.role, Role.customer);
    });
  });

  testWidgets('экран отказа предлагает вернуться на главную', (tester) async {
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: GoRouter(routes: [
        GoRoute(path: '/', builder: (c, s) => const ForbiddenScreen()),
      ]),
    ));
    expect(find.text('Недостаточно прав'), findsOneWidget);
    expect(find.text('На главную'), findsOneWidget);
  });
}
