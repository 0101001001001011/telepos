/// `SessionRegistry` — точка вставки задачи 21 закрытия долга безопасности:
/// выдача сеанса ([SessionRegistry.mint]) и его отзыв ([SessionRegistry.revoke],
/// а через него — [SessionRegistry.revokeSession]/[SessionRegistry.revokeForUser])
/// пишут в журнал событий безопасности. До этой задачи ни `mint`, ни `revoke`
/// не оставляли ни одного следа там.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/backend/security_journal.dart';
import 'package:telepos/backend/session_registry.dart';
import 'package:telepos/data/database/app_database.dart';

void main() {
  late AppDatabase db;
  late SecurityJournal journal;
  late SessionRegistry registry;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    journal = SecurityJournal(db.securityEventDao);
    registry = SessionRegistry(journal: journal);
  });

  tearDown(() => db.close());

  test('ГЛАВНЫЙ ТЕСТ: mint пишет session.issued с userId и terminalId', () async {
    registry.mint(
      userId: 7,
      name: 'Айгуль',
      role: 'cashier',
      permissions: const {'nav.sale'},
      operatingMode: 0,
      pointMode: 'cashier',
      shiftOpen: true,
      terminalId: 42,
    );
    // mint — синхронный, а запись в журнал — unawaited: даём событийному
    // циклу дойти до неё, прежде чем читать базу.
    await Future<void>.delayed(Duration.zero);

    final rows = await db.securityEventDao.findAll();
    expect(rows, hasLength(1));
    expect(rows.single.eventType, SecurityEventType.sessionIssued);
    expect(rows.single.outcome, SecurityOutcome.success);
    expect(rows.single.userId, 7);
    expect(rows.single.terminalId, 42);
  });

  test(
    'ГЛАВНЫЙ ТЕСТ: revoke живого токена пишет session.revoked с тем же '
    'userId/terminalId, что нёс сеанс',
    () async {
      final session = registry.mint(
        userId: 7,
        name: 'Айгуль',
        role: 'cashier',
        permissions: const {},
        operatingMode: 0,
        pointMode: 'cashier',
        shiftOpen: false,
        terminalId: 42,
      );
      await Future<void>.delayed(Duration.zero);

      registry.revoke(session.token);
      await Future<void>.delayed(Duration.zero);

      final rows = await db.securityEventDao.findAll();
      final revoked = rows.where(
        (r) => r.eventType == SecurityEventType.sessionRevoked,
      );
      expect(revoked, hasLength(1));
      expect(revoked.single.userId, 7);
      expect(revoked.single.terminalId, 42);
    },
  );

  test('revoke токена, которого уже нет, не пишет вторую запись', () async {
    final session = registry.mint(
      userId: 7,
      name: 'Айгуль',
      role: 'cashier',
      permissions: const {},
      operatingMode: 0,
      pointMode: 'cashier',
      shiftOpen: false,
      terminalId: 1,
    );
    await Future<void>.delayed(Duration.zero);

    registry.revoke(session.token);
    registry.revoke(session.token); // второй раз — токена уже нет.
    await Future<void>.delayed(Duration.zero);

    final rows = await db.securityEventDao.findAll();
    final revoked = rows.where(
      (r) => r.eventType == SecurityEventType.sessionRevoked,
    );
    expect(
      revoked,
      hasLength(1),
      reason: 'отзыв несуществующего токена — не событие: отзывать нечего',
    );
  });

  test(
    'revokeForUser пишет по одной записи session.revoked на каждый '
    'погашенный сеанс пользователя',
    () async {
      registry.mint(
        userId: 7,
        name: 'Айгуль',
        role: 'cashier',
        permissions: const {},
        operatingMode: 0,
        pointMode: 'cashier',
        shiftOpen: false,
        terminalId: 1,
      );
      registry.mint(
        userId: 7,
        name: 'Айгуль',
        role: 'cashier',
        permissions: const {},
        operatingMode: 0,
        pointMode: 'cashier',
        shiftOpen: false,
        terminalId: 2,
      );
      await Future<void>.delayed(Duration.zero);

      registry.revokeForUser(7);
      await Future<void>.delayed(Duration.zero);

      final rows = await db.securityEventDao.findAll();
      final revoked = rows.where(
        (r) => r.eventType == SecurityEventType.sessionRevoked,
      );
      expect(revoked, hasLength(2));
    },
  );

  test('без журнала (null) mint/revoke работают как раньше, без падения', () {
    final bare = SessionRegistry();
    final session = bare.mint(
      userId: 1,
      name: 'A',
      role: 'cashier',
      permissions: const {},
      operatingMode: 0,
      pointMode: 'cashier',
      shiftOpen: false,
      terminalId: 1,
    );
    expect(bare.revoke(session.token), isTrue);
  });
}
