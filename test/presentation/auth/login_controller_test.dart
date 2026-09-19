// Экран входа больше не читает базу и не считает PIN сам — он спрашивает
// `AuthRepository` и переносит ответ кассы в состояние. Эти тесты проверяют
// ровно две вещи, которых раньше не было ни строки: PIN уходит на кассу
// целиком, а не проверяется на месте (никакого `passwordEnc` в объекте
// попытки, никакого локального перебора), и у каждой из семи причин отказа
// есть собственное слово для человека — забытая восьмая причина не проходит
// мимо `switch` молча, а падает сборкой `messageForRejection`.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/domain/auth/auth_outcome.dart';
import 'package:telepos/domain/auth/auth_repository.dart';
import 'package:telepos/domain/auth/auth_user.dart';
import 'package:telepos/domain/auth/session_token_storage.dart';
import 'package:telepos/domain/host/host_capabilities.dart';
import 'package:telepos/domain/terminal/terminal.dart';
import 'package:telepos/domain/terminal/terminal_identity.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/terminal/terminal_secret_storage.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';
import 'package:telepos/presentation/controllers/auth/login_controller.dart';

import 'support/fakes.dart';
import 'package:telepos/domain/shift/shift_status.dart';

/// В отличие от [FakeTerminalIdentity] (`support/fakes.dart`) — на самом деле помнит: `remember`
/// пишет, `currentId` читает то, что было записано, `forget` стирает.
/// Нужен тестам ниже, которым важно различить «ещё не запомнено», «уже
/// запомнено» и «забыто снова».
class _StatefulTerminalIdentity implements TerminalIdentity {
  int? _id;

  /// Сколько раз звали `forget` — единственный способ проверить, что
  /// восстановление после `UnknownTerminalException` вообще коснулось
  /// личности, а не просто получило новый id откуда-то ещё.
  int forgetCallCount = 0;

  @override
  Future<int?> currentId() async => _id;

  @override
  Future<void> remember(int terminalId) async {
    _id = terminalId;
  }

  @override
  Future<void> forget() async {
    forgetCallCount++;
    _id = null;
  }
}

void main() {
  setUp(() {
    final getIt = GetIt.instance;
    if (getIt.isRegistered<TerminalIdentity>()) {
      getIt.unregister<TerminalIdentity>();
    }
    getIt.registerSingleton<TerminalIdentity>(FakeTerminalIdentity());
    // Умолчание — касса: до задачи 4 финального разбора `_resolveTerminalId`
    // звал `self()` всегда, и большинство тестов ниже об этом даже не знают.
    // Тесты, которым важен браузер, перерегистрируют это сами.
    getIt.registerSingleton<HostCapabilities>(HostCapabilities.desktop);
  });

  tearDown(() => GetIt.instance.reset());

  test('PIN уезжает на кассу целиком, а хэши не приезжают', () async {
    final auth = FakeAuthRepository(
      const AuthRejection(AuthRejectionReason.wrongPin),
    );
    GetIt.instance.registerSingleton<AuthRepository>(auth);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(loginControllerProvider.notifier);
    notifier.initialize();
    // `watchUsers()` здесь — `Stream.value`, её единственное событие приходит
    // микрозадачей; ждём его, а не гадаем количеством `pump`.
    await Future<void>.delayed(Duration.zero);

    for (final digit in ['1', '2', '3', '4']) {
      notifier.addDigit(digit);
    }
    await notifier.pendingVerification;

    // Красный без правки контроллера: старый `LoginNotifier` не звал
    // `AuthRepository` вовсе — сам перебирал `passwordEnc` каждого кассира,
    // прочитанного из `AppDatabase`, и `FakeAuthRepository.login` не увидел бы ни
    // одного вызова (`auth.seen` осталось бы `null`).
    expect(auth.seen?.pin, '1234');
    expect(auth.seen?.terminalId, 1);
  });

  test('каждой причине отказа — своё сообщение, а не общее «ошибка»', () {
    final messages = <AuthRejectionReason, String>{};
    for (final reason in AuthRejectionReason.values) {
      final message = messageForRejection(reason);
      // Красный без правки: `messageForRejection` в брифе используется, но
      // нигде не объявлен — этот файл не собрался бы вовсе.
      expect(message, isNotEmpty, reason: 'причина $reason осталась немой');
      messages[reason] = message;
    }

    // Не только «непусто» — ещё и «не одно и то же слово на все причины»:
    // общий текст в духе «ошибка входа» на каждую ветку тоже прошёл бы
    // проверку выше, но не сказал бы человеку, что делать именно сейчас.
    expect(
      messages.values.toSet(),
      hasLength(AuthRejectionReason.values.length),
      reason:
          'семь причин обязаны звучать семью разными словами, а не одним '
          'общим на все',
    );
  });

  // Главный тест правки про задержку. До неё каждая цифра начиная с
  // четвёртой сама звала кассу — у шестизначного PIN цифры 4 и 5 всегда
  // «неверный PIN» (неполный префикс), то есть проверенная попытка
  // засчитывала кассе (`LoginThrottle`) две неудачи прежде, чем человек
  // дописал бы свой код. `testWidgets`, а не простой `test()`: только у
  // `WidgetTester.pump(duration)` есть поддельные часы, которые двигают
  // настоящий `Timer` внутри `LoginNotifier`, не дожидаясь его в реальном
  // времени — тем же приёмом, каким уже набирают PIN в
  // `test/e2e/journeys/login_test.dart`.
  testWidgets('шесть цифр подряд дают ровно одно обращение к кассе, а не три', (
    tester,
  ) async {
    final auth = FakeAuthRepository(
      const AuthRejection(AuthRejectionReason.wrongPin),
    );
    GetIt.instance.registerSingleton<AuthRepository>(auth);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(loginControllerProvider.notifier);
    notifier.initialize();
    await tester.pump();

    // Быстрый честный набор: 60 мс между нажатиями, много меньше
    // 500-миллисекундной задержки — если бы задержки не было, цифры 4 и 5
    // уже позвали бы кассу сами по себе.
    for (final digit in ['1', '2', '3', '4', '5', '6']) {
      notifier.addDigit(digit);
      await tester.pump(const Duration(milliseconds: 60));
    }

    // Шестая цифра — дальше набирать некуда, и `_scheduleVerify` проверяет
    // её без задержки. Секунда добавлена на случай, если бы это оказалось
    // не так: тогда задержке дают истечь целиком, а не гадают, что она уже
    // прошла.
    await tester.pump(const Duration(seconds: 1));

    expect(
      auth.callCount,
      1,
      reason:
          'без задержки каждая цифра от четвёртой звала бы кассу — здесь '
          'было бы 3',
    );
    expect(auth.seen?.pin, '123456');
  });

  // Задача 46 плана «Продажа с браузерного терминала»: автопроверка
  // неполного PIN, который касса отвергла как неверный. Попытка на кассе к
  // этому моменту **уже сгорела** (`penalizeFailure` зовётся до сверки PIN),
  // а буфер оставался прежним: кассир дописывал цифры к отвергнутому
  // префиксу и тратил вторую попытку тем же набором. Красный на `9ac079a5`:
  // ветка `showNow == false` не трогала `enteredPin` вовсе.
  testWidgets('отвергнутый при автопроверке неполный PIN стирается из набора', (
    tester,
  ) async {
    final auth = FakeAuthRepository(
      const AuthRejection(AuthRejectionReason.wrongPin),
    );
    GetIt.instance.registerSingleton<AuthRepository>(auth);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(loginControllerProvider.notifier);
    notifier.initialize();
    await tester.pump();

    // Четыре цифры из шести возможных и пауза длиннее задержки — ровно
    // случай `showNow == false`: автопроверка, не предел длины, `wrongPin`.
    for (final digit in ['1', '2', '3', '4']) {
      notifier.addDigit(digit);
    }
    await tester.pump(const Duration(seconds: 1));

    expect(
      auth.callCount,
      1,
      reason: 'предпосылка: автопроверка дошла до кассы и попытка потрачена',
    );
    expect(
      container.read(loginControllerProvider).enteredPin,
      isEmpty,
      reason:
          'Касса уже засчитала неудачу, а набор остался: следующая цифра '
          'допишется к отвергнутому префиксу и сожжёт вторую попытку.',
    );
  });

  // Найдено ревью (отложено с задачи 11 до этой): `removeDigit`/`clearPin`
  // отменяли `Timer`, но не трогали `_inFlight` — будущее, которое исполняет
  // `Completer` внутри `_scheduleVerify`. Отменённый таймер не зовёт
  // `completer.complete(...)` никогда, и `pendingVerification` осталась бы
  // висеть до следующего набора.
  testWidgets('стёртая во время задержки цифра не оставляет ожидание висеть', (
    tester,
  ) async {
    final auth = FakeAuthRepository(
      const AuthRejection(AuthRejectionReason.wrongPin),
    );
    GetIt.instance.registerSingleton<AuthRepository>(auth);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(loginControllerProvider.notifier);
    notifier.initialize();
    await tester.pump();

    // Четыре цифры — дошли до `minPinLength`, `_scheduleVerify` завела
    // debounce-таймер на 500 мс. Он ещё не сработал.
    for (final digit in ['1', '2', '3', '4']) {
      notifier.addDigit(digit);
    }

    // Стирает цифру, пока таймер ещё висит — ровно тот момент, который
    // раньше терял `_inFlight`.
    notifier.removeDigit();

    // Красный без правки контроллера: `pendingVerification` здесь была бы
    // будущим отменённого `Completer`, которое не звало кассу и никогда бы
    // не завершилось само — `.timeout` сработал бы своим отдельным
    // таймером и `await` ниже бросил бы `TimeoutException`, не дождавшись
    // 60 мс. С правкой `_inFlight` уже `null` в момент `removeDigit()`, и
    // `pendingVerification` — готовое `Future.value()`, которое `.timeout`
    // пропускает не заводя собственный таймер вовсе.
    final pending = notifier.pendingVerification.timeout(
      const Duration(milliseconds: 50),
    );
    await tester.pump(const Duration(milliseconds: 60));
    await pending;

    expect(
      auth.callCount,
      0,
      reason: 'цифру стёрли раньше срабатывания — кассу спрашивать не о чем',
    );
  });

  test(
    'терминал, которого клиент ещё не помнит, добывается и запоминается',
    () async {
      final getIt = GetIt.instance;
      getIt.unregister<TerminalIdentity>();
      final identity = _StatefulTerminalIdentity();
      getIt.registerSingleton<TerminalIdentity>(identity);

      final terminals = FakeTerminalRepository(
        self: () async => const Terminal(
          id: 42,
          name: 'Касса 1',
          pointMode: PointMode.cashier,
        ),
      );
      getIt.registerSingleton<TerminalRepository>(terminals);

      final auth = FakeAuthRepository(
        const AuthRejection(AuthRejectionReason.wrongPin),
      );
      getIt.registerSingleton<AuthRepository>(auth);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(loginControllerProvider.notifier);
      notifier.initialize();
      await Future<void>.delayed(Duration.zero);

      expect(
        await identity.currentId(),
        isNull,
        reason: 'до первого входа терминал ничего не запомнил',
      );

      for (final digit in ['1', '2', '3', '4']) {
        notifier.addDigit(digit);
      }
      await notifier.pendingVerification;

      // Красный без правки: до неё `_verifyPin` спрашивал только
      // `TerminalIdentity.currentId()` и на `null` сразу сдавался
      // (`error.terminal_unknown`) — `terminals.selfCallCount` осталось бы
      // `0`, а не `1`.
      expect(
        terminals.selfCallCount,
        1,
        reason: 'первый вход обязан спросить кассу про её личность',
      );
      expect(
        await identity.currentId(),
        42,
        reason: 'найденный терминал обязан быть запомнен, а не спрошен заново',
      );
      expect(
        auth.seen?.terminalId,
        42,
        reason: 'попытка входа обязана нести найденный id',
      );

      notifier.clearPin();
      for (final digit in ['5', '6', '7', '8']) {
        notifier.addDigit(digit);
      }
      await notifier.pendingVerification;

      expect(
        terminals.selfCallCount,
        1,
        reason:
            'второй вход обязан найти уже запомненный id и не спрашивать '
            'кассу снова',
      );
      expect(auth.callCount, 2, reason: 'оба входа всё же дошли до кассы');
    },
  );

  test(
    'ненастроенная касса даёт названную причину, а не общий отказ',
    () async {
      final getIt = GetIt.instance;
      getIt.unregister<TerminalIdentity>();
      getIt.registerSingleton<TerminalIdentity>(_StatefulTerminalIdentity());

      final terminals = FakeTerminalRepository(
        self: () async => throw const InstallationNotConfiguredException(),
      );
      getIt.registerSingleton<TerminalRepository>(terminals);

      // Не должен даже понадобиться — до вопроса о PIN дело дойти не должно.
      final auth = FakeAuthRepository(
        const AuthRejection(AuthRejectionReason.wrongPin),
      );
      getIt.registerSingleton<AuthRepository>(auth);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(loginControllerProvider.notifier);
      notifier.initialize();
      await Future<void>.delayed(Duration.zero);

      for (final digit in ['1', '2', '3', '4']) {
        notifier.addDigit(digit);
      }
      await notifier.pendingVerification;

      // Красный без правки: раньше отказ этого рода вообще не существовал —
      // `TerminalRepository` контроллер не звал, а `null` от
      // `TerminalIdentity.currentId()` давал общее `error.terminal_unknown`,
      // а не названную причину «касса не настроена».
      expect(
        container.read(loginControllerProvider).error,
        'error.till_not_configured',
        reason:
            'человек обязан узнать, что кассу не настроили, а не увидеть общее '
            '«ошибка входа»',
      );
      expect(
        auth.callCount,
        0,
        reason: 'касса не настроена — вопроса о PIN быть не должно вовсе',
      );
    },
  );

  // Задача 12: `getPostLoginRoute()` спрашивает `HostCapabilities.ownsData`
  // раньше состояния смены. Красный без правки — до неё метод сразу смотрел
  // на `state.isShiftOpened` и при открытой смене вернул бы
  // `NavDestinations.defaultRoute(...)` (маршрут продажи), которого под
  // браузер не существует, вместо `AppRoutes.terminalHome`.
  test(
    'там, где базы нет, вход ведёт на дом терминала — даже при открытой смене',
    () async {
      GetIt.instance.unregister<HostCapabilities>();
      GetIt.instance.registerSingleton<HostCapabilities>(
        HostCapabilities.browser,
      );
      // Пункт 2 фазы 3/4 закрытия долга: браузер больше не находит
      // `terminalId` в `TerminalIdentity` (`FakeTerminalIdentity.currentId()`
      // здесь как раз отдал бы `1` — умолчание `setUp()`) — каждая сессия
      // обязана назвать себя кассе заново, значит `TerminalRepository`
      // теперь нужен и этому тесту, хотя раньше обходился без него. С
      // задачи 7 плана «знакомство терминала с кассой» (разбор блокера)
      // это ещё и код привязки — этому тесту он не интересен сам по себе,
      // поэтому вводится и отправляется тем же путём, каким это делал бы
      // человек, прежде чем набирать PIN.
      GetIt.instance.registerSingleton<TerminalRepository>(
        FakeTerminalRepository(
          register: (name, code) async =>
              Terminal(id: 1, name: name, pointMode: PointMode.cashier),
        ),
      );

      final session = AuthSession(
        token: 't',
        userId: 7,
        name: 'Айгуль',
        role: 'cashier',
        permissions: const {'nav.sale'},
        operatingMode: 0,
        pointMode: 'cashier',
        shift: ShiftStatus.open,
        issuedAt: DateTime(2026, 8, 20),
        expiresAt: DateTime(2026, 8, 21),
        terminalId: 1,
      );
      GetIt.instance.registerSingleton<AuthRepository>(
        FakeAuthRepository(session),
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(loginControllerProvider.notifier);
      notifier.initialize();
      await Future<void>.delayed(Duration.zero);

      notifier.updateEnrolmentCode('код-от-оператора');
      await notifier.submitEnrolmentCode();

      for (final digit in ['1', '2', '3', '4']) {
        notifier.addDigit(digit);
      }
      await notifier.pendingVerification;

      expect(
        container.read(loginControllerProvider).isAuthenticated,
        isTrue,
        reason: 'сеанс обязан был приняться — иначе весь тест ни о чём',
      );
      expect(notifier.getPostLoginRoute(), AppRoutes.terminalHome);
    },
  );

  // Обратная сторона предыдущего теста: там, где база есть (касса), правка
  // задачи 12 не имеет права поменять старый маршрут — `HostCapabilities`
  // здесь только добавляет ветку раньше, а не заменяет остальные.
  test(
    'там, где база есть, закрытая смена по-прежнему ведёт на /shift',
    () async {
      // `HostCapabilities.desktop` — уже умолчание `setUp()`, регистрировать
      // его здесь снова означало бы упасть на дублирующей записи в GetIt.

      final session = AuthSession(
        token: 't',
        userId: 7,
        name: 'Айгуль',
        role: 'cashier',
        permissions: const {'nav.sale'},
        operatingMode: 0,
        pointMode: 'cashier',
        shift: ShiftStatus.closed,
        issuedAt: DateTime(2026, 8, 20),
        expiresAt: DateTime(2026, 8, 21),
        terminalId: 1,
      );
      GetIt.instance.registerSingleton<AuthRepository>(
        FakeAuthRepository(session),
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(loginControllerProvider.notifier);
      notifier.initialize();
      await Future<void>.delayed(Duration.zero);

      for (final digit in ['1', '2', '3', '4']) {
        notifier.addDigit(digit);
      }
      await notifier.pendingVerification;

      expect(container.read(loginControllerProvider).isAuthenticated, isTrue);
      expect(notifier.getPostLoginRoute(), AppRoutes.shift);
    },
  );

  // Финальный разбор задачи 12: `_resolveTerminalId` там, где базы нет
  // (браузер), звал `self()` безусловно — тот же метод, каким пользуется
  // касса, — и `self()` в браузере уходит по проводу в `terminals.selfEnsure`,
  // которая отдаёт строку самой кассы. Каждый браузерный терминал
  // представлялся кассой: пересечение прав по режиму точки получало
  // `pointMode` кассы, а `LoginThrottle` запирал всех сразу одним счётчиком.
  group('личность браузерного терминала', () {
    test(
      'браузер заводит себе терминал через register, а не через self()',
      () async {
        final getIt = GetIt.instance;
        getIt.unregister<HostCapabilities>();
        getIt.registerSingleton<HostCapabilities>(HostCapabilities.browser);

        getIt.unregister<TerminalIdentity>();
        final identity = _StatefulTerminalIdentity();
        getIt.registerSingleton<TerminalIdentity>(identity);

        final terminals = FakeTerminalRepository(
          self: () async =>
              throw StateError('self() не имеет права звучать в браузере'),
          register: (name, code) async =>
              Terminal(id: 99, name: name, pointMode: PointMode.selfService),
        );
        getIt.registerSingleton<TerminalRepository>(terminals);

        final auth = FakeAuthRepository(
          const AuthRejection(AuthRejectionReason.wrongPin),
        );
        getIt.registerSingleton<AuthRepository>(auth);

        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(loginControllerProvider.notifier);
        notifier.initialize();
        await Future<void>.delayed(Duration.zero);

        // Задача 7 плана «знакомство терминала с кассой», разбор блокера:
        // без секрета и без кэша первая же попытка входа обязана попросить
        // код, а не позвать `register()` вслепую — красный без правки:
        // до неё `state.needsEnrolmentCode` не существовало вовсе, и
        // `_resolveTerminalId` уходил прямиком в `register(code: '')`.
        for (final digit in ['1', '2', '3', '4']) {
          notifier.addDigit(digit);
        }
        await notifier.pendingVerification;

        expect(
          terminals.registerCallCount,
          0,
          reason: 'без кода вопрос кассе задавать нечего',
        );
        expect(
          container.read(loginControllerProvider).needsEnrolmentCode,
          isTrue,
        );

        notifier.updateEnrolmentCode('код-от-оператора');
        await notifier.submitEnrolmentCode();

        expect(
          container.read(loginControllerProvider).needsEnrolmentCode,
          isFalse,
          reason: 'действительный код обязан снять гейт',
        );

        for (final digit in ['1', '2', '3', '4']) {
          notifier.addDigit(digit);
        }
        await notifier.pendingVerification;

        // Красный без правки: `self()` бросил бы (или, на настоящем
        // проводе, отдал бы строку кассы) — здесь брошено нарочно, чтобы
        // отличить «не звали self()» от «звали, но он бы сработал так же».
        expect(
          terminals.selfCallCount,
          0,
          reason: 'браузер не имеет права представляться кассой',
        );
        expect(terminals.registerCallCount, 1);
        expect(terminals.lastRegisterName, isNotEmpty);
        expect(terminals.lastRegisterCode, 'код-от-оператора');
        // Пункт 2 фазы 3/4 закрытия долга: браузер больше не кладёт
        // `terminalId` в `TerminalIdentity`/`localStorage` — касса верит
        // только тому, что сессия сама зарегистрировала на себе только что,
        // а не тому, что вкладка помнит с прошлой загрузки страницы
        // (докстринг `_resolveTerminalId`, `login_controller.dart`).
        // `identity.currentId()` остаётся `null` нарочно.
        expect(await identity.currentId(), isNull);
        expect(auth.seen?.terminalId, 99);
      },
    );

    test('второй вход тем же браузером не заводит второй терминал', () async {
      final getIt = GetIt.instance;
      getIt.unregister<HostCapabilities>();
      getIt.registerSingleton<HostCapabilities>(HostCapabilities.browser);

      getIt.unregister<TerminalIdentity>();
      final identity = _StatefulTerminalIdentity();
      getIt.registerSingleton<TerminalIdentity>(identity);

      final terminals = FakeTerminalRepository(
        self: () async => throw UnimplementedError(),
        register: (name, code) async =>
            Terminal(id: 99, name: name, pointMode: PointMode.selfService),
      );
      getIt.registerSingleton<TerminalRepository>(terminals);

      final auth = FakeAuthRepository(
        const AuthRejection(AuthRejectionReason.wrongPin),
      );
      getIt.registerSingleton<AuthRepository>(auth);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(loginControllerProvider.notifier);
      notifier.initialize();
      await Future<void>.delayed(Duration.zero);

      notifier.updateEnrolmentCode('код-от-оператора');
      await notifier.submitEnrolmentCode();

      for (final digit in ['1', '2', '3', '4']) {
        notifier.addDigit(digit);
      }
      await notifier.pendingVerification;

      notifier.clearPin();
      for (final digit in ['5', '6', '7', '8']) {
        notifier.addDigit(digit);
      }
      await notifier.pendingVerification;

      expect(
        terminals.registerCallCount,
        1,
        reason:
            'второй вход обязан найти уже запомненный id и не заводить '
            'терминал снова',
      );
      expect(auth.callCount, 2, reason: 'оба входа всё же дошли до кассы');
    });

    // Пункт 7 фазы 3/4 закрытия долга: до правки `_resolveTerminalId` ловил
    // `WireRefusal('terminal_limit_reached', …)` голым `catch (_)` — человек
    // видел `error.auth_unknown` («неизвестная ошибка»), код
    // `terminal_limit_reached` не читал никто.
    test('потолок терминалов называет причину человеку, а не «неизвестная '
        'ошибка»', () async {
      final getIt = GetIt.instance;
      getIt.unregister<HostCapabilities>();
      getIt.registerSingleton<HostCapabilities>(HostCapabilities.browser);

      getIt.unregister<TerminalIdentity>();
      getIt.registerSingleton<TerminalIdentity>(_StatefulTerminalIdentity());

      getIt.registerSingleton<TerminalRepository>(
        FakeTerminalRepository(
          self: () async => throw UnimplementedError(),
          register: (name, code) async => throw const WireRefusal(
            'terminal_limit_reached',
            'на этой кассе уже заведено 200 терминалов',
          ),
        ),
      );
      getIt.registerSingleton<AuthRepository>(
        FakeAuthRepository(const AuthRejection(AuthRejectionReason.wrongPin)),
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(loginControllerProvider.notifier);
      notifier.initialize();
      await Future<void>.delayed(Duration.zero);

      notifier.updateEnrolmentCode('код-от-оператора');
      await notifier.submitEnrolmentCode();

      expect(
        container.read(loginControllerProvider).error,
        'error.terminal_limit_reached',
        reason:
            'причина обязана называться поимённо, а не тонуть в общем '
            '«неизвестная ошибка»',
      );
      expect(
        container.read(loginControllerProvider).needsEnrolmentCode,
        isFalse,
        reason:
            'потолок терминалов — не про код: гейт снимается, чтобы экран '
            'вернулся к обычной ошибке, а не завис на форме ввода кода',
      );
    });

    // Задача 7 плана «знакомство терминала с кассой», разбор блокера:
    // код, который касса не признала, обязан назвать причину человеку
    // (`error.pairing_code_invalid`), а не общее «попробуйте ещё раз» —
    // это и есть БЛОКЕР 2 брифа задачи 7. Красный без правки: до неё этот
    // код тонул в голом `catch (_)` наравне с потолком терминалов, и
    // `state.error` стало бы `error.auth_unknown`.
    test(
      'неверный код привязки называет причину поимённо и держит гейт',
      () async {
        final getIt = GetIt.instance;
        getIt.unregister<HostCapabilities>();
        getIt.registerSingleton<HostCapabilities>(HostCapabilities.browser);

        getIt.unregister<TerminalIdentity>();
        getIt.registerSingleton<TerminalIdentity>(_StatefulTerminalIdentity());

        getIt.registerSingleton<TerminalRepository>(
          FakeTerminalRepository(
            self: () async => throw UnimplementedError(),
            register: (name, code) async => throw const WireRefusal(
              'pairing_code_invalid',
              'код привязки не найден, просрочен или уже использован',
            ),
          ),
        );
        getIt.registerSingleton<AuthRepository>(
          FakeAuthRepository(const AuthRejection(AuthRejectionReason.wrongPin)),
        );

        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(loginControllerProvider.notifier);
        notifier.initialize();
        await Future<void>.delayed(Duration.zero);

        notifier.updateEnrolmentCode('выдуманный-код');
        await notifier.submitEnrolmentCode();

        expect(
          container.read(loginControllerProvider).error,
          'error.pairing_code_invalid',
          reason:
              'человек обязан узнать, что дело в коде, а не увидеть общее '
              '«попробуйте ещё раз»',
        );
        expect(
          container.read(loginControllerProvider).needsEnrolmentCode,
          isTrue,
          reason:
              'форма ввода кода обязана остаться на экране — можно '
              'ввести другой код, не начиная заново',
        );
        expect(
          container.read(loginControllerProvider).enrolmentCode,
          isEmpty,
          reason:
              'отвергнутый (одноразовый на настоящей кассе) код не '
              'имеет смысла оставлять в поле',
        );
      },
    );
  });

  // Задача 5 плана «знакомство терминала с кассой» (шаг 2 спеки). Группа
  // «личность браузерного терминала» выше проверяет один и тот же
  // `LoginNotifier` (то же поле `_browserTerminalId` в памяти, «второй вход
  // тем же браузером») — здесь каждая «перезагрузка страницы» получает
  // **новый** `ProviderContainer`/`LoginNotifier` (тем же приёмом, что
  // умирает `_browserTerminalId`), а с ним делится только
  // `FakeTerminalSecretStorage` — тот самый двойник `localStorage`, который
  // переживает F5 по-настоящему.
  group('F5 переживает — секрет терминала (задача 5)', () {
    // `enrolmentCode` — задача 7 плана «знакомство терминала с кассой»,
    // разбор блокера: с задачи 6 `register()` без кода привязки всегда
    // отказывает `pairing_code_invalid`, значит там, где сценарий предполагает
    // настоящую заводку (а не только предъявление уже сохранённого секрета),
    // код обязан быть введён и отправлен раньше, чем PIN.
    Future<void> attemptLogin(
      ProviderContainer container, {
      String? enrolmentCode,
    }) async {
      final notifier = container.read(loginControllerProvider.notifier);
      notifier.initialize();
      await Future<void>.delayed(Duration.zero);
      if (enrolmentCode != null) {
        notifier.updateEnrolmentCode(enrolmentCode);
        await notifier.submitEnrolmentCode();
      }
      for (final digit in ['1', '2', '3', '4']) {
        notifier.addDigit(digit);
      }
      await notifier.pendingVerification;
    }

    test(
      'F5 (новый ProviderContainer, тот же секрет в хранилище) не заводит '
      'новой строки — предъявляет секрет через resume(), а не register()',
      () async {
        final getIt = GetIt.instance;
        getIt.unregister<HostCapabilities>();
        getIt.registerSingleton<HostCapabilities>(HostCapabilities.browser);
        getIt.unregister<TerminalIdentity>();
        getIt.registerSingleton<TerminalIdentity>(_StatefulTerminalIdentity());

        final secretStore = FakeTerminalSecretStorage();
        getIt.registerSingleton<TerminalSecretStorage>(secretStore);

        final terminals = FakeTerminalRepository(
          self: () async =>
              throw StateError('self() не имеет права звучать в браузере'),
          register: (name, code) async =>
              Terminal(id: 99, name: name, pointMode: PointMode.selfService),
          resume: (terminalId, secret) async {
            expect(terminalId, 99);
            expect(secret, FakeTerminalRepository.fakeSecret);
            return const Terminal(
              id: 99,
              name: 'Терминал у окна',
              pointMode: PointMode.selfService,
            );
          },
        );
        getIt.registerSingleton<TerminalRepository>(terminals);
        getIt.registerSingleton<AuthRepository>(
          FakeAuthRepository(const AuthRejection(AuthRejectionReason.wrongPin)),
        );

        // Первая «загрузка страницы»: секрета ещё нет — человек вводит код,
        // register() заводит терминал и сохраняет секрет — ровно то, что
        // делает `_resolveTerminalId` на самом первом входе этой вкладки.
        final firstContainer = ProviderContainer();
        addTearDown(firstContainer.dispose);
        await attemptLogin(firstContainer, enrolmentCode: 'код-от-оператора');

        expect(terminals.registerCallCount, 1);
        expect(
          secretStore.read(),
          (terminalId: 99, secret: FakeTerminalRepository.fakeSecret),
          reason: 'секрет обязан быть сохранён сразу после выдачи',
        );

        // F5: новый `ProviderContainer` — новый `LoginNotifier`,
        // `_browserTerminalId` умер вместе со старым (ровно то, что и делает
        // настоящая перезагрузка страницы) — но `secretStore` тот же самый
        // экземпляр, каким было бы `localStorage`, переживший перезагрузку.
        final secondContainer = ProviderContainer();
        addTearDown(secondContainer.dispose);
        await attemptLogin(secondContainer);

        expect(
          terminals.registerCallCount,
          1,
          reason:
              'ГЛАВНАЯ ПРОВЕРКА ЗАДАЧИ 5: F5 не имеет права завести новую '
              'строку терминала — брифом названо «сегодня заводит», это и '
              'есть красная линия, которую правка обязана передвинуть',
        );
        expect(
          terminals.resumeCallCount,
          1,
          reason: 'вторая «загрузка» обязана предъявить секрет, а не молчать',
        );
        expect(terminals.lastResumeArgs, (
          terminalId: 99,
          secret: FakeTerminalRepository.fakeSecret,
        ));
      },
    );

    // Задача 7 плана «знакомство терминала с кассой», разбор блокера: до
    // неё, обнаружив плохой секрет, `_resolveTerminalId` тут же звал
    // `register()` заново сам, без единого довода `code` — то есть на
    // настоящей кассе (с задачи 6) он получил бы `pairing_code_invalid`
    // ровно так же, как и самый первый вход. Правильное поведение — не
    // тихая автоматическая переустановка, а названная причина
    // (`error.terminal_secret_invalid`, пункт 7 брифа задачи 7) и гейт,
    // который снимается только новым кодом от человека.
    test('касса отказала сохранённому секрету — секрет забывается, гейт '
        'называет причину, а не переустанавливается тихо', () async {
      final getIt = GetIt.instance;
      getIt.unregister<HostCapabilities>();
      getIt.registerSingleton<HostCapabilities>(HostCapabilities.browser);
      getIt.unregister<TerminalIdentity>();
      getIt.registerSingleton<TerminalIdentity>(_StatefulTerminalIdentity());

      final secretStore = FakeTerminalSecretStorage()
        ..write(999, 'старый-чужой-или-испорченный-секрет');
      getIt.registerSingleton<TerminalSecretStorage>(secretStore);

      final terminals = FakeTerminalRepository(
        self: () async =>
            throw StateError('self() не имеет права звучать в браузере'),
        register: (name, code) async =>
            Terminal(id: 5, name: name, pointMode: PointMode.selfService),
        resume: (terminalId, secret) async => throw const WireRefusal(
          'terminal_secret_invalid',
          'терминал не найден или предъявленный секрет не подходит',
        ),
      );
      getIt.registerSingleton<TerminalRepository>(terminals);
      getIt.registerSingleton<AuthRepository>(
        FakeAuthRepository(const AuthRejection(AuthRejectionReason.wrongPin)),
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);
      await attemptLogin(container);

      expect(terminals.resumeCallCount, 1, reason: 'попытка предъявить была');
      expect(
        secretStore.clearCallCount,
        1,
        reason: 'касса доказала, что секрет плохой — он обязан быть забыт',
      );
      // ГЛАВНАЯ ПРОВЕРКА: красный без правки — старый код звал
      // `register()` здесь же, автоматически.
      expect(
        terminals.registerCallCount,
        0,
        reason:
            'без кода вопрос кассе задавать нечего — заводиться заново '
            'молча нельзя, задача 6 требует код на каждый register()',
      );
      expect(
        container.read(loginControllerProvider).needsEnrolmentCode,
        isTrue,
      );
      expect(
        container.read(loginControllerProvider).error,
        'error.terminal_secret_invalid',
        reason:
            '«старое устройство без секрета» обязано увидеть названную '
            'причину, а не общее «попробуйте ещё раз» (пункт 7 брифа '
            'задачи 7)',
      );

      // Человек получает новый код у оператора и вводит его — только
      // теперь вкладка заводится заново.
      final notifier = container.read(loginControllerProvider.notifier);
      notifier.updateEnrolmentCode('новый-код-от-оператора');
      await notifier.submitEnrolmentCode();

      expect(terminals.registerCallCount, 1);
      expect(terminals.lastRegisterCode, 'новый-код-от-оператора');
      expect(
        container.read(loginControllerProvider).needsEnrolmentCode,
        isFalse,
      );
      expect(
        secretStore.read(),
        (terminalId: 5, secret: FakeTerminalRepository.fakeSecret),
        reason:
            'новый секрет новой заводки обязан быть сохранён поверх старого',
      );
    });

    // До задачи 7 (разбор блокера) обрыв провода на `resume()` тоже вёл к
    // автоматической `register()` без единого кода — исправление то же,
    // что и выше: гейт вместо тихой попытки. Отличие от предыдущего теста —
    // секрет НЕ считается плохим (никакого `WireRefusal`), поэтому
    // `secretStore` не трогается — но с БЛОКЕРА пункта 4 финальной волны
    // (2026-08-24) `state.error` больше не остаётся `null`: до этой правки
    // человек видел тот же нейтральный текст, что и на настоящем новом
    // устройстве, и мог поверить ему и ввести код вручную — сжечь годный
    // одноразовый код и завести вторую строку терминала при живом секрете.
    // `error.auth_unknown` здесь не значит «дело в коде или в секрете» —
    // только «касса не ответила прямо сейчас», и это тот же ключ, что
    // ownsData-ветка использует на тот же смысл (`login_controller.dart`,
    // строка ~600).
    test(
      'провод недоступен на resume — хранилище не трогаем, гейт просит код '
      'с названной причиной, а не переустанавливается тихо и не молчит',
      () async {
        final getIt = GetIt.instance;
        getIt.unregister<HostCapabilities>();
        getIt.registerSingleton<HostCapabilities>(HostCapabilities.browser);
        getIt.unregister<TerminalIdentity>();
        getIt.registerSingleton<TerminalIdentity>(_StatefulTerminalIdentity());

        final secretStore = FakeTerminalSecretStorage()
          ..write(42, 'секрет-который-на-самом-деле-хорош');
        getIt.registerSingleton<TerminalSecretStorage>(secretStore);

        final terminals = FakeTerminalRepository(
          self: () async =>
              throw StateError('self() не имеет права звучать в браузере'),
          register: (name, code) async =>
              Terminal(id: 42, name: name, pointMode: PointMode.selfService),
          resume: (terminalId, secret) async =>
              throw Exception('провод недоступен'),
        );
        getIt.registerSingleton<TerminalRepository>(terminals);
        getIt.registerSingleton<AuthRepository>(
          FakeAuthRepository(const AuthRejection(AuthRejectionReason.wrongPin)),
        );

        final container = ProviderContainer();
        addTearDown(container.dispose);
        await attemptLogin(container);

        expect(terminals.resumeCallCount, 1);
        expect(
          secretStore.clearCallCount,
          0,
          reason:
              'обрыв провода не доказывает, что секрет плохой — стирать его '
              'на догадке нельзя',
        );
        expect(
          terminals.registerCallCount,
          0,
          reason:
              'без кода register() всё равно отказал бы — гейт вместо '
              'заведомо проигрышной попытки',
        );
        expect(
          container.read(loginControllerProvider).needsEnrolmentCode,
          isTrue,
        );
        expect(
          container.read(loginControllerProvider).error,
          'error.auth_unknown',
          reason:
              'обрыв провода обязан выставить названную причину вместе с '
              'гейтом — иначе человек видит тот же нейтральный текст, что и '
              'у настоящего нового устройства, поверит ему и сожжёт '
              'одноразовый код зря',
        );

        // Провод «ожил» (в этой подделке — просто потому, что человек
        // наконец ввёл код, который ему всё равно был бы нужен): гейт
        // снова пробует `resume()` первым (тот же секрет, тот же провод —
        // мок продолжает отказывать), убеждается, что он всё ещё недоступен,
        // и на этот раз, раз код уже введён, идёт в `register()`.
        final notifier = container.read(loginControllerProvider.notifier);
        notifier.updateEnrolmentCode('код-от-оператора');
        await notifier.submitEnrolmentCode();

        expect(
          terminals.resumeCallCount,
          2,
          reason:
              'секрет всё ещё в хранилище — resume() пробуется снова первым',
        );
        expect(terminals.registerCallCount, 1);
        expect(
          container.read(loginControllerProvider).needsEnrolmentCode,
          isFalse,
        );
      },
    );
  });

  // Пере-ревью финального разбора, пункт 2: `terminalId`, запомненный этой
  // вкладкой, больше не существует на кассе (восстановление из резервной
  // копии пересоздаёт терминалы) — до этой правки `_auth.login` звался без
  // единого `catch`, и исключение уходило в необработанное будущее:
  // `unawaited(_inFlight = _verifyPin(...))` в `attemptLogin`/
  // `_scheduleVerify`. Экран не показывал ничего — ни ошибки, ни ожидания.
  //
  // Пункт 2 фазы 3/4 закрытия долга сместил сам сценарий: браузер больше не
  // читает `terminalId` из `localStorage` вовсе (см. группу «личность
  // браузерного терминала» выше) — значит первая попытка любой новой сессии
  // уже зовёт `register()`, и `UnknownTerminalException` на первой попытке
  // означать «застрявший localStorage» больше не может. Настоящий (пусть и
  // редкий) случай теперь другой: терминал **этой самой сессии** удалили
  // (`terminals.delete`) между регистрацией и входом — гонка, не рабочий
  // путь, но касса обязана восстановиться так же, а не замолчать.
  // Задача 7 плана «знакомство терминала с кассой», разбор блокера: с
  // задачи 6 `register()` без кода привязки всегда отказывает
  // `pairing_code_invalid`, а код — одноразовый на настоящей кассе и
  // очищается из состояния сразу после того, как им воспользовались (успешно
  // или нет). Значит восстановление после `UnknownTerminalException` больше
  // не может звать `register()` автоматически, тем же кодом, каким терминал
  // только что завёлся, — оно заново показывает гейт и ждёт **нового** кода
  // от человека. Оба теста ниже — красные без правки контроллера: до неё
  // второй `register()` в обеих ветках звался сам, без единого довода `code`.
  group('терминал сессии удалили между регистрацией и входом', () {
    test('восстанавливается: сброс кэша сессии, гейт просит новый код, повтор '
        'входа проходит только после него', () async {
      final getIt = GetIt.instance;
      getIt.unregister<HostCapabilities>();
      getIt.registerSingleton<HostCapabilities>(HostCapabilities.browser);

      getIt.unregister<TerminalIdentity>();
      final identity = _StatefulTerminalIdentity();
      getIt.registerSingleton<TerminalIdentity>(identity);

      final terminals = FakeTerminalRepository(
        self: () async => throw UnimplementedError(),
        register: (name, code) async =>
            Terminal(id: 77, name: name, pointMode: PointMode.selfService),
      );
      getIt.registerSingleton<TerminalRepository>(terminals);

      final session = AuthSession(
        token: 'tok-7',
        userId: 3,
        name: 'Ерлан',
        role: 'cashier',
        permissions: const {'nav.sale'},
        operatingMode: 0,
        pointMode: 'selfService',
        shift: ShiftStatus.closed,
        issuedAt: DateTime(2026, 8, 21),
        expiresAt: DateTime(2026, 8, 22),
        terminalId: 1,
      );
      final auth = FakeAuthRepository(session)
        ..throwOnLogin.add(const UnknownTerminalException());
      getIt.registerSingleton<AuthRepository>(auth);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(loginControllerProvider.notifier);
      notifier.initialize();
      await Future<void>.delayed(Duration.zero);

      // Первая заводка этой сессии — человек уже знает код (только что
      // получил его у оператора).
      notifier.updateEnrolmentCode('код-1-от-оператора');
      await notifier.submitEnrolmentCode();
      expect(terminals.registerCallCount, 1);

      for (final digit in ['1', '2', '3', '4']) {
        notifier.addDigit(digit);
      }
      await notifier.pendingVerification;

      // `auth.login` бросил `UnknownTerminalException` — касса не узнала
      // терминал этой сессии (её удалили между заводкой и входом).
      // Восстановление сбрасывает кэш и зовёт `_resolveTerminalId` заново
      // — тот код, которым терминал только что завёлся, уже потрачен
      // (`enrolmentCode` очищается на успехе), так что вторая заводка САМА
      // СЕБЯ не проведёт: гейт возвращается, вход не завершён.
      expect(
        identity.forgetCallCount,
        1,
        reason:
            'вызов остаётся для десктопа — для браузера он теперь ничего '
            'не значит, но и не вредит',
      );
      expect(
        terminals.registerCallCount,
        1,
        reason:
            'ГЛАВНАЯ ПРОВЕРКА: без нового кода вторая заводка не имеет '
            'права состояться сама — красный без правки: старый код звал '
            'register() здесь автоматически, вторым разом',
      );
      expect(
        container.read(loginControllerProvider).needsEnrolmentCode,
        isTrue,
      );
      expect(container.read(loginControllerProvider).isAuthenticated, isFalse);
      expect(
        auth.callCount,
        1,
        reason: 'только первая попытка успела дойти до кассы',
      );

      // Оператор выдаёт новый код — человек вводит его, вкладка заводится
      // заново под тем же именем, и повтор входа наконец проходит.
      notifier.updateEnrolmentCode('код-2-от-оператора');
      await notifier.submitEnrolmentCode();
      expect(terminals.registerCallCount, 2);
      expect(terminals.lastRegisterCode, 'код-2-от-оператора');

      for (final digit in ['1', '2', '3', '4']) {
        notifier.addDigit(digit);
      }
      await notifier.pendingVerification;

      expect(auth.seen?.terminalId, 77);
      expect(
        auth.callCount,
        2,
        reason: 'вторая попытка входа — уже со свежим id, после нового кода',
      );
      expect(
        container.read(loginControllerProvider).isAuthenticated,
        isTrue,
        reason:
            'повтор с новым id после нового кода обязан пройти как '
            'обычный вход',
      );
    });

    test('если сбросить не выходит — названная причина, а не тишина', () async {
      final getIt = GetIt.instance;
      getIt.unregister<HostCapabilities>();
      getIt.registerSingleton<HostCapabilities>(HostCapabilities.browser);

      getIt.unregister<TerminalIdentity>();
      final identity = _StatefulTerminalIdentity();
      getIt.registerSingleton<TerminalIdentity>(identity);

      // Первая заводка (кодом человека) удаётся, вторая (после того как
      // касса не узнала терминал, уже другим кодом) — не выходит: провод
      // недоступен, например.
      var registerCalls = 0;
      final terminals = FakeTerminalRepository(
        self: () async => throw UnimplementedError(),
        register: (name, code) async {
          registerCalls++;
          if (registerCalls == 1) {
            return Terminal(
              id: 77,
              name: name,
              pointMode: PointMode.selfService,
            );
          }
          throw Exception('провод недоступен');
        },
      );
      getIt.registerSingleton<TerminalRepository>(terminals);

      final auth = FakeAuthRepository(
        const AuthRejection(AuthRejectionReason.wrongPin),
      )..throwOnLogin.add(const UnknownTerminalException());
      getIt.registerSingleton<AuthRepository>(auth);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(loginControllerProvider.notifier);
      notifier.initialize();
      await Future<void>.delayed(Duration.zero);

      notifier.updateEnrolmentCode('код-1-от-оператора');
      await notifier.submitEnrolmentCode();
      expect(registerCalls, 1);

      for (final digit in ['1', '2', '3', '4']) {
        notifier.addDigit(digit);
      }
      await notifier.pendingVerification;

      expect(identity.forgetCallCount, 1);
      expect(
        container.read(loginControllerProvider).needsEnrolmentCode,
        isTrue,
        reason: 'без нового кода восстановиться нечем — гейт возвращается',
      );
      expect(
        registerCalls,
        1,
        reason: 'без кода вторая заводка не звалась вовсе',
      );

      // Оператор выдаёт новый код — на этот раз сама заводка не выходит
      // (провод недоступен).
      notifier.updateEnrolmentCode('код-2-от-оператора');
      await notifier.submitEnrolmentCode();

      expect(registerCalls, 2);
      // Красный без правки: до неё этот путь либо не был достижим этим
      // тестом вовсе, либо (в исходной форме теста) молчал — здесь и есть
      // «провал восстановления обязан что-то сказать человеку».
      expect(
        container.read(loginControllerProvider).error,
        isNotNull,
        reason: 'провал восстановления обязан что-то сказать человеку',
      );
      expect(
        container.read(loginControllerProvider).needsEnrolmentCode,
        isTrue,
        reason: 'гейт остаётся — можно попробовать ещё раз, не начиная с PIN',
      );
      expect(container.read(loginControllerProvider).isAuthenticated, isFalse);
      expect(
        auth.callCount,
        1,
        reason: 'второй попытки входа быть не должно — заводить было не с чем',
      );
    });

    test('любой другой отказ провода тоже говорит, а не молчит', () async {
      final auth = FakeAuthRepository(
        const AuthRejection(AuthRejectionReason.wrongPin),
      )..throwOnLogin.add(Exception('обмен разошёлся'));
      GetIt.instance.registerSingleton<AuthRepository>(auth);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(loginControllerProvider.notifier);
      notifier.initialize();
      await Future<void>.delayed(Duration.zero);

      for (final digit in ['1', '2', '3', '4']) {
        notifier.addDigit(digit);
      }
      await notifier.pendingVerification;

      // Это и есть основной дефект пункта 2: `_auth.login` звался без
      // единого `catch`, и любое исключение — не только про устаревший
      // терминал — уходило в пустоту.
      expect(container.read(loginControllerProvider).error, isNotNull);
      expect(container.read(loginControllerProvider).isAuthenticated, isFalse);
    });
  });

  // Задача 3 финального разбора: `SessionTokenStore` регистрировался в
  // `main_web.dart` и не читался ниоткуда — `AuthRepository.logout` и
  // `watchSession` не звала ни одна строка рабочего кода.
  group('токен сеанса', () {
    test('успешный вход кладёт токен в хранилище браузера', () async {
      final getIt = GetIt.instance;
      final tokenStore = FakeSessionTokenStorage();
      getIt.registerSingleton<SessionTokenStorage>(tokenStore);

      final session = AuthSession(
        token: 'tok-1',
        userId: 7,
        name: 'Айгуль',
        role: 'cashier',
        permissions: const {'nav.sale'},
        operatingMode: 0,
        pointMode: 'cashier',
        shift: ShiftStatus.closed,
        issuedAt: DateTime(2026, 8, 20),
        expiresAt: DateTime(2026, 8, 21),
        terminalId: 1,
      );
      getIt.registerSingleton<AuthRepository>(FakeAuthRepository(session));

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(loginControllerProvider.notifier);
      notifier.initialize();
      await Future<void>.delayed(Duration.zero);

      for (final digit in ['1', '2', '3', '4']) {
        notifier.addDigit(digit);
      }
      await notifier.pendingVerification;

      expect(tokenStore.read(), 'tok-1');
    });

    test(
      'выход зовёт AuthRepository.logout(token) и чистит хранилище',
      () async {
        final getIt = GetIt.instance;
        final tokenStore = FakeSessionTokenStorage();
        getIt.registerSingleton<SessionTokenStorage>(tokenStore);

        final session = AuthSession(
          token: 'tok-2',
          userId: 7,
          name: 'Айгуль',
          role: 'cashier',
          permissions: const {},
          operatingMode: 0,
          pointMode: 'cashier',
          shift: ShiftStatus.closed,
          issuedAt: DateTime(2026, 8, 20),
          expiresAt: DateTime(2026, 8, 21),
          terminalId: 1,
        );
        final auth = FakeAuthRepository(session);
        getIt.registerSingleton<AuthRepository>(auth);

        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(loginControllerProvider.notifier);
        notifier.initialize();
        await Future<void>.delayed(Duration.zero);

        for (final digit in ['1', '2', '3', '4']) {
          notifier.addDigit(digit);
        }
        await notifier.pendingVerification;
        expect(tokenStore.read(), 'tok-2');

        await notifier.logout();

        // Красный без правки: `TerminalHomeScreen._logout` чистил только
        // `AppState` — ни касса, ни `sessionStorage` о выходе не узнавали.
        expect(auth.loggedOutToken, 'tok-2');
        expect(auth.logoutCallCount, 1);
        expect(tokenStore.read(), isNull);
        expect(
          container.read(loginControllerProvider).isAuthenticated,
          isFalse,
        );
      },
    );

    test('живой сеанс на подъёме — вход не спрашивается заново', () async {
      final getIt = GetIt.instance;
      final tokenStore = FakeSessionTokenStorage()
        ..write('tok-3', DateTime.now().add(const Duration(minutes: 25)));
      getIt.registerSingleton<SessionTokenStorage>(tokenStore);

      final auth = FakeAuthRepository(
        const AuthRejection(AuthRejectionReason.wrongPin),
      );
      auth.sessions['tok-3'] = AuthSession(
        token: 'tok-3',
        userId: 9,
        name: 'Данара',
        role: 'cashier',
        permissions: const {'nav.sale'},
        operatingMode: 0,
        pointMode: 'cashier',
        shift: ShiftStatus.open,
        issuedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        // Относительно `DateTime.now()`, а не календарной датой: этот тест
        // проходит через тот же `_restoreSession`, который проверяет
        // просрочку по-настоящему (пере-ревью финального разбора, пункт 1)
        // — фиксированная дата рано или поздно оказывается в прошлом
        // относительно настоящего времени прогона.
        expiresAt: DateTime.now().add(const Duration(minutes: 25)),
        terminalId: 1,
      );
      getIt.registerSingleton<AuthRepository>(auth);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(loginControllerProvider.notifier);
      notifier.initialize();
      await Future<void>.delayed(Duration.zero);

      // Красный без правки: до неё ничто на подъёме не читало токен —
      // `isAuthenticated` осталось бы `false`, и экран показывал бы выбор
      // кассира, хотя касса всё ещё считает сеанс живым.
      expect(container.read(loginControllerProvider).isAuthenticated, isTrue);
      expect(container.read(appStateProvider).userId, 9);
      expect(container.read(appStateProvider).userName, 'Данара');
      expect(auth.callCount, 0, reason: 'PIN тут вообще не при чём');
    });

    test('погасший сеанс на подъёме уводит на вход и чистит токен', () async {
      final getIt = GetIt.instance;
      // Хранимый expiresAt — в будущем: этот тест про отзыв, не про
      // истечение (пункт 6 второго круга задачи 7 различает их именно по
      // этой отметке — см. отдельный тест ниже про честное истечение).
      final tokenStore = FakeSessionTokenStorage()
        ..write('tok-4', DateTime.now().add(const Duration(minutes: 25)));
      getIt.registerSingleton<SessionTokenStorage>(tokenStore);

      final auth = FakeAuthRepository(
        const AuthRejection(AuthRejectionReason.wrongPin),
      );
      auth.sessions['tok-4'] = null;
      getIt.registerSingleton<AuthRepository>(auth);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(loginControllerProvider.notifier);
      notifier.initialize();
      await Future<void>.delayed(Duration.zero);

      expect(container.read(loginControllerProvider).isAuthenticated, isFalse);
      expect(
        container.read(loginControllerProvider).sessionEndedReason,
        'error.session_ended',
        reason:
            'хранимый expiresAt ещё в будущем — улики истечения нет, отзыв '
            'остаётся отзывом',
      );
      expect(
        tokenStore.read(),
        isNull,
        reason: 'токен без сеанса за ним — не информация, а риск',
      );
    });

    // Пункт 6 второго круга задачи 7 (2026-08-21): до этой правки
    // `_lastKnownExpiresAt` жил только в памяти процесса — F5 заводит новый
    // `LoginNotifier`, и самый обыденный случай (закрыл вкладку вечером,
    // открыл утром, касса уже вымела сеанс) приходил на свежий нотифаер
    // первым же событием `null` без единой улики: `sessionEndedReason`
    // называла это отзывом, хотя касса ничего не отзывала. Отличается от
    // «просроченный сеанс на подъёме» ниже: там касса отвечает записью с
    // `expiresAt` в прошлом (прямая улика от кассы); здесь касса отвечает
    // `null` — ровно то, что делает настоящий `SessionRegistry.watch` для
    // всех случаев исчезновения сразу, — и единственная улика приезжает из
    // хранилища вкладки, пережившего F5.
    test('F5 после истечения срока называет истечение, а не отзыв', () async {
      final getIt = GetIt.instance;
      final tokenStore = FakeSessionTokenStorage()
        ..write('tok-4b', DateTime.now().subtract(const Duration(hours: 2)));
      getIt.registerSingleton<SessionTokenStorage>(tokenStore);

      final auth = FakeAuthRepository(
        const AuthRejection(AuthRejectionReason.wrongPin),
      );
      // Касса отвечает `null` — не записью с `expiresAt` в прошлом, ровно
      // так, как отвечает настоящий `SessionRegistry.watch` (он чистит
      // просроченное первой строкой, докстринг `_lastKnownExpiresAt`).
      auth.sessions['tok-4b'] = null;
      getIt.registerSingleton<AuthRepository>(auth);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(loginControllerProvider.notifier);
      notifier.initialize();
      await Future<void>.delayed(Duration.zero);

      expect(container.read(loginControllerProvider).isAuthenticated, isFalse);
      expect(
        container.read(loginControllerProvider).sessionEndedReason,
        'error.session_expired',
        reason:
            'красный без правки: хранилище не помнило expiresAt, '
            '_lastKnownExpiresAt на свежем нотифаере был null, и причина '
            'называлась error.session_ended — «сеанс завершён на кассе», '
            'хотя касса лишь честно забыла просроченную запись',
      );
      expect(tokenStore.read(), isNull);
    });

    // Пере-ревью финального разбора, пункт 1 (клиентская половина): сервер
    // теперь чистит просроченные сеансы первой строкой `SessionRegistry.watch`
    // (`session_registry_test.dart`, «подписка на истёкший токен отдаёт
    // null»), а этот тест — вторая, независимая сторона той же дыры: даже
    // если касса когда-нибудь снова отдаст неотфильтрованную запись, вкладка
    // не должна впустить по её `expiresAt` в прошлом.
    test(
      'просроченный сеанс на подъёме уводит на вход и чистит токен',
      () async {
        final getIt = GetIt.instance;
        final tokenStore = FakeSessionTokenStorage()
          ..write('tok-5', DateTime.now().subtract(const Duration(hours: 2)));
        getIt.registerSingleton<SessionTokenStorage>(tokenStore);

        final auth = FakeAuthRepository(
          const AuthRejection(AuthRejectionReason.wrongPin),
        );
        auth.sessions['tok-5'] = AuthSession(
          token: 'tok-5',
          userId: 9,
          name: 'Данара',
          role: 'cashier',
          permissions: const {'nav.sale'},
          operatingMode: 0,
          pointMode: 'cashier',
          shift: ShiftStatus.open,
          issuedAt: DateTime.now().subtract(const Duration(hours: 3)),
          // В прошлом — тот самый случай, который тихая касса могла бы
          // отдать без правки `SessionRegistry.watch`: F5 через два часа
          // молчания воскрешал бы вход без единого нажатия PIN.
          expiresAt: DateTime.now().subtract(const Duration(hours: 2)),
          terminalId: 1,
        );
        getIt.registerSingleton<AuthRepository>(auth);

        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(loginControllerProvider.notifier);
        notifier.initialize();
        await Future<void>.delayed(Duration.zero);

        expect(
          container.read(loginControllerProvider).isAuthenticated,
          isFalse,
          reason: 'просроченный сеанс не имеет права впускать',
        );
        expect(
          tokenStore.read(),
          isNull,
          reason: 'просроченный токен — не информация, а риск, как и погасший',
        );
      },
    );

    // Пере-ревью финального разбора, пункт 3: местное состояние обязано
    // гаснуть, что бы ни случилось с проводом — у `WtDispatcher.ask` нет ни
    // таймаута, ни отмены.
    test(
      'выход уводит на вход даже когда провод на logout не отвечает никогда',
      () async {
        final getIt = GetIt.instance;
        final tokenStore = FakeSessionTokenStorage();
        getIt.registerSingleton<SessionTokenStorage>(tokenStore);

        final session = AuthSession(
          token: 'tok-6',
          userId: 7,
          name: 'Айгуль',
          role: 'cashier',
          permissions: const {},
          operatingMode: 0,
          pointMode: 'cashier',
          shift: ShiftStatus.closed,
          issuedAt: DateTime(2026, 8, 20),
          expiresAt: DateTime(2026, 8, 21),
          terminalId: 1,
        );
        final auth = FakeAuthRepository(session)..hangOnLogout = true;
        getIt.registerSingleton<AuthRepository>(auth);

        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(loginControllerProvider.notifier);
        notifier.initialize();
        await Future<void>.delayed(Duration.zero);

        for (final digit in ['1', '2', '3', '4']) {
          notifier.addDigit(digit);
        }
        await notifier.pendingVerification;
        expect(container.read(loginControllerProvider).isAuthenticated, isTrue);

        // Красный без правки: до неё `AppState`/локальное состояние чистились
        // ПОСЛЕ `await _auth.logout(token)` — `hangOnLogout` никогда не
        // отвечает, и это ожидание либо зависло бы навсегда (тест упал бы по
        // таймауту `flutter test`), либо, при менее терпеливом таймауте,
        // доказало бы, что кнопка выхода перестаёт работать на молчащей
        // кассе.
        await notifier.logout().timeout(const Duration(seconds: 2));

        expect(
          container.read(loginControllerProvider).isAuthenticated,
          isFalse,
        );
        expect(container.read(appStateProvider).isLoggedIn, isFalse);
        expect(
          auth.loggedOutToken,
          'tok-6',
          reason: 'касса всё же спрошена — просто не дожидаемся её ответа',
        );
      },
    );
  });

  test(
    'кассир, заведённый при открытом экране, снимает «нет кассиров» — '
    'найдено живой проверкой в браузере 2026-08-27',
    () async {
      final auth = FakeAuthRepository();
      // Пустая касса: экран открыт раньше, чем кассиры заведены. Ровно
      // порядок, который предписывает стенд (`test/manual/wt_stand.dart`):
      // открыть браузер ДО `stand/seed-cashiers`, иначе живая подписка не
      // проверена вовсе.
      auth.pushUsers(const []);
      GetIt.instance.registerSingleton<AuthRepository>(auth);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(loginControllerProvider.notifier);
      notifier.initialize();
      await Future<void>.delayed(Duration.zero);
      auth.pushUsers(const []);
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(loginControllerProvider).error,
        'error.no_users',
        reason: 'на пустой кассе причина обязана быть названа',
      );

      // Касса заводит кассира, пока экран открыт. Страницу никто не
      // перезагружает — это и есть проверяемое событие.
      auth.pushUsers(const [
        AuthUser(id: 7, name: 'Айгуль', role: 'Кассир', hasPin: true),
      ]);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(loginControllerProvider);
      expect(state.users, hasLength(1), reason: 'кассир доехал до состояния');
      expect(
        state.error,
        isNull,
        reason:
            'сообщение «нет кассиров» обязано исчезнуть вместе с причиной. '
            'Красный до правки: контроллер снимал его через '
            '`copyWith(error: null)`, а `copyWith` (login_controller.dart) '
            'считает `null` за «не трогать» — `error ?? this.error`, — и '
            'старая строка переживала приход кассиров. В браузере это '
            'выглядело так: слева два кассира и один выбран, справа красным '
            '«No registered users».',
      );
    },
  );

  test(
    'обрыв подписки на кассиров не выносит текст исключения в браузер (И68)',
    () async {
      final auth = FakeAuthRepository();
      auth.pushUsers(const []);
      GetIt.instance.registerSingleton<AuthRepository>(auth);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(loginControllerProvider.notifier);
      notifier.initialize();
      await Future<void>.delayed(Duration.zero);

      // Ровно то, что видно в браузере при обрыве провода: подписка отдаёт
      // ошибку. Сообщение исключения несёт подробности кассы, которым за её
      // границей делать нечего, — экран терминала это чужой процесс на
      // чужом устройстве.
      auth.failUsers(
        StateError('stream_failed: соединение потеряно, statement=SELECT ...'),
      );
      await Future<void>.delayed(Duration.zero);

      final error = container.read(loginControllerProvider).error;
      expect(error, startsWith('error.load_failed:'));
      expect(
        error,
        isNot(contains('statement')),
        reason:
            'сообщение исключения не имеет права доехать до браузера — '
            'красный до правки: было `\$e`, то есть `toString()` целиком. '
            'Найдено живой проверкой 2026-08-27: на экране входа горело '
            '«Data loading error: WtProtocolError(stream_failed: '
            'WebTransportError: Connection lost.)».',
      );
      expect(
        error,
        contains('StateError'),
        reason: 'род ошибки назван — `safeErrorText` отдаёт имя типа',
      );
    },
  );

  // Группа «слишком много попыток называет число» (пункт 6 первого круга
  // разбора) удалена во втором круге задачи 7 (2026-08-21): она проверяла
  // `retryAfter` у `AuthRejectionReason.tooManyAttempts`, а сама эта причина
  // ушла вместе с пределом одновременных ожиданий, который её единственный
  // порождал — `messageForRejection` больше не принимает `retryAfter` вовсе
  // (см. `login_controller.dart`).
}
