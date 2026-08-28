import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/print/print_job.dart';
import 'package:telepos/domain/print/print_queue.dart';

/// Общий наполненный набор для всех проверок этого файла (правило нуля
/// скилла `qa-depth`).
///
/// **Три терминала и три кассы, и они намеренно не совпадают.** И29 говорит,
/// что владелец задания — «терминал и касса», то есть владельцев два. Номера
/// терминалов (1, 2, 7) и касс (101, 102, 107) взяты из непересекающихся
/// диапазонов, и пары перекрёстные: один терминал обслуживает две кассы, одна
/// касса работает на двух терминалах. Совпадающие номера скрыли бы
/// перепутанные местами поля — самый дешёвый способ получить задание,
/// приписанное не той смене.
///
/// **Границы дат настоящие.** Смена, начатая 31 декабря и закрытая 1 января,
/// — обычный день магазина, и именно на ней ломаются сравнения сроков,
/// написанные через сравнение дней. Все моменты — UTC, чтобы прогон в другом
/// часовом поясе проверял то же самое.
const int terminalTill1 = 1;
const int terminalTill2 = 2;
const int terminalSelfService = 7;

const int posMain = 101;
const int posSecond = 102;
const int posSelfService = 107;

final DateTime yearRolloverBefore = DateTime.utc(2026, 12, 31, 23, 59, 59, 900);
final DateTime yearRolloverAfter = DateTime.utc(2027, 1, 1, 0, 0, 0, 100);

/// Байты чека несут кириллицу в CP866 и латиницу — домен обязан пронести их
/// без изменений, а не «нормализовать».
Uint8List seedPayloadBytes(String marker) {
  return Uint8List.fromList(<int>[
    0x1b, 0x40, // ESC @
    0x1b, 0x74, 0x11, // выбор кодовой страницы CP866
    0x8a, 0x80, 0x91, 0x91, 0x80, // «КАССА» в CP866
    ...marker.codeUnits,
    0x0a,
  ]);
}

PrintJob seedJob({
  required String id,
  required int terminalId,
  int posId = posMain,
  DateTime? createdAt,
  DateTime? expiresAt,
}) {
  final created = createdAt ?? yearRolloverBefore;
  return PrintJob(
    id: id,
    terminalId: terminalId,
    posId: posId,
    payloadBytes: seedPayloadBytes(id),
    createdAt: created,
    expiresAt: expiresAt ?? created.add(const Duration(minutes: 30)),
  );
}

/// Четыре задания, три терминала, три кассы, пары перекрёстные: терминал 1
/// обслуживает кассы 101 и 102, а касса 101 работает на терминалах 1 и 2.
/// Выборка по терминалу 1 обязана дать задания 1 и 2, выборка по кассе 101 —
/// задания 1 и 3. Наборы разные, значит поля действительно независимы.
List<PrintJob> seedJobs() => <PrintJob>[
  seedJob(
    id: 'receipt-2026-12-31-0001',
    terminalId: terminalTill1,
    posId: posMain,
  ),
  seedJob(
    id: 'receipt-2026-12-31-0002',
    terminalId: terminalTill1,
    posId: posSecond,
  ),
  seedJob(
    id: 'receipt-2026-12-31-0003',
    terminalId: terminalTill2,
    posId: posMain,
  ),
  seedJob(
    id: 'receipt-2027-01-01-0001',
    terminalId: terminalSelfService,
    posId: posSelfService,
  ),
];

void main() {
  group('владелец задания — терминал и касса (И29)', () {
    test('задание без терминала не строится: 0 отвергнут', () {
      expect(
        () => PrintJob(
          id: 'receipt-1',
          terminalId: 0,
          posId: posMain,
          payloadBytes: seedPayloadBytes('receipt-1'),
          createdAt: yearRolloverBefore,
          expiresAt: yearRolloverAfter,
        ),
        throwsA(isA<ArgumentError>()),
        reason:
            '0 — обычная заглушка для «терминал неизвестен»; задание без '
            'владельца печатать некому и повторять некому',
      );
    });

    test('задание без кассы не строится: 0 отвергнут', () {
      expect(
        () => PrintJob(
          id: 'receipt-1',
          terminalId: terminalTill1,
          posId: 0,
          payloadBytes: seedPayloadBytes('receipt-1'),
          createdAt: yearRolloverBefore,
          expiresAt: yearRolloverAfter,
        ),
        throwsA(isA<ArgumentError>()),
        reason:
            'И29: владелец — терминал **и касса**; чек без кассы не попадёт '
            'ни в чью смену',
      );
    });

    test('отрицательные идентификаторы владельцев отвергнуты', () {
      expect(
        () => seedJob(id: 'receipt-1', terminalId: -3),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => seedJob(id: 'receipt-1', terminalId: terminalTill1, posId: -3),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('терминал и касса — независимые поля, а не одно и то же', () {
      final jobs = seedJobs();

      final byTerminal1 = jobs
          .where((j) => j.terminalId == terminalTill1)
          .map((j) => j.id)
          .toList();
      final byPosMain = jobs
          .where((j) => j.posId == posMain)
          .map((j) => j.id)
          .toList();

      expect(byTerminal1, <String>[
        'receipt-2026-12-31-0001',
        'receipt-2026-12-31-0002',
      ]);
      expect(byPosMain, <String>[
        'receipt-2026-12-31-0001',
        'receipt-2026-12-31-0003',
      ]);
      expect(
        byTerminal1,
        isNot(byPosMain),
        reason:
            'если бы поля были одним и тем же (или перепутаны местами), эти '
            'две выборки совпали бы',
      );
    });

    test('владельцы переживают все переходы состояния', () {
      final job = seedJob(
        id: 'receipt-1',
        terminalId: terminalSelfService,
        posId: posSelfService,
      );
      final afterTransitions = job
          .beginAttempt()
          .failWith('Нет бумаги')
          .renewedUntil(
            job.expiresAt.add(const Duration(hours: 1)),
            now: job.createdAt,
          );

      expect(afterTransitions.terminalId, terminalSelfService);
      expect(afterTransitions.posId, posSelfService);
    });
  });

  group('идемпотентность: идентификатор задаёт вызывающий (И29)', () {
    test('задание несёт ровно тот идентификатор, что дал вызывающий', () {
      final job = seedJob(id: 'sale-42-receipt', terminalId: terminalTill1);
      expect(
        job.id,
        'sale-42-receipt',
        reason:
            'идентификатор, порождённый внутри, идемпотентности не даёт: '
            'повтор получил бы новый и напечатался бы вторым чеком',
      );
    });

    test('два задания с одним идентификатором — это одно задание', () {
      final first = seedJob(id: 'sale-42-receipt', terminalId: terminalTill1);
      final repeat = seedJob(id: 'sale-42-receipt', terminalId: terminalTill1);

      expect(first, equals(repeat));
      expect(first.hashCode, repeat.hashCode);
      expect(
        <PrintJob>{first, repeat},
        hasLength(1),
        reason: 'повтор после таймаута не печатает второй чек',
      );
    });

    test('повтор остаётся одним заданием при других байтах и другом сроке', () {
      final first = seedJob(id: 'sale-42-receipt', terminalId: terminalTill1);
      final repeat = PrintJob(
        id: 'sale-42-receipt',
        terminalId: terminalTill1,
        posId: posMain,
        payloadBytes: seedPayloadBytes('пересобранный чек'),
        createdAt: yearRolloverAfter,
        expiresAt: yearRolloverAfter.add(const Duration(hours: 2)),
        attempts: 3,
      );

      expect(
        <PrintJob>{first, repeat},
        hasLength(1),
        reason:
            'ключ идемпотентности — идентификатор, а не байты: пересобранный '
            'чек той же продажи не должен напечататься дважды',
      );
    });

    test('разные идентификаторы — разные задания', () {
      expect(seedJobs().toSet(), hasLength(4));
    });

    test('пустой идентификатор отвергнут', () {
      expect(
        () => seedJob(id: '   ', terminalId: terminalTill1),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('неделимость: задание печатается целиком (И29)', () {
    test('байты копируются при построении — источник больше не влияет', () {
      final source = seedPayloadBytes('receipt-1');
      final job = PrintJob(
        id: 'receipt-1',
        terminalId: terminalTill1,
        posId: posMain,
        payloadBytes: source,
        createdAt: yearRolloverBefore,
        expiresAt: yearRolloverAfter,
      );
      final expected = Uint8List.fromList(source);

      source[0] = 0x00;
      source[1] = 0x00;

      expect(
        job.payloadBytes,
        expected,
        reason:
            'задание, чьи байты можно поменять после сдачи в очередь, '
            'неделимым не является',
      );
    });

    test('байты задания нельзя изменить снаружи', () {
      final job = seedJob(id: 'receipt-1', terminalId: terminalTill1);
      expect(
        () => job.payloadBytes[0] = 0x00,
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('пустой чек не является заданием', () {
      expect(
        () => PrintJob(
          id: 'receipt-1',
          terminalId: terminalTill1,
          posId: posMain,
          payloadBytes: Uint8List(0),
          createdAt: yearRolloverBefore,
          expiresAt: yearRolloverAfter,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('кириллица в CP866 доходит до задания без изменений', () {
      final job = seedJob(id: 'receipt-1', terminalId: terminalTill1);
      expect(
        job.payloadBytes.sublist(5, 10),
        <int>[0x8a, 0x80, 0x91, 0x91, 0x80],
      );
    });
  });

  group('срок: непечатаемое задание становится видимой проблемой (И29)', () {
    test('срок раньше создания отвергнут', () {
      expect(
        () => PrintJob(
          id: 'receipt-1',
          terminalId: terminalTill1,
          posId: posMain,
          payloadBytes: seedPayloadBytes('receipt-1'),
          createdAt: yearRolloverAfter,
          expiresAt: yearRolloverBefore,
        ),
        throwsA(isA<ArgumentError>()),
        reason: 'задание, истёкшее в момент создания, — дефект настройки',
      );
    });

    test('срок, равный созданию, отвергнут', () {
      expect(
        () => PrintJob(
          id: 'receipt-1',
          terminalId: terminalTill1,
          posId: posMain,
          payloadBytes: seedPayloadBytes('receipt-1'),
          createdAt: yearRolloverBefore,
          expiresAt: yearRolloverBefore,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('срок пересекает границу года', () {
      final job = PrintJob(
        id: 'receipt-1',
        terminalId: terminalTill1,
        posId: posMain,
        payloadBytes: seedPayloadBytes('receipt-1'),
        createdAt: yearRolloverBefore,
        expiresAt: yearRolloverAfter,
      );

      expect(job.hasExpiredAt(yearRolloverBefore), isFalse);
      expect(
        job.hasExpiredAt(yearRolloverAfter),
        isTrue,
        reason:
            'сравнение сроков по календарному дню сломалось бы ровно здесь: '
            '31 декабря и 1 января — разные дни, но 200 мс разницы',
      );
      expect(
        job.hasExpiredAt(
          yearRolloverAfter.subtract(const Duration(milliseconds: 1)),
        ),
        isFalse,
      );
    });

    test('истёкшее задание отличимо от неудачного', () {
      final base = seedJob(id: 'receipt-1', terminalId: terminalTill1);

      final failed = base.beginAttempt().failWith('Нет бумаги');
      final expired = base
          .beginAttempt()
          .failWith('Принтер не отвечает')
          .expireAt(base.expiresAt.add(const Duration(seconds: 1)));

      expect(failed.state, PrintJobState.failed);
      expect(expired.state, PrintJobState.expired);
      expect(
        failed.state,
        isNot(expired.state),
        reason:
            '«ещё повторим» и «уже не повторим» — разные ответы оператору с '
            'разными действиями',
      );

      expect(
        failed.isTerminal,
        isFalse,
        reason: 'неудачное задание ещё будет повторено',
      );
      expect(
        expired.isTerminal,
        isTrue,
        reason: 'истёкшее не повторяется молча дальше',
      );

      expect(failed.failureReason, 'Нет бумаги');
      expect(
        expired.failureReason,
        'Принтер не отвечает',
        reason: 'причина, по которой не удалось, видна и после истечения срока',
      );
    });

    test('живое задание нельзя объявить истёкшим', () {
      final job = seedJob(id: 'receipt-1', terminalId: terminalTill1);
      expect(
        () => job.expireAt(job.createdAt.add(const Duration(seconds: 1))),
        throwsA(isA<StateError>()),
        reason: 'срок наступает по часам, а не по решению вызывающего',
      );
    });
  });

  group('ручной повтор (renewedUntil)', () {
    test('истёкшее продлевается: тот же ключ, новый срок, попытки с нуля', () {
      final job = seedJob(id: 'receipt-1', terminalId: terminalTill1);
      final expiredAt = job.expiresAt.add(const Duration(minutes: 1));
      final expired = job
          .beginAttempt()
          .failWith('Нет бумаги')
          .expireAt(expiredAt);

      final renewed = expired.renewedUntil(
        expiredAt.add(const Duration(hours: 1)),
        now: expiredAt,
      );

      expect(
        renewed.id,
        job.id,
        reason: 'повтор сохраняет ключ идемпотентности',
      );
      expect(renewed.state, PrintJobState.queued);
      expect(renewed.attempts, 0);
      expect(renewed.hasExpiredAt(expiredAt), isFalse);
    });

    test('ОТМЕНЁННОЕ задание не повторяется ни при каких условиях', () {
      final cancelled = seedJob(
        id: 'receipt-1',
        terminalId: terminalTill1,
      ).cancelled();

      expect(
        () => cancelled.renewedUntil(
          cancelled.expiresAt.add(const Duration(hours: 1)),
          now: cancelled.createdAt,
        ),
        throwsA(isA<StateError>()),
        reason:
            'отмена — решение оператора о том, что документа быть не должно; '
            'напечатать отменённый чек значит выдать покупателю документ, '
            'который кассир отменил',
      );
    });

    test('печатающееся задание не повторяется — это была бы двойная запись', () {
      final printing = seedJob(
        id: 'receipt-1',
        terminalId: terminalTill1,
      ).beginAttempt();

      expect(
        () => printing.renewedUntil(
          printing.expiresAt.add(const Duration(hours: 1)),
          now: printing.createdAt,
        ),
        throwsA(isA<StateError>()),
        reason:
            'второй экземпляр того же задания в очереди, пока первый пишет в '
            'принтер, — ровно то перемешивание, которое запрещает неделимость',
      );
    });

    test('напечатанное задание не повторяется', () {
      final printed = seedJob(id: 'receipt-1', terminalId: terminalTill1)
          .beginAttempt()
          .confirmPrinted();

      expect(
        () => printed.renewedUntil(
          printed.expiresAt.add(const Duration(hours: 1)),
          now: printed.createdAt,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('повтор с уже прошедшим сроком отвергнут по часам', () {
      final job = seedJob(id: 'receipt-1', terminalId: terminalTill1);
      final now = job.expiresAt.add(const Duration(hours: 5));
      final expired = job.expireAt(now);

      expect(
        () => expired.renewedUntil(
          now.subtract(const Duration(minutes: 1)),
          now: now,
        ),
        throwsA(isA<ArgumentError>()),
        reason:
            'новый срок позже createdAt, но раньше «сейчас» — сравнение с '
            'моментом создания пропустило бы его, и задание вернулось бы в '
            'очередь мёртвым',
      );
    });

    test('повтор со сроком, равным «сейчас», отвергнут', () {
      final job = seedJob(id: 'receipt-1', terminalId: terminalTill1);
      final now = job.expiresAt.add(const Duration(hours: 5));
      final expired = job.expireAt(now);

      expect(
        () => expired.renewedUntil(now, now: now),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('причина неудачи объясняет текущее состояние', () {
    test('успешная печать снимает причину прошлой неудачи', () {
      final printed = seedJob(id: 'receipt-1', terminalId: terminalTill1)
          .beginAttempt()
          .failWith('Нет бумаги')
          .beginAttempt()
          .confirmPrinted();

      expect(printed.state, PrintJobState.printed);
      expect(
        printed.failureReason,
        isNull,
        reason:
            'иначе экран очереди (задача 7) показал бы «Нет бумаги» рядом с '
            'уже выданным покупателю чеком',
      );
    });

    test('новая попытка снимает причину прошлой', () {
      final printing = seedJob(id: 'receipt-1', terminalId: terminalTill1)
          .beginAttempt()
          .failWith('Нет бумаги')
          .beginAttempt();

      expect(printing.state, PrintJobState.printing);
      expect(printing.failureReason, isNull);
      expect(printing.attempts, 2);
    });

    test('продление снимает причину: задание снова просто стоит в очереди', () {
      final job = seedJob(id: 'receipt-1', terminalId: terminalTill1);
      final now = job.expiresAt.add(const Duration(minutes: 1));
      final renewed = job
          .beginAttempt()
          .failWith('Нет бумаги')
          .expireAt(now)
          .renewedUntil(now.add(const Duration(hours: 1)), now: now);

      expect(renewed.state, PrintJobState.queued);
      expect(renewed.failureReason, isNull);
    });

    test('отмена сохраняет причину: видно, на что смотрел отменявший', () {
      final cancelled = seedJob(id: 'receipt-1', terminalId: terminalTill1)
          .beginAttempt()
          .failWith('Принтер не отвечает')
          .cancelled();

      expect(cancelled.state, PrintJobState.cancelled);
      expect(cancelled.failureReason, 'Принтер не отвечает');
    });

    test('пустая причина неудачи невыразима', () {
      final job = seedJob(id: 'receipt-1', terminalId: terminalTill1);
      expect(() => job.failWith('   '), throwsA(isA<ArgumentError>()));
    });
  });

  group('состояние задания', () {
    test('новое задание стоит в очереди и не имеет попыток', () {
      final job = seedJob(id: 'receipt-1', terminalId: terminalTill1);
      expect(job.state, PrintJobState.queued);
      expect(job.attempts, 0);
      expect(job.failureReason, isNull);
      expect(job.isTerminal, isFalse);
    });

    test('попытка увеличивает счётчик и переводит в печать', () {
      final job = seedJob(id: 'receipt-1', terminalId: terminalTill1);
      final printing = job.beginAttempt();

      expect(printing.state, PrintJobState.printing);
      expect(printing.attempts, 1);
      expect(job.attempts, 0, reason: 'задание неизменяемо');

      final second = printing.failWith('Обрыв связи').beginAttempt();
      expect(second.attempts, 2);
    });

    test('подтверждённое задание не переводится дальше', () {
      final printed = seedJob(id: 'receipt-1', terminalId: terminalTill1)
          .beginAttempt()
          .confirmPrinted();

      expect(printed.state, PrintJobState.printed);
      expect(printed.isTerminal, isTrue);
      expect(
        printed.beginAttempt,
        throwsA(isA<StateError>()),
        reason: 'повтор подтверждённого — это второй чек',
      );
      expect(printed.cancelled, throwsA(isA<StateError>()));
    });

    test('отменённое задание не печатается', () {
      final cancelled = seedJob(
        id: 'receipt-1',
        terminalId: terminalTill1,
      ).cancelled();
      expect(cancelled.state, PrintJobState.cancelled);
      expect(cancelled.isTerminal, isTrue);
      expect(cancelled.beginAttempt, throwsA(isA<StateError>()));
    });

    test('состояния передаются по имени, а не по номеру', () {
      expect(
        PrintJobState.values.map((s) => s.name).toList(),
        <String>[
          'queued',
          'printing',
          'printed',
          'failed',
          'expired',
          'cancelled',
        ],
        reason:
            'имена — часть контракта хранения (задача 2); хранение по индексу '
            'сломалось бы при добавлении состояния в середину',
      );
      expect(PrintJobState.values.byName('expired'), PrintJobState.expired);
    });
  });

  group('ответ очереди на сдачу задания', () {
    test('принято — это не напечатано', () {
      final outcome = PrintSubmitOutcome.accepted('receipt-1');
      expect(outcome.status, PrintSubmitStatus.accepted);
      expect(outcome.jobId, 'receipt-1');
      expect(outcome.isAccepted, isTrue);
      expect(outcome.message, isNotEmpty);
    });

    test('повтор известного задания — отдельный ответ, а не отказ', () {
      final outcome = PrintSubmitOutcome.duplicate('receipt-1');
      expect(outcome.status, PrintSubmitStatus.duplicate);
      expect(
        outcome.isAccepted,
        isFalse,
        reason: 'второй раз задание в очередь не встало',
      );
      expect(
        outcome.isRejected,
        isFalse,
        reason:
            'повтор — штатный успех вызывающего, а не ошибка: чек уже есть '
            'или уже в очереди',
      );
      expect(outcome.message, isNotEmpty);
    });

    test('отказ называет причину', () {
      final outcome = PrintSubmitOutcome.rejected(
        'receipt-1',
        'Очередь печати переполнена',
      );
      expect(outcome.status, PrintSubmitStatus.rejected);
      expect(outcome.isRejected, isTrue);
      expect(outcome.message, 'Очередь печати переполнена');
    });

    test('отказ без причины невыразим', () {
      expect(
        () => PrintSubmitOutcome.rejected('receipt-1', '  '),
        throwsA(isA<ArgumentError>()),
        reason: '«не удалось» без причины — не ответ оператору',
      );
    });

    test('ответы очереди передаются по имени', () {
      expect(
        PrintSubmitStatus.values.map((s) => s.name).toList(),
        <String>['accepted', 'duplicate', 'rejected'],
      );
    });
  });
}
