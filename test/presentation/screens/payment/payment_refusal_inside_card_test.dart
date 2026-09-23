/// Отказ оплаты виден кассиру **в карточке оплаты**, а не внизу окна поверх
/// затемнения и кнопки «Оплатить».
///
/// # Дефект, найденный живой приёмкой браузерного терминала
///
/// Диалог оплаты → «Рассрочка» без покупателя → «Оплатить» → отказ «Продажа в
/// долг без покупателя невозможна — выберите покупателя.» появился полосой
/// внизу окна, на затемнении, частично под карточкой — кассир его почти не
/// видел.
///
/// # Что измерено под `flutter test` (и чего измерить не удалось)
///
/// Полоса показывается **корневым** `ScaffoldMessenger` — тем, что
/// `MaterialApp.router` ставит над навигатором и делит между всеми
/// маршрутами. Отображает её `Scaffold` самой настольной раскладки оплаты, а
/// он растянут **на всё окно**: его фон — `AppColors.modalOverlay`, то самое
/// затемнение, а карточка — `Center` внутри тела. Поэтому полоса ложится к
/// нижнему краю **окна**: вне карточки, на затемнение, и на окне браузера
/// 1920×937 пересекает подвал карточки — ровно кнопку «Оплатить» (снимок
/// стенда до правки: полоса 881–929 по вертикали, кнопка 849–897).
///
/// Сама полоса под `flutter test` рисуется **поверх** карточки, а не под
/// ней: проверка попаданием в её центр отдаёт её текст. «Затемнена
/// барьером» в браузере этим стендом не воспроизвелась — названо здесь, а не
/// выдано за воспроизведённое.
///
/// # Что проба утверждает
///
/// Для **трёх** источников отказа, каждый своим путём к `ScaffoldMessenger`:
///
/// 1. отказ кассы в `PaymentState.error` — слушатель в `_PaymentScreenState`,
///    контекст **над** раскладкой;
/// 2. отказ платёжного терминала — `_handleCompleteInner`, тот же контекст;
/// 3. отказ вида оплаты — `PaymentTypeSelector`, свой контекст **внутри**
///    раскладки.
///
/// утверждения одни и те же, и первые два не зависят ни от одного ключа,
/// заведённого правкой: полоса не перекрывает «Оплатить» и сверху по
/// попаданию; затем — что она целиком в карточке.
///
/// Обратная сторона: сообщение **об успехе** обязано пережить уход с экрана
/// оплаты — оно показывается перед `pop` и читается уже на экране продажи.
/// Отказ, унесённый в карточку, не имеет права унести с собой и его.
library;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import 'package:telepos/presentation/common/utils/error_localizer.dart';
import 'package:telepos/presentation/controllers/payment/payment_controller.dart';
import 'package:telepos/presentation/controllers/sale/sale_controller.dart';
import 'package:telepos/presentation/screens/payment/payment_screen.dart';
import 'package:telepos/presentation/screens/sale/sale_screen.dart';

import '../../../helpers/mock_providers.dart';

Decimal _d(String v) => Decimal.parse(v);

class _Payment extends MockPaymentNotifier {
  _Payment(super.initialState, {this.charge});

  /// Ответ платёжного терминала; `null` — терминал не привязан.
  final CardCharge? charge;

  void refuse(String errorKey) => state = state.copyWith(error: errorKey);

  @override
  Future<CardCharge> chargeCardViaTerminal(Decimal amount) async {
    chargedAmounts.add(amount);
    return charge ?? const CardCharge(outcome: CardChargeOutcome.notConfigured);
  }
}

const _complete = Key('payment_complete');
const _card = Key('payment_card');

void main() {
  late SharedPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    if (!isLoggerReady) installLogger(Talker());
  });

  setUp(() async => GetIt.I.reset());
  tearDown(() async => GetIt.I.reset());

  void view(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
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

  /// Экран продажи, поверх него — оплата, тем же `push`, каким её открывает
  /// `SaleScreen._handlePay`. Окно — браузер из живой приёмки.
  Future<void> openPayment(
    WidgetTester tester,
    _Payment payment, {
    Size size = const Size(1920, 937),
  }) async {
    view(tester, size);
    final router = GoRouter(
      initialLocation: '/sale',
      routes: [
        GoRoute(
          path: '/sale',
          builder: (context, state) =>
              const Scaffold(body: SaleScreen(shiftClose: ShiftCloseAtTill())),
        ),
        GoRoute(
          path: '/payment',
          builder: (context, state) => const PaymentScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          saleControllerProvider.overrideWith(MockSaleNotifier.new),
          paymentControllerProvider.overrideWith(() => payment),
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
    router.push('/payment');
    await tester.pumpAndSettle();
    expect(find.byType(PaymentScreen), findsOneWidget, reason: 'предпосылка');
  }

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(PaymentScreen)))!;

  /// «Оплатить» — тем же синхронным зовом обработчика, что и
  /// `payment_acquiring_call_test.dart` (там же измерено, почему не `tap`).
  Future<void> pressPay(WidgetTester tester) async {
    final onPressed = tester
        .widget<ElevatedButton>(find.byKey(_complete))
        .onPressed;
    expect(onPressed, isNotNull, reason: 'предпосылка: кнопка живая');
    onPressed!();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
  }

  /// Три утверждения о том, **где** полоса с текстом [text].
  void expectRefusalInsideCard(WidgetTester tester, Finder text) {
    expect(text, findsOneWidget, reason: 'предпосылка: отказ показан');
    final snack = find.ancestor(of: text, matching: find.byType(SnackBar));
    expect(snack, findsOneWidget, reason: 'предпосылка: отказ — полосой');
    final snackRect = tester.getRect(snack);
    final payRect = tester.getRect(find.byKey(_complete));

    // 1. Кнопка, которой кассир повторит оплату, не под отказом.
    expect(
      snackRect.overlaps(payRect),
      isFalse,
      reason:
          'полоса отказа $snackRect легла на «Оплатить» $payRect: она '
          'показана у нижнего края окна, а не в карточке оплаты',
    );

    // 2. Сверху по попаданию: центр полосы отдаёт саму полосу, а не то, что
    // над ней (карточку, барьер, другой маршрут).
    final center = snackRect.center;
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(result, center, tester.view.viewId);
    final snackBox = tester.renderObject(snack);
    final topBox = result.path
        .map((entry) => entry.target)
        .whereType<RenderObject>()
        .first;
    var inSnack = false;
    for (RenderObject? r = topBox; r != null; r = r.parent) {
      if (identical(r, snackBox)) {
        inSnack = true;
        break;
      }
    }
    expect(
      inSnack,
      isTrue,
      reason: 'в центре полосы сверху лежит не она, а $topBox',
    );

    // 3. Целиком в карточке оплаты и её потомок в дереве.
    final card = find.byKey(_card);
    expect(card, findsOneWidget, reason: 'карточка оплаты не найдена');
    final cardRect = tester.getRect(card);
    expect(
      cardRect.contains(snackRect.topLeft) &&
          cardRect.contains(snackRect.bottomRight - const Offset(0.01, 0.01)),
      isTrue,
      reason: 'полоса $snackRect выходит за карточку $cardRect',
    );
    expect(
      find.ancestor(of: snack, matching: card),
      findsOneWidget,
      reason: 'полоса показана не в карточке оплаты',
    );
  }

  group('настольная раскладка, окно браузера 1920×937', () {
    testWidgets('отказ кассы (рассрочка без покупателя) — в карточке', (
      tester,
    ) async {
      final payment = _Payment(PaymentState(totalAmount: _d('1150')));
      await openPayment(tester, payment);
      final expected = ErrorLocalizer.localize(
        tester.element(find.byType(PaymentScreen)),
        'error.debt_customer_required',
      );

      payment.refuse('error.debt_customer_required');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      expectRefusalInsideCard(tester, find.text(expected));
    });

    testWidgets('отказ платёжного терминала — в карточке', (tester) async {
      final payment = _Payment(
        PaymentState(totalAmount: _d('1150'), paymentType: PaymentType.card),
        charge: const CardCharge(outcome: CardChargeOutcome.declined),
      )..completes = false;
      await openPayment(tester, payment);

      await pressPay(tester);
      expect(payment.chargedAmounts, [_d('1150')], reason: 'предпосылка');

      expectRefusalInsideCard(
        tester,
        find.text(l10n(tester).kaspiNoConnection),
      );
    });

    testWidgets('отказ вида оплаты на этом рабочем месте — в карточке', (
      tester,
    ) async {
      final payment = _Payment(
        PaymentState(
          totalAmount: _d('1150'),
          allowedPaymentTypes: const {PaymentType.card},
        ),
      );
      await openPayment(tester, payment);

      await tester.tap(find.byKey(const Key('payment_type_button_cash')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      expectRefusalInsideCard(
        tester,
        find.byKey(const Key('payment_type_denied_reason')),
      );
    });

    testWidgets('успех оплаты переживает уход с экрана и виден на продаже', (
      tester,
    ) async {
      final payment = _Payment(
        PaymentState(
          totalAmount: _d('1150'),
          paymentType: PaymentType.cash,
          cashReceived: _d('1150'),
        ),
      )..completes = true;
      await openPayment(tester, payment);
      final success = l10n(tester).paymentSuccessMessage;

      await pressPay(tester);
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      expect(
        find.byType(PaymentScreen),
        findsNothing,
        reason: 'предпосылка: оплата прошла и экран закрылся',
      );
      expect(
        find.text(success),
        findsOneWidget,
        reason:
            'сообщение об успехе показывается перед уходом с экрана — оно '
            'обязано жить в корневом ScaffoldMessenger, а не в карточке, '
            'которая уходит вместе с маршрутом',
      );
    });
  });

  testWidgets('планшетная раскладка: отказ по-прежнему показан', (
    tester,
  ) async {
    final payment = _Payment(PaymentState(totalAmount: _d('1150')));
    await openPayment(tester, payment, size: const Size(800, 1000));
    final expected = ErrorLocalizer.localize(
      tester.element(find.byType(PaymentScreen)),
      'error.debt_customer_required',
    );

    payment.refuse('error.debt_customer_required');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    final text = find.text(expected);
    expect(text, findsOneWidget);
    expect(
      tester
          .getRect(find.ancestor(of: text, matching: find.byType(SnackBar)))
          .overlaps(tester.getRect(find.byKey(_complete))),
      isFalse,
      reason: 'на планшете подвал — bottomNavigationBar, полоса над ним',
    );
  });
}
