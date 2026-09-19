/// Отказ кассы доезжает до кассира — и на его языке.
///
/// # Зачем отдельная проба, если словарь уже проверен сторожем
///
/// Потому что словарь и экран — разные вещи, и в этой работе разница уже
/// стоила измерения: `test/architecture/sale_refusal_codes_localized_test
/// .dart` доказывает, что у каждого кода есть строка во всех пяти локалях,
/// и **зеленел бы целиком**, даже если экран продажи не показывает отказ
/// вовсе. Так и было: до задачи 23 `SaleState.error` не рисовался нигде —
/// единственный слушатель `sale_screen.dart` разбирал один особый ключ
/// (`kShiftOverAgeError`) и молча ронял все прочие. Кассир, получивший
/// «чек устарел», не видел ничего: кнопка не сработала, и всё.
///
/// Поэтому проба смотрит на **увиденное кассиром** — на текст в дереве
/// виджетов, а не на возврат функции перевода.
///
/// # Почему ожидаемая строка берётся из словаря, а не вписана сюда
///
/// Вписанная казахская фраза превращает пробу в проверку одной строки:
/// поправили формулировку — красное, поменяли механизм показа — зелёное.
/// Здесь наоборот: строка берётся тем же `ErrorLocalizer`, каким её берёт
/// продукт, а проба утверждает две вещи, которые формулировка изменить не
/// может — эта строка на экране есть, а русской и самого ключа там нет.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/utils/error_localizer.dart';
import 'package:telepos/presentation/controllers/sale/sale_controller.dart';
import 'package:telepos/presentation/screens/sale/sale_screen.dart';

import '../../../helpers/mock_providers.dart';

/// Кассир, который умеет получить отказ уже после того, как экран собран.
///
/// Отказ — **изменение** состояния, а не начальное значение: слушатель
/// `ref.listen` на начальное значение не срабатывает вовсе, и проба,
/// собравшая экран сразу с ошибкой, доказывала бы не то.
class _PushableSaleNotifier extends MockSaleNotifier {
  _PushableSaleNotifier() : super(const SaleState());

  void refuse(String errorKey) => state = state.copyWith(error: errorKey);

  /// Промежуточный ноль, который `SaleController._emitError` пишет перед
  /// повторным тем же отказом — тем же синхронным шагом.
  void clearRefusal() => state = state.copyWith(clearError: true);
}

void main() {
  late SharedPreferences prefs;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  /// Экран продажи под названной локалью; `ctx` — контекст внутри дерева,
  /// тот самый, из которого продукт берёт перевод.
  Future<({_PushableSaleNotifier sale, BuildContext ctx})> pumpSale(
    WidgetTester tester,
    String locale,
  ) async {
    final notifier = _PushableSaleNotifier();
    late BuildContext ctx;
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          saleControllerProvider.overrideWith(() => notifier),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale(locale),
          home: Scaffold(
            body: Builder(
              builder: (c) {
                ctx = c;
                return const SaleScreen(shiftClose: ShiftCloseAtTill());
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (sale: notifier, ctx: ctx);
  }

  /// Переполнение раскладки на узком стенде — не предмет этой пробы.
  void suppressOverflowErrors() {
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed by')) return;
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);
  }

  testWidgets('отказ корзины виден кассиру на экране продажи (ru)', (
    tester,
  ) async {
    suppressOverflowErrors();
    final stand = await pumpSale(tester, 'ru');

    final expected = ErrorLocalizer.localize(stand.ctx, 'error.cart_stale');
    expect(
      find.text(expected),
      findsNothing,
      reason: 'до отказа фразы на экране быть не должно — контрольный случай',
    );

    stand.sale.refuse('error.cart_stale');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text(expected),
      findsOneWidget,
      reason:
          'Отказ кассы не доехал до экрана: `SaleState.error` меняется, а '
          'кассир не видит ничего. Показ отказа — `sale_screen.dart`, '
          'слушатель `s.error`.',
    );
    expect(
      find.text('error.cart_stale'),
      findsNothing,
      reason: 'на экране сам ключ вместо фразы',
    );
  });

  testWidgets('кассир с казахским интерфейсом читает казахскую фразу', (
    tester,
  ) async {
    suppressOverflowErrors();

    // Русская фраза берётся у словаря напрямую, а не вторым прогоном
    // экрана: два `pumpWidget` подряд `ProviderScope` не пересоздаёт —
    // подмена второго стенда не применяется, и проба падает изнутри
    // Riverpod, ничего не измерив (измерено здесь же, 2026-09-06).
    final ru = (await AppLocalizations.delegate.load(const Locale('ru')))
        .errorCartWrongReceipt;

    final stand = await pumpSale(tester, 'kk');
    final kk = ErrorLocalizer.localize(stand.ctx, 'error.cart_wrong_receipt');
    expect(
      kk,
      isNot(equals(ru)),
      reason: 'казахского перевода нет — словарь отдаёт русскую строку',
    );

    stand.sale.refuse('error.cart_wrong_receipt');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text(kk),
      findsOneWidget,
      reason: 'казахской фразы нет на экране',
    );
    expect(
      find.text(ru),
      findsNothing,
      reason: 'кассиру с казахским интерфейсом показали русскую фразу',
    );
  });

  testWidgets('тот же отказ, пришедший снова, кассир видит снова', (
    tester,
  ) async {
    suppressOverflowErrors();
    final stand = await pumpSale(tester, 'ru');
    final expected = ErrorLocalizer.localize(stand.ctx, 'error.line_not_found');

    stand.sale.refuse('error.line_not_found');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text(expected), findsOneWidget, reason: 'первый показ');

    // Пару «ноль, затем тот же ключ» пишет `SaleController._emitError`
    // одним синхронным шагом, и что он её действительно пишет — доказано
    // на настоящем контроллере (`test/integration/
    // sale_controller_refusal_test.dart`). Здесь проверяется вторая
    // половина той же пары: экран, получив тот же ключ после ноля,
    // показывает его снова, а не считает «уже показывал».
    stand.sale.clearRefusal();
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    stand.sale.refuse('error.line_not_found');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(
      find.text(expected),
      findsOneWidget,
      reason:
          'Кассир, повторивший то же действие и получивший тот же отказ, '
          'не получил ответа вовсе.',
    );
  });
}
