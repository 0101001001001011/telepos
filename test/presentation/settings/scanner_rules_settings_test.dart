import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/data/database/app_database.dart' hide Terminal;
import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/data/repositories/scanner_rules_repository_impl.dart';
import 'package:telepos/data/terminal/device_binding_repository_local.dart';
import 'package:telepos/domain/device/device_profile_catalog.dart';
import 'package:telepos/domain/repositories/scanner_rules_repository.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/terminal/device_binding_repository.dart';
import 'package:telepos/domain/terminal/terminal.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/settings/hardware_settings_screen.dart';

/// Plan 2b, task 3 — the second half of the "readable and migrated but not
/// editable" finding. Schema v28 gave `scannerTimeoutMs` a column, a
/// migration and a live reader; until this task nothing in the interface
/// could set any of the three И142 rules.
///
/// These tests drive the real `HardwareSettingsScreen` over the real
/// `LocalScannerRulesRepository` and a real in-memory drift database, and
/// assert on what the database holds afterwards — a test that only checked
/// the fields render would not distinguish "editable" from "looks editable".

class _FakeTerminalRepository implements TerminalRepository {
  _FakeTerminalRepository(this.terminalId);

  final int terminalId;

  /// Что экран записал набором видов оплаты (задача 15). Записывается, а не
  /// бросает, потому что `HardwareSettingsScreen` теперь сохраняет виды
  /// оплаты той же кнопкой, что и правила сканера, — и «упасть громко»
  /// здесь означало бы уронить проверку правил сканера из-за соседней
  /// секции, к которой она не относится.
  final List<Set<PaymentType>> savedPaymentTypes = [];

  /// Набор, который экран прочтёт при открытии. Пустой — «все виды».
  Set<PaymentType> allowedPaymentTypes = const {};

  @override
  Future<Terminal> self() async => Terminal(
    id: terminalId,
    name: 'Касса-1',
    pointMode: PointMode.cashier,
    allowedPaymentTypes: allowedPaymentTypes,
  );

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
  Future<void> rename(int terminalId, String name) =>
      throw UnimplementedError();

  @override
  Future<void> setAllowedPaymentTypes(
    int terminalId,
    Set<PaymentType> types,
  ) async => savedPaymentTypes.add(types);

  @override
  Future<void> delete(int terminalId) => throw UnimplementedError();
}

void main() {
  late AppDatabase db;
  late ScannerRulesRepository rules;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    final terminal = await db.terminalDao.ensureSelf(fallbackName: 'Касса-1');
    // The installation row the three rules live on. Without it there is
    // nowhere to write, which is a state this screen must survive — covered
    // by its own test below.
    await db.thisPosDao.upsert(
      const ThisPosEntriesCompanion(companyName: Value('ТОО Тест')),
    );
    rules = LocalScannerRulesRepository(db);

    await GetIt.I.reset();
    GetIt.I.registerSingleton<DeviceProfileCatalog>(
      BuiltinDeviceProfileCatalog(),
    );
    GetIt.I.registerSingleton<DeviceBindingRepository>(
      LocalDeviceBindingRepository(db, BuiltinDeviceProfileCatalog()),
    );
    GetIt.I.registerSingleton<TerminalRepository>(
      _FakeTerminalRepository(terminal.id),
    );
    GetIt.I.registerSingleton<ScannerRulesRepository>(rules);
  });

  tearDown(() async {
    await GetIt.I.reset();
    await db.close();
  });

  Future<Widget> host() async {
    final prefs = await SharedPreferences.getInstance();
    return ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ru'),
        home: const HardwareSettingsScreen(),
      ),
    );
  }

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(await host());
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String key, String text) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(Key(key)), text);
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.byIcon(TeleposIcons.save));
    await tester.pumpAndSettle();
  }

  testWidgets('all three И142 rules are editable and are actually written', (
    tester,
  ) async {
    await open(tester);

    await enter(tester, 'scanner_rule_min_length', '8');
    await enter(tester, 'scanner_rule_max_length', '14');
    await enter(tester, 'scanner_rule_timeout_ms', '120');
    await save(tester);

    final saved = await rules.read();
    expect(saved.barcodeMinLength, 8);
    expect(saved.barcodeMaxLength, 14);
    expect(
      saved.scannerTimeoutMs,
      120,
      reason:
          'scannerTimeoutMs had a column, a migration and a reader — this '
          'is the writer that was missing',
    );

    // And it is really on the row the live decoder reads, not somewhere
    // parallel: `BarcodeScannerMixin._loadScannerSettings` reads exactly
    // these three columns of `ThisPosEntries`.
    final row = await db.thisPosDao.get();
    expect(row!.barcodeMinLength, 8);
    expect(row.barcodeMaxLength, 14);
    expect(row.scannerTimeoutMs, 120);
  });

  testWidgets('previously saved rules are shown when the screen reopens', (
    tester,
  ) async {
    await rules.save(
      ScannerRules(
        barcodeMinLength: 6,
        barcodeMaxLength: 20,
        scannerTimeoutMs: 55,
      ),
    );

    await open(tester);

    expect(
      tester
          .widget<TextField>(find.byKey(const Key('scanner_rule_timeout_ms')))
          .controller!
          .text,
      '55',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('scanner_rule_min_length')))
          .controller!
          .text,
      '6',
    );
  });

  testWidgets(
    'a minimum above the maximum is refused and named, not saved as a rule no '
    'barcode can satisfy',
    (tester) async {
      await open(tester);

      await enter(tester, 'scanner_rule_min_length', '20');
      await enter(tester, 'scanner_rule_max_length', '5');
      await save(tester);

      expect(
        (await rules.read()).barcodeMinLength,
        isNull,
        reason: 'nothing may be written when the pair is contradictory',
      );

      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      final text = (snackBar.content as Text).data ?? '';
      expect(text, contains('больше максимальной'));
    },
  );

  testWidgets('a non-numeric value is refused and quoted back', (tester) async {
    await open(tester);

    await enter(tester, 'scanner_rule_timeout_ms', '80ms');
    await save(tester);

    expect((await rules.read()).scannerTimeoutMs, isNull);

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    final text = (snackBar.content as Text).data ?? '';
    expect(
      text,
      contains('80ms'),
      reason: 'the operator must see which value was rejected',
    );
  });

  testWidgets(
    'clearing a field means "use the default" — it is stored as unset, not as '
    'zero',
    (tester) async {
      await rules.save(
        ScannerRules(
          barcodeMinLength: 6,
          barcodeMaxLength: 20,
          scannerTimeoutMs: 55,
        ),
      );
      await open(tester);

      await enter(tester, 'scanner_rule_timeout_ms', '');
      await save(tester);

      final saved = await rules.read();
      expect(saved.scannerTimeoutMs, isNull);
      expect(
        saved.effectiveScannerTimeoutMs,
        ScannerRules.defaultScannerTimeoutMs,
        reason:
            'unset must fall back to the same default the live decoder '
            'uses, not to zero',
      );
    },
  );
}
