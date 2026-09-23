import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/app/config/background_task_manager.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/shift/shift_controller.dart';
import 'package:telepos/presentation/screens/shift/widgets/shift_actions.dart';

import '../../../fixtures/test_states.dart';

/// **Кассир узнаёт, что Z-отчёта на бумаге ещё нет — из ответа на своё
/// нажатие.**
///
/// До очереди печати `printZReport` возвращала `true` уже после записи в
/// принтер, и снекбар «Z-отчёт распечатан» был правдой. С очередью «принято» —
/// это не «напечатано»: задание ждёт принтера тридцать минут
/// (`PrintSubmission.documentLifetime`), после чего истекает и требует ручного
/// повтора с экрана настроек принтера. Смена при этом ничего не ждёт, и это
/// верно (И30). Неверно было другое: об этом никому не говорили, а экран
/// продолжал сообщать «распечатан» о документе, которого нет.
///
/// Для фискальной отчётности Z-отчёт — документ, а не удобство, поэтому
/// проверяется именно **текст**, который читает кассир, а не тип значения,
/// вернувшегося из контроллера: значение можно поменять и оставить экран
/// говорить прежнее.
void main() {
  setUp(() {
    // Кнопка Z-отчёта защищена дребезгом на статическом поле
    // (`shift_actions.dart`), общим для всех проверок в этом процессе. Без
    // этого второе нажатие в файле молча не сработало бы, а проверка
    // «снекбара нет» прошла бы по неверной причине.
    BackgroundTaskManager.disabledForTests = true;
  });

  tearDown(() {
    BackgroundTaskManager.disabledForTests = false;
  });

  Widget wrap(_StubShiftNotifier notifier) => ProviderScope(
    overrides: [shiftControllerProvider.overrideWith(() => notifier)],
    child: MaterialApp(
      // Тема приложения, а не умолчание Material: экран берёт цвета
      // ролями (`context.semantic`, `colorScheme`), и под голым
      // `MaterialApp` расширение `AppSemanticColors` не
      // зарегистрировано — обращение к нему падает. Это и есть та
      // причина, по которой такой тест проверял не тот продукт,
      // что уезжает заказчику.
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

  Future<AppLocalizations> tapZReport(
    WidgetTester tester,
    ZReportOutcome outcome,
  ) async {
    final notifier = _StubShiftNotifier(outcome);
    await tester.pumpWidget(wrap(notifier));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(ShiftActions)),
    )!;

    await tester.tap(find.text(l10n.shiftPrintZReport));
    await tester.pumpAndSettle();

    expect(
      notifier.calls,
      1,
      reason: 'нажатие не дошло до контроллера — проверять нечего',
    );
    return l10n;
  }

  group('Z-отчёт, принятый очередью, виден кассиру как принятый', () {
    testWidgets('принято в очередь — сказано «принят», а не «распечатан»', (
      tester,
    ) async {
      final l10n = await tapZReport(tester, ZReportOutcome.queued);

      expect(
        find.text(l10n.shiftZReportQueued),
        findsOneWidget,
        reason:
            'смена закрывается без бумажного Z-отчёта молча — это первое, о '
            'чём спросит эксплуатация',
      );
      expect(
        l10n.shiftZReportQueued,
        contains('очередь'),
        reason:
            'сообщение обязано назвать очередь: «отправлен на печать» кассир '
            'прочитает как «напечатан»',
      );
    });

    testWidgets('повторное нажатие — «уже сдан», а не ошибка', (tester) async {
      final l10n = await tapZReport(tester, ZReportOutcome.alreadyQueued);

      expect(find.text(l10n.shiftZReportAlreadyQueued), findsOneWidget);
      expect(
        find.text(l10n.shiftZReportPrintFailed),
        findsNothing,
        reason: 'идемпотентный повтор — успех вызывающего, а не отказ',
      );
    });

    testWidgets('отказ очереди назван отказом', (tester) async {
      final l10n = await tapZReport(tester, ZReportOutcome.failed);

      expect(find.text(l10n.shiftZReportPrintFailed), findsOneWidget);
      expect(find.text(l10n.shiftZReportQueued), findsNothing);
    });
  });
}

/// Контроллер смены, который отвечает заранее назначенным исходом сдачи
/// Z-отчёта и считает нажатия.
class _StubShiftNotifier extends Notifier<ShiftState> implements ShiftNotifier {
  _StubShiftNotifier(this.outcome);

  final ZReportOutcome outcome;
  int calls = 0;

  @override
  ShiftState build() => TestShiftStates.open;

  @override
  Future<ZReportOutcome> printZReport() async {
    calls++;
    return outcome;
  }

  @override
  Future<void> openShift(Decimal initialAmount, {int? userId}) async {}

  @override
  Future<void> closeShift() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
