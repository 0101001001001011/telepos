import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/repositories/scanner_rules_repository_impl.dart';
import 'package:telepos/domain/repositories/scanner_rules_repository.dart';
import 'package:telepos/presentation/common/mixins/barcode_scanner_mixin.dart';

/// `BarcodeScannerMixin` is the live keyboard-wedge scanning path six real
/// screens attach to (`sale_screen.dart`, `movement_screen.dart`,
/// `movement_dialog.dart`, `supply_form.dart`, `supplier_return_screen.dart`,
/// `supplier_return_dialog.dart`) — unlike the now-deleted
/// `BarcodeScannerService`, which nothing ever started. Fix round 1 (task
/// 5(c), plan 2b) moved `scannerTimeoutMs` reading here, from the dead
/// class, because "wire the setting into a reader" and "wire it into a
/// reader that runs" are different claims — this file is the second one.
///
/// No test existed for this mixin at all before this file — every prior
/// assignment in `_loadScannerSettings` (`_minBarcodeLength`,
/// `_maxBarcodeLength`) was also unverified, which is exactly the shape of
/// gap that let `_scannerMaxGapMs` sit `final` unnoticed.
class _ScannerHost extends StatefulWidget {
  const _ScannerHost({super.key});

  @override
  State<_ScannerHost> createState() => _ScannerHostState();
}

class _ScannerHostState extends State<_ScannerHost> with BarcodeScannerMixin {
  final scanned = <String>[];

  @override
  void initState() {
    super.initState();
    initBarcodeScanner();
  }

  @override
  void dispose() {
    disposeBarcodeScanner();
    super.dispose();
  }

  @override
  void onBarcodeScanned(String barcode) {
    scanned.add(barcode);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await GetIt.I.reset();
    // Задача 13: миксин больше не читает `ThisPosEntries` сам — он
    // спрашивает доменный контракт, и здесь стоит **та же** реализация,
    // которую регистрирует боевой DI (`service_locator.dart:585`:
    // `LocalScannerRulesRepository(getIt<AppDatabase>())`) над **той же**
    // таблицей. Проверяется по-прежнему сквозной путь «настройка в базе →
    // живой декодер», а не то, что позвали подделку.
    //
    // Причина переезда: экран продажи (один из шести, кто подмешивает этот
    // декодер) переехал в браузерную таблицу маршрутов, а базы в браузере
    // нет вовсе — прежний путь тянул `dart:io` и `dart:ffi` в веб-сборку.
    final rules = LocalScannerRulesRepository(db);
    GetIt.I
      ..registerSingleton<ScannerRulesRepository>(rules)
      // Задача 45: миксин читает правила через `ScannerRulesReader` — тот
      // же синглтон, что и в `service_locator.dart`.
      ..registerSingleton<ScannerRulesReader>(rules);
    // Deliberately no TerminalRepository registration: `_loadScannerSettings`
    // assigns `_scannerMaxGapMs`/`_minBarcodeLength`/`_maxBarcodeLength`
    // *before* it ever checks for one (see that method's source) — this
    // test's whole point is that assignment, so it should not depend on
    // machinery the assignment itself does not depend on.
  });

  tearDown(() async {
    await GetIt.I.reset();
    await db.close();
  });

  Future<_ScannerHostState> pumpHost(WidgetTester tester) async {
    final key = GlobalKey<_ScannerHostState>();
    await tester.pumpWidget(MaterialApp(home: _ScannerHost(key: key)));
    await tester.pumpAndSettle();
    return key.currentState!;
  }

  testWidgets(
    'a configured scannerTimeoutMs reaches the live keyboard-wedge decoder, '
    'not just the profile/binding it has nothing to do with',
    (tester) async {
      await db
          .into(db.thisPosEntries)
          .insertOnConflictUpdate(
            const ThisPosEntriesCompanion(
              rId: Value(true),
              scannerTimeoutMs: Value(250),
            ),
          );

      final state = await pumpHost(tester);

      expect(
        state.debugScannerMaxGapMs,
        250,
        reason:
            'before fix round 1, this mixin left _scannerMaxGapMs at its '
            'fixed 80ms default forever — scannerTimeoutMs was wired only '
            'into BarcodeScannerService, which no screen using this mixin '
            'ever started',
      );
    },
  );

  testWidgets(
    'no scannerTimeoutMs configured — falls back to 80ms, the default this '
    'always had',
    (tester) async {
      await db
          .into(db.thisPosEntries)
          .insertOnConflictUpdate(
            const ThisPosEntriesCompanion(rId: Value(true)),
          );

      final state = await pumpHost(tester);

      expect(state.debugScannerMaxGapMs, 80);
    },
  );

  testWidgets(
    'no ThisPosEntries row at all — still falls back to 80ms rather than '
    'crashing the six screens that attach this mixin in initState',
    (tester) async {
      final state = await pumpHost(tester);

      expect(state.debugScannerMaxGapMs, 80);
    },
  );
}
