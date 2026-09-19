/// Память об импульсах ящика: то, чего у кассы не было вовсе.
///
/// # Что здесь по-настоящему проверяется
///
/// Не «список рисуется», а **граница знания кассы**. Обратной связи от
/// соленоида нет ни на одном из двух путей, и экран обязан говорить «команда
/// принята», а не «ящик открыт». Разница читается как придирка ровно до
/// первой жалобы «ящик не открылся»: с честной подписью разбор начинается с
/// проводки, с уютной — с поиска несуществующей ошибки в кассе.
///
/// # Что изменилось с пунктом 4 плана диагностики
///
/// Вкладка перестала брать `CashDrawerJournal` из `GetIt` — между ней и
/// журналом встал порт `HardwareDiagnosticsRepository`, и на планшете она
/// теперь есть. **Проба от этого не ослабла**: под вкладку ставится
/// настоящая `LocalHardwareDiagnostics` над настоящим журналом, то есть
/// проверяется тот же путь, каким вкладка живёт на кассе.
///
/// Прибавилось утверждение, которого не было и быть не могло: «памяти об
/// импульсах нет» и «ящик не звали» — **разные ответы**, и первый на месте
/// второго отправил бы наладчика искать обрыв в исправной проводке.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/data/diagnostics/local_hardware_diagnostics.dart';
import 'package:telepos/domain/diagnostics/hardware_diagnostics.dart';
import 'package:telepos/domain/terminal/terminal.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/hardware/cash_drawer/cash_drawer_journal.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/diagnostics/drawer_diagnostics_tab.dart';

void main() {
  late CashDrawerJournal journal;

  setUp(() async {
    journal = CashDrawerJournal();
    await GetIt.I.reset();
  });

  tearDown(() async {
    await journal.dispose();
    await GetIt.I.reset();
  });

  /// Настоящая кассовая реализация порта над настоящим журналом — тот же
  /// путь, каким вкладка живёт на кассе.
  void bindPort({CashDrawerJournal? drawer}) {
    GetIt.I.registerSingleton<HardwareDiagnosticsRepository>(
      LocalHardwareDiagnostics(
        terminals: _SelfTerminals(),
        drawerJournal: drawer,
      ),
    );
  }

  Future<void> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: DrawerDiagnosticsTab()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('пустой журнал говорит «не открывали», а не молчит', (
    tester,
  ) async {
    bindPort(drawer: journal);
    await mount(tester);

    expect(
      find.byKey(const ValueKey('drawer-diagnostics-empty')),
      findsOneWidget,
      reason: 'пустой экран неотличим от сломанного',
    );
  });

  testWidgets('«памяти нет» и «не открывали» — разные ответы', (tester) async {
    // Касса без журнала: голый процесс `bin/telepos_backend.dart`. Скажи
    // вкладка здесь «ящик не открывали ни разу», наладчик пошёл бы искать
    // обрыв в проводке ящика, который никто не спрашивал.
    bindPort();
    await mount(tester);

    expect(
      find.byKey(const ValueKey('drawer-diagnostics-unavailable')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('drawer-diagnostics-empty')),
      findsNothing,
      reason: 'два разных состояния кассы обязаны читаться по-разному',
    );
  });

  testWidgets('порта нет вовсе — вкладка говорит и это', (tester) async {
    // Контейнер без порта: единственная законная развилка, оставшаяся во
    // вкладке. Пустой список здесь был бы третьим ответом на месте двух.
    await mount(tester);

    expect(find.textContaining('спросить не у кого'), findsOneWidget);
    expect(find.byKey(const ValueKey('drawer-diagnostics-list')), findsNothing);
  });

  testWidgets('экран не обещает, что ящик открылся', (tester) async {
    journal.record(
      CashDrawerKick(
        at: DateTime(2026, 9, 19, 12, 30, 5),
        path: CashDrawerPath.viaPrinter,
        accepted: true,
      ),
    );
    bindPort(drawer: journal);
    await mount(tester);

    expect(find.text('Команда принята'), findsOneWidget);
    expect(
      find.textContaining('обратной связи нет'),
      findsOneWidget,
      reason:
          'граница знания кассы обязана быть на экране, а не в исходниках: '
          'жалоба «ящик не открылся» разбирается с этой строки',
    );
    expect(
      find.textContaining('Открыт'),
      findsNothing,
      reason: 'касса этого не знает — и не имеет права так писать',
    );
  });

  testWidgets('отказ виден с путём и дословной причиной', (tester) async {
    journal.record(
      CashDrawerKick(
        at: DateTime(2026, 9, 19, 12, 31),
        path: CashDrawerPath.serialPort,
        accepted: false,
        note: 'Не удалось открыть порт COM9: Access denied',
      ),
    );
    bindPort(drawer: journal);
    await mount(tester);

    expect(find.text('Команда отклонена'), findsOneWidget);
    expect(
      find.textContaining('Access denied'),
      findsOneWidget,
      reason:
          'дословная причина — то, ради чего журнал и заведён; общее слово '
          '«ошибка» не разбирает ни одну жалобу',
    );
    expect(find.textContaining('последовательный порт'), findsOneWidget);
  });

  testWidgets('импульс, случившийся при открытой вкладке, доезжает', (
    tester,
  ) async {
    // Довод рода операции, проверенный на экране: наладчик держит вкладку
    // открытой и жмёт «Открыть ящик» с соседнего экрана. Вопрос вместо
    // подписки оставил бы здесь «не открывали ни разу».
    bindPort(drawer: journal);
    await mount(tester);
    expect(
      find.byKey(const ValueKey('drawer-diagnostics-empty')),
      findsOneWidget,
      reason: 'предпосылка: до импульса пусто',
    );

    journal.record(
      CashDrawerKick(
        at: DateTime(2026, 9, 19, 12, 40),
        path: CashDrawerPath.viaPrinter,
        accepted: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Команда принята'), findsOneWidget);
  });

  // Не виджет-проба: вопрос к самому журналу, а не к его показу.
  test('новые попытки сверху, и их число не растёт без предела', () async {
    final small = CashDrawerJournal(limit: 3);
    for (var i = 0; i < 5; i++) {
      small.record(
        CashDrawerKick(
          at: DateTime(2026, 9, 19, 12, i),
          path: CashDrawerPath.viaPrinter,
          accepted: true,
          note: 'попытка $i',
        ),
      );
    }

    final kept = small.recent();
    expect(kept, hasLength(3));
    expect(
      kept.first.note,
      'попытка 4',
      reason: 'наверху — последняя: вопрос экрана «что было только что»',
    );
    expect(
      kept.map((k) => k.note),
      isNot(contains('попытка 0')),
      reason: 'список без границы перестаёт быть ответом на этот вопрос',
    );
    await small.dispose();
  });
}

class _SelfTerminals implements TerminalRepository {
  @override
  Future<Terminal> self() async =>
      const Terminal(id: 1, name: 'Касса', pointMode: PointMode.cashier);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'проба диагностики: ${invocation.memberName} у терминалов не поднят',
  );
}
