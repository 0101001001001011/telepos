import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/backend/login_throttle.dart';

void main() {
  // Реальных задержек тесты не ждут: `sleep` подменён на функцию, которая
  // записывает запрошенную длительность и завершается немедленно. Это
  // проверяет, что `penalizeFailure` *попросил бы* ждать именно столько,
  // не тратя секунды прогона набора на настоящий `Future.delayed`.
  List<Duration> waits = [];
  Future<void> fakeSleep(Duration d) {
    waits.add(d);
    return Future.value();
  }

  setUp(() => waits = []);

  LoginThrottle throttle() => LoginThrottle(
    graceFailures: 2,
    baseDelay: const Duration(seconds: 1),
    maxDelay: const Duration(seconds: 30),
    sleep: fakeSleep,
  );

  group('delayFor — чистый расчёт', () {
    test('первые две неудачи ничего не стоят (льгота на опечатку)', () async {
      final t = throttle();
      expect(t.delayFor(terminalId: 1, userId: 1), Duration.zero);
      await t.penalizeFailure(terminalId: 1, userId: 1);
      expect(t.delayFor(terminalId: 1, userId: 1), Duration.zero);
      await t.penalizeFailure(terminalId: 1, userId: 1);
      expect(t.delayFor(terminalId: 1, userId: 1), Duration.zero);
    });

    test('задержка растёт удвоением после льготы', () async {
      final t = throttle();
      // Третья неудача (первая сверх льготы) — базовая секунда.
      await t.penalizeFailure(terminalId: 1, userId: 1);
      await t.penalizeFailure(terminalId: 1, userId: 1);
      await t.penalizeFailure(terminalId: 1, userId: 1);
      expect(t.delayFor(terminalId: 1, userId: 1), const Duration(seconds: 1));
      await t.penalizeFailure(terminalId: 1, userId: 1);
      expect(t.delayFor(terminalId: 1, userId: 1), const Duration(seconds: 2));
      await t.penalizeFailure(terminalId: 1, userId: 1);
      expect(t.delayFor(terminalId: 1, userId: 1), const Duration(seconds: 4));
    });

    test('задержка не растёт выше предела', () async {
      final t = throttle();
      for (var i = 0; i < 20; i++) {
        await t.penalizeFailure(terminalId: 1, userId: 1);
      }
      expect(t.delayFor(terminalId: 1, userId: 1), const Duration(seconds: 30));
      // Ещё неудача — предел не пробит.
      await t.penalizeFailure(terminalId: 1, userId: 1);
      expect(t.delayFor(terminalId: 1, userId: 1), const Duration(seconds: 30));
      // И сама задержка, которую фактически попросили выждать, тоже не
      // превышала предел ни разу.
      expect(
        waits,
        everyElement(lessThanOrEqualTo(const Duration(seconds: 30))),
      );
    });

    test('успешный вход полностью сбрасывает счёт (не декремент)', () async {
      final t = throttle();
      for (var i = 0; i < 4; i++) {
        await t.penalizeFailure(terminalId: 1, userId: 1);
      }
      expect(t.delayFor(terminalId: 1, userId: 1), greaterThan(Duration.zero));
      t.recordSuccess(terminalId: 1, userId: 1);
      expect(t.delayFor(terminalId: 1, userId: 1), Duration.zero);
      // Полный сброс, не «минус одна»: снова нужны две неудачи без цены.
      await t.penalizeFailure(terminalId: 1, userId: 1);
      expect(t.delayFor(terminalId: 1, userId: 1), Duration.zero);
      await t.penalizeFailure(terminalId: 1, userId: 1);
      expect(t.delayFor(terminalId: 1, userId: 1), Duration.zero);
    });
  });

  group('penalizeFailure — реально ждёт', () {
    test('запрашивает у sleep именно посчитанную задержку', () async {
      // Каждая попытка платит за счёт, накопленный *до* неё (см. docstring
      // `penalizeFailure`) — льготны первые три вызова (счёт до вызова:
      // 0, 1, 2 — все не больше `graceFailures` = 2), не первые два.
      final t = throttle();
      await t.penalizeFailure(terminalId: 1, userId: 1); // 1-я, счёт был 0
      await t.penalizeFailure(terminalId: 1, userId: 1); // 2-я, счёт был 1
      await t.penalizeFailure(terminalId: 1, userId: 1); // 3-я, счёт был 2
      expect(waits, isEmpty); // льготные неудачи sleep не зовут вовсе
      await t.penalizeFailure(terminalId: 1, userId: 1); // 4-я, счёт был 3 — 1с
      expect(waits, [const Duration(seconds: 1)]);
      await t.penalizeFailure(terminalId: 1, userId: 1); // 5-я, счёт был 4 — 2с
      expect(waits, [const Duration(seconds: 1), const Duration(seconds: 2)]);
    });
  });

  group(
    'пункт 1 разбора (2026-08-21) — предел одновременных ожиданий снят',
    () {
      // До этой правки `LoginThrottle` держал `_activePenalties` — счётчик,
      // общий на всю кассу и полностью управляемый нападающим: набрав
      // `maxConcurrentPenalties` (20) параллельных неудач по любым ключам и
      // держа их занятыми долгим сном, он превращал в мгновенный, бесплатный
      // проход все следующие попытки — включая попытку по имени настоящей
      // жертвы. Этот тест обязан был краснеть на старой реализации: см.
      // `phase2-fix2-report.md`, там приведён прогон именно на ней.
      test(
        '20 параллельных неудач по чужому ключу не делают попытку по целевому '
        'ключу бесплатной',
        () async {
          // `hangingSleep` не завершается сам — держит попытку «ожидающей»,
          // пока тест не отпустит её вручную. Так видно, ждёт ли попытка
          // *реально*, а не просто быстро прошла.
          final pending = <Completer<void>>[];
          Future<void> hangingSleep(Duration d) {
            final completer = Completer<void>();
            pending.add(completer);
            return completer.future;
          }

          final t = LoginThrottle(
            graceFailures: 0,
            baseDelay: const Duration(seconds: 1),
            maxDelay: const Duration(seconds: 30),
            sleep: hangingSleep,
          );

          // Затравка: у жертвы и у каждого из двадцати чужих ключей уже по
          // одной (льготной при graceFailures: 0 — первая неудача всегда
          // бесплатна, счёт был 0) неудаче, так что следующая неудача каждого
          // из них уже не льготная и реально просит `sleep`.
          await t.penalizeFailure(terminalId: 500, userId: 99); // жертва
          for (var i = 0; i < 20; i++) {
            await t.penalizeFailure(terminalId: 600 + i, userId: 1000 + i);
          }

          // Нападающий открывает ровно `maxConcurrentPenalties` (20) —
          // столько, сколько раньше исчерпывало предел, — параллельных
          // неудач по чужим ключам, ни разу не касаясь жертву.
          final attackerFutures = <Future<void>>[
            for (var i = 0; i < 20; i++)
              t.penalizeFailure(terminalId: 600 + i, userId: 1000 + i),
          ];

          // И тут же, пока все двадцать ещё висят, — неудача по жертве.
          var victimResolved = false;
          final victimFuture = t
              .penalizeFailure(terminalId: 500, userId: 99)
              .whenComplete(() => victimResolved = true);

          // Даём event loop прокрутиться один раз. На старой реализации
          // ровно здесь попытка жертвы уже вернулась бы: `_activePenalties`
          // достиг бы 20 на двадцати чужих попытках, и попытка жертвы,
          // проверив предел синхронно, получила бы `tooBusy` и не стала бы
          // ждать вовсе.
          await Future<void>.delayed(Duration.zero);
          expect(
            victimResolved,
            isFalse,
            reason:
                'попытка по жертве обязана ждать свою задержку так же, как '
                'и остальные — предел одновременных ожиданий по чужим ключам '
                'не должен освобождать её попытку от ожидания',
          );

          // Отпускаем все повисшие ожидания, чтобы тест не оставил
          // незавершённые Future.
          for (final completer in pending) {
            completer.complete();
          }
          await Future.wait([...attackerFutures, victimFuture]);
        },
      );

      test(
        'больше двадцати параллельных попыток тоже ждут все — предела нет',
        () async {
          final pending = <Completer<void>>[];
          Future<void> hangingSleep(Duration d) {
            final completer = Completer<void>();
            pending.add(completer);
            return completer.future;
          }

          final t = LoginThrottle(
            graceFailures: 0,
            baseDelay: const Duration(seconds: 1),
            maxDelay: const Duration(seconds: 30),
            sleep: hangingSleep,
          );

          // 25 ключей, у каждого уже по одной неудаче — следующая не льготная.
          for (var i = 0; i < 25; i++) {
            await t.penalizeFailure(terminalId: 700 + i, userId: 2000 + i);
          }

          // Все 25 запускаются параллельно, ни разу не await-нутые по одной.
          final futures = [
            for (var i = 0; i < 25; i++)
              t.penalizeFailure(terminalId: 700 + i, userId: 2000 + i),
          ];

          // Без предела все 25 обязаны реально позвать sleep и повиснуть —
          // не двадцать, не какое-то другое число.
          expect(pending, hasLength(25));

          for (final completer in pending) {
            completer.complete();
          }
          await Future.wait(futures);
        },
      );
    },
  );

  group('пункт 2 разбора (2026-08-21) — параллельные неудачи не делят одну '
      'задержку', () {
    // До правки `delayFor` читался до `await _sleep`, а `_failures[...]++`
    // выполнялся после — два параллельных вызова по одному ключу читали
    // один и тот же доинкрементный счёт, ждали одинаково и лишь потом оба
    // инкрементировали. Правка считает неудачу синхронно, до вычисления
    // задержки: второй параллельный вызов уже видит инкремент первого.
    test(
      'две параллельные неудачи по одному ключу получают разные задержки',
      () async {
        final t = throttle(); // graceFailures: 2, fakeSleep
        // Три неудачи выводят счёт за льготу — следующая уже не бесплатна.
        await t.penalizeFailure(terminalId: 1, userId: 1);
        await t.penalizeFailure(terminalId: 1, userId: 1);
        await t.penalizeFailure(terminalId: 1, userId: 1);
        waits = [];

        // Две параллельные, не await-нутые по одной.
        final f1 = t.penalizeFailure(terminalId: 1, userId: 1);
        final f2 = t.penalizeFailure(terminalId: 1, userId: 1);
        await Future.wait([f1, f2]);

        expect(waits, hasLength(2));
        expect(
          waits[0],
          isNot(waits[1]),
          reason:
              'настоящий последовательный нападающий платил бы 1с и 2с за эти '
              'две неудачи — параллельный не обязан платить меньше, вторая '
              'попытка обязана увидеть счёт, уже учитывающий первую',
        );
      },
    );
  });

  group('пункт 3 разбора (2026-08-21) — просроченные записи чистятся', () {
    test(
      'запись стирается на следующем обращении к замку, не по будильнику',
      () async {
        var now = DateTime.utc(2026, 8, 21);
        final t = LoginThrottle(
          graceFailures: 0,
          baseDelay: const Duration(seconds: 1),
          maxDelay: const Duration(seconds: 30),
          staleAfter: const Duration(hours: 1),
          sleep: fakeSleep,
          clock: () => now,
        );

        await t.penalizeFailure(terminalId: 1, userId: 1);
        expect(
          t.delayFor(terminalId: 1, userId: 1),
          greaterThan(Duration.zero),
        );

        // Час бездействия по этому ключу проходит.
        now = now.add(const Duration(hours: 1, seconds: 1));

        // Любое другое обращение к замку — не по этому ключу — и есть
        // ленивая уборка «на любом обращении»: будильника нет, чистит
        // именно следующий вызов penalizeFailure.
        await t.penalizeFailure(terminalId: 99, userId: 99);

        // Первый ключ пережил час бездействия только как отсутствие записи:
        // следующая его неудача снова льготная, будто он не ошибался вовсе.
        expect(t.delayFor(terminalId: 1, userId: 1), Duration.zero);
      },
    );

    test('свежая запись час бездействия не переживает раньше срока', () async {
      var now = DateTime.utc(2026, 8, 21);
      final t = LoginThrottle(
        graceFailures: 0,
        baseDelay: const Duration(seconds: 1),
        maxDelay: const Duration(seconds: 30),
        staleAfter: const Duration(hours: 1),
        sleep: fakeSleep,
        clock: () => now,
      );

      await t.penalizeFailure(terminalId: 1, userId: 1);

      // 59 минут — ещё не час.
      now = now.add(const Duration(minutes: 59));
      await t.penalizeFailure(terminalId: 99, userId: 99);

      expect(
        t.delayFor(terminalId: 1, userId: 1),
        greaterThan(Duration.zero),
        reason: 'до истечения staleAfter запись обязана остаться',
      );
    });
  });

  group(
    'задача 6 не сломана: ключ замка — userId, terminalId остаётся вторым',
    () {
      // `terminals.register` открыта и не дедуплицирует — нападающий может
      // назвать новый `terminalId` на каждую попытку. `userId` он не
      // выбирает — он именует жертву, и это имя не меняется. Задержка обязана
      // расти по имени жертвы, даже когда терминал каждый раз новый.
      test(
        'серия неудач по одному userId с разными terminalId растит его задержку',
        () async {
          final t = throttle();
          for (var i = 0; i < 5; i++) {
            // Новый terminalId на каждую попытку — ровно то, что даёт открытая
            // `terminals.register`.
            await t.penalizeFailure(terminalId: 1000 + i, userId: 7);
          }
          // Шестая попытка — снова новый terminalId, тот же userId: задержка
          // всё равно посчитана по накопленному счёту кассира, не по нулевому
          // счёту нового терминала.
          expect(
            t.delayFor(terminalId: 2000, userId: 7),
            greaterThan(Duration.zero),
          );
        },
      );

      test(
        'перебор одного userId не растит задержку другого, ни разу не тронутого',
        () async {
          final t = throttle();
          for (var i = 0; i < 5; i++) {
            await t.penalizeFailure(terminalId: 1000 + i, userId: 7); // жертва
          }
          expect(t.delayFor(terminalId: 2000, userId: 8), Duration.zero);
        },
      );

      test('задержка по terminalId продолжает работать (не потеряли)', () async {
        final t = throttle();
        for (var i = 0; i < 5; i++) {
          // Пять разных кассиров, каждый ошибся по разу — ни один персональный
          // счётчик не вырос настолько, но терминал использован пять раз
          // подряд.
          await t.penalizeFailure(terminalId: 1, userId: 100 + i);
        }
        expect(
          t.delayFor(terminalId: 1, userId: 999),
          greaterThan(Duration.zero),
        );
        // Другой терминал теми же (едва тронутыми) кассирами не задет.
        expect(t.delayFor(terminalId: 2, userId: 100), Duration.zero);
      });

      test('walk-up (без userId) считается общим счётчиком на кассу', () async {
        final t = throttle();
        for (var i = 0; i < 5; i++) {
          await t.penalizeFailure(terminalId: 3000 + i); // userId не назван
        }
        expect(t.delayFor(terminalId: 4000), greaterThan(Duration.zero));
      });

      test(
        'walk-up не путает свой общий счётчик со счётчиком поимённого кассира',
        () async {
          final t = throttle();
          for (var i = 0; i < 5; i++) {
            await t.penalizeFailure(
              terminalId: 5000 + i,
            ); // walk-up, без userId
          }
          expect(t.delayFor(terminalId: 6000, userId: 42), Duration.zero);

          final t2 = throttle();
          for (var i = 0; i < 5; i++) {
            await t2.penalizeFailure(terminalId: 7000 + i, userId: 42);
          }
          expect(t2.delayFor(terminalId: 8000), Duration.zero);
        },
      );

      test(
        'успешный вход сбрасывает и кассира, и терминал этой попытки',
        () async {
          final t = throttle();
          // Три неудачи (счёт 0→1→2→3) выводят счёт за льготу (`graceFailures`
          // = 2): задержка уже выросла.
          for (var i = 0; i < 3; i++) {
            await t.penalizeFailure(terminalId: 9000 + i, userId: 7);
          }
          expect(
            t.delayFor(terminalId: 9010, userId: 7),
            greaterThan(Duration.zero),
          );

          t.recordSuccess(terminalId: 9099, userId: 7);
          // Полный сброс, не декремент: сразу после успеха задержки снова нет.
          expect(t.delayFor(terminalId: 9010, userId: 7), Duration.zero);

          // Снова нужны три неудачи (льгота полностью восстановлена), прежде
          // чем задержка вернётся.
          for (var i = 0; i < 2; i++) {
            await t.penalizeFailure(terminalId: 9100 + i, userId: 7);
            expect(t.delayFor(terminalId: 9200, userId: 7), Duration.zero);
          }
          await t.penalizeFailure(terminalId: 9102, userId: 7);
          expect(
            t.delayFor(terminalId: 9200, userId: 7),
            greaterThan(Duration.zero),
          );
        },
      );
    },
  );

  group(
    'правка 1 БЛОКЕРА закрытия долга (2026-08-22) — потолок держит, '
    'очередь снята',
    () {
      // Обратное тому, что проверял этот же тест до правки 1 БЛОКЕРА: тогда
      // `_queueTail` держала N параллельных неудач в очереди, и они стоили
      // сумму задержек (31 с на шесть неудач при graceFailures: 0). Очередь
      // снята — теперь N параллельных неудач по одному ключу стоят максимум
      // задержек, не сумму: все таймеры независимы и тикают одновременно.
      // `fake_async` даёт реальный `Future.delayed` (не `fakeSleep`
      // остальных тестов файла — тот отвечает мгновенно и ничего не
      // показал бы) и виртуальные часы.
      test(
        'шесть параллельных неудач по одному ключу стоят как одна — '
        'максимум задержек, не сумму',
        () {
          fakeAsync((async) {
            const n = 6;
            final t = LoginThrottle(
              graceFailures: 0, // каждая из шести — платная
              baseDelay: const Duration(seconds: 1),
              maxDelay: const Duration(seconds: 30),
            );

            // Самая долгая из шести: неудача с накопленным счётом c стоит
            // `_delayForCount(c)` — при graceFailures: 0 это 0, 1, 2, 4, 8,
            // 16 секунд для c = 0..5. Максимум — 16 с (шестая, счёт 5), не
            // сумма (31 с).
            const expectedWall = Duration(seconds: 16);

            Duration? lastCompletedAt;
            for (var i = 0; i < n; i++) {
              final future = t.penalizeFailure(terminalId: 1, userId: 1);
              future.then((_) => lastCompletedAt = async.elapsed);
            }

            async.elapse(const Duration(minutes: 5));

            expect(
              lastCompletedAt,
              expectedWall,
              reason:
                  'после снятия очереди шесть параллельных неудач обязаны '
                  'стоить нападающему максимум задержек (16 с), не их сумму '
                  '(31 с) — сумма и была правкой 1 БЛОКЕРА (честная попытка '
                  'наследовала бы ту же сумму, вставая в ту же очередь)',
            );
          });
        },
      );

      /// Главный тест правки 1 БЛОКЕРА: величины прода настоящие (не
      /// масштабированные), `fake_async` только виртуализирует таймер.
      /// Чужая серия из [failures] неудач по ключу жертвы (`userId: 99`,
      /// разные `terminalId` — ротация из задачи 6) отправлена не дожидаясь
      /// ответов; следом — одна честная попытка того же `userId`, свежим
      /// `terminalId`. Печатает измеренное ожидание — числа идут в отчёт
      /// (`throttle-cap-report.md`) как есть, не подогнанные.
      void expectHonestBounded(int failures) {
        fakeAsync((async) {
          final t = LoginThrottle(); // настоящие величины по умолчанию
          const victimUserId = 99;

          for (var i = 0; i < failures; i++) {
            unawaited(
              t.penalizeFailure(terminalId: 1000 + i, userId: victimUserId),
            );
          }

          Duration? honestWait;
          unawaited(
            t
                .penalizeFailure(terminalId: 999999, userId: victimUserId)
                .then((_) => honestWait = async.elapsed),
          );

          async.elapse(const Duration(hours: 1));

          expect(
            honestWait,
            isNotNull,
            reason: 'час виртуального времени обязан хватить с большим '
                'запасом сверх потолка в 30 с',
          );
          // ignore: avoid_print
          print(
            'честная попытка после $failures чужих неудач по userId: '
            '${honestWait!.inMilliseconds} мс '
            '(${(honestWait!.inMilliseconds / 1000).toStringAsFixed(1)} с)',
          );
          expect(
            honestWait,
            const Duration(seconds: 30), // LoginThrottle.maxDelay умолчания
            reason:
                'честная попытка после чужой серии в $failures неудач '
                'обязана ждать не дольше потолка (maxDelay) — независимо от '
                'того, сколько чужих неудач накопилось до неё. До правки 1 '
                'БЛОКЕРА (очередь `_queueTail`) она наследовала бы сумму '
                'чужих задержек: 200 неудач держали бы её 1 ч 36 мин, 1000 — '
                '8 ч 16 мин, 10⁴ — 83 часа',
          );
        });
      }

      test(
        'честная попытка после чужой серии в 200 неудач отвечает в '
        'пределах потолка',
        () => expectHonestBounded(200),
      );
      test(
        'честная попытка после чужой серии в 1000 неудач отвечает в '
        'пределах потолка',
        () => expectHonestBounded(1000),
      );
      test(
        'честная попытка после чужой серии в 10⁴ неудач отвечает в '
        'пределах потолка',
        () => expectHonestBounded(10000),
      );
    },
  );
}
