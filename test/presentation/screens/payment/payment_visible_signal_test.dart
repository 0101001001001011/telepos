/// Кассир **видит** беду железа и нефискальный чек — задача 16, круг
/// правки 2.
///
/// # Почему эта проба обязана существовать
///
/// Круг правки 1 вернул в экран оба сигнала — оранжевый снек об отказе
/// печати и предупреждение о нефискальном чеке — и **не покрыл их ничем**.
/// Измерено разбором: снять из `payment_screen.dart` весь видимый сигнал
/// (и снек `paymentNotFiscalized`, и вызов `_reportHardwareTroubles`)
/// оставляло `test/presentation/ test/web/ test/backend/
/// test/architecture/` зелёными — 427 проб, ни одна не смотрела на
/// увиденное. `PaymentNotifier.lastOutcome` не читала ни одна проба.
///
/// Поэтому здесь экран **монтируется**, кнопка **нажимается**, и
/// утверждение делается о тексте на снеке, а не о состоянии контроллера.
library;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:talker/talker.dart';

import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/logging/app_talker.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/payment/gift_certificate.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/payment/payment_controller.dart';
import 'package:telepos/presentation/controllers/sale/sale_controller.dart';
import 'package:telepos/presentation/screens/payment/payment_screen.dart';

import '../../../helpers/mock_providers.dart';

void main() {
  Decimal d(String v) => Decimal.parse(v);

  late _SignallingPayments payments;

  /// Экран поверх настоящего `GoRouter`: `_onPaymentRecorded` уходит с
  /// экрана через `context.canPop()`/`context.go`, и без маршрутизатора
  /// проба падала бы на уходе, а не на том, что проверяет.
  Future<void> mount(
    WidgetTester tester, {
    required SaleFiscalization fiscal,
    required List<CompletionTrouble> troubles,
  }) async {
    if (!isLoggerReady) installLogger(Talker());

    // Переполнение раскладки — не предмет этой пробы, и оно приходит не
    // только в момент нажатия: снеки прокручиваются ещё несколько
    // секунд. Тот же приём, что в `payment_screen_test.dart`, но на всю
    // пробу.
    final onError = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.exceptionAsString();
      if (text.contains('overflowed') || text.contains('A RenderFlex')) return;
      if (onError != null) onError(details);
    };
    addTearDown(() => FlutterError.onError = onError);

    payments = _SignallingPayments(fiscal: fiscal, troubles: troubles);
    if (GetIt.I.isRegistered<PaymentService>()) {
      GetIt.I.unregister<PaymentService>();
    }
    GetIt.I.registerSingleton<PaymentService>(payments);
    addTearDown(() {
      if (GetIt.I.isRegistered<PaymentService>()) {
        GetIt.I.unregister<PaymentService>();
      }
    });

    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final router = GoRouter(
      initialLocation: '/payment',
      routes: [
        GoRoute(
          path: '/payment',
          builder: (_, _) => PaymentScreen(amount: d('1000')),
        ),
        GoRoute(
          path: '/sale',
          builder: (_, _) => const Scaffold(body: Text('экран продажи')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          saleControllerProvider.overrideWith(MockSaleNotifier.new),
          paymentAccountsProvider.overrideWith((ref) async => const []),
        ],
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
    await tester.pump();
  }

  /// Довести экран до оплаты **его же путём**: набрать наличные и нажать
  /// «ОПЛАТИТЬ». Через контроллер напрямую проба доказывала бы, что
  /// контроллер зовут, а не что кассир видит.
  Future<void> payCash(WidgetTester tester) async {
    final context = tester.element(find.byType(PaymentScreen));
    final container = ProviderScope.containerOf(context);
    final notifier = container.read(paymentControllerProvider.notifier);
    notifier.initialize(d('1000'));
    notifier.setPaymentType(PaymentType.cash);
    notifier.setCashReceived(d('1000'));
    await tester.pump();

    expect(
      container.read(paymentControllerProvider).canComplete,
      isTrue,
      reason: 'страховка от вырождения: кнопка обязана быть живой',
    );

    await tester.tap(find.text('ОПЛАТИТЬ'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  /// Дождаться снека с текстом [text].
  ///
  /// `ScaffoldMessenger` показывает снеки **по одному**: предупреждение
  /// стоит в очереди за «Оплата успешна» и появится только когда тот
  /// уйдёт. Проба и ждёт очередь, а не гадает про задержку.
  Future<void> expectSnack(WidgetTester tester, String text) async {
    for (var i = 0; i < 40; i++) {
      if (find.text(text).evaluate().isNotEmpty) return;
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.text(text), findsOneWidget);
  }

  /// Ни один снек за всю очередь не сказал [text].
  Future<void> expectNoSnack(WidgetTester tester, Pattern text) async {
    for (var i = 0; i < 40; i++) {
      expect(find.textContaining(text), findsNothing);
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  testWidgets('нефискальный чек кассир видит словом, а не в журнале', (
    tester,
  ) async {
    await mount(
      tester,
      fiscal: const SaleFiscalization(
        FiscalState.failed,
        message: 'ОФД недоступен',
      ),
      troubles: const [],
    );

    await payCash(tester);

    await expectSnack(tester, 'Оплата успешна');
    await expectSnack(tester, 'Чек не фискализован — оплата проведена');
  });

  testWidgets('отказ печати кассир видит словом', (tester) async {
    await mount(
      tester,
      fiscal: SaleFiscalization.notRequired,
      troubles: const [
        CompletionTrouble(
          kind: CompletionTroubleKind.print,
          receiptNo: 1,
          message: 'бумаги нет',
        ),
      ],
    );

    await payCash(tester);

    await expectSnack(tester, 'Ошибка печати: бумаги нет');
    expect(payments.troublesAsked, [(7, 1)], reason: 'спрошено владельцем');
  });

  testWidgets('отказ ящика не подписывается ошибкой печати', (tester) async {
    // Круг правки 2: первая редакция подписывала любую беду «Ошибкой
    // печати», и отказ ящика читался как «Ошибка печати: денежный ящик не
    // открылся» — сообщение, которое само себе противоречит.
    await mount(
      tester,
      fiscal: SaleFiscalization.notRequired,
      troubles: const [
        CompletionTrouble(
          kind: CompletionTroubleKind.drawer,
          receiptNo: 1,
          message: 'порт занят',
        ),
      ],
    );

    await payCash(tester);

    await expectSnack(tester, 'Денежный ящик не открылся: порт занят');
    expect(find.textContaining('Ошибка печати'), findsNothing);
  });

  testWidgets('пустая подпись не даёт двоеточия в пустоту', (tester) async {
    // Касса отказала ящиком чисто, без причины. Здесь слой данных слал
    // дословный повтор заголовка ПО-РУССКИ, и на английской кассе выходило
    // «Cash drawer did not open: денежный ящик не открылся». Поймано
    // пробным проходом главы 7 (2026-09-22).
    //
    // Пустая подпись означает «сверх заголовка сказать нечего»: заголовок
    // показывается один, и двоеточие в пустоту за ним не тянется.
    await mount(
      tester,
      fiscal: SaleFiscalization.notRequired,
      troubles: const [
        CompletionTrouble(
          kind: CompletionTroubleKind.drawer,
          receiptNo: 1,
          message: '',
        ),
      ],
    );

    await payCash(tester);

    await expectSnack(tester, 'Денежный ящик не открылся');
    expect(
      find.textContaining('Денежный ящик не открылся:'),
      findsNothing,
      reason: 'двоеточие тянется за собой пустоту',
    );
  });

  /// Задача 5: три «документа нет» — три разных сигнала кассиру.
  ///
  /// Проба стоит парой: одна требует красной полосы, другая требует её
  /// **отсутствия**. Поодиночке любая из них зеленеет вырождением —
  /// «показывать всегда» проходит первую, «не показывать никогда»
  /// проходит вторую.
  testWidgets('сборка без узла фискализации — красная полоса, каждый раз', (
    tester,
  ) async {
    await mount(
      tester,
      fiscal: SaleFiscalization.fiscalModuleAbsent,
      troubles: const [],
    );

    await payCash(tester);

    await expectSnack(tester, 'Оплата успешна');
    await expectSnack(
      tester,
      'Модуль фискализации недоступен — чеки не фискализуются',
    );

    // Красная, а не оранжевая: это сломанная сборка, а не предупреждение
    // о чеке. Цвет — часть сигнала, и проба на один текст его не ловит.
    //
    // Сверяется с **ролью темы**, а не с константой `AppColors.error`:
    // константа одинакова в светлой и тёмной, и полоса на ней вышла бы
    // нечитаемой ночью. Это поймал сторож `no_baked_theme_colors_test`
    // — уже после того, как эта проба зеленела на константе.
    // Тема читается из контекста **самой полосы**, а не экрана оплаты:
    // к этому моменту `PaymentScreen` уже ушёл (`context.pop`), и
    // `find.byType(PaymentScreen)` бросает «No element».
    final scheme = Theme.of(
      tester.element(find.byType(SnackBar).first),
    ).colorScheme;
    final bars = tester.widgetList<SnackBar>(find.byType(SnackBar));
    final red = bars.where((b) => b.backgroundColor == scheme.error);
    expect(red, isNotEmpty, reason: 'полоса обязана быть красной по теме');
    expect(
      bars.where((b) => b.backgroundColor == AppColors.warning),
      isEmpty,
      reason: 'сломанная сборка — не оранжевое предупреждение',
    );
  });

  testWidgets('оператора нет — окна нет: это настройка, а не беда', (
    tester,
  ) async {
    // Окно на каждой продаже отучаются замечать за день, и тогда оно
    // перестаёт работать и для настоящих бед. Место этого сигнала —
    // подвал чека (`noFiscalDocumentReason`), а не экран оплаты.
    await mount(
      tester,
      fiscal: SaleFiscalization.operatorAbsent,
      troubles: const [],
    );

    await payCash(tester);

    await expectSnack(tester, 'Оплата успешна');
    await expectNoSnack(tester, 'Модуль фискализации');
    await expectNoSnack(tester, 'Чек не фискализован');
  });

  testWidgets('всё прошло — лишних предупреждений нет', (tester) async {
    // Страховка от вырождения: снек показывается по беде, а не всегда.
    await mount(
      tester,
      fiscal: const SaleFiscalization(FiscalState.done, sign: 'ФП-1'),
      troubles: const [],
    );

    await payCash(tester);

    await expectSnack(tester, 'Оплата успешна');
    await expectNoSnack(tester, 'Чек не фискализован');
    await expectNoSnack(tester, 'Ошибка печати');
    await expectNoSnack(tester, 'Денежный ящик');
  });
}

/// Оплата, которая отвечает заданным исходом и заданными бедами.
class _SignallingPayments implements PaymentService {
  @override
  Future<String?> qrUnavailableReason() async => null;

  @override
  Future<Decimal> prepaymentBalance(int customerId) async => Decimal.zero;

  @override
  Future<GiftCertificate> findCertificate(String number, {String? pin}) =>
      throw UnimplementedError('проба про сигнал, а не про сертификат');

  @override
  Future<QrTender> startQr(int t, Decimal a, CartCommandMeta m) =>
      throw UnimplementedError('проба про сигнал, а не про QR');

  @override
  Future<QrTender> pollQr(int t, String k) =>
      throw UnimplementedError('проба про сигнал, а не про QR');

  @override
  Future<QrTender> cancelQr(int t, String k) =>
      throw UnimplementedError('проба про сигнал, а не про QR');

  _SignallingPayments({required this.fiscal, required this.troubles});

  final SaleFiscalization fiscal;
  final List<CompletionTrouble> troubles;

  /// Кто и о каком чеке спрашивал — владение проверяется кассой, и экран
  /// обязан спрашивать тем же именем, каким оплачивал.
  final List<(int, int)> troublesAsked = [];

  @override
  Future<List<PaymentAccount>> accounts() async => const [];

  @override
  Future<bool> sellsInDebt() async => false;

  @override
  Future<LoyaltyCustomer?> findLoyalty(String phone) async => null;

  @override
  Future<Decimal> reserveBonus(int customerId, Decimal amount) async => amount;

  @override
  Future<CardCharge> chargeCard(
    int terminalId,
    Decimal amount,
    CartCommandMeta meta,
  ) async => const CardCharge(outcome: CardChargeOutcome.notConfigured);

  @override
  Future<SaleOutcome> complete(
    int terminalId,
    PaymentRequest request,
    CartCommandMeta meta,
  ) async => SaleOutcome(
    receiptNo: 1,
    posId: 1,
    amount: Decimal.fromInt(1000),
    change: Decimal.zero,
    paid: Decimal.fromInt(1000),
    debt: Decimal.zero,
    fiscal: fiscal,
  );

  @override
  Future<List<CompletionTrouble>> hardwareTroubles(
    int terminalId,
    int receiptNo,
  ) async {
    troublesAsked.add((terminalId, receiptNo));
    return troubles;
  }
}
