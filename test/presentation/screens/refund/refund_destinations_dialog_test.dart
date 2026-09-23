/// Кассир видит, **куда уйдут деньги**, до нажатия «Подтвердить» — задача 26.
///
/// Экран ведётся настоящим нажатием «ВОЗВРАТ»; строки приходят снимком
/// кассы (`RefundView.destinations`), и проба утверждает текст **на экране**,
/// а не поле состояния: состояние со строками и диалог без них — ровно тот
/// дефект, который здесь сторожится.
library;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';

import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/logging/app_talker.dart' as app_log;
import 'package:telepos/domain/refund/refund_allocation.dart';
import 'package:telepos/domain/refund/refund_service.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/terminal/terminal.dart';
import 'package:telepos/domain/terminal/terminal_identity.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/refund/refund_screen.dart';

import '../../auth/support/fakes.dart';

class _DraftWithDestinations implements RefundService {
  @override
  Stream<RefundView> watch(int terminalId) => Stream.value(
    RefundView(
      posId: 1,
      terminalId: terminalId,
      version: 3,
      draftNo: 1,
      saleReceiptNo: 5001,
      salePosId: 1,
      lines: [
        RefundLine(
          id: '11',
          productId: 100,
          name: 'Молоко 3.2%',
          quantity: Decimal.fromInt(2),
          price: Decimal.fromInt(500),
          maxQuantity: Decimal.fromInt(2),
        ),
      ],
      destinations: [
        RefundDestination(
          route: RefundRoute.certificate,
          amount: Decimal.fromInt(600),
          kindId: 5,
          kindName: 'Сертификат',
          detail: 'C-600',
        ),
        RefundDestination(
          route: RefundRoute.card,
          amount: Decimal.fromInt(400),
          kindId: 2,
          kindName: 'Карта',
          detail: '440043******1234',
        ),
      ],
    ),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} не нужен этой пробе');
}

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
      )
      ..registerSingleton<RefundService>(_DraftWithDestinations());
  });

  tearDown(() async => GetIt.I.reset());

  testWidgets('диалог подтверждения называет получателей и суммы', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
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
      ),
    );
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    await tester.tap(find.text('ВОЗВРАТ').first);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(find.text('Куда уйдут деньги'), findsOneWidget);
    expect(
      // Получатель «сертификат» с 2026-09-16 всегда значит «будет выпущена
      // новая бумажка»: на ту же деньги не возвращаются никогда (решение 2).
      // Прежняя строка «На сертификат» обещала кассиру не то, что произойдёт.
      find.text(
        'Новым сертификатом (старый остаётся погашенным) · Сертификат · '
        'C-600 — 600',
      ),
      findsOneWidget,
    );
    expect(
      find.text('На карту через терминал · Карта · 440043******1234 — 400'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('refund-destination-drawer')),
      findsNothing,
      reason: 'наличных из ящика в этом возврате нет — и строки нет',
    );
  });
}
