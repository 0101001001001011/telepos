library;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/locale/app_locale.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/fiscal/fiscal_models.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';
import 'package:telepos/domain/usecases/fiscal/fiscal_service.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/shift/shift_controller.dart';
import 'package:telepos/presentation/screens/settings/fiscal_correction_screen.dart';
import 'package:telepos/presentation/screens/shift/widgets/shift_actions.dart';

import '../support/harness.dart';

class _SpyFiscalService implements FiscalService {
  int xReportCalls = 0;
  int correctionCalls = 0;
  FiscalCorrectionRequest? lastCorrection;

  FiscalReportResult xReportResult = const FiscalReportResult(
    result: FiscalResult(success: true, fiscalSign: 'X-001'),
    shiftNumber: 7,
    documentCount: 3,
  );
  FiscalResult correctionResult = const FiscalResult(
    success: true,
    fiscalSign: 'CORR-001',
  );

  bool enabled = true;

  @override
  Future<FiscalReportResult> xReport() async {
    xReportCalls++;
    return xReportResult;
  }

  @override
  Future<FiscalResult> correction(FiscalCorrectionRequest req) async {
    correctionCalls++;
    lastCorrection = req;
    return correctionResult;
  }

  @override
  Future<FiscalSettings> currentSettings() async => FiscalSettings.disabled();
  @override
  Future<bool> isEnabled() async => enabled;
  @override
  Future<FiscalResult> fiscalizeSale({
    required int saleReceiptNo,
    required int salePosId,
    required Decimal amount,
    required Decimal cashAmount,
    required Decimal cardAmount,
    String? customerBin,
  }) async => FiscalResult.queued();
  @override
  Future<FiscalResult> fiscalizeRefund({
    required int refundLocalId,
    required int? originalSaleReceiptNo,
    required Decimal amount,
  }) async => FiscalResult.queued();
  @override
  Future<FiscalResult> fiscalizePurchase(FiscalSaleRequest req) async =>
      FiscalResult.queued();
  @override
  Future<FiscalResult> fiscalizePurchaseReturn(FiscalRefundRequest req) async =>
      FiscalResult.queued();
  @override
  Future<FiscalResult> moneyIn({
    required Decimal amount,
    String? comment,
    String? idempotencyKey,
  }) async => FiscalResult.queued();
  @override
  Future<FiscalResult> moneyOut({
    required Decimal amount,
    String? comment,
    String? idempotencyKey,
  }) async => FiscalResult.queued();
  @override
  Future<FiscalResult> openShift() async => FiscalResult.queued();
  @override
  Future<FiscalReportResult> closeShift() async => const FiscalReportResult(
    result: FiscalResult(success: true, queued: true),
  );
  @override
  Future<FiscalStatus> status() async => FiscalStatus.notConfigured();
}

void main() {
  final h = E2eHarness();
  late _SpyFiscalService spy;
  late ProviderContainer container;

  setUpAll(() async {
    await h.setUp();
    GetIt.I.registerSingleton<AppDatabase>(h.db);
  });
  tearDownAll(() => h.tearDown());

  setUp(() {
    spy = _SpyFiscalService();
    GetIt.I.registerSingleton<FiscalService>(spy);
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  Future<ShiftNotifier> settledNotifier() async {
    final n = container.read(shiftControllerProvider.notifier);
    for (var i = 0; i < 30; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      if (!container.read(shiftControllerProvider).isLoading) break;
    }
    return n;
  }

  Widget wrap(Widget child) => UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
   // Тема приложения, а не умолчание Material: экран берёт цвета
   // ролями (`context.semantic`, `colorScheme`), и под голым
   // `MaterialApp` расширение `AppSemanticColors` не
   // зарегистрировано — обращение к нему падает. Это и есть та
   // причина, по которой такой тест проверял не тот продукт,
   // что уезжает заказчику.
   theme: AppTheme.light,
      locale: const Locale('ru'),
      supportedLocales: AppLocale.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: child),
    ),
  );

  test(
    'runXReport invokes FiscalService.xReport and returns its result',
    () async {
      final notifier = await settledNotifier();
      final outcome = await notifier.runXReport();
      expect(
        spy.xReportCalls,
        1,
        reason: 'controller must call xReport exactly once',
      );
      expect(outcome.fiscal, isNotNull);
      expect(outcome.fiscal!.success, isTrue);
      expect(outcome.fiscal!.shiftNumber, 7);
      expect(outcome.fiscal!.result.fiscalSign, 'X-001');
    },
  );

  test(
    'runXReport is offline-safe: queued result returns without blocking',
    () async {
      spy.xReportResult = FiscalReportResult.failure(
        'X-отчёт не поддерживается оператором: none',
        code: FiscalErrorCode.unsupported,
      );
      final notifier = await settledNotifier();
      final outcome = await notifier.runXReport();
      expect(spy.xReportCalls, 1);
      expect(outcome.fiscal, isNotNull);
      expect(outcome.fiscal!.success, isFalse);
      expect(
        outcome.fiscal!.result.errorCode,
        FiscalErrorCode.unsupported,
        reason: 'unsupported case is surfaced honestly, not swallowed',
      );
    },
  );

  test(
    'runCorrection invokes FiscalService.correction with the request',
    () async {
      final notifier = await settledNotifier();
      final req = FiscalCorrectionRequest(
        idempotencyKey: 'corr-test-1',
        positions: [
          FiscalPosition(
            name: 'Коррекция',
            quantity: Decimal.one,
            unitPrice: d('1500'),
            lineTotal: d('1500'),
            tax: FiscalTax.none(),
          ),
        ],
        payments: [
          FiscalPayment(kind: FiscalPaymentKind.cash, amount: d('1500')),
        ],
        comment: 'ручная коррекция',
      );
      final result = await notifier.runCorrection(req);
      expect(spy.correctionCalls, 1);
      expect(result.success, isTrue);
      expect(spy.lastCorrection?.idempotencyKey, 'corr-test-1');
      expect(spy.lastCorrection?.payments.first.amount, d('1500'));
    },
  );

  test(
    'runCorrection surfaces the unsupported case honestly (offline-safe)',
    () async {
      spy.correctionResult = FiscalResult.unsupported('correction');
      final notifier = await settledNotifier();
      final req = FiscalCorrectionRequest(
        idempotencyKey: 'corr-unsupported',
        positions: const [],
        payments: const [],
      );
      final result = await notifier.runCorrection(req);
      expect(spy.correctionCalls, 1);
      expect(result.success, isFalse);
      expect(result.errorCode, FiscalErrorCode.unsupported);
    },
  );

  testWidgets('tapping the X-отчёт button invokes FiscalService.xReport', (
    tester,
  ) async {
    final openState = ShiftState(isOpen: true);
    await tester.pumpWidget(wrap(ShiftActions(state: openState)));
    await tester.pumpAndSettle();

    final btn = find.byKey(const ValueKey('shift-xreport-button'));
    expect(
      btn,
      findsOneWidget,
      reason: 'X-отчёт button must be present when open',
    );

    await tester.tap(btn);
    await tester.pumpAndSettle();

    expect(
      spy.xReportCalls,
      1,
      reason: 'tapping X-отчёт calls FiscalService.xReport',
    );
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('correction screen submit invokes FiscalService.correction', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const FiscalCorrectionScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('correction-reason')),
      'ошибка кассира',
    );
    await tester.enterText(
      find.byKey(const ValueKey('correction-amount')),
      '2500',
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('correction-submit')));
    await tester.pumpAndSettle();

    expect(
      spy.correctionCalls,
      1,
      reason: 'submit calls FiscalService.correction exactly once',
    );
    expect(
      spy.lastCorrection?.payments.first.amount,
      d('2500'),
      reason: 'collected amount flows into the correction request',
    );
    expect(spy.lastCorrection?.comment, 'ошибка кассира');
    expect(
      find.byType(SnackBar),
      findsOneWidget,
      reason: 'result surfaced honestly to the user',
    );
  });

  testWidgets('correction screen honestly shows the unsupported result', (
    tester,
  ) async {
    spy.correctionResult = FiscalResult.unsupported('correction');
    await tester.pumpWidget(wrap(const FiscalCorrectionScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('correction-amount')),
      '100',
    );
    await tester.tap(find.byKey(const ValueKey('correction-submit')));
    await tester.pumpAndSettle();

    expect(spy.correctionCalls, 1);
    expect(find.byKey(const ValueKey('correction-result')), findsOneWidget);
  });
}
