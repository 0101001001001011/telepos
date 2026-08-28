import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/security_event_dao.dart';

/// Задача 20 (план «замок кассы», фаза 8): таблица и цепочка отпечатков
/// журнала событий безопасности (И66–И69). Главный тест файла —
/// «цепочка обнаруживает вырезание» ниже: три подряд идущие записи образуют
/// цепочку, вырезание средней должно быть обнаружено проверкой.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('схема поднялась минимум до 34 (таблица журнала уже есть)', () {
    expect(db.schemaVersion, greaterThanOrEqualTo(34));
  });

  test('пустой журнал: цепочка цела (нечему рваться)', () async {
    expect(await db.securityEventDao.firstBrokenLinkId(), isNull);
  });

  test('первая запись журнала несёт genesisFingerprint как отпечаток '
      'предыдущей', () async {
    final first = await db.securityEventDao.record(
      occurredAtEpochMs: 1000,
      userId: 1,
      terminalId: 1,
      eventType: 'auth.login',
      outcome: 'success',
      correlationId: 'corr-1',
    );

    expect(first.previousFingerprint, SecurityEventDao.genesisFingerprint);
  });

  test(
    'ГЛАВНЫЙ ТЕСТ: три записи подряд образуют цепочку; вырезание средней '
    'делает цепочку разорванной, и проверка это находит',
    () async {
      final e1 = await db.securityEventDao.record(
        occurredAtEpochMs: 1000,
        userId: 1,
        terminalId: 1,
        eventType: 'auth.login',
        outcome: 'success',
        correlationId: 'corr-1',
      );
      final e2 = await db.securityEventDao.record(
        occurredAtEpochMs: 2000,
        userId: 1,
        terminalId: 1,
        eventType: 'session.revoke',
        outcome: 'success',
        correlationId: 'corr-2',
      );
      final e3 = await db.securityEventDao.record(
        occurredAtEpochMs: 3000,
        userId: 2,
        terminalId: 1,
        eventType: 'auth.login',
        outcome: 'failure',
        correlationId: 'corr-3',
      );

      // Цепочка выстроена: каждая следующая ссылается на отпечаток
      // предыдущей, и три подряд идущих отпечатка не совпадают друг с
      // другом (иначе проверка ниже ничего не доказывала бы — совпадение
      // означало бы, что отпечаток не зависит от содержимого).
      expect(e1.previousFingerprint, SecurityEventDao.genesisFingerprint);
      expect(e2.previousFingerprint, isNot(e1.previousFingerprint));
      expect(e3.previousFingerprint, isNot(e2.previousFingerprint));

      // Цела до вмешательства.
      expect(
        await db.securityEventDao.firstBrokenLinkId(),
        isNull,
        reason: 'нетронутая цепочка обязана проверяться как целая',
      );

      // Вырезаем среднюю запись в обход DAO — напрямую через drift, потому
      // что через сам DAO вырезать нечем (в нём нет ни update, ни delete,
      // см. докстринг SecurityEventDao).
      final deleted = await (db.delete(
        db.securityEvents,
      )..where((t) => t.id.equals(e2.id))).go();
      expect(deleted, 1, reason: 'фикстура обязана реально вырезать строку');

      // Проверка обязана найти разрыв — и найти его на первой уцелевшей
      // записи после дыры, а не молчать и не указывать на что-то другое.
      final brokenAt = await db.securityEventDao.firstBrokenLinkId();
      expect(
        brokenAt,
        e3.id,
        reason:
            'после вырезания e2 запись e3 всё ещё ссылается на отпечаток '
            'вырезанной e2 — разрыв обязан обнаружиться именно на ней',
      );
    },
  );

  group('БЛОКЕР 2 закрытия долга безопасности — усечение хвоста', () {
    // Доказывает границу, названную в брифе БЛОКЕРА 2 дословно: цепочка
    // отпечатков идёт только вперёд от genesis и останавливается на
    // последней уцелевшей строке — вырезание записей С КОНЦА не оставляет
    // разрыва, который она могла бы найти. Тест ниже красный без
    // `isTailTruncated` бы не был — он подтверждает то, что
    // `firstBrokenLinkId` в это не видит вовсе, не заменяет её.
    test(
      'ГЛАВНЫЙ ТЕСТ: firstBrokenLinkId не видит удаление хвоста — '
      'isTailTruncated видит',
      () async {
        for (var i = 0; i < 3; i++) {
          await db.securityEventDao.record(
            occurredAtEpochMs: 1000 + i,
            userId: 1,
            terminalId: 1,
            eventType: 'auth.login',
            outcome: 'success',
            correlationId: 'corr-$i',
          );
        }

        expect(
          await db.securityEventDao.isTailTruncated(),
          isFalse,
          reason: 'нетронутый журнал — seq и MAX(id) совпадают',
        );

        // Вырезаем последнюю запись — id=3, самый большой в таблице —
        // ровно то, чего хочет злоумышленник: стереть то, что он только
        // что сделал.
        final maxIdRow = await db.customSelect(
          'SELECT MAX(id) AS max_id FROM security_events',
        ).getSingle();
        final lastId = maxIdRow.data['max_id'] as int;
        final deleted = await (db.delete(
          db.securityEvents,
        )..where((t) => t.id.equals(lastId))).go();
        expect(deleted, 1, reason: 'фикстура обязана реально вырезать хвост');

        // То самое, что называет брифинг БЛОКЕРА 2: цепочка вперёд от
        // genesis не находит здесь ничего — она физически не видит
        // строку, которой больше нет, и останавливается на последней
        // уцелевшей, как на целой.
        expect(
          await db.securityEventDao.firstBrokenLinkId(),
          isNull,
          reason:
              'ГРАНИЦА: удаление хвоста НЕ обнаруживается цепочкой '
              'отпечатков — это и есть дыра, которую закрывает '
              'isTailTruncated отдельной сверкой',
        );

        // Отдельная сверка (sqlite_sequence.seq против MAX(id)) находит
        // то, что цепочка не могла найти структурно.
        expect(
          await db.securityEventDao.isTailTruncated(),
          isTrue,
          reason:
              'seq (высший когда-либо выданный id) теперь больше '
              'MAX(id) — это и есть признак усечённого хвоста',
        );
      },
    );

    test(
      'вырезание из середины НЕ считается усечением хвоста — seq и '
      'MAX(id) не расходятся',
      () async {
        final rows = <SecurityEvent>[];
        for (var i = 0; i < 3; i++) {
          rows.add(
            await db.securityEventDao.record(
              occurredAtEpochMs: 1000 + i,
              userId: 1,
              terminalId: 1,
              eventType: 'auth.login',
              outcome: 'success',
              correlationId: 'corr-$i',
            ),
          );
        }

        await (db.delete(
          db.securityEvents,
        )..where((t) => t.id.equals(rows[1].id))).go();

        expect(
          await db.securityEventDao.isTailTruncated(),
          isFalse,
          reason:
              'MAX(id) остался прежним (id последней, уцелевшей строки не '
              'менялся) — этот вид вырезания ловит firstBrokenLinkId, не '
              'эта сверка; см. тест выше про то, что каждая ловит своё',
        );
      },
    );

    test('пустой журнал — не усечён (стирать нечего)', () async {
      expect(await db.securityEventDao.isTailTruncated(), isFalse);
    });
  });

  group('И68 — маскирование секретов', () {
    // Правка волны закрытия долга безопасности (2026-08-22): здесь раньше
    // стоял тест «запись о входе не содержит ни PIN, ни хэша, ни токена»,
    // который сам составлял `correlationId` через `fingerprintOfSecret` и
    // никуда настоящий PIN не передавал — он не мог покраснеть ни при каком
    // поведении боевого кода, только при поведении самого себя. Настоящая
    // улика — прогнать `LocalAuthRepository.login` с известным PIN через
    // настоящую точку вставки: `test/data/auth/local_auth_repository_
    // security_journal_test.dart`, «ГЛАВНЫЙ ТЕСТ: запись о входе не несёт
    // сырой PIN». `fingerprintOfSecret` сама снята за отсутствием
    // вызывающего (докстринг `SecurityEventDao`) — второй тест здесь,
    // проверявший только её саму, снят вместе с ней.

    test(
      'в схеме таблицы нет колонки, приглашающей хранить секрет как есть',
      () {
        final columnNames = db.securityEvents.$columns
            .map((c) => c.name.toLowerCase())
            .toSet();
        for (final forbidden in ['pin', 'password', 'hash', 'token', 'secret']) {
          expect(
            columnNames.any((name) => name.contains(forbidden)),
            isFalse,
            reason:
                'колонка, содержащая "$forbidden" в имени, — прямое '
                'приглашение записать секрет как есть; нашлись: '
                '${columnNames.where((n) => n.contains(forbidden))}',
          );
        }
      },
    );
  });
}
