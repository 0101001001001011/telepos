/// Окно закрытия смены называет **ждущие документы** — дыра 1 ревизии
/// 2026-09-19, половина, доезжающая до кассира.
///
/// # Почему это отдельная полоса, а не та же
///
/// Нефискализованный чек и ждущий документ — разные положения. Первому
/// документа не будет сам собой (нетранзиентный отказ или просроченное окно
/// 72 ч), и его лечит человек. Второй уедет сам — но Z-отчёт его дожидается
/// (`ShiftServiceImpl.onCloseShift`), и если связь не вернётся, отчёт не
/// уйдёт вовсе. Кассиру это говорится **до** нажатия, пока он ещё может
/// подождать сети.
///
/// # Что здесь проверяется
///
/// Не «метод позвали», а **текст, который читает кассир**, и то, что две
/// полосы не слиплись в одну: каждая появляется по своему поводу и молчит,
/// когда повода нет.
///
/// # Чего это НЕ доказывает
///
/// Что Z-отчёт действительно дождался документов — это доказывают пробы
/// `test/data/services/shift_close_waits_for_fiscal_queue_test.dart`, над
/// настоящей очередью и настоящим планировщиком.
library;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/domain/services/shift_service.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/shift/widgets/shift_actions.dart';

import '../../../fixtures/test_states.dart';
import '../../../support/till_currency.dart';

void main() {
  tearDown(() async => GetIt.I.reset());

  Widget wrap() => ProviderScope(
    child: MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ru'), Locale('en')],
      locale: const Locale('ru'),
      home: Scaffold(body: ShiftActions(state: TestShiftStates.open)),
    ),
  );

  Future<AppLocalizations> openCloseDialog(
    WidgetTester tester,
    UnfiscalizedAtClose summary,
  ) async {
    GetIt.I.allowReassignment = true;
    GetIt.I.registerSingleton<ShiftService>(_StubShifts(summary));
    // Окно закрытия называет сумму — значит нужна валюта кассы. Служба
    // НАСТОЯЩАЯ: среда собирает тот же граф, что и касса.
    registerTillCurrency();

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(ShiftActions)),
    )!;
    await tester.tap(find.text(l10n.shiftClose));
    await tester.pumpAndSettle();
    return l10n;
  }

  testWidgets('ждущие документы названы числом и номерами чеков', (
    tester,
  ) async {
    final l10n = await openCloseDialog(
      tester,
      const UnfiscalizedAtClose(
        count: 0,
        receiptNumbers: [],
        onTheWay: 2,
        onTheWayReceipts: [41, 42],
      ),
    );

    expect(
      find.byKey(const ValueKey('shift-close-on-the-way')),
      findsOneWidget,
    );
    expect(
      find.text(l10n.documentsOnTheWayAtShiftClose(2, '41, 42')),
      findsOneWidget,
      reason:
          'фраза словаря, а не собранная экраном строка: кассир с казахским '
          'интерфейсом читает свой язык',
    );
    expect(
      find.byKey(const ValueKey('shift-close-unfiscalized')),
      findsNothing,
      reason: 'беды нет — полоса беды молчит, иначе она обесценится',
    );
  });

  testWidgets('нефискализованные чеки названы своей полосой, отдельно', (
    tester,
  ) async {
    final l10n = await openCloseDialog(
      tester,
      const UnfiscalizedAtClose(count: 1, receiptNumbers: [7]),
    );

    expect(
      find.byKey(const ValueKey('shift-close-unfiscalized')),
      findsOneWidget,
    );
    expect(find.text(l10n.unfiscalizedAtShiftClose(1, '7')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('shift-close-on-the-way')),
      findsNothing,
      reason: 'ждущих нет — вторая полоса не появляется',
    );
  });

  testWidgets('ни беды, ни ожидания — окно закрытия молчит', (tester) async {
    await openCloseDialog(tester, UnfiscalizedAtClose.empty);

    expect(find.byKey(const ValueKey('shift-close-on-the-way')), findsNothing);
    expect(
      find.byKey(const ValueKey('shift-close-unfiscalized')),
      findsNothing,
    );
  });
}

/// Служба смены, от которой окну нужна ровно одна сводка.
class _StubShifts implements ShiftService {
  _StubShifts(this.summary);

  final UnfiscalizedAtClose summary;

  @override
  Future<UnfiscalizedAtClose> unfiscalizedAtClose() async => summary;

  @override
  Future<void> onOpenShift(int userId, {Decimal? openingCash}) async {}

  @override
  Future<void> onCloseShift(Decimal cashInPos) async {}

  @override
  Future<dynamic> getOpenedShift() async => null;

  @override
  Future<bool> isShiftOverAge({Duration maxAge = const Duration(hours: 24)}) =>
      Future.value(false);

  /// Долг по Z окну закрытия не нужен вовсе: его гасит **открытие**
  /// следующей смены. Бросок вместо пустого ответа — чтобы обращение
  /// сюда было видно, а не принято за «долга нет».
  @override
  Future<void> settleOwedZReport() async =>
      throw StateError('окно закрытия долг по Z не гасит');

  @override
  Future<OwedZReport?> owedZReport() async =>
      throw StateError('окно закрытия долг по Z не читает');
}
