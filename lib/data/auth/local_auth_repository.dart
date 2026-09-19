/// Вход на самой кассе: база рядом, сеть не нужна.
///
/// Единственная реализация проверки PIN в системе. Десктоп зовёт её внутри
/// процесса, браузер — по проводу через `TillOperations`; обработчик провода
/// логики входа не содержит вовсе.
library;

import 'dart:async';
import 'dart:isolate';

import 'package:drift/drift.dart' show Value;
import 'package:talker/talker.dart';
import 'package:telepos/backend/login_throttle.dart';
import 'package:telepos/backend/security_journal.dart';
import 'package:telepos/backend/session_registry.dart';
import 'package:telepos/core/constants/enums/user_role.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/core/security/pin_credential.dart';
import 'package:telepos/data/auth/pbkdf2_gate.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/auth/auth_attempt.dart';
import 'package:telepos/domain/auth/auth_outcome.dart';
import 'package:telepos/domain/auth/auth_repository.dart';
import 'package:telepos/domain/auth/auth_user.dart';
import 'package:telepos/domain/terminal/point_mode_permissions.dart';
import 'package:telepos/domain/terminal/terminal.dart';

class LocalAuthRepository implements AuthRepository {
  LocalAuthRepository({
    required AppDatabase db,
    required SessionRegistry sessions,
    required LoginThrottle throttle,
    Talker? logger,
    Pbkdf2Gate? pbkdf2Gate,
    SecurityJournal? securityJournal,
  }) : _db = db,
       _sessions = sessions,
       _throttle = throttle,
       _logger = logger,
       _pbkdf2Gate = pbkdf2Gate ?? Pbkdf2Gate(),
       _securityJournal = securityJournal;

  final AppDatabase _db;
  final SessionRegistry _sessions;
  final LoginThrottle _throttle;
  final Talker? _logger;

  /// Журнал событий безопасности — задача 21 закрытия долга безопасности.
  /// `null` тем же приёмом, что и остальные опциональные доводы этого
  /// класса — тесты, которым запись не нужна, не обязаны знать о новом
  /// доводе.
  final SecurityJournal? _securityJournal;

  /// Правка 1 волны закрытия долга безопасности (2026-08-22): единственный
  /// настоящий ограниченный ресурс входа, теперь ограниченный на самом деле
  /// — см. докстринг [Pbkdf2Gate] и докстринг [LoginThrottle], «БЛОКЕР».
  /// Один на кассу (одна `LocalAuthRepository` на процесс — тот же довод,
  /// что и у [_sessions]/[_throttle]), а не заводится заново на каждый
  /// вызов [_matchAll]: предел общий на все одновременные попытки входа,
  /// а не предел «не больше двух на этот конкретный запрос».
  final Pbkdf2Gate _pbkdf2Gate;

  @override
  Stream<List<AuthUser>> watchUsers() => _db.userDao.watchActiveUsers().map(
    (users) => users
        .map(
          (user) => AuthUser(
            id: user.id,
            name: user.name ?? 'N/A',
            role: UserRole.fromIndex(user.role ?? 0).displayName,
            // Не сам хэш, а факт его наличия — это всё, что нужно знать
            // экрану.
            hasPin: user.passwordEnc != null && user.passwordEnc!.isNotEmpty,
          ),
        )
        .toList(),
  );

  @override
  Future<void> logout(String token) async => _sessions.revoke(token);

  @override
  Stream<AuthSession?> watchSession(String token) => _sessions.watch(token);

  @override
  Future<AuthOutcome> login(AuthAttempt attempt) async {
    final outcome = await _attemptLogin(attempt);
    // Задача 21 закрытия долга безопасности: единственная точка на всю
    // систему, где проверяется PIN (докстринг класса) — значит и
    // единственная, что может написать «попытка входа» в журнал, не
    // задваивая её на стороне каждого вызывающего (десктоп зовёт это
    // напрямую, браузер — через `TillOperations.askHandlers[auth.login]`,
    // `till_operations.dart`; оба пути сходятся здесь).
    //
    // `outcome` — либо выписанный сеанс, либо названный отказ
    // (`AuthOutcome`, `auth_outcome.dart`): исход журнала — `success` для
    // первого и `AuthRejectionReason.name` того отказа для второго, тот же
    // канонический код, которым уже отвечает `AuthRejection.reason`, а не
    // второй, придуманный заново (докстринг `SecurityJournal`).
    //
    // `unawaited`: запись не имеет права задержать ответ кассиру, который
    // и так ждал — `_throttle`/`_pbkdf2Gate` — до этой строки.
    unawaited(
      _securityJournal?.record(
        eventType: SecurityEventType.authLogin,
        outcome: switch (outcome) {
          AuthSession() => SecurityOutcome.success,
          AuthRejection(:final reason) => reason.name,
        },
        terminalId: attempt.terminalId,
        userId: switch (outcome) {
          AuthSession(:final userId) => userId,
          AuthRejection() => attempt.userId,
        },
      ),
    );
    return outcome;
  }

  Future<AuthOutcome> _attemptLogin(AuthAttempt attempt) async {
    // Правка 1 разбора фаз 3/4 закрытия долга (2026-08-21), пункт 3: замок
    // теперь ждёт **до** проверки, не после.
    //
    // # Величина, которую мерил замок, была не той
    //
    // До этой правки задержка ложилась только на подтверждённо неверный PIN
    // — после того как `_matchAll` уже ответил, `return`-ом ниже по функции.
    // Верный PIN отвечал немедленно. Обработчики провода запускаются
    // параллельно нарочно (`unawaited(_onRequest(...))`, `till_wire.dart`) —
    // значит нападающему, которому не нужны отказы, замок не стоил ничего:
    // он слал 10⁴ кадров `auth.login` одним махом и ждал единственный,
    // который вернётся быстро, — то и был успех. Настоящая цена подбора,
    // 299791 секунда (83 часа) на 10⁴ значений (`login_throttle.dart`,
    // измерено `throttle-wall-report.md`), для этого нападающего не значила
    // ничего: он не ждал ни одного отказа.
    //
    // # Правка: `awaitTurn` до `_matchAll`, а не после
    //
    // [LoginThrottle.penalizeFailure] зовётся один раз на попытку, здесь, до
    // какой-либо проверки PIN, — на КАЖДУЮ попытку с реальным кандидатом
    // (`candidates` не пуст), а не только на подтверждённо неверную. Класс
    // не переименован и не переработан: он уже считал неудачу синхронно, до
    // `await _sleep`, и уже стоял в очереди по ключу (второй круг задачи 7,
    // правка 1 разбора) — поменялось только КОГДА его зовут, не КАК он
    // считает.
    //
    // Это не возвращает запирание. Задержка **никогда** не превращается в
    // отказ: `penalizeFailure` только ждёт, ответ после ожидания зависит
    // ровно от того же `_matchAll`, что и раньше. Верная попытка платит тот
    // же ход, что и неверная, — она тоже зовёт `penalizeFailure` первой
    // строкой, до какой-либо проверки, — и это единственное, что закрывает
    // оракул: быстрый ответ не может быть признаком успеха, потому что и
    // успех, и неудача с одним и тем же накопленным счётом ждут одну и ту же
    // задержку. Успех сбрасывает счёт (`recordSuccess`, как и раньше).
    //
    // # Правка 1 БЛОКЕРА закрытия долга (2026-08-22): сколько именно ждёт
    // верная попытка
    //
    // Абзац этого докстринга писался, когда `LoginThrottle` держал ещё и
    // цепную **очередь** ожиданий по ключу (`_queueTail`, снята правкой 1
    // блокера) — тогда верная попытка ждала не просто «секунду-другую», а
    // **сумму** задержек всех чужих неудач, ещё не доигравших свою очередь:
    // измерено, 200 чужих неудач держали её час 36 минут, 10⁴ — 83 часа
    // (`login_throttle.dart`, докстринг класса, «БЛОКЕР»). Очередь снята:
    // задержка любой попытки, честной или нет, ограничена сверху
    // [LoginThrottle.maxDelay] (30 с) и не зависит от того, сколько чужих
    // неудач накопилось до неё — только от счёта по её собственному ключу
    // (`_delayForCount`, который сам капается тем же потолком). Throughput
    // нападающего, шлющего тысячи попыток параллельно, теперь ограничен не
    // этой задержкой (она у всех параллельных попыток примерно одна и та
    // же, и это ожидаемо, не дыра), а очередью на саму проверку PIN —
    // [_pbkdf2Gate], докстринг [Pbkdf2Gate].
    //
    // # Правка А БЛОКЕРА (2026-08-22): 30 с — это НЕ полное ожидание входа
    //
    // Абзац выше писался про [LoginThrottle] саму по себе и остаётся верным
    // про неё; неверно было бы читать его как ответ на «сколько всего ждёт
    // честный кассир при заливе». `login()` ждёт ДВЕ очереди последовательно
    // — [_throttle] (потолок 30 с, не зависит ни от чего чужого) и затем
    // [_pbkdf2Gate] (докстринг [Pbkdf2Gate]) — и до этой правки вторая была
    // ОБЩЕЙ FIFO на все попытки разом: то самое число, которое
    // `throttle-cap-report.md` называл ценой нападающему (~17 минут на 10⁴
    // значений), было на деле ценой, посчитанной с двух сторон одной
    // очереди, — её же платила бы и честная попытка. Очередь
    // [Pbkdf2Gate] стала круговой по ключу справедливости — QUIC-сессии
    // ([AuthAttempt.sessionKey]), не `userId`, — и честная попытка теперь
    // ждёт слот раз в N чужих СЕССИЙ, а не раз в N его ПОПЫТОК: измерено
    // (`pbkdf2_gate_fairness_bench_test.dart`, залп 10⁴, худший случай)
    // 412 мс / 1442 мс / 21012 мс при 1 / 10 / 200 чужих сессиях. Полное
    // ожидание честного кассира — сумма: 30 с (throttle) + это число
    // (Pbkdf2Gate). Полного потолка нет — он растёт с числом РАЗЛИЧНЫХ
    // сессий, которые успел завести нападающий, а не какой-либо константой;
    // это ограничено потолком регистрации терминалов (200) и ленивой
    // уборкой (`TillOperations._pruneUnusedTerminals`), названо границей в
    // спеке. Точные числа — `fairqueue-and-perms-report.md`.
    //
    // # Пункт 4 закрылся тем же ходом
    //
    // `credentialUnreadable` раньше возвращался до всякого `penalizeFailure`
    // — единственная испорченная запись PIN среди кандидатов делала любой
    // неверный PIN бесплатным для всей попытки. Ждать теперь — до того, как
    // known исход вообще определён, поэтому этот путь платит наравне со
    // всеми остальными без отдельной правки веткой ниже.
    try {
      final settings = await _db.thisPosDao.authSettings();
      final thisPos = await _db.thisPosDao.get();
      final legacyKey = thisPos?.rsaPublicKey;

      final users = await _db.userDao.findActiveUsers();
      final candidates = attempt.userId == null
          ? users
          : users.where((u) => u.id == attempt.userId).toList();

      if (attempt.userId == null && !settings.walkUpEnabled) {
        return const AuthRejection(AuthRejectionReason.walkUpDisabled);
      }
      if (candidates.isEmpty) {
        // Никого не перебирали — замок за это не в ответе: запись неудачи
        // здесь наказывала бы за чужую опечатку в userId, а не за подбор PIN.
        return const AuthRejection(AuthRejectionReason.wrongPin);
      }

      // Стена — здесь, до какой-либо проверки PIN. Ждёт задержку,
      // накопленную предыдущими попытками по этому ключу («кто» + терминал)
      // — свою собственную она заплатит только следующему разу, платит
      // всегда за прошлое (докстринг [LoginThrottle.penalizeFailure]).
      await _throttle.penalizeFailure(
        terminalId: attempt.terminalId,
        userId: attempt.userId,
      );

      // Явно выбранный кассир без PIN — «Войти без PIN», а не перебор.
      //
      // До 40246c2 (`экран входа спрашивает кассу`) это решалось на экране:
      // `_verifyPin` видела `selected != null && state.userHasNoPassword` и
      // логинила без единого вызова проверки PIN (`_loginSuccess()`). Тот
      // ранний выход исчез вместе с переездом проверки на кассу, а сюда, в
      // единственную оставшуюся реализацию, эквивалент так и не переехал —
      // экран по‑прежнему шлёт `userId` выбранного кассира и пустой `pin`,
      // а `_matchAll` пустой PIN ни с чем не сопоставляет, и без этой ветки
      // ниже сработал бы `noPinSet`: кассир без PIN никогда не мог войти
      // кнопкой «Войти без PIN» — застревал на `/login` каждый раз (найдено
      // здесь: `flutter test test/golden` требовал живого входа и падал
      // 8 из 8 разворотов на `Expected: '/shift' Actual: '/login'`, притом
      // что 500‑мс дебаунс в контроллере входа этот путь не задевает вовсе —
      // измерено пробным тестом с `pumpAndSettle(seconds: 3)`, задержки с
      // запасом).
      //
      // Условие уже, чем «нет пароля»: `attempt.pin.isEmpty` — иначе тест
      // «у кассира без PIN — своя причина отказа»
      // (`test/data/auth/local_auth_repository_login_test.dart`, реально
      // набранный PIN против кассира без PIN) обязан остаться `noPinSet`, а
      // не тихо превратиться во вход. `candidates.length == 1` — тот же
      // выбор, что делал старый код (`selected != null`): анонимный
      // walk-up (`attempt.userId == null`) сюда не попадает вовсе, и
      // `walkUpEnabled` его по‑прежнему решает выше.
      if (attempt.userId != null &&
          attempt.pin.isEmpty &&
          candidates.length == 1 &&
          (candidates.single.passwordEnc ?? '').isEmpty) {
        final session = await _issue(candidates.single, attempt.terminalId);
        _throttle.recordSuccess(
          terminalId: attempt.terminalId,
          userId: attempt.userId,
        );
        return session;
      }

      if (candidates.every((u) => (u.passwordEnc ?? '').isEmpty)) {
        return const AuthRejection(AuthRejectionReason.noPinSet);
      }

      final results = await _matchAll(
        attempt.pin,
        candidates,
        legacyKey,
        attempt.sessionKey,
      );
      final matches = results
          .where((r) => r.outcome == PinCheckOutcome.ok)
          .toList();

      if (matches.isEmpty) {
        // «Запись нечитаема» — не «PIN не подошёл»: человек ничего не сделал
        // не так, и повторный набор ничего не чинит (документация
        // PinCheckOutcome.unreadable, pin_credential.dart). Показать это как
        // обычный неверный PIN отправило бы кассира набирать заново то, что
        // заново не набрать, а счётчик неудач посчитал бы это подбором,
        // каким это не было.
        final unreadable = results.any(
          (r) => r.outcome == PinCheckOutcome.unreadable,
        );
        // Задержка уже выждана выше, до `_matchAll` — здесь только сам
        // отказ, второй раз ждать нечего (см. докстринг [login]).
        if (unreadable) {
          return const AuthRejection(AuthRejectionReason.credentialUnreadable);
        }
        return const AuthRejection(AuthRejectionReason.wrongPin);
      }
      if (matches.length > 1) {
        // Не «первый подошедший». Совпавший PIN у двоих — это чек, выписанный
        // не на того человека, и деньги смены, записанные не туда. Задержка
        // — тем же порядком, что и выше: уже выждана до `_matchAll`.
        return const AuthRejection(AuthRejectionReason.ambiguousPin);
      }

      final matched = matches.single;
      final user = candidates.firstWhere((u) => u.id == matched.userId);

      final upgraded = matched.upgradedStorage;
      if (upgraded != null) {
        // Вся миграция: запись легаси-схемы уже доказала себя тем самым
        // PIN, который набрал кассир, и заменяется на месте — тем же
        // способом и с тем же расчётом, каким это делает
        // login_controller.dart::_persistUpgrade: собственный try/catch,
        // не общий на всю функцию. Верный PIN уже проверен — если запись
        // не удалась (база занята, залочена, конфликт), это неудача
        // миграции, а не неудача входа, и не должна становиться
        // AuthRejection.unknown для человека, который всё набрал верно.
        // Старая запись всё ещё проверяется, и следующий вход попробует
        // мигрировать снова. await оставлен: запись одна и стоит куда
        // меньше уже потраченных 206 мс перебора, а без ожидания тест
        // этого пути не мог бы быть детерминированным.
        try {
          await _db.userDao.updateUser(
            user.id,
            UsersCompanion(passwordEnc: Value(upgraded)),
          );
        } catch (error, stack) {
          // safeErrorText, а не сам объект и не его текст: до этой правки
          // сюда уезжал `error` целиком, а `SqliteException.toString()`
          // печатает `parameters: …` — запрос здесь
          // `UPDATE users SET password_enc = ?`, и параметр — свежий хэш
          // PIN. Talker уровня warning идёт в файловый сток и в syslog
          // (`lib/data/logging/syslog_log_sink.dart`) и виден на экране
          // журнала; до этой ветки эквивалент писал в `debugPrint`, так что
          // печать объекта здесь — регресс, внесённый этой работой, а не
          // унаследованный.
          _logger?.warning(
            'вход: PIN верный, но перенос легаси-записи не удался '
            '(${safeErrorText(error)}) — следующий вход попробует снова',
            null,
            stack,
          );
        }
      }

      final session = await _issue(user, attempt.terminalId);
      _throttle.recordSuccess(
        terminalId: attempt.terminalId,
        userId: attempt.userId,
      );
      return session;
    } catch (error, stack) {
      // Отказ, а не вход. До 2026-08-20 здесь возвращались allPermissions —
      // то есть сбой чтения открывал кассиру всё.
      //
      // safeErrorText, а не сам объект: этот `catch` накрывает весь
      // `login()`, включая чтение из базы — тот же риск, что и у переноса
      // легаси-записи выше, тем же приёмом закрыт здесь.
      _logger?.warning(
        'вход: касса не смогла ответить (${safeErrorText(error)})',
        null,
        stack,
      );
      return const AuthRejection(AuthRejectionReason.unknown);
    }
  }

  /// Все кассиры, чей PIN подошёл — и заодно исход каждого, кто не подошёл.
  ///
  /// Не первый матч — **все**, и не только `bool`, а весь [PinCheckOutcome]:
  /// без него `login` не отличил бы «неверно» от «нечитаемо» и не узнал бы
  /// про миграцию легаси-записи — `upgradedStorage` живёт только внутри
  /// `PinCheckResult`, который [PinCredential.check] возвращает на одного
  /// кандидата, а не на всю пачку разом.
  ///
  /// Идёт в отдельном изоляте: одна проверка PBKDF2 — 206 мс (измерено
  /// 2026-08-02), и четыре кандидата на интерфейсном изоляте кассы означали бы
  /// почти секунду замороженного экрана у человека с очередью.
  ///
  /// `Isolate.run`, а не `compute`: `compute` живёт в
  /// `package:flutter/foundation`, а этот класс работает и в голом
  /// Dart-процессе `bin/telepos_backend.dart`, где Flutter нет.
  ///
  /// Обёрнут в [_pbkdf2Gate] целиком, вместе со спавном изолята — правка 1
  /// волны закрытия долга безопасности (2026-08-22): это и есть тот самый
  /// ограниченный ресурс, докстринг [Pbkdf2Gate]. При достижении предела
  /// вызов ждёт своей очереди — не отказывает, `login()` продолжает ждать
  /// тем же `await`, каким ждал бы саму проверку.
  ///
  /// [sessionKey] едет в гейт как ключ справедливости (правка А БЛОКЕРА,
  /// 2026-08-22, см. докстринг [Pbkdf2Gate]) — круговая раздача слотов по
  /// QUIC-сессии вместо общей FIFO, чтобы залп одного нападающего не отнимал
  /// слоты у чужой, честной попытки.
  Future<List<({int userId, PinCheckOutcome outcome, String? upgradedStorage})>>
  _matchAll(
    String pin,
    List<User> candidates,
    String? legacyKey,
    int? sessionKey,
  ) {
    final probes = candidates
        .where((u) => (u.passwordEnc ?? '').isNotEmpty)
        .map((u) => (id: u.id, stored: u.passwordEnc!))
        .toList();

    return _pbkdf2Gate.run(
      () => Isolate.run(() {
        final results =
            <
              ({int userId, PinCheckOutcome outcome, String? upgradedStorage})
            >[];
        for (final probe in probes) {
          final result = PinCredential.check(
            pin: pin,
            stored: probe.stored,
            legacyPublicKeyBase64: legacyKey,
          );
          results.add((
            userId: probe.id,
            outcome: result.outcome,
            upgradedStorage: result.upgradedStorage,
          ));
        }
        return results;
      }),
      key: sessionKey,
    );
  }

  /// Выписывает сеанс с уже посчитанным действующим правом.
  Future<AuthSession> _issue(User user, int terminalId) async {
    final role = UserRole.fromIndex(user.role ?? 0);
    final ofRole = role == UserRole.owner
        ? PermissionKeys.allPermissions
        : await _db.userPermissionDao.getAllowedKeys(user.id);

    final terminal = await _db.terminalDao.findById(terminalId);
    final pointMode = PointMode.values.firstWhere(
      (m) => m.name == terminal?.pointMode,
      // Неизвестный режим читается как самый узкий, а не как самый широкий —
      // и это **осознанно другое** решение, чем у
      // `LocalTerminalRepository._pointModeFromStored`
      // (lib/data/terminal/terminal_repository_local.dart), которая на тот же
      // случай бросает StateError и отказывается открыться вовсе. Там довод —
      // «терминал, который не открылся, безопаснее терминала, открывшегося
      // с чужими правами»; здесь довод обратный и тоже измеримый:
      // `PointModePermissions.effective` только **вычитает** права у роли
      // (см. её докстринг), поэтому откат на самый узкий режим физически не
      // может выдать право, которого не выдал бы честно распознанный режим —
      // а отказ входа целиком означал бы, что касса новее терминала
      // останавливает торговлю там, где могла бы вести её с урезанными, но
      // правильными правами. Расхождение с `_pointModeFromStored` — не
      // забытая копия, а разные ставки для разных операций (чтение терминала
      // вообще против выдачи прав входа); встречный комментарий там же не
      // даёт этому разойтись молча дальше.
      orElse: () => PointMode.selfService,
    );

    final thisPos = await _db.thisPosDao.get();
    final openShift = await _db.shiftDao.findOpenedShift();

    // Тот самый реестр, что пришёл в конструктор, и никакой другой. Новый
    // `SessionRegistry(...)` здесь выглядел бы естественно — он даже позволил
    // бы задать срок из настроек прямо на месте, — но выписал бы сеанс в
    // карту, которую тут же выбросят: `lookup` на следующей операции не нашёл
    // бы его никогда. Срок бездействия задаётся реестру при сборке кассы
    // (задача 9), а не на каждый вход.
    return _sessions.mint(
      userId: user.id,
      name: user.name ?? 'N/A',
      role: role.displayName,
      permissions: PointModePermissions.effective(
        ofRole: ofRole,
        at: pointMode,
      ),
      operatingMode: thisPos?.operatingMode ?? 0,
      pointMode: pointMode.name,
      shiftOpen: openShift != null,
      // Круг правки 4: исключения для `isSelf` здесь **нет**, и это правка
      // круга 3, снятая целиком. Оно заводилось затем, чтобы вкладка,
      // вошедшая на строку самой кассы через открытый `terminals.selfEnsure`,
      // не выбивала кассира с экрана кассы, — но тем же движением возвращало
      // на эту строку двух человек сразу, а с ними и общий черновик возврата
      // (блокер 1 круга 4). Причина вырезана в другом месте: `selfEnsure`
      // больше не привязывает место к сессии, и войти по проводу на строку
      // кассы теперь нельзя вовсе. Правило «за одним местом один человек»
      // снова действует без исключений.
      terminalId: terminalId,
    );
  }
}
