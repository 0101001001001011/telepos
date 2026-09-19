/// Экран диагностики на планшете открывается и **говорит словами** — пункт
/// «Достижимость с браузерного терминала» плана
/// `2026-09-19-hardware-diagnostics.md`.
///
/// # Что здесь по-настоящему проверяется
///
/// Не «вкладки нарисовались». Три вещи, каждая из которых ломается молча:
///
/// 1. **все пять вкладок открываются на проводном порту.** Вкладка,
///    спросившая кассовую службу из `GetIt`, в браузере упала бы или
///    показала пустоту — ровно это и было до работы. Проба открывает каждую
///    и требует, чтобы ни одна не бросила;
/// 2. **из экрана есть выход.** У браузерной таблицы нет ни оболочки, ни
///    стека переходов: вкладку открывают прямо по адресу, и `pop()` в ней не
///    делает ничего. Экран без двери — тупик с надписью, и этот вывод уже
///    оплачен `WtNotPortedScreen`;
/// 3. **вкладок ровно пять** (пункт 4 плана: было две). Ящик, весы и дисплей
///    поехали по проводу своими подписками; шестая, «Оплата», по-прежнему
///    кассовая, и её отсутствие — названная граница работы, а не забытая
///    вкладка.
///
/// Порт здесь подставной, а не `WtHardwareDiagnostics`: провод целиком
/// проверяет `test/backend/diagnostics_op_test.dart` обеими половинами, и
/// поднимать его второй раз тут значило бы мерить то же самое хуже.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'package:telepos/domain/diagnostics/hardware_diagnostics.dart';
import 'package:telepos/domain/print/print_job.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/diagnostics/terminal_diagnostics_screen.dart';

void main() {
  setUp(() => GetIt.I.reset());
  tearDown(() => GetIt.I.reset());

  /// Маршрутизатор из двух записей: экран и дом. Настоящий `GoRouter`, а не
  /// подделка, — проверяется именно переход, а он и есть предмет.
  GoRouter routerWithHome() => GoRouter(
    initialLocation: '/terminal-diagnostics',
    routes: [
      GoRoute(
        path: '/terminal-diagnostics',
        builder: (context, state) =>
            const TerminalDiagnosticsScreen(homeRoute: '/terminal-home'),
      ),
      GoRoute(
        path: '/terminal-home',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('ДОМ ТЕРМИНАЛА'))),
      ),
    ],
  );

  Future<void> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp.router(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: routerWithHome(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('все пять вкладок открываются и ни одна не падает', (
    tester,
  ) async {
    GetIt.I.registerSingleton<HardwareDiagnosticsRepository>(
      _PortWithOneJob(),
    );

    await mount(tester);

    for (final tab in const [
      'printer',
      'drawer',
      'scales',
      'display',
      'fiscal',
    ]) {
      expect(
        find.byKey(ValueKey('terminal-diagnostics-tab-$tab')),
        findsOneWidget,
        reason: 'вкладки «$tab» нет на экране планшета',
      );
    }

    // Обход в обе стороны: вкладка, упавшая при возврате на неё, выглядит
    // исправной при обходе в одну.
    for (final tab in const [
      'drawer',
      'scales',
      'display',
      'fiscal',
      'display',
      'scales',
      'drawer',
      'printer',
    ]) {
      await tester.tap(
        find.byKey(ValueKey('terminal-diagnostics-tab-$tab')),
      );
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'вкладка «$tab» упала при открытии на планшете',
      );
    }

    // Чек приехал разобранным кассой — вкладка показывает строку.
    expect(find.textContaining('MOLOKO'), findsNothing);
    await tester.tap(find.text('t1/p1/s1/sale/7001/c1'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('MOLOKO'),
      findsOneWidget,
      reason: 'текст чека приезжает с кассы готовым и показывается как есть',
    );
  });

  testWidgets('вкладок ровно пять: оплата по проводу пока не едет', (
    tester,
  ) async {
    GetIt.I.registerSingleton<HardwareDiagnosticsRepository>(
      _PortWithOneJob(),
    );

    await mount(tester);

    expect(
      find.byType(Tab),
      findsNWidgets(5),
      reason:
          'шестая вкладка на планшете показывала бы пустые намерения оплаты '
          '— то есть «денег не брали» вместо честного «спросить нечем». '
          'Число здесь точное нарочно: вкладка, добавленная без своей '
          'подписки, выглядит работающей и молчит',
    );
  });

  testWidgets('ящик, весы и дисплей показывают то, что прислала касса', (
    tester,
  ) async {
    // Вкладка, открывшаяся без падения, ещё ничего не доказывает: пустой
    // список и спиннер тоже не падают. Здесь проверяется, что данные порта
    // дошли до экрана — по одному свидетелю на вкладку.
    GetIt.I.registerSingleton<HardwareDiagnosticsRepository>(
      _PortWithOneJob(),
    );

    await mount(tester);

    await tester.tap(
      find.byKey(const ValueKey('terminal-diagnostics-tab-drawer')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Команда принята'), findsOneWidget);
    expect(
      find.textContaining('через принтер'),
      findsOneWidget,
      reason: 'путь приехал именем значения и переведён вкладкой',
    );

    await tester.tap(
      find.byKey(const ValueKey('terminal-diagnostics-tab-scales')),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('1.250'),
      findsOneWidget,
      reason:
          'вес приезжает готовой строкой с тремя знаками: «1.25» здесь '
          'означал бы потерянный грамм',
    );

    await tester.tap(
      find.byKey(const ValueKey('terminal-diagnostics-tab-display')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('1250.00'), findsWidgets);
  });

  testWidgets('с экрана есть выход — он ведёт домой, а не в никуда', (
    tester,
  ) async {
    GetIt.I.registerSingleton<HardwareDiagnosticsRepository>(
      _PortWithOneJob(),
    );

    await mount(tester);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(
      find.text('ДОМ ТЕРМИНАЛА'),
      findsOneWidget,
      reason:
          'вкладку открывают прямо по адресу, стека переходов у неё нет, и '
          '`pop()` не делает ничего: экран без двери — тупик с надписью',
    );
  });

  testWidgets('порта нет — все пять вкладок говорят словами, а не пустотой', (
    tester,
  ) async {
    // Ни одной привязки: так стоит сборка без контейнера зависимостей.
    await mount(tester);

    expect(find.textContaining('спросить не у кого'), findsOneWidget);
    for (final tab in const ['drawer', 'scales', 'display', 'fiscal']) {
      await tester.tap(
        find.byKey(ValueKey('terminal-diagnostics-tab-$tab')),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('спросить не у кого'),
        findsOneWidget,
        reason:
            'вкладка «$tab» без порта обязана сказать это словами: пустота '
            'здесь читается как «прибор молчит», и наладчик пошёл бы искать '
            'обрыв в исправной проводке',
      );
    }
  });
}

/// Порт, отвечающий одним заданием и настроенным оператором.
///
/// Текст чека приходит **готовым**: по проводу он и приезжает готовым, а
/// раскладки в браузерной половине нет ни строки.
class _PortWithOneJob implements HardwareDiagnosticsRepository {
  @override
  Stream<PrinterDiagnosticsView> watchPrinter() => Stream.value(
    PrinterDiagnosticsView(
      available: true,
      jobs: [
        PrintJobDiagnostics(
          id: 't1/p1/s1/sale/7001/c1',
          state: PrintJobState.printed,
          attempts: 1,
          createdAt: DateTime(2026, 9, 19, 10),
          text: '          MAGAZIN\nMOLOKO        500.00\n',
        ),
      ],
    ),
  );

  @override
  Future<FiscalDiagnosticsView> fiscal() async => const FiscalDiagnosticsView(
    configured: true,
    accepted: [],
    queued: [],
  );

  /// Ящик, дисплей и весы — по одному свидетелю на вкладку.
  ///
  /// Все три приезжают **готовыми**: путь и вид вызова именем значения
  /// (переводит вкладка), вес — строкой с тремя знаками и статусом,
  /// разобранным кассой. Ни одного из этих правил в браузерной половине нет.
  @override
  Stream<DrawerDiagnosticsView> watchDrawer() => Stream.value(
    DrawerDiagnosticsView(
      available: true,
      kicks: [
        DrawerKickDiagnostics(
          at: DateTime(2026, 9, 19, 12, 30),
          path: DrawerKickPath.viaPrinter,
          accepted: true,
        ),
      ],
    ),
  );

  @override
  Stream<DisplayDiagnosticsView> watchDisplay() {
    final line = DisplayLineDiagnostics(
      at: DateTime(2026, 9, 19, 13),
      kind: DisplayCallKind.total,
      text: '1250.00',
    );
    return Stream.value(
      DisplayDiagnosticsView(
        available: true,
        lines: [line],
        current: line,
      ),
    );
  }

  @override
  Stream<ScalesDiagnosticsView> watchScales() => Stream.value(
    const ScalesDiagnosticsView(
      bound: true,
      port: 'COM7',
      baudRate: 9600,
      protocol: 'cas',
      connected: true,
      reading: ScalesReadingDiagnostics(
        weight: '1.250',
        unit: 'kg',
        status: ScalesReadingStatus.stable,
      ),
    ),
  );
}
