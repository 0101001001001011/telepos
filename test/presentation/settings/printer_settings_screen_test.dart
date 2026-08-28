import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/data/database/app_database.dart' hide Terminal;
import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/data/terminal/device_binding_repository_local.dart';
import 'package:telepos/domain/device/device_profile_catalog.dart';
import 'package:telepos/domain/terminal/device_binding_repository.dart';
import 'package:telepos/domain/terminal/terminal.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/settings/printer_settings_screen.dart';

/// Minimal fake — only `self()` is exercised by this screen; every other
/// member throws if ever called, so an accidental new dependency on it
/// fails loudly instead of silently returning a plausible value.
class _FakeTerminalRepository implements TerminalRepository {
  _FakeTerminalRepository(this.terminalId);

  final int terminalId;

  @override
  Future<Terminal> self() async =>
      Terminal(id: terminalId, name: 'Касса-1', pointMode: PointMode.cashier);

  @override
  Future<List<Terminal>> list() => throw UnimplementedError();

  // Подписок этот экран не заводит: свой терминал он спрашивает один раз при
  // открытии. Бросают по той же причине, что и остальные члены — случайная
  // новая зависимость обязана падать громко, а не возвращать правдоподобное.
  @override
  Stream<List<Terminal>> watchAll() => throw UnimplementedError();

  @override
  Stream<Terminal?> watchSelf() => throw UnimplementedError();

  @override
  Future<TerminalEnrollment> register({
    required String name,
    String code = '',
  }) => throw UnimplementedError();

  @override
  Future<Terminal> resume({required int terminalId, required String secret}) =>
      throw UnimplementedError();

  @override
  Future<void> rename(int terminalId, String name) => throw UnimplementedError();

  @override
  Future<void> delete(int terminalId) => throw UnimplementedError();
}

/// End-to-end through the real widget: profile picker → dynamic fields →
/// Save button → real `LocalDeviceBindingRepository` over an in-memory
/// drift database — proving the whole screen, not just its pieces.
void main() {
  late AppDatabase db;
  late int terminalId;
  late DeviceBindingRepository repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final terminal = await db.terminalDao.ensureSelf(fallbackName: 'Касса-1');
    terminalId = terminal.id;
    repo = LocalDeviceBindingRepository(db, BuiltinDeviceProfileCatalog());

    await GetIt.I.reset();
    GetIt.I.registerSingleton<DeviceProfileCatalog>(BuiltinDeviceProfileCatalog());
    GetIt.I.registerSingleton<DeviceBindingRepository>(repo);
    GetIt.I.registerSingleton<TerminalRepository>(
      _FakeTerminalRepository(terminalId),
    );
  });

  tearDown(() async {
    await GetIt.I.reset();
    await db.close();
  });

  Widget host() {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const PrinterSettingsScreen(),
    );
  }

  /// The printer section starts disabled (no prior binding) — the profile
  /// picker and its fields only render once the section's `Switch` is on.
  Future<void> enablePrinterSection(WidgetTester tester) async {
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'choosing a profile, filling its required parameter and saving persists '
    'a binding the repository returns afterwards',
    (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await enablePrinterSection(tester);

      await tester.tap(find.text('Чековый принтер ESC/POS 80 мм'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('param_printer.escpos.80mm_ipAddress')),
        '192.168.10.20',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(TeleposIcons.save));
      await tester.pumpAndSettle();

      final saved = await repo.forTerminal(terminalId);
      expect(saved, hasLength(1));
      expect(saved.single.profileId, 'printer.escpos.80mm');
      expect(saved.single.parameters['ipAddress'], '192.168.10.20');

      // A visible confirmation, not just a silently-successful write.
      expect(find.byType(SnackBar), findsOneWidget);
    },
  );

  testWidgets(
    'leaving the required IP address empty refuses to save and names the '
    'parameter, rather than saving a partial binding',
    (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await enablePrinterSection(tester);

      await tester.tap(find.text('Чековый принтер ESC/POS 80 мм'));
      await tester.pumpAndSettle();
      // ipAddress left blank on purpose.

      await tester.tap(find.byIcon(TeleposIcons.save));
      await tester.pumpAndSettle();

      expect(
        await repo.forTerminal(terminalId),
        isEmpty,
        reason: 'nothing must be written when the required field is blank',
      );

      final snackBarFinder = find.byType(SnackBar);
      expect(snackBarFinder, findsOneWidget);
      final snackBar = tester.widget<SnackBar>(snackBarFinder);
      final text = (snackBar.content as Text).data ?? '';
      expect(
        text,
        contains('ipAddress'),
        reason: 'the operator must be told which parameter is missing, not '
            'just that saving failed',
      );
    },
  );

  testWidgets(
    'switching the printer profile then saving replaces the binding rather '
    'than accumulating a second row',
    (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await enablePrinterSection(tester);

      await tester.tap(find.text('Чековый принтер ESC/POS 80 мм'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('param_printer.escpos.80mm_ipAddress')),
        '10.0.0.1',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(TeleposIcons.save));
      await tester.pumpAndSettle();

      await tester.tap(
        find.text('ESC/POS Receipt Printer 58mm (compact, no cutter)'),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('param_printer.escpos.58mm-compact_ipAddress')),
        '10.0.0.2',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(TeleposIcons.save));
      await tester.pumpAndSettle();

      final saved = await repo.forTerminal(terminalId);
      expect(
        saved,
        hasLength(1),
        reason: 'switching profile must replace, not add a sibling row',
      );
      expect(saved.single.profileId, 'printer.escpos.58mm-compact');
      expect(saved.single.parameters['ipAddress'], '10.0.0.2');
    },
  );
}
