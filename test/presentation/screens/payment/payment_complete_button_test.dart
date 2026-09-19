/// Нажатие «Оплатить» доводит оплату до кассы — через **настоящий**
/// обработчик экрана.
///
/// # Почему проба заведена и почему именно такая
///
/// Круг правки 5 задачи 14 поставил признак обработки первой строкой
/// `_handleComplete` (сторож от двойного нажатия), а `processPayment`
/// первой строкой спрашивала `PaymentState.canComplete`, который первой
/// строкой отвечает `false`, когда обработка идёт. **Сторож от второго
/// нажатия отбивал первое:** десктопная касса переставала проводить оплату
/// вовсе — кассир жмёт, и ничего не происходит, бесконечно.
///
/// Дефект прожил круг разбора, и причина названа прямо: **все виджет-пробы
/// задачи 14 зовут `processPayment()` напрямую, минуя `_handleComplete`.**
/// Проба на двойное нажатие — тоже, и она была права по форме (гонка
/// проверяется синхронным зовом обработчика кнопки), но слепа к этому:
/// подделка контроллера возвращала успех, не спрашивая ничьего состояния.
///
/// Поэтому здесь **настоящий** `PaymentNotifier` над подставной кассой, и
/// путь ровно тот, каким идёт кассир: нажатие → `_handleComplete` →
/// `processPayment` → `PaymentService.complete`. Проверяется не состояние
/// экрана, а то, **дошли ли деньги до кассы**.
library;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:talker/talker.dart';
import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/logging/app_talker.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/payment/gift_certificate.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/payment/payment_controller.dart';
import 'package:telepos/presentation/controllers/sale/sale_controller.dart';
import 'package:telepos/presentation/screens/payment/payment_screen.dart';

import 'package:telepos/presentation/controllers/app/app_state_controller.dart';

import '../../../helpers/mock_providers.dart';

void main() {
  Decimal d(String v) => Decimal.parse(v);

  late _RecordingPayments payments;
  late ProviderContainer container;

  setUp(() {
    if (!isLoggerReady) installLogger(Talker());
    payments = _RecordingPayments();
    if (GetIt.I.isRegistered<PaymentService>()) {
      GetIt.I.unregister<PaymentService>();
    }
    GetIt.I.registerSingleton<PaymentService>(payments);
    container = ProviderContainer(
      overrides: [
        saleControllerProvider.overrideWith(MockSaleNotifier.new),
        paymentAccountsProvider.overrideWith(
          (ref) async => const <PaymentAccount>[],
        ),
        // Задача 16: селектор видов оплаты читает право `op.sellDebt` из
        // сеанса (`hasPermissionProvider`). Настоящий `AppStateNotifier`
        // заводит в `build` часы и сторож места — периодические таймеры,
        // которые переживают дерево и роняют пробу «A Timer is still
        // pending». Подделка их не заводит; прав у неё нет, и это верно
        // для этого файла: он про кнопку «Оплатить», а не про долг.
        appStateProvider.overrideWith(MockAppStateNotifier.new),
      ],
    );
    addTearDown(() {
      container.dispose();
      if (GetIt.I.isRegistered<PaymentService>()) {
        GetIt.I.unregister<PaymentService>();
      }
    });
  });

  /// Экран оплаты в настоящем маршрутизаторе: после удачной оплаты он
  /// уходит на продажу, и без маршрутов это падало бы там, где проба уже
  /// доказала своё.
  Future<void> mount(WidgetTester tester, Decimal amount) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => PaymentScreen(amount: amount),
        ),
        GoRoute(
          path: AppRoutes.sale,
          builder: (_, _) => const Scaffold(body: Text('продажа')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('ru')],
          locale: const Locale('ru'),
          routerConfig: router,
        ),
      ),
    );
    // Экран сам зовёт `initialize` отложенным кадром — состояние
    // выставляется **после** него, иначе он затрёт выставленное.
    await tester.pumpAndSettle();
  }

  Future<void> pressPay(WidgetTester tester) async {
    final button = find.byKey(const Key('payment_complete'));
    expect(button, findsOneWidget);
    final onPressed = tester.widget<ElevatedButton>(button).onPressed;
    expect(
      onPressed,
      isNotNull,
      reason: 'кнопка оплаты погашена — нажать нечего',
    );
    onPressed!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('нажатие «Оплатить» доводит наличную оплату до кассы', (
    tester,
  ) async {
    await mount(tester, d('450'));
    final notifier = container.read(paymentControllerProvider.notifier);
    notifier.setPaymentType(PaymentType.cash);
    notifier.setCashReceived(d('1000'));
    await tester.pump();

    await pressPay(tester);

    expect(
      payments.completed,
      hasLength(1),
      reason: 'нажатие не дошло до кассы — оплата не состоялась',
    );
    expect(payments.completed.single.cashReceived, d('1000'));
  });

  testWidgets('нажатие «Оплатить» доводит смешанную оплату до кассы', (
    tester,
  ) async {
    // Второй вид оплаты: та же дорога, но с зовом эквайринга по пути —
    // именно её удлинил круг правки 3, и именно на ней сторож от второго
    // нажатия стоил дороже всего.
    await mount(tester, d('1000'));
    final notifier = container.read(paymentControllerProvider.notifier);
    notifier.setPaymentType(PaymentType.mixed);
    notifier.setCardAmount(d('400'));
    notifier.setCashReceived(d('600'));
    await tester.pump();

    await pressPay(tester);

    expect(payments.charged, [d('400')]);
    expect(payments.completed, hasLength(1));
  });

  testWidgets('два нажатия в одном кадре — одно списание и одна оплата', (
    tester,
  ) async {
    // **Недостающая половина довода про двойное нажатие.** Проба в
    // `payment_acquiring_call_test.dart` ведёт **подделку** контроллера, а
    // значит про связку с настоящим — после того как круг правки развёл
    // признак обработки и достаточность денег — не говорит ничего. Здесь
    // настоящий контроллер и настоящий экран: если сторож `_completing`
    // снять, второе нажатие снова дойдёт и до эквайринга, и до кассы.
    //
    // Нажатия синхронные, в **одном кадре**: `tester.tap` прогоняет
    // очередь микрозадач, и второе нажатие стало бы законной повторной
    // попыткой, а не гонкой (измерено кругом правки 5).
    await mount(tester, d('1000'));
    final notifier = container.read(paymentControllerProvider.notifier);
    notifier.setPaymentType(PaymentType.mixed);
    notifier.setCardAmount(d('400'));
    notifier.setCashReceived(d('600'));
    await tester.pump();

    final button = find.byKey(const Key('payment_complete'));
    final onPressed = tester.widget<ElevatedButton>(button).onPressed;
    expect(onPressed, isNotNull);
    onPressed!();
    onPressed();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(payments.charged, [d('400')], reason: 'карту провели дважды');
    expect(payments.completed, hasLength(1), reason: 'оплатили дважды');
  });

  testWidgets('два зова операции подряд — одна оплата, без экрана', (
    tester,
  ) async {
    // **Сторож операции, а не экрана**, и проверяется он в обход экрана
    // намеренно: экранный признак обработки отбивает второе нажатие
    // раньше, поэтому проба через кнопку про `_completing` не говорит
    // ничего — измерено диверсией (сняли `_completing`, проба через
    // кнопку осталась зелёной).
    //
    // А защищает он настоящего вызывающего: `processPayment` зовут не
    // только с кнопки (сквозные сценарии, будущие вызывающие), и признак
    // экрана им не принадлежит.
    await mount(tester, d('450'));
    final notifier = container.read(paymentControllerProvider.notifier);
    notifier.setPaymentType(PaymentType.cash);
    notifier.setCashReceived(d('1000'));
    await tester.pump();

    final both = await Future.wait([
      notifier.processPayment(),
      notifier.processPayment(),
    ]);

    expect(payments.completed, hasLength(1), reason: 'оплатили дважды');
    expect(both.where((ok) => ok), hasLength(1));
  });

  testWidgets('после неудачи вход в операцию снова открыт', (tester) async {
    // Страховка от вырождения: сторож снимается на **каждом** выходе —
    // иначе одна неудача заперла бы кассу до пересоздания экрана.
    await mount(tester, d('450'));
    final notifier = container.read(paymentControllerProvider.notifier);
    notifier.setPaymentType(PaymentType.cash);
    notifier.setCashReceived(d('1000'));
    await tester.pump();

    payments.failOnce = true;
    expect(await notifier.processPayment(), isFalse);
    expect(await notifier.processPayment(), isTrue);
    expect(payments.completed, hasLength(1));
  });

  testWidgets('денег не хватает — до кассы не доходит', (tester) async {
    // Страховка от вырождения: снят **признак обработки** из входного
    // условия, а не само условие. Недобор наличных обязан остаться
    // недобором.
    await mount(tester, d('450'));
    final notifier = container.read(paymentControllerProvider.notifier);
    notifier.setPaymentType(PaymentType.cash);
    notifier.setCashReceived(d('100'));
    await tester.pump();

    final button = find.byKey(const Key('payment_complete'));
    expect(
      tester.widget<ElevatedButton>(button).onPressed,
      isNull,
      reason: 'кнопка обязана быть погашена, когда денег не хватает',
    );
    expect(payments.completed, isEmpty);
  });
}

/// Касса, которая всё одобряет и всё записывает.
class _RecordingPayments implements PaymentService {
  @override
  Future<String?> qrUnavailableReason() async => null;

  @override
  Future<Decimal> prepaymentBalance(int customerId) async => Decimal.zero;

  @override
  Future<GiftCertificate> findCertificate(String number, {String? pin}) =>
      throw UnimplementedError('проба про кнопку, а не про сертификат');

  @override
  Future<QrTender> startQr(int t, Decimal a, CartCommandMeta m) =>
      throw UnimplementedError('проба про кнопку, а не про QR');

  @override
  Future<QrTender> pollQr(int t, String k) =>
      throw UnimplementedError('проба про кнопку, а не про QR');

  @override
  Future<QrTender> cancelQr(int t, String k) =>
      throw UnimplementedError('проба про кнопку, а не про QR');

  final completed = <PaymentRequest>[];
  final charged = <Decimal>[];

  /// Одна неудача кассы — «фискализация бросила».
  bool failOnce = false;

  @override
  Future<List<PaymentAccount>> accounts() async => const [];

  @override
  Future<bool> sellsInDebt() async => false;

  /// Заведён при слиянии: задача 16 добавила беды железа в контракт
  /// `PaymentService`, эта проба написана до неё. Пустой список — «железо
  /// не жаловалось»; проба утверждает про число вызовов `complete`, а не
  /// про печать.
  @override
  Future<List<CompletionTrouble>> hardwareTroubles(
    int terminalId,
    int receiptNo,
  ) async => const [];

  @override
  Future<LoyaltyCustomer?> findLoyalty(String phone) async => null;

  @override
  Future<Decimal> reserveBonus(int customerId, Decimal amount) async => amount;

  @override
  Future<CardCharge> chargeCard(
    int terminalId,
    Decimal amount,
    CartCommandMeta meta,
  ) async {
    charged.add(amount);
    return CardCharge(
      outcome: CardChargeOutcome.approved,
      amount: amount,
      approvalCode: '123456',
      cardMask: '**** 4242',
      transactionId: 'tx-1',
    );
  }

  @override
  Future<SaleOutcome> complete(
    int terminalId,
    PaymentRequest request,
    CartCommandMeta meta,
  ) async {
    if (failOnce) {
      failOnce = false;
      throw Exception('касса споткнулась');
    }
    completed.add(request);
    return SaleOutcome(
      receiptNo: 1,
      posId: 1,
      amount: Decimal.fromInt(450),
      change: Decimal.fromInt(550),
      paid: Decimal.fromInt(450),
      debt: Decimal.zero,
    );
  }
}
