import 'dart:io';

import 'package:drift/native.dart';
import 'package:drift/remote.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:telepos/data/database/app_database.dart';

/// The half of the schema guards that no other test could see.
///
/// Every other database test in this repository opens the database with
/// `NativeDatabase.memory()` — 54 call sites. That runs sqlite in the *same*
/// isolate, so a failed statement arrives as a plain [SqliteException]. The
/// application does not do that: `database_connection_native.dart` opens with
/// `NativeDatabase.createInBackground`, and drift wraps anything thrown on the
/// worker isolate in a [DriftRemoteException] before it crosses back.
///
/// Every `_safe*` guard in [AppDatabase] used to be written `on
/// SqliteException`. In tests that matched; in the application it never
/// matched once. Measured 2026-08-02 on a real till still at schema v25:
/// upgrading died with `no such column: printer_type`, thrown from inside a
/// guard whose comment explained the pre-v26 case it existed to absorb. The
/// till would not start, `/api/setup/state` answered 500, and the browser
/// client read that as "not configured" and offered to run the setup wizard on
/// a configured shop.
///
/// So these tests open the database the way the application opens it. That is
/// the whole point of the file: a guard proved only against an unwrapped
/// exception is a guard proved against a case that never happens.
void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('telepos_bg_isolate');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } on FileSystemException {
        // Windows keeps the file mapped for a moment after close.
      }
    }
  });

  File dbFile() => File('${tempDir.path}${Platform.pathSeparator}store.db');

  group('what a background-isolate database actually throws', () {
    test(
      'a schema complaint arrives wrapped, not as SqliteException',
      () async {
        final db = AppDatabase(NativeDatabase.createInBackground(dbFile()));
        addTearDown(db.close);

        Object? caught;
        try {
          await db
              .customSelect('SELECT no_such_column_at_all FROM terminals')
              .get();
        } catch (e) {
          caught = e;
        }

        expect(caught, isNotNull, reason: 'the query must fail');
        expect(
          caught,
          isNot(isA<SqliteException>()),
          reason: 'this is the assumption every guard was built on, and it is '
              'false for the way the application opens its database',
        );
        expect(
          caught,
          isA<DriftRemoteException>(),
          reason: 'this is what the till gets, and what `on SqliteException` '
              'silently failed to catch',
        );
      },
    );

    test('the guard recognises it anyway', () async {
      final db = AppDatabase(NativeDatabase.createInBackground(dbFile()));
      addTearDown(db.close);

      Object? caught;
      try {
        await db.customSelect('SELECT nope FROM terminals').get();
      } catch (e) {
        caught = e;
      }

      expect(
        AppDatabase.isExpectedSchemaError(caught!, 'no such column'),
        isTrue,
        reason: 'the wrapped sqlite complaint must still be classified',
      );
    });

    test('and it does not swallow an unrelated failure', () async {
      final db = AppDatabase(NativeDatabase.createInBackground(dbFile()));
      addTearDown(db.close);

      Object? caught;
      try {
        await db.customSelect('SELECT * FROM no_such_table_here').get();
      } catch (e) {
        caught = e;
      }

      expect(
        AppDatabase.isExpectedSchemaError(caught!, 'no such column'),
        isFalse,
        reason: 'a missing *table* is not a missing column — a guard that '
            'said yes here would hide real damage',
      );
    });

    test('an unrecognised error type is not treated as expected', () {
      expect(
        AppDatabase.isExpectedSchemaError(
          StateError('something else entirely'),
          'no such column',
        ),
        isFalse,
      );
    });
  });

  group('upgrading a till that predates v26', () {
    test(
      'a database with no legacy device columns migrates instead of dying',
      () async {
        // The fixture is built by letting drift create the real schema and
        // then winding the version marker back, rather than by hand-writing a
        // v25 `CREATE TABLE` set. Hand-writing it would test a schema nobody
        // ships; this way every table is the genuine one.
        //
        // What that leaves is exactly the shape of the defect: the tables all
        // exist (so `_safeCreateTable` meets "already exists"), the seven v26
        // per-terminal device columns do not (so the raw legacy SELECT and
        // `_safeDropColumn` both meet "no such column"), and the migration
        // from 25 has to walk through all of it. Three guards, one run, over a
        // background isolate.
        final file = dbFile();
        final seed = AppDatabase(NativeDatabase.createInBackground(file));
        await seed.customSelect('SELECT 1').get();
        await seed.close();

        final raw = sqlite3.open(file.path);
        raw.execute('PRAGMA user_version = 25');
        raw.dispose();

        final db = AppDatabase(NativeDatabase.createInBackground(file));
        addTearDown(db.close);

        // Any statement forces drift to run the migration first. Before the
        // fix this threw DriftRemoteException("no such column: printer_type")
        // and the application refused to start.
        await expectLater(
          db.customSelect('SELECT 1 AS ok').get(),
          completes,
          reason: 'a pre-v26 installation must be able to upgrade at all',
        );

        final version = await db
            .customSelect('PRAGMA user_version')
            .map((r) => r.read<int>('user_version'))
            .getSingle();
        expect(
          version,
          db.schemaVersion,
          reason: 'the migration must actually land, not merely not throw',
        );
      },
    );
  });
}
