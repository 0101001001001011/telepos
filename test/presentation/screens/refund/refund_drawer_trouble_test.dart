import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';

import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/logging/app_talker.dart' as app_log;
import 'package:telepos/domain/refund/refund_service.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/payment_service.dart'
    show CompletionTrouble, CompletionTroubleKind;
import 'package:telepos/domain/terminal/terminal.dart';
import 'package:telepos/domain/terminal/terminal_identity.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/refund/refund_screen.dart';

import '../../auth/support/fakes.dart';

/// Беда ящика после возврата доходит до кассира — **через настоящее нажатие**.
///
/// Приёмка 2026-09-17: касса открывает ящик на возврате с наличной частью и
/// помнит беду, если он не открылся (`RefundService.hardwareTroubles`), но
/// экран её не спрашивал — кассир видел «Возврат проведён» и не знал, что
/// ящик придётся открывать ключом.
class _DrawerFailingRefunds implements RefundService {
  _DrawerFailingRefunds({required this.troubles});

  final List<CompletionTrouble> troubles;
  final asked = <(int, int)>[];

  @override
  Stream<RefundView> watch(int terminalId) => Stream.value(
    RefundView(
      posId: 1,
      terminalId: terminalId,
      version: 3,
      draftNo: 1,
      saleReceiptNo: 12345,
      salePosId: 1,
      lines: [
        RefundLine(
          id: '11',
          productId: 42,
          name: 'Молоко',
          quantity: Decimal.fromInt(1),
          price: Decimal.parse('450'),
          maxQuantity: Decimal.fromInt(1),
        ),
      ],
    ),
  );

  @override
  Future<RefundOutcome> complete(int terminalId, CartCommandMeta meta) async =>
      RefundOutcome(
        refundLocalId: 77,
        amount: Decimal.parse('450'),
        lineCount: 1,
        paymentCount: 1,
        saleReceiptNo: 12345,
        salePosId: 1,
      );

  @override
  Future<List<CompletionTrouble>> hardwareTroubles(
    int terminalId,
    int refundLocalId,
  ) async {
    asked.add((terminalId, refundLocalId));
    return troubles;
  }

  @override
  Future<RefundView> loadReceipt(
    int terminalId,
    int receiptNo,
    int posId,
    CartCommandMeta meta,
  ) => throw UnimplementedError();

  @override
  Future<RefundView> startWithoutReceipt(
    int terminalId,
    CartCommandMeta meta,
  ) => throw UnimplementedError();

  @override
  Future<RefundView> addProduct(
    int terminalId,
    int productId,
    Decimal quantity,
    CartCommandMeta meta,
  ) => throw UnimplementedError();

  @override
  Future<RefundView> setLineQuantity(
    int terminalId,
    String lineId,
    Decimal quantity,
    CartCommandMeta meta,
  ) => throw UnimplementedError();

  @override
  Future<void> abandon(int terminalId) async {}
}

Widget _app() => ProviderScope(
  child: MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('ru'),
    supportedLocales: const [Locale('ru'), Locale('en')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: const Scaffold(body: RefundScreen()),
  ),
);

void main() {
  setUp(() {
    app_log.installLogger(Talker());
    GetIt.I
      ..registerSingleton<TerminalIdentity>(FakeTerminalIdentity())
      ..registerSingleton<TerminalRepository>(
        FakeTerminalRepository(
          self: () async => const Terminal(
            id: 1,
            name: 'Планшет',
            pointMode: PointMode.cashier,
          ),
        ),
      );
  });

  tearDown(() async => GetIt.I.reset());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Future<void> refund(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await settle(tester);
    await tester.tap(find.text('ВОЗВРАТ').last);
    await settle(tester);
    await tester.tap(find.text('Подтвердить'));
    await settle(tester);
    // Полоса беды встаёт за полосой успеха — как у оплаты. Промотать, пока
    // успех не погаснет.
    await tester.pump(const Duration(seconds: 6));
    await settle(tester);
  }

  testWidgets('ящик не открылся — кассир узнаёт об этом после возврата', (
    tester,
  ) async {
    final refunds = _DrawerFailingRefunds(
      troubles: const [
        CompletionTrouble(
          kind: CompletionTroubleKind.drawer,
          receiptNo: 77,
          message: 'ящик не ответил',
        ),
      ],
    );
    GetIt.I.registerSingleton<RefundService>(refunds);

    await refund(tester);

    expect(refunds.asked, [
      (1, 77),
    ], reason: 'беды спрашиваются тем местом и тем возвратом, что провели');
    expect(
      find.text('Денежный ящик не открылся'),
      findsOneWidget,
      reason: 'деньги выдаются из ящика — кассир обязан знать, что он закрыт',
    );
  });

  testWidgets('бед нет — предупреждения нет', (tester) async {
    GetIt.I.registerSingleton<RefundService>(
      _DrawerFailingRefunds(troubles: const []),
    );

    await refund(tester);

    expect(find.text('Денежный ящик не открылся'), findsNothing);
  });
}
