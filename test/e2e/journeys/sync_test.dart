library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:get_it/get_it.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/locale/app_locale.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/sync/sync_controller.dart';
import 'package:telepos/presentation/screens/sync/sync_screen.dart';

import '../support/harness.dart';

Future<void> seedPendingUploads(
  AppDatabase db, {
  required int sales,
  required int refunds,
}) async {
  for (int i = 0; i < sales; i++) {
    await db
        .into(db.sales)
        .insert(
          SalesCompanion.insert(
            receiptNo: 9000 + i,
            posId: 1,
            userId: 1,
            amount: Decimal.parse('100'),
            time: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            state: const Value(1),
          ),
        );
  }
  for (int i = 0; i < refunds; i++) {
    await db
        .into(db.refunds)
        .insert(
          RefundsCompanion.insert(
            userId: 1,
            time: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            saleReceiptNo: Value(8000 + i),
            salePosId: const Value(1),
            amount: Value(Decimal.parse('50')),
            state: const Value(1),
          ),
        );
  }
}

Future<void> pumpSyncScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
   // Тема приложения, а не умолчание Material: экран берёт цвета
   // ролями (`context.semantic`, `colorScheme`), и под голым
   // `MaterialApp` расширение `AppSemanticColors` не
   // зарегистрировано — обращение к нему падает. Это и есть та
   // причина, по которой такой тест проверял не тот продукт,
   // что уезжает заказчику.
   theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        locale: const Locale('ru'),
        supportedLocales: AppLocale.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const SyncScreen(),
      ),
    ),
  );
  for (int i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Finder syncButton() => find.ancestor(
  of: find.text('СИНХРОНИЗИРОВАТЬ'),
  matching: find.byWidgetPredicate((w) => w is ElevatedButton),
);

void main() {
  final h = E2eHarness();

  setUpAll(() async {
    await h.setUp();
    GetIt.I.registerSingleton<AppDatabase>(h.db);
  });
  tearDownAll(() => h.tearDown());

  group('Sync screen — offline honesty', () {
    testWidgets(
      'EMPTY then READ real counts; OFFLINE sync does NOT fake-zero counts '
      'and shows an honest error; no crash/block',
      (tester) async {
        await pumpSyncScreen(tester);

        expect(
          find.text('Синхронизация'),
          findsWidgets,
          reason: 'Sync screen title should be visible',
        );

        expect(await h.db.saleDao.countWithState(1), 0);
        expect(
          find.text('К выгрузке: 0'),
          findsOneWidget,
          reason: 'No pending data -> honest zero, not a fabricated number',
        );

        expect(
          syncButton(),
          findsOneWidget,
          reason: '"Sync now" button must exist',
        );
        expect(
          tester.widget<ElevatedButton>(syncButton()).onPressed,
          isNull,
          reason:
              'With no pending data the sync button must be disabled — it '
              'must not offer to "sync" nothing',
        );

        const pendingSales = 3;
        const pendingRefunds = 2;
        const expectedUpload = pendingSales + pendingRefunds;
        await seedPendingUploads(
          h.db,
          sales: pendingSales,
          refunds: pendingRefunds,
        );
        expect(await h.db.saleDao.countWithState(1), pendingSales);
        expect(await h.db.refundDao.countWithState(1), pendingRefunds);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(SyncScreen)),
        );
        await container.read(syncProvider.notifier).refresh();
        for (int i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        expect(
          find.text('К выгрузке: $expectedUpload'),
          findsOneWidget,
          reason:
              'Upload chip must show the REAL aggregated pending count from '
              'the DB ($expectedUpload), not a mock value',
        );
        expect(
          find.text('К загрузке: 0'),
          findsOneWidget,
          reason:
              'Download pending has no local source -> must be 0, not faked',
        );
        expect(
          find.text('Продажи'),
          findsWidgets,
          reason: 'Per-type "Продажи" row should be listed',
        );

        expect(
          tester.widget<ElevatedButton>(syncButton()).onPressed,
          isNotNull,
          reason: 'Sync button must be enabled when there is real pending data',
        );

        await tester.tap(syncButton());
        var sawError = false;
        for (int i = 0; i < 50; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          if (find.text('Ошибка синхронизации').evaluate().isNotEmpty) {
            sawError = true;
            break;
          }
        }
        expect(
          sawError,
          isTrue,
          reason:
              'Offline/not-configured sync must resolve to an honest error '
              'state (not spin forever, not fake success)',
        );

        expect(
          find.text('Синхронизация завершена'),
          findsNothing,
          reason: 'Offline/not-configured sync MUST NOT report fake success',
        );
        expect(
          find.text('Ошибка синхронизации'),
          findsOneWidget,
          reason: 'Offline/not-configured sync must surface an honest error',
        );
        expect(
          find.text('not_configured'),
          findsOneWidget,
          reason: 'The honest offline/not-configured reason must be visible',
        );

        expect(
          find.text('К выгрузке: $expectedUpload'),
          findsOneWidget,
          reason:
              'After a failed offline sync the REAL pending count must remain '
              '($expectedUpload) — it must not be fake-zeroed/simulated away',
        );
        expect(
          await h.db.saleDao.countWithState(1),
          pendingSales,
          reason: 'Offline sync must not mutate local sale sync-state',
        );
        expect(
          await h.db.refundDao.countWithState(1),
          pendingRefunds,
          reason: 'Offline sync must not mutate local refund sync-state',
        );

        expect(find.byType(Scaffold), findsWidgets);
        expect(
          syncButton(),
          findsOneWidget,
          reason:
              'After a failed sync the screen returns to an actionable, '
              'non-blocked state (retry possible)',
        );
        expect(
          tester.widget<ElevatedButton>(syncButton()).onPressed,
          isNotNull,
          reason:
              'Retry must remain possible (button re-enabled, data still pending)',
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}
