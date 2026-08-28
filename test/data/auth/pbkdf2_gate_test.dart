import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/auth/pbkdf2_gate.dart';

void main() {
  test('не пускает больше maxConcurrent заданий одновременно', () async {
    final gate = Pbkdf2Gate(maxConcurrent: 2);
    final started = <int>[];
    final releasers = <Completer<void>>[];

    Future<void> job(int id) => gate.run(() async {
      started.add(id);
      final release = Completer<void>();
      releasers.add(release);
      await release.future;
    });

    final futures = [for (var i = 0; i < 5; i++) job(i)];
    await Future<void>.delayed(Duration.zero);

    expect(
      started,
      hasLength(2),
      reason:
          'ровно maxConcurrent заданий обязаны реально начаться, остальные '
          'три — ждать слота, не начавшись вовсе',
    );

    // Освобождаем всё — тест ниже проверяет, что никто не потерялся.
    for (final r in releasers) {
      if (!r.isCompleted) r.complete();
    }
    // Дренаж: каждое освобождение открывает следующему слот и стартует
    // следующее задание — их нужно освобождать по мере появления, не одним
    // проходом по уже собранному списку.
    for (var i = 0; i < 10 && started.length < 5; i++) {
      await Future<void>.delayed(Duration.zero);
      for (final r in List<Completer<void>>.of(releasers)) {
        if (!r.isCompleted) r.complete();
      }
    }
    await Future.wait(futures);

    expect(started, hasLength(5), reason: 'все пять обязаны были выполниться');
  });

  test(
    'предел — очередь, а не пропуск: ждущее задание выполняется, а не '
    'отказывает',
    () async {
      // Тот самый порок `maxConcurrentPenalties` (`login_throttle.dart`,
      // «предел одновременных ожиданий снят»): при достижении предела
      // старая реализация отвечала мгновенно, без ожидания. Здесь третье
      // задание при maxConcurrent: 2 обязано реально ждать — не вернуть
      // управление раньше, чем освободится слот.
      final gate = Pbkdf2Gate(maxConcurrent: 2);
      final blockerA = Completer<void>();
      final blockerB = Completer<void>();

      unawaited(gate.run(() => blockerA.future));
      unawaited(gate.run(() => blockerB.future));

      var thirdRan = false;
      final third = gate.run(() async {
        thirdRan = true;
        return 42;
      });

      await Future<void>.delayed(Duration.zero);
      expect(
        thirdRan,
        isFalse,
        reason: 'третье задание обязано ждать слот, а не выполниться сразу',
      );

      blockerA.complete();
      final result = await third;

      expect(thirdRan, isTrue);
      expect(result, 42, reason: 'ждавшее задание не потеряло свой результат');

      blockerB.complete();
    },
  );

  test('очередь честная — задания выполняются в порядке ожидания (FIFO)',
      () async {
    final gate = Pbkdf2Gate(maxConcurrent: 1);
    final order = <int>[];
    final holdFirst = Completer<void>();

    unawaited(
      gate.run(() async {
        await holdFirst.future;
      }),
    );
    await Future<void>.delayed(Duration.zero);

    final futures = [
      for (var i = 0; i < 4; i++)
        gate.run(() async {
          order.add(i);
        }),
    ];
    await Future<void>.delayed(Duration.zero);

    holdFirst.complete();
    await Future.wait(futures);

    expect(order, [0, 1, 2, 3]);
  });

  group('правка А-2 БЛОКЕРА (2026-08-22) — предел не превышается гонкой', () {
    test(
      'разбуженный ждущий не проверяет предел повторно: старая '
      'реализация (`if`, отдельный decrement) пропускает лишнего',
      () async {
        // Разбор доказал прогоном копии класса: `live=2 peak=2` после
        // старта, `live=3 peak=3` (предел = 2) после барж-ина. Здесь то же
        // самое, но на настоящем экспортируемом `Pbkdf2Gate`, без копии —
        // гонка строится не угадыванием тайминга, а детерминированно, и
        // проверена прогоном (сначала на копии старого класса в отдельном
        // пробном файле, затем здесь): собственный слушатель на том же
        // `blockerA.future`, зарегистрированный ПОСЛЕ внутреннего слушателя
        // job1 (тот зарегистрировался раньше — job1 стартовал первым),
        // становится микрозадачей той же «волны» и исполняется уже ПОСЛЕ
        // `_running--` (правка ещё не применена), но ДО пробуждения job3 —
        // если внутри него вызвать `gate.run` НАПРЯМУЮ, без лишнего хопа
        // (лишний `scheduleMicrotask` вокруг вызова отодвинул бы его за
        // пробуждение job3 и гонку не воспроизвёл бы — проверено).
        final gate = Pbkdf2Gate(maxConcurrent: 2);
        var live = 0;
        var peak = 0;

        Future<void> Function() jobOf(Completer<void> blocker) {
          return () {
            live++;
            if (live > peak) peak = live;
            return blocker.future.whenComplete(() => live--);
          };
        }

        final blockerA = Completer<void>();
        final blockerB = Completer<void>();
        final blockerC = Completer<void>();
        final blockerD = Completer<void>();

        unawaited(gate.run(jobOf(blockerA))); // job1 — стартует сразу
        unawaited(gate.run(jobOf(blockerB))); // job2 — стартует сразу
        await Future<void>.delayed(Duration.zero);
        expect(live, 2, reason: 'предпосылка: оба слота заняты');

        unawaited(gate.run(jobOf(blockerC))); // job3 — ждёт слота
        await Future<void>.delayed(Duration.zero);
        expect(
          live,
          2,
          reason: 'предпосылка: третье задание ещё не стартовало',
        );

        // Регистрируется ПОСЛЕ внутреннего слушателя job1 (тот уже ждёт
        // `blockerA.future` — job1 стартовал раньше) — при завершении
        // `blockerA` оба слушателя планируются микрозадачами в порядке
        // регистрации: сначала цепочка job1 (она же уменьшает `_running`),
        // и только потом эта — ровно после декремента, ровно до пробуждения
        // job3. Вызов — напрямую, без обёртки `scheduleMicrotask`: лишний
        // хоп отодвинул бы его за пробуждение job3 (проверено пробным
        // прогоном).
        blockerA.future.then((_) {
          unawaited(gate.run(jobOf(blockerD))); // job4
        });
        blockerA.complete();

        // `Future.delayed` исполняется только после того, как микрозадачная
        // очередь опустеет ПОЛНОСТЬЮ (сколько бы новых микрозадач ни
        // появилось по ходу дренажа) — одного ожидания достаточно, чтобы
        // гонка (или её отсутствие) успела проявиться целиком.
        await Future<void>.delayed(Duration.zero);

        expect(
          peak,
          lessThanOrEqualTo(2),
          reason:
              'maxConcurrent=2 обязан быть настоящим потолком ОДНОВРЕМЕННО '
              'выполняющихся заданий — старая реализация (`if`, а не '
              '`while`/передача слота без декремента) даёт live=3 при '
              'пределе 2, ровно как в разборе',
        );

        blockerB.complete();
        blockerC.complete();
        blockerD.complete();
        await Future<void>.delayed(Duration.zero);
      },
    );
  });

  group(
    'справедливость: круговая раздача по ключу, а не общая FIFO (правка А '
    'БЛОКЕРА, 2026-08-22)',
    () {
      test(
        'залп по одной сессии не отодвигает другую сессию в общий хвост',
        () async {
          final gate = Pbkdf2Gate(maxConcurrent: 1);
          final order = <String>[];

          // Держит единственный слот занятым вручную — иначе первый же
          // вызов занял бы свободный слот напрямую, и справедливость было
          // бы нечем проверить: обоим (и заливу, и честной попытке) нужно
          // реально встать в очередь.
          final holder = Completer<void>();
          unawaited(gate.run(() => holder.future));
          await Future<void>.delayed(Duration.zero);

          // 500 попыток одной атакующей сессии — все встают в очередь под
          // одним и тем же ключом, до того как честная попытка вообще
          // придёт (худший случай из задания: очередь нападающего уже
          // выстроена).
          final attackerFutures = [
            for (var i = 0; i < 500; i++)
              gate.run(() async {
                order.add('attacker');
              }, key: 'attackerSession'),
          ];
          await Future<void>.delayed(Duration.zero);

          // Честная попытка — другая сессия, встаёт в очередь последней по
          // времени прихода.
          final honest = gate.run(() async {
            order.add('honest');
          }, key: 'honestSession');
          await Future<void>.delayed(Duration.zero);

          holder.complete();
          await honest;

          expect(
            order.indexOf('honest'),
            lessThanOrEqualTo(1),
            reason:
                'при круговой раздаче честная сессия обязана получить один '
                'из первых слотов после освобождения — не 500-й по счёту, '
                'как было бы при общей FIFO-очереди по времени прихода',
          );

          for (final f in attackerFutures) {
            unawaited(f.catchError((_) {}));
          }
        },
      );
    },
  );
}
