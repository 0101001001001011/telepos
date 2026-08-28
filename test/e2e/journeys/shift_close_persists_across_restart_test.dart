library;

import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';

import 'package:telepos/app/services/auto_backup_service.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/services/shift_service_impl.dart';
import 'package:telepos/domain/services/shift_service.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory tmp;
  late String dbPath;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('shift_restart');
    dbPath = '${tmp.path}${Platform.pathSeparator}store.db';
  });
  tearDown(() {
    GetIt.I.reset();
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  Future<AppDatabase> openWal() async {
    final db = AppDatabase.forTesting(NativeDatabase(File(dbPath)));
    await db.customStatement('PRAGMA journal_mode = WAL');
    return db;
  }

  ShiftService shiftServiceFor(AppDatabase db) {
    if (GetIt.I.isRegistered<AppDatabase>()) {
      GetIt.I.unregister<AppDatabase>();
    }
    GetIt.I.registerSingleton<AppDatabase>(db);
    return ShiftServiceImpl(db: db, logger: Talker());
  }

  test('closed shift stays closed after a simulated restart/update', () async {
    var db = await openWal();
    var svc = shiftServiceFor(db);

    await svc.onOpenShift(7, openingCash: Decimal.parse('5000'));
    final opened = await db.shiftDao.findOpenedShift();
    expect(opened, isNotNull, reason: 'shift opens');
    expect(opened!.isOpened, isTrue);

    await svc.onCloseShift(Decimal.parse('5000'));
    expect(
      await db.shiftDao.findOpenedShift(),
      isNull,
      reason: 'closed within the same session',
    );

    await db.close();

    db = await openWal();
    final afterRestart = await db.shiftDao.findOpenedShift();
    expect(
      afterRestart,
      isNull,
      reason:
          'REGRESSION: a closed shift must NOT reappear as open '
          'after restart/update',
    );

    final all = await db.select(db.shifts).get();
    expect(all, hasLength(1));
    expect(all.single.isOpened, isFalse, reason: 'close marker persisted');
    expect(all.single.closeTime, isNotNull, reason: 'closeTime persisted');

    await db.close();
    db = await openWal();
    expect(
      await db.shiftDao.findOpenedShift(),
      isNull,
      reason: 'second app-init does not resurrect the closed shift',
    );
    expect(await db.shiftDao.countOpened(), 0);
    await db.close();
  });

  test('createBackup checkpoints WAL so the snapshot is complete', () async {
    final db = await openWal();
    final svc = shiftServiceFor(db);
    await svc.onOpenShift(7, openingCash: Decimal.parse('2000'));
    await svc.onCloseShift(Decimal.parse('2000'));
    expect(await db.shiftDao.findOpenedShift(), isNull);

    final backupDir = '${tmp.path}${Platform.pathSeparator}backups';
    final backup = AutoBackupService(
      databasePath: dbPath,
      backupDirectory: backupDir,
      logger: Talker(),
    );
    final info = await backup.createBackup(
      description: 'closed-shift snapshot',
    );
    expect(info, isNotNull, reason: 'backup created');
    await db.close();

    final bdb = AppDatabase.forTesting(NativeDatabase(File(info!.filePath)));
    expect(
      await bdb.shiftDao.findOpenedShift(),
      isNull,
      reason: 'backup captured the closed state (WAL was checkpointed)',
    );
    await bdb.close();
  });

  test(
    'restore over a REAL stale WAL does not resurrect a closed shift',
    () async {
      final backupPath = '${tmp.path}${Platform.pathSeparator}closed_backup.db';
      {
        final side = '${tmp.path}${Platform.pathSeparator}seed.db';
        final sdb = AppDatabase.forTesting(NativeDatabase(File(side)));
        await sdb.customStatement('PRAGMA journal_mode = WAL');
        await sdb
            .into(sdb.shifts)
            .insert(
              ShiftsCompanion.insert(
                userId: 7,
                openTime: 1000,
                isOpened: false,
                isSynced: false,
                closeTime: const Value(2000),
              ),
            );
        await sdb.close();
        File(side).copySync(backupPath);
      }

      final live = AppDatabase.forTesting(NativeDatabase(File(dbPath)));
      await live.customStatement('PRAGMA journal_mode = WAL');
      await live.customStatement('PRAGMA wal_autocheckpoint = 0');
      await live
          .into(live.shifts)
          .insert(
            ShiftsCompanion.insert(
              userId: 7,
              openTime: 1000,
              isOpened: true,
              isSynced: false,
            ),
          );
      expect(
        File('$dbPath-wal').lengthSync(),
        greaterThan(0),
        reason: 'a genuine WAL with the OPEN-shift write is on disk',
      );
      final walBytes = File('$dbPath-wal').readAsBytesSync();
      final shmBytes = File('$dbPath-shm').readAsBytesSync();
      await live.close();

      final backup = AutoBackupService(
        databasePath: dbPath,
        backupDirectory: '${tmp.path}${Platform.pathSeparator}pre',
        logger: Talker(),
      );

      File(backupPath).copySync(dbPath);
      File('$dbPath-wal').writeAsBytesSync(walBytes);
      File('$dbPath-shm').writeAsBytesSync(shmBytes);
      final ghostDb = AppDatabase.forTesting(NativeDatabase(File(dbPath)));
      final ghost = await ghostDb.shiftDao.findOpenedShift();
      await ghostDb.close();
      expect(
        ghost,
        isNotNull,
        reason:
            'control: a matching stale WAL DOES replay an open shift — '
            'which is exactly the user bug the fix must prevent',
      );

      File('$dbPath-wal').writeAsBytesSync(walBytes);
      File('$dbPath-shm').writeAsBytesSync(shmBytes);
      final restored = await backup.restoreBackup(backupPath);
      expect(restored, isTrue);
      expect(
        File('$dbPath-wal').existsSync(),
        isFalse,
        reason: 'FIX: restoreBackup deleted the stale WAL sidecar',
      );
      expect(
        File('$dbPath-shm').existsSync(),
        isFalse,
        reason: 'FIX: restoreBackup deleted the stale SHM sidecar',
      );

      final fresh = AppDatabase.forTesting(NativeDatabase(File(dbPath)));
      expect(
        await fresh.shiftDao.findOpenedShift(),
        isNull,
        reason: 'closed shift stays closed after restore (no WAL replay)',
      );
      await fresh.close();
    },
  );
}
