import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/backend/session_registry.dart';
import 'package:telepos/domain/auth/session_lookup.dart';

void main() {
  late DateTime now;
  DateTime clock() => now;

  setUp(() => now = DateTime.utc(2026, 8, 20, 10));

  SessionRegistry registryWith({Duration idle = const Duration(minutes: 30)}) =>
      SessionRegistry(idleTimeout: idle, clock: clock, random: Random(1));

  group('SessionRegistry', () {
    test('выписанный сеанс находится по своему токену', () {
      final registry = registryWith();
      final session = registry.mint(
        userId: 7,
        name: 'Айгуль',
        role: 'cashier',
        permissions: const {'nav.sale'},
        operatingMode: 0,
        pointMode: 'cashier',
        shiftOpen: true,
        terminalId: 1,
      );

      expect(registry.lookup(session.token)?.userId, 7);
      expect(session.expiresAt, now.add(const Duration(minutes: 30)));
    });

    // Задача 9 закрытия долга: до неё `mint` не принимал `terminalId` вовсе,
    // и `terminals.delete` не мог отличить «терминал самой кассы» от
    // «терминал вызывающей вкладки» — запрет «не удаляй себя» пришлось
    // истолковать как первое (см. `LocalTerminalRepository.delete`,
    // `lib/data/terminal/terminal_repository_local.dart`).
    test('выписанный сеанс несёт тот terminalId, с которым входили', () {
      final registry = registryWith();
      final session = registry.mint(
        userId: 7,
        name: 'Айгуль',
        role: 'cashier',
        permissions: const {'nav.sale'},
        operatingMode: 0,
        pointMode: 'cashier',
        shiftOpen: true,
        terminalId: 42,
      );

      expect(session.terminalId, 42);
      // И найденный по токену — тот же самый объект с тем же полем, а не
      // сеанс, потерявший его при поиске.
      expect(registry.lookup(session.token)?.terminalId, 42);
    });

    test('два сеанса не получают один токен', () {
      final registry = registryWith();
      final a = registry.mint(
        userId: 1,
        name: 'A',
        role: 'cashier',
        permissions: const {},
        operatingMode: 0,
        pointMode: 'cashier',
        shiftOpen: false,
        terminalId: 1,
      );
      final b = registry.mint(
        userId: 2,
        name: 'B',
        role: 'cashier',
        permissions: const {},
        operatingMode: 0,
        pointMode: 'cashier',
        shiftOpen: false,
        terminalId: 1,
      );

      expect(a.token, isNot(b.token));
    });

    test('сеанс гаснет по бездействию', () {
      final registry = registryWith(idle: const Duration(minutes: 30));
      final session = registry.mint(
        userId: 7,
        name: 'A',
        role: 'cashier',
        permissions: const {},
        operatingMode: 0,
        pointMode: 'cashier',
        shiftOpen: false,
        terminalId: 1,
      );

      now = now.add(const Duration(minutes: 31));

      expect(registry.lookup(session.token), isNull);
    });

    test('обращение продлевает сеанс', () {
      final registry = registryWith(idle: const Duration(minutes: 30));
      final session = registry.mint(
        userId: 7,
        name: 'A',
        role: 'cashier',
        permissions: const {},
        operatingMode: 0,
        pointMode: 'cashier',
        shiftOpen: false,
        terminalId: 1,
      );

      now = now.add(const Duration(minutes: 20));
      expect(registry.lookup(session.token), isNotNull);

      now = now.add(const Duration(minutes: 20));
      // Без продления сеанс был бы мёртв на 31-й минуте; обращение на 20-й
      // сдвинуло срок.
      expect(registry.lookup(session.token), isNotNull);
    });

    test('выход гасит сеанс, второй выход молчит', () {
      final registry = registryWith();
      final session = registry.mint(
        userId: 7,
        name: 'A',
        role: 'cashier',
        permissions: const {},
        operatingMode: 0,
        pointMode: 'cashier',
        shiftOpen: false,
        terminalId: 1,
      );

      expect(registry.revoke(session.token), isTrue);
      expect(registry.revoke(session.token), isFalse);
      expect(registry.lookup(session.token), isNull);
    });

    // Пере-ревью финального разбора, пункт 1: `watch()` отдавал `_live[token]`
    // как есть, без `_forget()`, а рабочий код зовёт `_forget()` только из
    // `mint` — `lookup` не зовёт никто (`authSession` в `till_operations.dart`
    // подписывается через `watch`, не спрашивает `lookup`). Просроченный
    // сеанс висел в карте, пока на кассе не случится `mint` от кого-то
    // другого: F5 через два часа бездействия на тихой кассе воскрешал бы
    // вход без единого нажатия PIN.
    test(
      'подписка на истёкший токен отдаёт null, а не устаревший сеанс',
      () async {
        final registry = registryWith(idle: const Duration(minutes: 30));
        final session = registry.mint(
          userId: 7,
          name: 'A',
          role: 'cashier',
          permissions: const {},
          operatingMode: 0,
          pointMode: 'cashier',
          shiftOpen: false,
          terminalId: 1,
        );

        // Тихая касса: время ушло далеко за срок, но ничего больше не звало
        // ни `mint`, ни `lookup` — единственное, что могло бы вымести запись
        // раньше этой правки.
        now = now.add(const Duration(hours: 2));

        final events = <int?>[];
        final sub = registry
            .watch(session.token)
            .listen((s) => events.add(s?.userId));
        await Future<void>.delayed(Duration.zero);

        expect(events, [null]);
        await sub.cancel();
      },
    );

    test(
      'слежение доносит гашение до подписчика без окна для потери события',
      () async {
        final registry = registryWith();
        final session = registry.mint(
          userId: 7,
          name: 'A',
          role: 'cashier',
          permissions: const {},
          operatingMode: 0,
          pointMode: 'cashier',
          shiftOpen: false,
          terminalId: 1,
        );

        final seen = <int?>[];
        final sub = registry
            .watch(session.token)
            .listen((s) => seen.add(s?.userId));
        // revoke() сразу за .listen(), без паузы: пауза здесь обходила бы окно
        // гонки, а не проверяла его отсутствие. Холодный async* подписывался
        // на исходный поток позже, чем revoke() успевал разослать null в
        // пустоту, — событие терялось молча, без ошибки и без следа.
        registry.revoke(session.token);
        await Future<void>.delayed(Duration.zero);

        // Первое значение — текущее состояние, второе — гашение. Ровно так же
        // ведут себя все подписки провода.
        expect(seen, [7, null]);
        await sub.cancel();
      },
    );

    test(
      'карта подписчиков не растёт: watcherCount возвращается к нулю после отмены',
      () async {
        final registry = registryWith();
        final session = registry.mint(
          userId: 7,
          name: 'A',
          role: 'cashier',
          permissions: const {},
          operatingMode: 0,
          pointMode: 'cashier',
          shiftOpen: false,
          terminalId: 1,
        );

        expect(registry.watcherCount, 0);

        final sub = registry.watch(session.token).listen((_) {});
        expect(registry.watcherCount, 1);

        await sub.cancel();

        // Без уборки в onCancel запись осталась бы навсегда: токен минтится
        // заново на каждый вход, и карта подписчиков росла бы без предела на
        // кассе, что работает месяцами без перезапуска.
        expect(registry.watcherCount, 0);
      },
    );

    test(
      'продление меняет только срок — остальные поля переживают его как есть',
      () {
        // `lookup` собирает продлённый сеанс через `AuthSession.copyWith`, а не
        // вручную по десяти полям, как было до неё — ручная сборка молча
        // теряла бы новое поле в продлении, не предупредив об этом ни типом,
        // ни тестом. Здесь сверяется каждое поле, кроме `expiresAt`.
        final registry = registryWith(idle: const Duration(minutes: 30));
        final minted = registry.mint(
          userId: 7,
          name: 'Айгуль',
          role: 'cashier',
          permissions: const {'nav.sale', 'settings.hardware'},
          operatingMode: 2,
          pointMode: 'unattended',
          shiftOpen: true,
          terminalId: 9,
        );

        now = now.add(const Duration(minutes: 1));
        final extended = registry.lookup(minted.token)!;

        expect(extended.token, minted.token);
        expect(extended.userId, minted.userId);
        expect(extended.name, minted.name);
        expect(extended.role, minted.role);
        expect(extended.permissions, minted.permissions);
        expect(extended.operatingMode, minted.operatingMode);
        expect(extended.pointMode, minted.pointMode);
        expect(extended.shift, minted.shift);
        expect(extended.issuedAt, minted.issuedAt);
        expect(extended.terminalId, minted.terminalId);
        expect(
          extended.expiresAt,
          isNot(minted.expiresAt),
          reason: 'только это поле и обязано было продлиться',
        );
      },
    );

    test(
      'revokeForUser гасит сеансы затронутого пользователя и не трогает '
      'чужие',
      () {
        // Задача правки после 19: `revokeAll()`, которым первая версия
        // `user_management_screen.dart` реагировала на смену PIN, гасила
        // всю кассу — второй кассир, работающий на той же кассе, вылетал
        // бы посреди смены. `revokeForUser` сужает отзыв до сеансов
        // одного [userId].
        final registry = registryWith();
        final mine1 = registry.mint(
          userId: 7,
          name: 'Айгуль',
          role: 'cashier',
          permissions: const {},
          operatingMode: 0,
          pointMode: 'cashier',
          shiftOpen: false,
          terminalId: 1,
        );
        final mine2 = registry.mint(
          userId: 7,
          name: 'Айгуль',
          role: 'cashier',
          permissions: const {},
          operatingMode: 0,
          pointMode: 'cashier',
          shiftOpen: false,
          terminalId: 2,
        );
        final other = registry.mint(
          userId: 999,
          name: 'Сторонний кассир',
          role: 'cashier',
          permissions: const {},
          operatingMode: 0,
          pointMode: 'cashier',
          shiftOpen: false,
          terminalId: 3,
        );

        registry.revokeForUser(7);

        expect(
          registry.lookup(mine1.token),
          isNull,
          reason: 'первый сеанс затронутого пользователя обязан погаснуть',
        );
        expect(
          registry.lookup(mine2.token),
          isNull,
          reason:
              'второй сеанс того же пользователя (другой терминал) тоже '
              'обязан погаснуть',
        );
        expect(
          registry.lookup(other.token),
          isNotNull,
          reason:
              'сеанс постороннего пользователя не должен пострадать — в '
              'этом и есть отличие от revokeAll()',
        );
        expect(registry.outstanding, 1);
      },
    );

    test(
      'вкладка затронутого пользователя уходит на вход сама, вкладка '
      'соседа — нет',
      () async {
        // Зеркалит «слежение доносит гашение до подписчика» выше, но через
        // revokeForUser: живая подписка (задача 5) обязана сработать для
        // отозванного сеанса ровно так же, как для revoke()/revokeAll(), и
        // не сработать для чужого.
        final registry = registryWith();
        final affected = registry.mint(
          userId: 7,
          name: 'Айгуль',
          role: 'cashier',
          permissions: const {},
          operatingMode: 0,
          pointMode: 'cashier',
          shiftOpen: false,
          terminalId: 1,
        );
        final neighbor = registry.mint(
          userId: 999,
          name: 'Сторонний кассир',
          role: 'cashier',
          permissions: const {},
          operatingMode: 0,
          pointMode: 'cashier',
          shiftOpen: false,
          terminalId: 2,
        );

        final affectedEvents = <int?>[];
        final neighborEvents = <int?>[];
        final affectedSub = registry
            .watch(affected.token)
            .listen((s) => affectedEvents.add(s?.userId));
        final neighborSub = registry
            .watch(neighbor.token)
            .listen((s) => neighborEvents.add(s?.userId));

        registry.revokeForUser(7);
        await Future<void>.delayed(Duration.zero);

        expect(
          affectedEvents,
          [7, null],
          reason: 'вкладка затронутого пользователя обязана узнать о '
              'гашении и уйти на вход сама',
        );
        expect(
          neighborEvents,
          [999],
          reason:
              'вкладка соседа не должна получить гашение вовсе — её сеанс '
              'не тронут',
        );

        await affectedSub.cancel();
        await neighborSub.cancel();
      },
    );

    group('SessionAdmin — задача 19 закрытия долга безопасности', () {
      test('live не несёт токена и отдаёт актуальный список', () {
        final registry = registryWith();
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
          userId: 8,
          name: 'Бота',
          role: 'administrator',
          permissions: const {},
          operatingMode: 0,
          pointMode: 'cashier',
          shiftOpen: false,
          terminalId: 2,
        );

        final list = registry.live;

        expect(list, hasLength(2));
        expect(list.map((s) => s.terminalId).toSet(), {1, 2});
        expect(list.map((s) => s.name).toSet(), {'Айгуль', 'Бота'});
      });

      test('истёкший сеанс не попадает в live', () {
        final registry = registryWith(idle: const Duration(minutes: 30));
        registry.mint(
          userId: 7,
          name: 'A',
          role: 'cashier',
          permissions: const {},
          operatingMode: 0,
          pointMode: 'cashier',
          shiftOpen: false,
          terminalId: 1,
        );

        now = now.add(const Duration(minutes: 31));

        expect(registry.live, isEmpty);
      });

      test('revokeSession гасит сеанс терминала, второй раз молчит', () {
        final registry = registryWith();
        final session = registry.mint(
          userId: 7,
          name: 'A',
          role: 'cashier',
          permissions: const {},
          operatingMode: 0,
          pointMode: 'cashier',
          shiftOpen: false,
          terminalId: 42,
        );

        expect(registry.revokeSession(42), completion(isTrue));
        expect(registry.lookup(session.token), isNull);
      });

      test('revokeSession неизвестного терминала отвечает false, не ошибкой', () {
        final registry = registryWith();
        expect(registry.revokeSession(999), completion(isFalse));
      });

      // Задача 5: вкладка, чей сеанс отозвали, уходит на вход сама — через
      // `watch(token)`, на который подписан `LoginNotifier` (браузер).
      // Отзыв из списка сеансов обязан пройти по тому же пути: этот тест —
      // прямое доказательство, что `revokeSession` (админ, по терминалу)
      // доходит до того же самого подписчика токена, что и `revoke` (сам
      // кассир, по токену) — без него у отозванной вкладки не было бы
      // никакого способа узнать об отзыве до следующего собственного
      // действия.
      test(
        'сеанс, отозванный по терминалу, гасит подписку того же токена — '
        'тот самый путь, которым отозванная вкладка уходит на вход сама',
        () async {
          final registry = registryWith();
          final session = registry.mint(
            userId: 7,
            name: 'A',
            role: 'cashier',
            permissions: const {},
            operatingMode: 0,
            pointMode: 'cashier',
            shiftOpen: false,
            terminalId: 42,
          );

          final seen = <int?>[];
          final sub = registry
              .watch(session.token)
              .listen((s) => seen.add(s?.userId));
          await Future<void>.delayed(Duration.zero);
          expect(seen, [7], reason: 'снимок на момент подписки — сеанс жив');

          final revoked = await registry.revokeSession(42);
          await Future<void>.delayed(Duration.zero);

          expect(revoked, isTrue);
          expect(
            seen,
            [7, null],
            reason:
                'ровно то событие, на которое реагирует LoginNotifier '
                '(lib/presentation/controllers/auth/login_controller.dart): '
                'вкладка уходит на вход без единого нажатия',
          );

          await sub.cancel();
        },
      );

      test('watchLiveSessions отдаёт снимок, потом вход и отзыв', () async {
        final registry = registryWith();

        final seen = <int>[];
        final sub = registry.watchLiveSessions().listen(
          (list) => seen.add(list.length),
        );
        await Future<void>.delayed(Duration.zero);
        expect(seen, [0], reason: 'снимок на момент подписки — сеансов нет');

        registry.mint(
          userId: 7,
          name: 'A',
          role: 'cashier',
          permissions: const {},
          operatingMode: 0,
          pointMode: 'cashier',
          shiftOpen: false,
          terminalId: 1,
        );
        await Future<void>.delayed(Duration.zero);
        expect(seen, [0, 1], reason: 'новый вход доехал до подписчика списка');

        await registry.revokeSession(1);
        await Future<void>.delayed(Duration.zero);
        expect(seen, [0, 1, 0], reason: 'отзыв доехал до подписчика списка');

        await sub.cancel();
      });

      test(
        'отзыв каждого из нескольких сеансов доходит до подписчика списка, '
        'не только до подписчика токена',
        () async {
          // Зеркалит тест выше (`revokeSession`), только на двух сеансах
          // сразу — задача 21 закрытия долга безопасности сняла `revokeAll`
          // (не звался ни одной строкой рабочего кода), и эта проверка
          // больше не может опираться на него: она бьёт по [revokeForUser]
          // за оба сеанса подряд, доказывая то же самое свойство —
          // широковещательный сигнал доходит на каждый отзыв, а не только
          // на первый.
          final registry = registryWith();
          registry.mint(
            userId: 1,
            name: 'A',
            role: 'cashier',
            permissions: const {},
            operatingMode: 0,
            pointMode: 'cashier',
            shiftOpen: false,
            terminalId: 1,
          );
          registry.mint(
            userId: 2,
            name: 'B',
            role: 'cashier',
            permissions: const {},
            operatingMode: 0,
            pointMode: 'cashier',
            shiftOpen: false,
            terminalId: 2,
          );

          final seen = <int>[];
          final sub = registry.watchLiveSessions().listen(
            (list) => seen.add(list.length),
          );
          await Future<void>.delayed(Duration.zero);
          expect(seen, [2]);

          // Между отзывами — своя пауза на каждый: `live` в подписчике
          // выше читает состояние на момент доставки, а не на момент
          // `add()`, так что без паузы обе доставки видели бы уже конечное
          // состояние (0), а не промежуточное (1) — это про доставку
          // событий, а не про то, что здесь проверяется.
          registry.revokeForUser(1);
          await Future<void>.delayed(Duration.zero);
          registry.revokeForUser(2);
          await Future<void>.delayed(Duration.zero);

          expect(seen, [2, 1, 0]);
          await sub.cancel();
        },
      );
    });

    test('чтение по порту продлевает сеанс', () {
      final registry = registryWith(idle: const Duration(minutes: 30));
      final session = registry.mint(
        userId: 7,
        name: 'A',
        role: 'cashier',
        permissions: const {},
        operatingMode: 0,
        pointMode: 'cashier',
        shiftOpen: false,
        terminalId: 1,
      );
      final SessionLookup port = registry;

      now = now.add(const Duration(minutes: 20));
      expect(port.sessionFor(session.token), isNotNull);

      now = now.add(const Duration(minutes: 20));
      // Без продления сеанс был бы мёртв на 31-й минуте; чтение на 20-й
      // сдвинуло срок. Сегодня продлевать его некому вовсе: lookup не зовёт
      // ни одна строка рабочего кода.
      expect(port.sessionFor(session.token), isNotNull);
    });

    test('просроченный токен порт не отдаёт', () {
      final registry = registryWith(idle: const Duration(minutes: 30));
      final session = registry.mint(
        userId: 7,
        name: 'A',
        role: 'cashier',
        permissions: const {},
        operatingMode: 0,
        pointMode: 'cashier',
        shiftOpen: false,
        terminalId: 1,
      );
      final SessionLookup port = registry;

      now = now.add(const Duration(minutes: 31));

      expect(port.sessionFor(session.token), isNull);
    });

    group(
      'правка 3 разбора (2026-08-21) — продление доходит до подписчика',
      () {
        // До этой правки `_notify` в `lookup` не звался вовсе — продление
        // молчало. Вкладка, ни разу не перезагрузившая страницу (значит, ни
        // разу заново не подписавшаяся через `watch()`), помнила бы срок с
        // момента своей последней подписки и в какой-то момент посчитала бы
        // себя истёкшей — даже если касса всё это время реально продлевала
        // сеанс по операциям с провода. Это зеркало дефекта про отзыв: там
        // врали про истечение отозванного сеанса, здесь врали бы про
        // истечение живого.
        test(
          'заметный сдвиг срока доходит до подписчика без переподписки (F5)',
          () async {
            final registry = registryWith(idle: const Duration(minutes: 30));
            final session = registry.mint(
              userId: 7,
              name: 'A',
              role: 'cashier',
              permissions: const {},
              operatingMode: 0,
              pointMode: 'cashier',
              shiftOpen: false,
              terminalId: 1,
            );

            final seen = <DateTime?>[];
            final sub = registry
                .watch(session.token)
                .listen((s) => seen.add(s?.expiresAt));
            await Future<void>.delayed(Duration.zero);
            // Первое значение — снимок на момент подписки, т.е. срок с mint.
            expect(seen, [session.expiresAt]);

            // Первое обращение к lookup всегда доносит продление до
            // подписчика (нет ранее разосланного срока, с которым сравнивать
            // сдвиг) — это и есть первая реальная активность по сеансу.
            now = now.add(const Duration(minutes: 1));
            registry.lookup(session.token);
            await Future<void>.delayed(Duration.zero);
            expect(
              seen.length,
              2,
              reason: 'первое продление обязано дойти до подписчика',
            );
            final firstNotifiedExpiry = seen.last;
            expect(firstNotifiedExpiry, isNot(session.expiresAt));

            // Мелкий сдвиг (2 минуты — меньше половины 30-минутного окна)
            // подписчику не разослан: не на каждой операции, см. докстринг
            // `lookup`. Карта сеансов при этом реально продлена — просто
            // подписчик про этот конкретный сдвиг не узнал.
            now = now.add(const Duration(minutes: 2));
            registry.lookup(session.token);
            await Future<void>.delayed(Duration.zero);
            expect(
              seen.length,
              2,
              reason: 'мелкий сдвиг срока не стоит лишнего события на проводе',
            );

            // Заметный сдвиг (ещё 20 минут — вместе с прошлым необращённым
            // сдвигом это больше половины окна от последнего разосланного
            // срока) снова доходит.
            now = now.add(const Duration(minutes: 20));
            final extended = registry.lookup(session.token);
            await Future<void>.delayed(Duration.zero);
            expect(
              seen.length,
              3,
              reason: 'заметный сдвиг обязан снова дойти до подписчика',
            );
            expect(seen.last, extended!.expiresAt);
            expect(
              seen.last!.isAfter(firstNotifiedExpiry!),
              isTrue,
              reason:
                  'подписчик обязан увидеть более поздний срок, а не тот же '
                  'самый — иначе вкладка так и продолжит считать по старому',
            );

            await sub.cancel();
          },
        );

        test(
          'настоящий отзыв доходит немедленно, минуя порог продления',
          () async {
            final registry = registryWith(idle: const Duration(minutes: 30));
            final session = registry.mint(
              userId: 7,
              name: 'A',
              role: 'cashier',
              permissions: const {},
              operatingMode: 0,
              pointMode: 'cashier',
              shiftOpen: false,
              terminalId: 1,
            );

            final seen = <int?>[];
            final sub = registry
                .watch(session.token)
                .listen((s) => seen.add(s?.userId));
            await Future<void>.delayed(Duration.zero);

            // Секундой позже — заведомо меньше порога в половину окна —
            // сеанс отзывает владелец. Порог продления к настоящему гашению
            // не применяется вовсе: гашение не проходит через [lookup].
            now = now.add(const Duration(seconds: 1));
            registry.revoke(session.token);
            await Future<void>.delayed(Duration.zero);

            expect(seen, [7, null]);
            await sub.cancel();
          },
        );
      },
    );
  });
}
