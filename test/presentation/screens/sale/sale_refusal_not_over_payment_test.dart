/// Полоса отказа продажи не накрывает кнопки открытой оплаты — приёмка
/// браузерного терминала 2026-09-17.
///
/// # Что измерено живьём
///
/// «Товар не найден» → внизу полоса на 4 секунды → «ОПЛАТИТЬ». Открылась
/// карточка оплаты, и полоса осталась **поверх неё**, накрыв «Отмена» и
/// «ОПЛАТИТЬ». Механизм — корневой `ScaffoldMessenger`: он один на все
/// маршруты и стоит над навигатором, поэтому переход на другой маршрут
/// полосу не трогает. Тот же механизм уже был измерен с другой стороны — у
/// самого экрана оплаты (докстринг `_PaymentScreenState._refusals`).
///
/// # Почему проба смотрит на дерево, а не на координаты
///
/// «Полоса накрывает кнопку» — это про пересечение прямоугольников, и
/// проба, сравнивающая их, зависела бы от размера окна, длины фразы и
/// раскладки: на окне другой высоты она зеленела бы, ничего не починив.
/// Требование сильнее и проще: полосы продажи над оплатой **не бывает
/// вовсе**. Пересечение проверяется отдельным утверждением как контроль —
/// им доказано, что на измеренном окне 1920×937 полоса действительно легла
/// бы на кнопку, то есть проба мерит дефект, а не удобную геометрию.
///
/// # Обе таблицы маршрутов
///
/// Как и у `sale_scanner_under_dialog_test.dart`: касса держит продажу во
/// вложенном навигаторе (`ShellRoute`), браузер — в корневом. Полоса живёт
/// над обоими, и беда обязана проверяться в обеих.
library;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker/talker.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/core/logging/app_talker.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/payment/payment_controller.dart';
import 'package:telepos/presentation/controllers/sale/sale_controller.dart';
import 'package:telepos/presentation/screens/payment/payment_screen.dart';
import 'package:telepos/presentation/screens/sale/sale_screen.dart';

import '../../../helpers/mock_providers.dart';

/// Чек с одной строкой — иначе «ОПЛАТИТЬ» заперта и уходить с экрана нечем.
class _PushableSale extends MockSaleNotifier {
  _PushableSale()
    : super(
        SaleState(
          receiptNo: 1,
          items: [
            SaleItem(
              id: 'kefir',
              productId: 200,
              name: 'Кефир',
              price: Decimal.parse('499.995'),
              quantity: Decimal.one,
              barcode: '4870007654321',
            ),
          ],
        ),
      );

  /// Отказ — **изменение** состояния: `ref.listen` на начальное значение не
  /// срабатывает вовсе, и стенд, собранный сразу с ошибкой, доказывал бы не
  /// то.
  void refuse(String errorKey) => state = state.copyWith(error: errorKey);
}

void main() {
  late SharedPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    if (!isLoggerReady) installLogger(Talker());
  });

  setUp(() async => GetIt.I.reset());
  tearDown(() async => GetIt.I.reset());

  /// Окно живой приёмки — то самое, на котором полоса легла на кнопку.
  void desktop(WidgetTester tester) {
    tester.view.physicalSize = const Size(1920, 937);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.exceptionAsString();
      if (text.contains('overflowed') || text.contains('A RenderFlex')) return;
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);
  }

  Future<({_PushableSale sale, GoRouter router})> pumpStand(
    WidgetTester tester, {
    required bool shell,
  }) async {
    final sale = _PushableSale();
    final rootKey = GlobalKey<NavigatorState>();
    final router = GoRouter(
      navigatorKey: rootKey,
      initialLocation: '/sale',
      routes: [
        if (shell)
          ShellRoute(
            builder: (context, state, child) => Scaffold(body: child),
            routes: [
              GoRoute(
                path: '/sale',
                builder: (context, state) =>
                    const SaleScreen(shiftClose: ShiftCloseAtTill()),
              ),
            ],
          )
        else
          GoRoute(
            path: '/sale',
            builder: (context, state) => const Scaffold(
              body: SaleScreen(shiftClose: ShiftCloseAtTill()),
            ),
          ),
        GoRoute(
          path: '/payment',
          parentNavigatorKey: rootKey,
          builder: (context, state) => const PaymentScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          saleControllerProvider.overrideWith(() => sale),
          paymentControllerProvider.overrideWith(
            () => MockPaymentNotifier(
              PaymentState(totalAmount: Decimal.parse('499.995')),
            ),
          ),
          paymentAccountsProvider.overrideWith(
            (ref) async => <PaymentAccount>[],
          ),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
          locale: const Locale('ru'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (sale: sale, router: router);
  }

  for (final shell in const [false, true]) {
    final table = shell
        ? 'касса (продажа во вложенном навигаторе)'
        : 'браузер (оба маршрута в корне)';

    group(table, () {
      testWidgets('полоса отказа не переезжает на экран оплаты', (
        tester,
      ) async {
        desktop(tester);
        final stand = await pumpStand(tester, shell: shell);

        stand.sale.refuse('error.cart_stale');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(
          find.byType(SnackBar),
          findsOneWidget,
          reason:
              'контрольный случай: полоса действительно показана — иначе '
              'проба ниже зеленела бы, ничего не измерив',
        );

        // Кассир целится в «ОПЛАТИТЬ» экрана продажи.
        await tester.tap(find.text('ОПЛАТИТЬ').first);
        await tester.pumpAndSettle();

        expect(
          find.byType(PaymentScreen),
          findsOneWidget,
          reason: 'контрольный случай: оплата действительно открылась',
        );
        expect(
          find.byType(SnackBar),
          findsNothing,
          reason:
              'ПОЛОСА ОТКАЗА ПРОДАЖИ ОСТАЛАСЬ ПОВЕРХ ОТКРЫТОЙ ОПЛАТЫ. Её '
              'показывает корневой `ScaffoldMessenger` — один на все '
              'маршруты, — и уход на другой маршрут её не трогает. Снятие — '
              '`_SaleScreenState._handlePay`.',
        );
      });
    });
  }

  testWidgets('контроль: на измеренном окне полоса легла бы на кнопки оплаты', (
    tester,
  ) async {
    // Доказательство, что предыдущая проба мерит дефект, а не удобную
    // геометрию: та же полоса, показанная **до** ухода на оплату, на этом
    // окне действительно пересекается с подвалом карточки оплаты. Без
    // этого контроля «полосы нет» могло бы означать «она всё равно никуда
    // не попадала».
    desktop(tester);
    final stand = await pumpStand(tester, shell: false);

    stand.sale.refuse('error.cart_stale');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final bar = tester.getRect(find.byType(SnackBar));

    // Уходим на оплату **мимо** экрана продажи — маршрутом, а не кнопкой:
    // снятие полосы живёт в обработчике кнопки, и обойти его здесь надо
    // нарочно, чтобы увидеть прежнюю геометрию.
    stand.router.push('/payment');
    await tester.pumpAndSettle();

    final pay = tester.getRect(find.text('ОПЛАТИТЬ').first);

    expect(
      bar.overlaps(pay),
      isTrue,
      reason:
          'на окне 1920×937 полоса продажи не пересекается с кнопкой оплаты '
          '— значит проба выше мерит не тот дефект, что нашла приёмка',
    );
  });
}
