import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/data/database/app_database.dart' hide Terminal;
import 'package:telepos/data/device/device_profile_catalog_builtin.dart';
import 'package:telepos/data/terminal/device_binding_repository_local.dart';
import 'package:telepos/domain/device/device_class.dart';
import 'package:telepos/domain/device/device_profile_catalog.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/terminal/device_binding.dart';
import 'package:telepos/domain/terminal/device_binding_repository.dart';
import 'package:telepos/domain/terminal/terminal.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/catalog/dialogs/print_price_tag_dialog.dart';

/// Minimal fake — only `self()` is exercised by this dialog; every other
/// member throws if ever called, so an accidental new dependency fails
/// loudly instead of silently returning a plausible value.
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
  Future<void> setAllowedPaymentTypes(
    int terminalId,
    Set<PaymentType> types,
  ) => throw UnimplementedError();

  @override
  Future<void> delete(int terminalId) => throw UnimplementedError();
}

/// Final review finding C4: this dialog used to read
/// `ThisPosEntries.labelPrinterConnectionType`/`.labelPrinterAddress`/
/// `.labelPrinterPort`/`.labelPrinterLanguage` directly (`lib/data`, a
/// presentation-layer violation) and build its own `LabelPrinterService` —
/// pointed at columns whose only writer, `ThisPosDao.updateLabelPrinter`,
/// had zero call sites left. These tests prove the dialog now reads the
/// label-printer *binding* — through `DeviceBindingRepository`, a
/// `lib/domain` contract — instead.
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
    GetIt.I.registerSingleton<AppDatabase>(db);
  });

  tearDown(() async {
    await GetIt.I.reset();
    await db.close();
  });

  Widget host(List<PriceTagProduct> products) {
    return MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => PrintPriceTagDialog.show(context, products: products),
            child: const Text('open'),
          ),
        ),
      ),
    );
  }

  final products = [
    PriceTagProduct(
      name: 'Тест-товар',
      barcode: '4607001000001',
      price: Decimal.fromInt(1000),
    ),
  ];

  Future<void> openDialogAndPrint(WidgetTester tester) async {
    await tester.pumpWidget(host(products));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.print));
    await tester.pumpAndSettle(const Duration(seconds: 1));
  }

  testWidgets(
    'no label-printer binding configured — reports "not configured", never '
    'attempts a connection',
    (tester) async {
      await openDialogAndPrint(tester);

      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
      expect(find.text(l10n.labelPrinterNotConfigured), findsOneWidget);
    },
  );

  testWidgets(
    'a label-printer binding saved through DeviceBindingRepository is what '
    'the dialog actually uses to print — not a coincidence with the '
    "'not configured' path",
    (tester) async {
      await repo.save(
        terminalId,
        const DeviceBinding(
          deviceClass: DeviceClass.labelPrinter,
          profileId: 'printer.label.zpl.104mm',
          parameters: {'ipAddress': '127.0.0.1', 'port': '65530'},
          options: {'paperWidthMm': '104', 'labelHeightMm': '40'},
        ),
      );

      await openDialogAndPrint(tester);

      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
      expect(
        find.text(l10n.labelPrinterNotConfigured),
        findsNothing,
        reason:
            'a real binding exists — the dialog must attempt to use it, not '
            'fall back to the "unconfigured" message',
      );
    },
  );

  testWidgets(
    'a disabled label-printer binding is treated as unconfigured, same as '
    'no binding at all',
    (tester) async {
      await repo.save(
        terminalId,
        const DeviceBinding(
          deviceClass: DeviceClass.labelPrinter,
          profileId: 'printer.label.zpl.104mm',
          parameters: {'ipAddress': '127.0.0.1', 'port': '65530'},
          enabled: false,
        ),
      );

      await openDialogAndPrint(tester);

      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
      expect(find.text(l10n.labelPrinterNotConfigured), findsOneWidget);
    },
  );
}
