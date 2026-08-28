/// `LocalTerminalRepository.delete` — единственная реализация удаления
/// терминала (докстринг класса, зовётся и с провода, и с десктопных
/// настроек напрямую) — точка вставки задачи 21 закрытия долга безопасности.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/backend/security_journal.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/terminal/terminal_repository_local.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

void main() {
  late AppDatabase db;
  late SecurityJournal journal;
  late LocalTerminalRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    journal = SecurityJournal(db.securityEventDao);
    repo = LocalTerminalRepository(db, journal: journal);
  });

  tearDown(() => db.close());

  test(
    'ГЛАВНЫЙ ТЕСТ: удаление терминала пишет terminal.deleted с id '
    'удалённого терминала',
    () async {
      final terminal = (await repo.register(name: 'Касса у окна')).terminal;

      await repo.delete(terminal.id);

      final rows = await db.securityEventDao.findAll();
      expect(rows, hasLength(1));
      expect(rows.single.eventType, SecurityEventType.terminalDeleted);
      expect(rows.single.outcome, SecurityOutcome.success);
      expect(rows.single.terminalId, terminal.id);
    },
  );

  test('отказавшее удаление (несуществующий id) не пишет ничего', () async {
    await expectLater(() => repo.delete(999), throwsA(isA<WireRefusal>()));

    final rows = await db.securityEventDao.findAll();
    expect(rows, isEmpty);
  });

  test('отказавшее удаление isSelf-терминала не пишет ничего', () async {
    final self = await db.terminalDao.ensureSelf(fallbackName: 'Касса-1');

    await expectLater(
      () => repo.delete(self.id),
      throwsA(isA<WireRefusal>()),
    );

    final rows = await db.securityEventDao.findAll();
    expect(rows, isEmpty);
  });

  test('без журнала (null) удаление работает как раньше, без падения', () async {
    final bare = LocalTerminalRepository(db);
    final terminal = (await bare.register(name: 'Касса без журнала')).terminal;

    await bare.delete(terminal.id);

    expect(await db.terminalDao.findById(terminal.id), isNull);
  });
}
