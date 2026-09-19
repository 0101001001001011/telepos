@Tags(['manual'])
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/terminal/terminal_repository_local.dart';
import 'package:telepos/domain/sale/payment_service.dart';

/// Разовая проверка миграции v38 на **копии живой базы**. Путь задаётся
/// переменной окружения LIVE_DB.
void main() {
  test('копия живой базы поднимается до v38 и терминалы не немеют', () async {
    final path = Platform.environment['LIVE_DB'];
    expect(path, isNotNull, reason: 'LIVE_DB не задана');
    final file = File(path!);
    expect(file.existsSync(), isTrue, reason: path);

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);

    final before = await db
        .customSelect('SELECT count(*) c FROM terminals')
        .getSingle();
    // ignore: avoid_print
    print('terminals rows: ${before.read<int>('c')}');

    final version = await db.customSelect('PRAGMA user_version').getSingle();
    // ignore: avoid_print
    print('user_version after open: ${version.read<int>('user_version')}');

    final sales = await db
        .customSelect('SELECT count(*) c FROM sales')
        .getSingle();
    // ignore: avoid_print
    print('sales rows: ${sales.read<int>('c')}');

    final terminals = await LocalTerminalRepository(db).list();
    for (final terminal in terminals) {
      // ignore: avoid_print
      print(
        'terminal #${terminal.id} "${terminal.name}" '
        'allowed=${terminal.allowedPaymentTypes}',
      );
      expect(terminal.allowedPaymentTypes, isEmpty);
      for (final type in PaymentType.values) {
        expect(terminal.allows(type), isTrue);
      }
    }

    final integrity = await db
        .customSelect('PRAGMA integrity_check')
        .getSingle();
    // ignore: avoid_print
    print('integrity: ${integrity.read<String>('integrity_check')}');
    expect(integrity.read<String>('integrity_check'), 'ok');
  });
}
