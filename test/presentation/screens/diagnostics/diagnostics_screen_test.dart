/// Экран диагностики: все вкладки достижимы, и пометка эмулятора зажигается
/// по **адресу привязки**, а не по состоянию выключателя.
///
/// # Почему пометка проверяется отдельно и придирчиво
///
/// Наладчик смотрит на этот экран, чтобы решить «работает или нет». Чек,
/// разобравшийся в окне эмулятора, и чек, вышедший на бумаге, выглядят здесь
/// одинаково — и это правильно, байты те же. Различает их ровно одна плашка.
/// Плашка, зажжённая не тем признаком (например, выключателем встроенного
/// эмулятора), молчала бы про эмулятор, запущенный руками, — то есть врала бы
/// в единственном месте, ради которого она есть.
///
/// # Чего проба НЕ доказывает
///
/// Содержимое вкладок: оно проверено своими пробами
/// (`printer_diagnostics_tab_test.dart`, `fiscal_diagnostics_tab_test.dart`).
/// Здесь — сборка: терминал найден, вкладки на месте, пометка честная.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/data/database/app_database.dart' hide Terminal;
import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/data/diagnostics/local_hardware_diagnostics.dart';
import 'package:telepos/data/terminal/device_binding_repository_local.dart';
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/diagnostics/hardware_diagnostics.dart';
import 'package:telepos/domain/entities/receipt/receipt_options.dart';
import 'package:telepos/domain/print/print_job.dart';
import 'package:telepos/domain/print/print_queue.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/services/receipt_print_service.dart';
import 'package:telepos/domain/terminal/device_binding.dart';
import 'package:telepos/domain/terminal/device_binding_repository.dart';
import 'package:telepos/domain/terminal/terminal.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/hardware/cash_drawer/cash_drawer_journal.dart';
import 'package:telepos/hardware/display/customer_display_journal.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/diagnostics/diagnostics_screen.dart';

class _FakeTerminalRepository implements TerminalRepository {
  _FakeTerminalRepository(this.terminalId);

  final int terminalId;

  @override
  Future<Terminal> self() async =>
      Terminal(id: terminalId, name: 'Касса-1', pointMode: PointMode.cashier);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'проба диагностики: ${invocation.memberName} у терминалов не поднят',
  );
}

class _EmptyQueue implements PrintQueue {
  @override
  Stream<List<PrintJob>> watch({int? terminalId}) =>
      Stream.value(const <PrintJob>[]);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'проба диагностики: ${invocation.memberName} у очереди не поднят',
  );
}

class _FixedWidthPrinter implements ReceiptPrintService {
  @override
  Future<ReceiptPaperWidth> currentPaperWidth() async => ReceiptPaperWidth.mm80;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'проба диагностики: ${invocation.memberName} у печати не поднят',
  );
}

void main() {
  late AppDatabase db;
  late DeviceBindingRepository repo;
  late int terminalId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final terminal = await db.terminalDao.ensureSelf(fallbackName: 'Касса-1');
    terminalId = terminal.id;
    repo = LocalDeviceBindingRepository(db, BuiltinDeviceProfileCatalog());

    await GetIt.I.reset();
    GetIt.I
      ..registerSingleton<AppDatabase>(db)
      ..registerSingleton<DeviceBindingRepository>(repo)
      ..registerSingleton<TerminalRepository>(
        _FakeTerminalRepository(terminalId),
      )
      // Диагностика вкладок ходит через порт с 2026-09-19 (пункт
      // «Достижимость с браузерного терминала» плана диагностики): та же
      // кассовая реализация над теми же подставными сотрудниками, что
      // регистрировались здесь поимённо до неё.
      // Пункт 4 того же плана добавил сюда журналы ящика и дисплея: вкладки
      // перестали брать их из `GetIt` напрямую и спрашивают тот же порт.
      // Регистрация journals рядом осталась бы мёртвой — её сняли.
      ..registerSingleton<HardwareDiagnosticsRepository>(
        LocalHardwareDiagnostics(
          terminals: _FakeTerminalRepository(terminalId),
          queue: _EmptyQueue(),
          printer: _FixedWidthPrinter(),
          db: db,
          fiscalQueue: null,
          drawerJournal: CashDrawerJournal(),
          displayJournal: CustomerDisplayJournal(),
        ),
      );
  });

  tearDown(() async {
    await GetIt.I.reset();
    await db.close();
  });

  Future<void> bindPrinterTo(String ipAddress) => repo.save(
    terminalId,
    DeviceBinding(
      deviceClass: DeviceClass.receiptPrinter,
      profileId: 'printer.escpos.80mm',
      parameters: {'ipAddress': ipAddress, 'port': '9100'},
    ),
  );

  Future<void> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DiagnosticsScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('все вкладки на месте и открываются', (tester) async {
    await bindPrinterTo('192.168.1.50');
    await mount(tester);

    expect(find.byKey(const ValueKey('diagnostics-tab-printer')), findsOneWidget);
    expect(find.byKey(const ValueKey('diagnostics-tab-fiscal')), findsOneWidget);
    expect(find.byKey(const ValueKey('diagnostics-tab-drawer')), findsOneWidget);

    // Пройти по всем, а не по одной: у каждой вкладки свои зависимости из
    // контейнера, и незарегистрированная всплывает только при открытии.
    for (final tab in const [
      'drawer',
      'scales',
      'display',
      'fiscal',
      'printer',
    ]) {
      await tester.tap(find.byKey(ValueKey('diagnostics-tab-$tab')));
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'вкладка «$tab» упала при открытии',
      );
    }
  });

  testWidgets('принтер в сети магазина — пометки эмулятора нет', (tester) async {
    await bindPrinterTo('192.168.1.50');
    await mount(tester);

    expect(
      find.byKey(const ValueKey('diagnostics-emulator-banner')),
      findsNothing,
      reason: 'пометка на живой кассе читалась бы как неисправность',
    );
  });

  testWidgets('привязка на петлю — пометка «за портом эмулятор»', (
    tester,
  ) async {
    await bindPrinterTo('127.0.0.1');
    await mount(tester);

    expect(
      find.byKey(const ValueKey('diagnostics-emulator-banner')),
      findsOneWidget,
      reason:
          'иначе чек, разобравшийся в окне, не отличить от вышедшего на бумаге',
    );
  });

  testWidgets('эмулятор, запущенный руками под именем localhost, тоже помечен', (
    tester,
  ) async {
    // Признак — адрес, а не выключатель встроенного эмулятора: касса, чья
    // привязка направлена на процесс, поднятый из командной строки, ничем не
    // отличается и обязана быть помечена так же.
    await bindPrinterTo('localhost');
    await mount(tester);

    expect(
      find.byKey(const ValueKey('diagnostics-emulator-banner')),
      findsOneWidget,
    );
  });
}
