/// `buildWireDeniedJournalHandler` — БЛОКЕР 3 закрытия долга безопасности
/// (2026-08-22): неаутентифицированный не может расти боевую базу без
/// предела.
///
/// До этой правки каждый отказ сторожа писал строку транзакцией в ту же базу,
/// которой касса принимает деньги, без ограничителя, склейки и потолка —
/// `{"op":"nope"}`, посланный сколько угодно раз на одной открытой
/// QUIC-сессии (соединение предшествует входу), рос базу навсегда. Этот
/// набор проверяет оба хода решения по отдельности: `unknown_op` не
/// журналируется вовсе, а повторные отказы одной сессии в окне склеиваются
/// в одну строку — и что настоящие отказы (`forbidden`/`unauthorized`) при
/// этом не пропадают целиком, только не растут без предела.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/backend/security_journal.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/wire/wire_guard.dart';

void main() {
  late AppDatabase db;
  late SecurityJournal journal;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    journal = SecurityJournal(db.securityEventDao);
  });

  tearDown(() async {
    await db.close();
  });

  /// Ждёт, пока все `unawaited` записи журнала, поставленные этим тиком
  /// event loop, реально дойдут до базы — `journal.record` асинхронный и
  /// не awaited вызывающим (`buildWireDeniedJournalHandler`, докстринг про
  /// `unawaited`), поэтому проверка сразу после вызова обработчика читала бы
  /// базу до того, как запись успела улечься.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test(
    'ГЛАВНЫЙ ТЕСТ: unknown_op не журналируется вовсе, сколько раз ни '
    'повтори — это и есть путь неаутентифицированного нападающего',
    () async {
      final onDenied = buildWireDeniedJournalHandler(
        journal: journal,
        resolveTerminal: (_) => null,
      );

      for (var i = 0; i < 500; i++) {
        onDenied(
          'nope',
          const WireDenied('unknown_op', 'операция не объявлена'),
          1,
          const {},
        );
      }
      await settle();

      final rows = await db.securityEventDao.findAll();
      expect(
        rows,
        isEmpty,
        reason:
            'unknown_op — расхождение протокола, не событие безопасности; '
            'ни один залп по нему не имеет права попасть в боевую базу',
      );
    },
  );

  test(
    'ГЛАВНЫЙ ТЕСТ: повторные forbidden одной сессии в окне склеиваются в '
    'одну строку, а не растут без предела',
    () async {
      final now = DateTime.utc(2026, 8, 22, 12);
      final onDenied = buildWireDeniedJournalHandler(
        journal: journal,
        resolveTerminal: (_) => 7,
        coalesceWindow: const Duration(seconds: 5),
        clock: () => now,
      );

      for (var i = 0; i < 500; i++) {
        onDenied(
          'terminals.rename',
          const WireDenied('forbidden', 'нет права'),
          1,
          const {},
        );
      }
      await settle();

      final rows = await db.securityEventDao.findAll();
      expect(
        rows,
        hasLength(1),
        reason: '500 отказов одной сессии в одно и то же мгновение — одна '
            'строка, не 500',
      );
      expect(rows.single.outcome, 'forbidden');
    },
  );

  test(
    'настоящий отказ не пропадает целиком: серия, растянутая дольше окна, '
    'пишет по строке на каждый выход за окно',
    () async {
      var now = DateTime.utc(2026, 8, 22, 12);
      final onDenied = buildWireDeniedJournalHandler(
        journal: journal,
        resolveTerminal: (_) => 7,
        coalesceWindow: const Duration(seconds: 5),
        clock: () => now,
      );

      // Первый отказ сессии — пишется.
      onDenied(
        'terminals.rename',
        const WireDenied('forbidden', 'нет права'),
        1,
        const {},
      );
      // Тут же второй — склеен окном.
      onDenied(
        'terminals.rename',
        const WireDenied('forbidden', 'нет права'),
        1,
        const {},
      );
      // Окно прошло — третий пишется снова.
      now = now.add(const Duration(seconds: 6));
      onDenied(
        'terminals.rename',
        const WireDenied('forbidden', 'нет права'),
        1,
        const {},
      );
      await settle();

      final rows = await db.securityEventDao.findAll();
      expect(
        rows,
        hasLength(2),
        reason:
            'серия видна журналу как серия (две строки на три отказа, '
            'разнесённых окном), а не как ноль строк',
      );
    },
  );

  test(
    'разные сессии не склеиваются друг с другом — у каждой своя первая '
    'строка',
    () async {
      final now = DateTime.utc(2026, 8, 22, 12);
      final onDenied = buildWireDeniedJournalHandler(
        journal: journal,
        resolveTerminal: (_) => null,
        clock: () => now,
      );

      onDenied(
        'terminals.rename',
        const WireDenied('unauthorized', 'нужен сеанс'),
        1,
        const {},
      );
      onDenied(
        'terminals.rename',
        const WireDenied('unauthorized', 'нужен сеанс'),
        2,
        const {},
      );
      onDenied(
        'terminals.rename',
        const WireDenied('unauthorized', 'нужен сеанс'),
        3,
        const {},
      );
      await settle();

      final rows = await db.securityEventDao.findAll();
      expect(
        rows,
        hasLength(3),
        reason: 'три разные QUIC-сессии — три строки, склейка ключуется '
            'сессией, не кодом отказа',
      );
    },
  );

  test(
    'guard_failed проходит через ту же склейку, что forbidden/unauthorized '
    '— не выброшен и не льётся без предела',
    () async {
      final now = DateTime.utc(2026, 8, 22, 12);
      final onDenied = buildWireDeniedJournalHandler(
        journal: journal,
        resolveTerminal: (_) => null,
        clock: () => now,
      );

      for (var i = 0; i < 10; i++) {
        onDenied(
          'setup.complete',
          const WireDenied('guard_failed', 'StateError'),
          1,
          const {},
        );
      }
      await settle();

      final rows = await db.securityEventDao.findAll();
      expect(rows, hasLength(1));
      expect(rows.single.outcome, 'guard_failed');
    },
  );
}
