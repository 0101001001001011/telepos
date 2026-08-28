/// `SecurityJournal` — обёртка над `SecurityEventDao.record`, задача 21
/// закрытия долга безопасности («замок кассы», фаза 8).
///
/// Задача 20 построила таблицу и цепочку (`test/data/database/security_journal_test.dart`)
/// и уже доказала, что цепочка обнаруживает вырезание. Этот набор проверяет
/// то, что добавляет именно [SecurityJournal]: словарь родов события,
/// автоматический `correlationId` и — главное — что отказ записи не роняет
/// вызывающего.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/backend/security_journal.dart';
import 'package:telepos/data/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('record пишет строку с переданными полями', () async {
    final journal = SecurityJournal(db.securityEventDao);

    await journal.record(
      eventType: SecurityEventType.sessionIssued,
      outcome: SecurityOutcome.success,
      terminalId: 7,
      userId: 3,
    );

    final rows = await db.securityEventDao.findAll();
    expect(rows, hasLength(1));
    expect(rows.single.eventType, SecurityEventType.sessionIssued);
    expect(rows.single.outcome, SecurityOutcome.success);
    expect(rows.single.terminalId, 7);
    expect(rows.single.userId, 3);
  });

  test('userId остаётся null, если не передан — событие без опознанного '
      'субъекта', () async {
    final journal = SecurityJournal(db.securityEventDao);

    await journal.record(
      eventType: SecurityEventType.authLogin,
      outcome: 'wrongPin',
      terminalId: 1,
    );

    final rows = await db.securityEventDao.findAll();
    expect(rows.single.userId, isNull);
  });

  test(
    'correlationId генерируется сам, если не передан, и разный на каждый '
    'вызов',
    () async {
      final journal = SecurityJournal(db.securityEventDao);

      await journal.record(
        eventType: SecurityEventType.authLogin,
        outcome: SecurityOutcome.success,
        terminalId: 1,
      );
      await journal.record(
        eventType: SecurityEventType.authLogin,
        outcome: SecurityOutcome.success,
        terminalId: 1,
      );

      final rows = await db.securityEventDao.findAll();
      expect(rows, hasLength(2));
      expect(rows[0].correlationId, isNotEmpty);
      expect(rows[1].correlationId, isNotEmpty);
      expect(
        rows[0].correlationId,
        isNot(rows[1].correlationId),
        reason: 'два разных действия не обязаны делить один и тот же '
            'сквозной идентификатор',
      );
    },
  );

  test('переданный correlationId едет как есть, а не заменяется своим', () async {
    final journal = SecurityJournal(db.securityEventDao);

    await journal.record(
      eventType: SecurityEventType.authLogin,
      outcome: SecurityOutcome.success,
      terminalId: 1,
      correlationId: 'my-corr-id',
    );

    final rows = await db.securityEventDao.findAll();
    expect(rows.single.correlationId, 'my-corr-id');
  });

  // ГЛАВНЫЙ ТЕСТ файла: осторожность из брифа задачи 21 — «запись в журнал
  // не должна ронять операцию» — измерена, а не продекларирована. Без
  // try/catch внутри `record` этот тест краснеет `SqliteException`,
  // всплывшим из таблицы, которой больше нет, вместо тихого `completes`.
  //
  // Таблица дропается напрямую, а не база закрывается: закрытая
  // `NativeDatabase.memory()` в тестовом окружении не отказывает следующему
  // запросу (измерено отдельно) — таблицы, которой нет, для этого надёжнее.
  test(
    'ГЛАВНЫЙ ТЕСТ: отказ записи (таблицы больше нет) не бросает исключение '
    'наружу — предупреждение в лог, а не падение вызывающего',
    () async {
      final talker = Talker();
      final journal = SecurityJournal(db.securityEventDao, logger: talker);

      await db.customStatement('DROP TABLE security_events');

      await expectLater(
        journal.record(
          eventType: SecurityEventType.authLogin,
          outcome: SecurityOutcome.success,
          terminalId: 1,
        ),
        completes,
      );

      expect(
        talker.history,
        isNotEmpty,
        reason: 'отказ записи не имеет права пройти молча — см. докстринг '
            'SecurityJournal.record',
      );
    },
  );

  group(
    'checkSecurityJournalIntegrityAtBoot — пункт 6 брифа закрытия долга '
    'безопасности',
    () {
      // ГЛАВНЫЙ ТЕСТ группы: до этой функции findAll/firstBrokenLinkId не
      // звала ни одна строка `lib/` — читателя у журнала не было вовсе.
      // Проверяет, что вызов реально читает цепочку (не заглушка,
      // всегда отвечающая «всё цело») и пишет свой результат в журнал.
      test(
        'ГЛАВНЫЙ ТЕСТ: цела — пишет journalIntegrityChecked/intact',
        () async {
          final journal = SecurityJournal(db.securityEventDao);
          await journal.record(
            eventType: SecurityEventType.authLogin,
            outcome: SecurityOutcome.success,
            terminalId: 1,
          );

          await checkSecurityJournalIntegrityAtBoot(
            dao: db.securityEventDao,
            journal: journal,
            terminalId: 1,
          );

          final rows = await db.securityEventDao.findAll();
          final checkRows = rows.where(
            (r) => r.eventType == SecurityEventType.journalIntegrityChecked,
          );
          expect(checkRows, hasLength(1));
          expect(checkRows.single.outcome, 'intact');
        },
      );

      test(
        'ГЛАВНЫЙ ТЕСТ: разорвана (вырезание из середины) — пишет outcome, '
        'называющий broken_link',
        () async {
          final journal = SecurityJournal(db.securityEventDao);
          final e1 = await db.securityEventDao.record(
            occurredAtEpochMs: 1000,
            terminalId: 1,
            eventType: 'auth.login',
            outcome: 'success',
            correlationId: 'c1',
          );
          final e2 = await db.securityEventDao.record(
            occurredAtEpochMs: 2000,
            terminalId: 1,
            eventType: 'auth.login',
            outcome: 'success',
            correlationId: 'c2',
          );
          final e3 = await db.securityEventDao.record(
            occurredAtEpochMs: 3000,
            terminalId: 1,
            eventType: 'auth.login',
            outcome: 'success',
            correlationId: 'c3',
          );
          // Держим e1 не выброшенным — тестовые тулы Dart не любят
          // "unused var"; используется ниже как факт, что цепочка была
          // выстроена нормально.
          expect(e1.id, isNotNull);
          await (db.delete(
            db.securityEvents,
          )..where((t) => t.id.equals(e2.id))).go();

          await checkSecurityJournalIntegrityAtBoot(
            dao: db.securityEventDao,
            journal: journal,
            terminalId: 1,
          );

          final rows = await db.securityEventDao.findAll();
          final checkRows = rows.where(
            (r) => r.eventType == SecurityEventType.journalIntegrityChecked,
          );
          expect(checkRows, hasLength(1));
          expect(checkRows.single.outcome, 'broken_link:${e3.id}');
        },
      );

      test(
        'усечён хвост — пишет outcome, называющий tail_truncated',
        () async {
          final journal = SecurityJournal(db.securityEventDao);
          for (var i = 0; i < 2; i++) {
            await db.securityEventDao.record(
              occurredAtEpochMs: 1000 + i,
              terminalId: 1,
              eventType: 'auth.login',
              outcome: 'success',
              correlationId: 'c$i',
            );
          }
          final maxIdRow = await db.customSelect(
            'SELECT MAX(id) AS max_id FROM security_events',
          ).getSingle();
          await (db.delete(db.securityEvents)
                ..where((t) => t.id.equals(maxIdRow.data['max_id'] as int)))
              .go();

          await checkSecurityJournalIntegrityAtBoot(
            dao: db.securityEventDao,
            journal: journal,
            terminalId: 1,
          );

          final rows = await db.securityEventDao.findAll();
          final checkRows = rows.where(
            (r) => r.eventType == SecurityEventType.journalIntegrityChecked,
          );
          expect(checkRows, hasLength(1));
          expect(checkRows.single.outcome, 'tail_truncated');
        },
      );

      test(
        'отказ самой проверки (таблицы больше нет) не бросает исключение '
        'наружу — касса не имеет права не подняться из-за этого',
        () async {
          final talker = Talker();
          final journal = SecurityJournal(db.securityEventDao, logger: talker);
          await db.customStatement('DROP TABLE security_events');

          await expectLater(
            checkSecurityJournalIntegrityAtBoot(
              dao: db.securityEventDao,
              journal: journal,
              terminalId: 1,
              logger: talker,
            ),
            completes,
          );
        },
      );
    },
  );
}
