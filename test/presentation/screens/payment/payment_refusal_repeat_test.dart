/// Отказ кассы виден **на каждое** нажатие, и сразу.
///
/// # Откуда проба
///
/// Живая приёмка 2026-09-17 (стенд 3, сертификат `PS-0002`): кассир жал
/// «Проверить» с неверным ПИНом. Первый отказ появлялся, второй и третий —
/// нет: экран показывает полосу, когда ключ ошибки **сменился**, а
/// одинаковый отказ состояния не менял. Кассир видел кнопку, которая
/// «не работает», хотя касса каждый раз отвечала и считала неудачи.
///
/// Вторая половина — очередь: полоса нового отказа ждала, пока погаснет
/// прежняя, и ответ приходил с опозданием на секунды.
///
/// Путь настоящий: `PaymentNotifier` над подставной кассой, нажатие по
/// кнопке панели, полоса экрана.
library;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:talker/talker.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/logging/app_talker.dart';
import 'package:telepos/domain/payment/gift_certificate.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';
import 'package:telepos/presentation/controllers/payment/payment_controller.dart';
import 'package:telepos/presentation/controllers/sale/sale_controller.dart';
import 'package:telepos/presentation/screens/payment/payment_screen.dart';

import '../../../helpers/mock_providers.dart';

const _pinWrong = 'ПИН сертификата не подошёл';
const _unknown = 'Сертификата с таким номером на этой кассе нет';

void main() {
  late _RefusingPayments payments;
  late ProviderContainer container;

  setUp(() {
    if (!isLoggerReady) installLogger(Talker());
    payments = _RefusingPayments();
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

  Future<void> mount(WidgetTester tester) async {
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
          builder: (_, _) => PaymentScreen(amount: Decimal.fromInt(3200)),
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
    await tester.pumpAndSettle();
  }

  Future<void> present(WidgetTester tester, String number) async {
    final field = find.byKey(const Key('payment_certificate_number'));
    await tester.ensureVisible(field);
    await tester.enterText(field, number);
    await tester.enterText(
      find.byKey(const Key('payment_certificate_pin')),
      '1111',
    );
    await tester.tap(find.byKey(const Key('payment_certificate_present')));
    // Короче, чем живёт полоса: отказ обязан быть виден сразу.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
  }

  Future<void> letBannerExpire(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 12));
    await tester.pumpAndSettle();
  }

  testWidgets('второй одинаковый отказ показан так же, как первый', (
    tester,
  ) async {
    await mount(tester);

    payments.refuseWith = certificatePinWrongCode;
    await present(tester, 'PS-0002');
    expect(find.textContaining(_pinWrong), findsOneWidget);

    await letBannerExpire(tester);
    expect(find.textContaining(_pinWrong), findsNothing);

    await present(tester, 'PS-0002');
    expect(
      find.textContaining(_pinWrong),
      findsOneWidget,
      reason: 'касса отказала второй раз — кассир обязан это видеть',
    );
    expect(payments.asked, 2);
  });

  testWidgets('новый отказ вытесняет висящую полосу, а не ждёт очереди', (
    tester,
  ) async {
    await mount(tester);

    payments.refuseWith = certificatePinWrongCode;
    await present(tester, 'PS-0002');
    expect(find.textContaining(_pinWrong), findsOneWidget);

    payments.refuseWith = certificateUnknownCode;
    await present(tester, 'PS-9999');
    await tester.pump(const Duration(milliseconds: 800));
    expect(
      find.textContaining(_unknown),
      findsOneWidget,
      reason: 'ответ на последнее нажатие виден сразу',
    );
  });
}

class _RefusingPayments implements PaymentService {
  String refuseWith = certificatePinWrongCode;
  int asked = 0;

  @override
  Future<GiftCertificate> findCertificate(String number, {String? pin}) async {
    asked++;
    throw WireRefusal(refuseWith, 'отказ подставной кассы');
  }

  @override
  Future<String?> qrUnavailableReason() async => null;

  @override
  Future<Decimal> prepaymentBalance(int customerId) async => Decimal.zero;

  @override
  Future<QrTender> startQr(int t, Decimal a, CartCommandMeta m) =>
      throw UnimplementedError('проба про отказ сертификата');

  @override
  Future<QrTender> pollQr(int t, String k) =>
      throw UnimplementedError('проба про отказ сертификата');

  @override
  Future<QrTender> cancelQr(int t, String k) =>
      throw UnimplementedError('проба про отказ сертификата');

  @override
  Future<List<PaymentAccount>> accounts() async => const [];

  @override
  Future<bool> sellsInDebt() async => false;

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
  ) => throw UnimplementedError('проба про отказ сертификата');

  @override
  Future<SaleOutcome> complete(
    int terminalId,
    PaymentRequest request,
    CartCommandMeta meta,
  ) => throw UnimplementedError('проба про отказ сертификата');
}
