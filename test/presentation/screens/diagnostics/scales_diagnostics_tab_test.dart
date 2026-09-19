/// Весы на экране диагностики: показание живьём и честная пустота.
///
/// # Почему «весы не привязаны» проверяется отдельно
///
/// Касса без весов и весы с оборванным проводом дают на экране одно и то же —
/// ничего. Это тот же класс беды, что пустая очередь фискализации: пустота
/// отвечает «ничего нет» на два противоположных вопроса, и различить их может
/// только слово.
///
/// # Что изменилось с пунктом 4 плана диагностики
///
/// Вкладка перестала спрашивать `ScalesService` у `GetIt` — между ней и
/// прибором встал порт `HardwareDiagnosticsRepository`, и на планшете она
/// теперь есть. Под вкладку здесь ставится **настоящая**
/// `LocalHardwareDiagnostics` над настоящей `ScalesService`, то есть
/// проверяется тот же путь, каким вкладка живёт на кассе, вместе с
/// прореживанием кадров.
///
/// Вес при этом приезжает **готовой строкой с тремя знаками**, приготовленной
/// кассой: `Decimal` печатает 1.250 как «1.25», и вкладка, форматирующая
/// сама, теряла бы граммы молча. Проба берёт именно такой вес.
library;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/data/diagnostics/local_hardware_diagnostics.dart';
import 'package:telepos/domain/diagnostics/hardware_diagnostics.dart';
import 'package:telepos/domain/terminal/terminal.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/hardware/scales/scales_service.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/diagnostics/scales_diagnostics_tab.dart';

void main() {
  tearDown(() => GetIt.I.reset());

  /// Настоящая кассовая реализация порта над настоящей службой весов.
  ///
  /// Окно прореживания взято нулевым: длина окна — не предмет этих проб (она
  /// измеряется в `test/backend/diagnostics_op_test.dart`), а задержка в
  /// виджет-пробе означала бы `pumpAndSettle`, ждущий таймера.
  void bindPort({ScalesService? scales}) {
    GetIt.I.registerSingleton<HardwareDiagnosticsRepository>(
      LocalHardwareDiagnostics(
        terminals: _SelfTerminals(),
        scales: scales,
        scalesFrameInterval: Duration.zero,
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
        home: Scaffold(body: ScalesDiagnosticsTab()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('весов нет — сказано словами, а не пустым полем', (tester) async {
    bindPort();
    await mount(tester);

    expect(
      find.byKey(const ValueKey('scales-diagnostics-unbound')),
      findsOneWidget,
    );
  });

  testWidgets('порта диагностики нет — вкладка говорит и это', (tester) async {
    // Единственная законная развилка, оставшаяся во вкладке. «Весы не
    // привязаны» здесь было бы неправдой: про весы никто не спрашивал.
    await mount(tester);

    expect(find.textContaining('спросить не у кого'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('scales-diagnostics-unbound')),
      findsNothing,
    );
  });

  testWidgets('порт есть, но весы молчат — это тоже сказано', (tester) async {
    bindPort(scales: ScalesService(port: 'COM9'));
    await mount(tester);

    expect(
      find.byKey(const ValueKey('scales-diagnostics-live')),
      findsOneWidget,
    );
    expect(
      find.text('—'),
      findsOneWidget,
      reason: 'ноль здесь был бы неправдой: весы не сказали «ноль»',
    );
    expect(find.textContaining('ещё ничего не прислали'), findsOneWidget);
  });

  testWidgets('показание капает в поле живьём, и граммы не теряются', (
    tester,
  ) async {
    final scales = ScalesService(port: 'COM9');
    addTearDown(scales.dispose);
    bindPort(scales: scales);
    await mount(tester);

    scales.setManualWeight(Decimal.parse('1.250'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('1.250'),
      findsOneWidget,
      reason:
          'вкладка обязана обновляться потоком, а не по открытию экрана; '
          'а «1.25» на экране означал бы потерянный грамм — молча',
    );
  });

  testWidgets('порт весов назван — по нему и ищут обрыв', (tester) async {
    bindPort(scales: ScalesService(port: 'COM9'));
    await mount(tester);

    expect(find.textContaining('COM9'), findsOneWidget);
    expect(
      find.textContaining('Порт закрыт'),
      findsOneWidget,
      reason: 'connect() не звали — экран не имеет права показывать «открыт»',
    );
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
