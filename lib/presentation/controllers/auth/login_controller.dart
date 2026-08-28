import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/app/router/app_routes.dart';
import 'package:telepos/core/constants/enums/operating_mode.dart';
import 'package:telepos/core/constants/enums/user_role.dart';
import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/domain/auth/auth_attempt.dart';
import 'package:telepos/domain/auth/auth_outcome.dart';
import 'package:telepos/domain/auth/auth_repository.dart';
import 'package:telepos/domain/auth/auth_user.dart';
import 'package:telepos/domain/auth/session_token_storage.dart';
import 'package:telepos/domain/host/host_capabilities.dart';
import 'package:telepos/domain/terminal/terminal_identity.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/terminal/terminal_secret_storage.dart';
import 'package:telepos/domain/wire/session_lost.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/presentation/common/navigation/nav_destinations.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';
import 'package:telepos/presentation/screens/auth/widgets/user_selector.dart';

/// Что сказать человеку у кассы про отказ входа.
///
/// `switch` без `default`: восьмая причина, если её когда-нибудь заведут в
/// [AuthRejectionReason], обязана стать ошибкой сборки этого файла, а не
/// молча остаться безмолвной на экране. Каждая ветка возвращает **ключ**
/// локализации — тот же язык, каким уже говорит весь остальной экран
/// (`error.no_users`, `error.pin_too_short` и так далее), а не готовый текст:
/// разбирает его `ErrorLocalizer.localize`.
///
/// Until the second round of task 7 (2026-08-21, `login_throttle.dart`) this
/// took an extra `retryAfter` parameter for `AuthRejectionReason
/// .tooManyAttempts` — the reason given when the till was holding the
/// maximum number of concurrently-delayed failed attempts and turned this
/// one away without waiting. That concurrency limit is gone entirely (every
/// attempt waits its own delay now, however many are in flight), and with it
/// went the reason that needed a retry estimate — there is no longer a
/// second way `login()` can reject an attempt.
String messageForRejection(AuthRejectionReason reason) {
  return switch (reason) {
    AuthRejectionReason.wrongPin => 'error.wrong_pin',
    AuthRejectionReason.ambiguousPin => 'error.ambiguous_pin',
    AuthRejectionReason.noPinSet => 'error.no_pin_set',
    AuthRejectionReason.walkUpDisabled => 'error.walk_up_disabled',
    AuthRejectionReason.credentialUnreadable => 'error.credential_unreadable',
    AuthRejectionReason.unknown => 'error.auth_unknown',
  };
}

@immutable
class LoginState {
  const LoginState({
    this.users = const [],
    this.selectedUser,
    this.enteredPin = '',
    this.isLoading = false,
    this.error,
    this.isAuthenticated = false,
    this.isShiftOpened = false,
    this.sessionEndedReason,
    this.needsEnrolmentCode = false,
    this.enrolmentCode = '',
  });

  final List<UserItem> users;

  final UserItem? selectedUser;

  final String enteredPin;

  final bool isLoading;

  final String? error;

  final bool isAuthenticated;

  final bool isShiftOpened;

  /// Ключ локализации причины, по которой сеанс кончился не по нажатию.
  /// Ровно два значения, различённых настолько, насколько это доказано
  /// данными (круг правок 1, задача 5) — оба решаются в одном месте,
  /// [_reasonForVanishedSession]:
  ///
  /// - `error.session_expired` — есть прямая улика, что срок прошёл: либо
  ///   сама подписка принесла запись с `expiresAt` в прошлом (нечастый
  ///   случай — настоящая касса сперва чистит такие записи, `_watchSession`),
  ///   либо касса ответила `null`/бросила `SessionLost`, но клиент помнит
  ///   последний известный `expiresAt`, и он уже в прошлом.
  /// - `error.session_ended` — улики нет: касса ответила `null`/бросила
  ///   `SessionLost`, а последний известный `expiresAt` либо ещё не прошёл,
  ///   либо неизвестен вовсе. Отзыв владельцем и выметание по бездействию до
  ///   истечения срока в данных по-прежнему неразличимы — выдумывать
  ///   различие, которого нет в данных, не входит в эту правку.
  ///
  /// **Второй круг задачи 7, пункт 6 (2026-08-21) сдвинул границу между
  /// ними.** До него `null`/`SessionLost` **всегда** означал
  /// `error.session_ended` для вкладки, пережившей F5: последний известный
  /// `expiresAt` жил только в памяти процесса ([_lastKnownExpiresAt]) и
  /// терялся при перезагрузке — самый обыденный случай (закрыл вкладку
  /// вечером, открыл утром) читался как отзыв, хотя касса лишь честно
  /// забыла просроченную запись. Теперь [_restoreSession] переносит
  /// `expiresAt` из [SessionTokenStorage], и она переживает перезагрузку
  /// вместе с токеном — так что `null`/`SessionLost` тоже может дать
  /// `error.session_expired`, не только `error.session_ended`.
  ///
  /// `null` — экран открыт впервые или сеанс кончился по собственному выходу
  /// человека, которому причина не нужна.
  ///
  /// Отдельное поле, а не переиспользование [error]: `initialize()` чистит
  /// [error] на каждом заходе экрана ([copyWith] с `clearError: true`) —
  /// человек как раз только что ушёл со своего экрана на `/login`, `LoginScreen`
  /// монтируется заново и тут же зовёт `initialize()`. Живи причина в [error],
  /// она была бы стёрта раньше, чем что-либо успело бы её показать.
  final String? sessionEndedReason;

  /// Устройство, которого касса ещё не знает — задача 7 плана «знакомство
  /// терминала с кассой», разбор блокера: браузерная вкладка без секрета
  /// (новая, или чей секрет касса только что отвергла) не имеет права
  /// вызывать `terminals.register` без кода привязки — с задачи 6 касса
  /// откажет `pairing_code_invalid` на каждой такой попытке. Экран заменяет
  /// обычный выбор кассира этим состоянием, пока код не введён и не принят.
  ///
  /// Всегда `false` на кассе/appliance (`HostCapabilities.ownsData ==
  /// true`): [LoginNotifier._resolveTerminalId] там зовёт `self()`, а не
  /// `register()`, и этой ветки просто не достигает — см. докстринг
  /// [LoginNotifier._resolveTerminalId].
  final bool needsEnrolmentCode;

  /// То, что человек набрал в поле кода привязки — живёт здесь, а не в
  /// собственном `TextEditingController` экрана, тем же приёмом, что и
  /// [enteredPin]: `LoginScreen` — представление состояния, а не его
  /// источник.
  final String enrolmentCode;

  static const int minPinLength = 4;

  static const int maxPinLength = 6;

  bool get isPinComplete => enteredPin.length >= minPinLength;

  bool get isPinMaxLength => enteredPin.length >= maxPinLength;

  bool get hasError => error != null;

  bool get userHasNoPassword =>
      selectedUser != null && !selectedUser!.hasPassword;

  bool get hasNoUsers => users.isEmpty;

  bool get hasSingleUser => users.length == 1;

  LoginState copyWith({
    List<UserItem>? users,
    UserItem? selectedUser,
    bool clearSelectedUser = false,
    String? enteredPin,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool? isAuthenticated,
    bool? isShiftOpened,
    String? sessionEndedReason,
    bool clearSessionEndedReason = false,
    bool? needsEnrolmentCode,
    String? enrolmentCode,
  }) {
    return LoginState(
      users: users ?? this.users,
      selectedUser: clearSelectedUser
          ? null
          : (selectedUser ?? this.selectedUser),
      enteredPin: enteredPin ?? this.enteredPin,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isShiftOpened: isShiftOpened ?? this.isShiftOpened,
      sessionEndedReason: clearSessionEndedReason
          ? null
          : (sessionEndedReason ?? this.sessionEndedReason),
      needsEnrolmentCode: needsEnrolmentCode ?? this.needsEnrolmentCode,
      // `enrolmentCode` не несёт своего `clearX`: пустая строка — тот же
      // самый смысл, что и «очищено», а `??` смотрит только на `null`, не на
      // пустоту — `enrolmentCode: ''` доводом уже заменяет прежнее значение.
      enrolmentCode: enrolmentCode ?? this.enrolmentCode,
    );
  }
}

class LoginNotifier extends Notifier<LoginState> {
  /// Через геттер, а не поле, заполненное в [build]: `build()` кассы вызывает
  /// провайдер раньше, чем тест успевает подменить регистрацию в `GetIt`, а
  /// геттер читает актуальную запись на каждый вызов — тем же приёмом, каким
  /// уже поднимаются `AppDatabase`-зависимые контроллеры в этом кодовой базе.
  AuthRepository get _auth => GetIt.instance<AuthRepository>();

  TerminalIdentity get _identity => GetIt.instance<TerminalIdentity>();

  TerminalRepository get _terminals => GetIt.instance<TerminalRepository>();

  HostCapabilities get _capabilities => GetIt.instance<HostCapabilities>();

  /// `null` там, где токен нечего хранить — то есть везде, кроме браузера.
  ///
  /// Единственный десктопный процесс не переживает F5 (у него нет вкладки,
  /// которую можно перезагрузить), и заводить для него хранилище токена
  /// значило бы решать вопрос, которого там нет.
  SessionTokenStorage? get _tokenStore =>
      GetIt.instance.isRegistered<SessionTokenStorage>()
      ? GetIt.instance<SessionTokenStorage>()
      : null;

  /// Секрет терминала этой вкладки, если браузерный регистр поднялся.
  ///
  /// `null` там же, где `null` и [_tokenStore] — везде, кроме браузера — и
  /// по той же причине: десктопный процесс не переживает F5, и хранить для
  /// него нечего. Отдельный контракт от [_tokenStore], не второе имя того
  /// же самого: секрет терминала переживает закрытие вкладки, токен сеанса
  /// — нет (докстринг `TerminalSecretStorage`,
  /// `lib/domain/terminal/terminal_secret_storage.dart`).
  TerminalSecretStorage? get _secretStore =>
      GetIt.instance.isRegistered<TerminalSecretStorage>()
      ? GetIt.instance<TerminalSecretStorage>()
      : null;

  /// Терминал этой вкладки на этой QUIC-сессии — только в браузере
  /// (`!ownsData`), только в памяти, никогда в `SharedPreferences`.
  ///
  /// Пункт 2 фазы 3/4 закрытия долга: касса теперь берёт `terminalId` для
  /// `auth.login` из того, что эта же QUIC-сессия сама зарегистрировала
  /// (`terminals.register`), а не из тела кадра — иначе кассир со своим
  /// действительным PIN мог назваться чужим терминалом. Значит **каждая
  /// новая QUIC-сессия обязана зарегистрировать себя заново** — старый номер
  /// из `localStorage` прошлой загрузки страницы эта сессия никак не может
  /// доказать кассе, у которой нет ни малейшего способа отличить его от
  /// подделки.
  ///
  /// Это поле — кэш только на время жизни *этого* `LoginNotifier`: переживает
  /// повторный набор PIN на той же вкладке (не плодит терминал на каждую
  /// опечатку — `register()` больше не дедуплицирует по имени, см.
  /// `terminal_repository_local.dart`), но не переживает F5 — новый
  /// нотифаер встаёт с полем `null`, и первый вход этой вкладки заново
  /// называет себя кассе на новой сессии. См. докстринг [_resolveTerminalId].
  int? _browserTerminalId;

  StreamSubscription<List<AuthUser>>? _usersSubscription;

  /// Живая подписка на сеанс этой вкладки — заводится в [_restoreSession] и
  /// живёт весь срок его жизни, а не до первого значения. Касса, погасившая
  /// или отозвавшая сеанс, доводит это до вкладки сама, тем же путём, каким
  /// уже узнаёт о заведённом кассире `_usersSubscription`.
  ///
  /// Отменяется в трёх местах — в выходе ([logout]), на каждом новом заходе
  /// ([initialize], симметрично [_usersSubscription]) и здесь же, при
  /// разборе нотифаера: неотменённая подписка на кассиров однажды уже вешала
  /// весь набор (см. `AppDatabase.forTesting()` и её
  /// `closeStreamsSynchronously`) — таймер драйвера заводится в момент
  /// отмены, и не отменённая подписка эту заводку просто никогда не делает,
  /// но сам процесс/тест всё равно не отпускает добытые ресурсы.
  StreamSubscription<AuthSession?>? _sessionSubscription;

  @override
  LoginState build() {
    ref.onDispose(() {
      _usersSubscription?.cancel();
      _sessionSubscription?.cancel();
      _cancelPendingVerify();
    });
    return const LoginState();
  }

  /// Кассиры приезжают подпиской и обновляются сами.
  ///
  /// Было: один вопрос базе в `initialize()`, и заведённый на кассе кассир
  /// появлялся на экране только после перезахода. Стало: касса говорит
  /// первой.
  void initialize() {
    _usersSubscription?.cancel();
    // Не `_restoreSession()` ниже — тот заведёт свою собственную, если есть
    // что восстанавливать. Здесь только не оставить сиротой подписку
    // прошлого захода экрана: без этой строки второй `initialize()` (заново
    // смонтированный `LoginScreen`) копил бы вторую живую подписку поверх
    // первой, а не заменял её.
    _sessionSubscription?.cancel();
    _sessionSubscription = null;
    _cancelPendingVerify();
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      isAuthenticated: false,
      enteredPin: '',
      // `sessionEndedReason` намеренно не трогается: если сюда привёл
      // отозванный сеанс, `LoginScreen` монтируется заново и тут же зовёт
      // `initialize()` — стереть причину здесь значило бы стереть её раньше,
      // чем что-либо успело её показать. Гасится она в другом месте — там,
      // где действительно кончается сама история (см. `_onSession`, `reset`).
    );
    // Токен вкладки, если он есть, читается параллельно со списком кассиров,
    // а не вместо него: пока касса отвечает про сеанс, экран уже готов
    // показать выбор — а если сеанс жив, `_onSession` уведёт с этого экрана
    // раньше, чем человек успеет что-то нажать (см. `_restoreSession`).
    unawaited(_restoreSession());
    _usersSubscription = _auth.watchUsers().listen(
      (users) {
        final items = users
            .map(
              (user) => UserItem(
                id: user.id,
                name: user.name,
                role: user.role,
                hasPassword: user.hasPin,
              ),
            )
            .toList();
        state = state.copyWith(
          users: items,
          selectedUser: items.length == 1 ? items.first : null,
          isLoading: false,
          error: items.isEmpty ? 'error.no_users' : null,
          // `clearError`, а не один только `error: null`: [copyWith] ниже
          // читает `null` как «не трогать» (`error ?? this.error`), и снять
          // сообщение им нельзя — для этого и заведён отдельный флаг, тем
          // же приёмом, что в [selectUser]. Без него «нет кассиров»,
          // поставленное на пустой кассе, переживало приход кассиров:
          // список слева заполнялся живьём, а справа продолжало гореть
          // красным «нет зарегистрированных пользователей». Найдено живой
          // проверкой в браузере 2026-08-27 — набор из 3580 тестов этого
          // не видел, потому что подставная касса отдавала список одним
          // `Stream.value`, то есть второго события не было вовсе.
          clearError: items.isNotEmpty,
        );
      },
      // `safeErrorText`, а не `$e`: этот экран живёт в браузере ЧУЖОГО
      // устройства, то есть за границей процесса кассы, и текст исключения
      // туда выносить нельзя (И68 — то же правило, которым закрыты пути
      // отказа провода и мастер настройки). `toString()` у `SqliteException`
      // дописывает параметры упавшего запроса, среди которых бывает
      // `Users.passwordEnc`; здесь до этого не доходит только потому, что
      // ошибка сегодня приходит от провода, а не от базы, — но «сегодня не
      // доходит» это не защита. Найдено живой проверкой 2026-08-27: на
      // экране входа горело «Data loading error: WtProtocolError(
      // stream_failed: WebTransportError: Connection lost.)».
      //
      // Остальные 94 таких места (23 контроллера, измерено там же) живут в
      // процессе самой кассы и этой границы не пересекают — они названы в
      // карте отдельным пунктом, а не починены заодно.
      onError: (Object e) => state = state.copyWith(
        isLoading: false,
        error: 'error.load_failed:${safeErrorText(e)}',
      ),
    );
  }

  void selectUser(UserItem? user) {
    state = state.copyWith(
      selectedUser: user,
      clearSelectedUser: user == null,
      enteredPin: '',
      clearError: true,
    );
  }

  void addDigit(String digit) {
    if (state.isPinMaxLength) return;

    state = state.copyWith(
      enteredPin: state.enteredPin + digit,
      clearError: true,
    );

    if (state.enteredPin.length >= LoginState.minPinLength) {
      _scheduleVerify();
    }
  }

  void removeDigit() {
    if (state.enteredPin.isEmpty) return;

    // Отменяет отложенную проверку, а не только цифру: без этого проверка,
    // назначенная на прежний, более длинный набор, всё равно сработала бы
    // по тому PIN, который окажется на экране к моменту срабатывания
    // таймера, — `_verifyPin` читает `state.enteredPin` в момент запуска, а
    // не в момент назначения.
    _cancelPendingVerify();

    state = state.copyWith(
      enteredPin: state.enteredPin.substring(0, state.enteredPin.length - 1),
      clearError: true,
    );
  }

  void clearPin() {
    _cancelPendingVerify();
    state = state.copyWith(enteredPin: '', clearError: true);
  }

  /// Отменяет отложенную проверку так, чтобы никто не остался её ждать.
  ///
  /// Найдено ревью: до этой правки `removeDigit`/`clearPin` отменяли только
  /// `Timer` (`_debounce?.cancel()`), а `_inFlight` — будущее, которое
  /// `_scheduleVerify` завёл под этот же таймер, — не трогали вовсе.
  /// `Completer`, которым оно исполняется, довершает себя только внутри
  /// сработавшего таймера (`completer.complete(_verifyPin(...))` в
  /// `_scheduleVerify`); отменённый таймер этот код не выполняет никогда.
  /// Итог — `pendingVerification` (`_inFlight ?? Future.value()`) отдавала
  /// бы будущее, которое не завершится до следующего набора: не в проде
  /// сегодня — `pendingVerification` только `@visibleForTesting` — но ровно
  /// тот класс дефекта, который уже стоил часов на зависших тестах в этом
  /// проекте. Здесь и держится всё, что делает или отменяет отложенную
  /// проверку, — `_scheduleVerify` тоже переписан на этот метод, чтобы
  /// отмена и заводка жили в одном месте, а не в двух.
  void _cancelPendingVerify() {
    _debounce?.cancel();
    _debounce = null;
    _inFlight = null;
  }

  void attemptLogin() {
    _cancelPendingVerify();

    if (state.selectedUser != null && state.userHasNoPassword) {
      unawaited(_inFlight = _verifyPin(autoVerify: false));
      return;
    }

    if (!state.isPinComplete) {
      state = state.copyWith(error: 'error.pin_too_short');
      return;
    }

    unawaited(_inFlight = _verifyPin(autoVerify: false));
  }

  Timer? _debounce;

  /// Задержка между последней набранной цифрой и обращением к кассе.
  ///
  /// Раньше перебор шёл на месте — дёшево, и каждая цифра начиная с
  /// четвёртой сама по себе ничего не стоила. Теперь каждая проверка — это
  /// `AuthRepository.login()`, и касса считает её настоящей попыткой
  /// (`LoginThrottle.recordFailure` на каждый несовпавший PIN). При честном
  /// наборе шестизначного PIN без задержки цифры 4 и 5 сами по себе всегда
  /// «неверный PIN» — это не опечатка, это неполный префикс, — и два-три
  /// подряд честных входа запирали бы терминал раньше, чем человек успел бы
  /// ошибиться хоть раз. Задержка коалесцирует быстрый набор в один вызов;
  /// каждая новая цифра её сбрасывает, а цифра, после которой длиннее PIN
  /// быть не может ([LoginState.isPinMaxLength]), проверяется сразу — ждать
  /// уже нечего.
  static const _verifyDebounce = Duration(milliseconds: 500);

  void _scheduleVerify() {
    _cancelPendingVerify();

    if (state.isPinMaxLength) {
      unawaited(_inFlight = _verifyPin(autoVerify: true));
      return;
    }

    // `_inFlight` обязан отражать задержку целиком, а не только сетевой
    // вызов после неё: `pendingVerification` — то, чем тесты (и e2e-стенд)
    // ждут «проверка для набранного полностью закончилась», а до этой
    // правки момент начала сетевого вызова и момент, когда стоило начать
    // ждать, совпадали. `Completer.complete(future)` — обычное сцепление:
    // будущее комплитера не завершится, пока не завершится переданное.
    final completer = Completer<void>();
    _inFlight = completer.future;
    _debounce = Timer(_verifyDebounce, () {
      completer.complete(_verifyPin(autoVerify: true));
    });
  }

  /// Которой проверке принадлежит ответ, приехавший от кассы.
  ///
  /// [addDigit] запускает проверку на каждое нажатие, и теперь это сетевой
  /// круговорот, а не локальный расчёт — два запроса могут быть в полёте
  /// одновременно, и медленный может прийти последним. Без счётчика устаревший
  /// «не подошёл» очистил бы PIN, который оператор уже дописал, а устаревшее
  /// совпадение — того хуже — впустило бы по цифрам, которых уже нет на
  /// экране.
  int _verifyGeneration = 0;

  Future<void>? _inFlight;

  /// Проверка, идущая сейчас, либо уже завершённое будущее.
  ///
  /// Для тестов — и это не удобство ради удобства. `testWidgets` крутит
  /// поддельные часы; ответ от настоящей сети внутри такого теста не
  /// приходит никогда, и `pumpAndSettle` возвращается, так и не дождавшись
  /// входа. Тест ждёт именно это, а не гадает с `pump` на глазок.
  @visibleForTesting
  Future<void> get pendingVerification => _inFlight ?? Future<void>.value();

  /// Терминал, которым эта вкладка представилась кассе на текущей QUIC-сессии
  /// — задача 22 закрытия долга безопасности (живая проверка).
  ///
  /// Только для наблюдения снаружи, тем же приёмом, что [pendingVerification]
  /// выше: `null`, пока вход этой вкладкой ещё не пробовался ни разу
  /// ([_resolveTerminalId] не звался), иначе — то же значение, что уже несёт
  /// [_browserTerminalId]. Живому щупу (`test/manual/wt_lock_probe.dart`)
  /// нужно это число, чтобы вторая вкладка могла назвать кассе, чей именно
  /// сеанс отзывать (`auth.sessionRevoke` требует `terminalId`, не токен, —
  /// см. докстринг `TillOps.authSessionRevoke`), а прочитать его неоткуда:
  /// на десктопе это поле играет ту же роль, что и [TerminalIdentity], но в
  /// браузере кэшируется только здесь (см. докстринг [_browserTerminalId]).
  @visibleForTesting
  int? get browserTerminalId => _browserTerminalId;

  /// Личность терминала — лениво, в момент, когда она впервые нужна.
  ///
  /// До этой правки ничто в рабочем коде не звало
  /// [TerminalIdentity.remember] ни на кассе, ни в браузере — экран входа
  /// был единственным читателем [TerminalIdentity.currentId], и вход был
  /// тупиком на каждой установке, потому что спросить эту личность было
  /// некому. Заводить её при подъёме процесса не выйдет: [TerminalRepository.self]
  /// бросает [InstallationNotConfiguredException] на установке, где мастер
  /// настройки ещё не проходил, а до экрана входа такая установка не
  /// доходит вовсе — у нашей заводки нет чистого момента загрузки, который
  /// был бы верен всегда. Ленивая заводка сама себя чинит: первый вход
  /// спрашивает и запоминает, каждый следующий уже находит запомненное и
  /// ни [TerminalRepository.self], ни [TerminalRepository.register] больше
  /// не зовёт.
  ///
  /// # `self()` там, где база своя — `register()` там, где базы нет
  ///
  /// [TerminalRepository.self] в браузере уходит по проводу в
  /// `terminals.selfEnsure` и отдаёт **строку самой кассы** (`isSelf`) — до
  /// этой правки каждый браузерный терминал представлялся кассой, к которой
  /// подключён. Из-за этого не работали две вещи, ради которых заводилось
  /// действующее право и замок попыток: пересечение прав по режиму точки
  /// (браузер получал `pointMode` кассы вместо своего) и `LoginThrottle`
  /// (один счётчик неудач на терминал кассы — на всех браузерных вкладках
  /// разом).
  ///
  /// Развожено по возможности, а не по облику: [HostCapabilities.ownsData]
  /// истинно ровно там, где терминал — это сама база (касса, appliance), и
  /// «представиться собой» там осмысленно. Где базы нет — то есть в
  /// браузере, — терминал заводит **свою** строку через [TerminalRepository.register],
  /// ту же операцию, которой пользуется экран настроек терминалов для ручной
  /// заводки. Имя — разумное умолчание с меткой времени; переименовать можно
  /// оттуда же в любой момент, это не тот единственный шанс.
  ///
  /// # Правка пункта 2 фазы 3/4 закрытия долга (2026-08-21): десктоп и
  /// браузер разведены до конца
  ///
  /// До этой правки оба пути делили один и тот же кэш —
  /// [TerminalIdentity], сохраняемый в `SharedPreferences`/`localStorage` — и
  /// одну и ту же логику «спросили один раз, дальше находим запомненное».
  /// Для десктопа это по-прежнему верно: `self()` не ходит по проводу вовсе
  /// (тот же процесс, что и база), подделать там нечего, и переживать F5
  /// там некому — десктоп его не знает.
  ///
  /// Для браузера это перестало быть верным ровно тогда, когда касса
  /// перестала верить `terminalId` из тела `auth.login` и стала брать его из
  /// того, что сама увидела на **этой QUIC-сессии** (`till_operations.dart`,
  /// `_sessionTerminals`). Голый id в `localStorage` переживает F5, но новая
  /// QUIC-сессия его не заводила и подтвердить не может — значит [_identity]
  /// (`TerminalIdentity`) браузеру бесполезен, и кэшем на время жизни *этого*
  /// нотифаера остаётся только [_browserTerminalId].
  ///
  /// # Задача 5: секрет, а не голый id, переживает и перезагрузку
  ///
  /// До задачи 5 плана «знакомство терминала с кассой» на этом абзац и
  /// заканчивался: каждая новая вкладка (и каждая пережившая F5) заново
  /// звала `register()` на своей новой сессии — честная новая строка
  /// каждый раз, потому что доказать касса могла ровно то, что сессия сама
  /// зарегистрировала, а голый id из `localStorage` доказательством не был
  /// (докстринг [TerminalRepository.register] про то, почему дедупликация
  /// по имени была дырой — тот же довод верен и для id: оба видны через
  /// `terminals.list`).
  ///
  /// Задача 4 добавила третье, чего раньше не было вовсе — секрет
  /// ([TerminalEnrollment.secret]), высокоэнтропийную строку, которую
  /// касса выдаёт **вместе** с `register()` и хранит только отпечатком.
  /// Секрет — не id: его нельзя подсмотреть через `terminals.list`, и
  /// предъявить его может только тот, кто получил его от кассы в момент
  /// заведения. Задача 5 сохраняет его в [_secretStore] (`localStorage`, не
  /// `sessionStorage` — докстринг `TerminalSecretStorage`) и предъявляет
  /// обратно через [TerminalRepository.resume] раньше, чем звать
  /// `register()` заново: касса привязывает **тот же** `terminalId` к новой
  /// сессии, а не заводит новую строку. F5 больше не заводит новой строки —
  /// заводит только вкладка, которая делает это первый раз в жизни, или чей
  /// сохранённый секрет касса отказалась признать (терминал удалили,
  /// хранилище испорчено или скопировано с чужого устройства).
  ///
  /// # БЛОКЕР задачи 7 (разбор, 2026-08-23): код привязки — довод, который
  /// раньше некому было спросить
  ///
  /// Задача 6 сделала `register()` заперт: без кода привязки
  /// (`PairingInvites`, `/terminal-pairing`) касса всегда отказывает
  /// `pairing_code_invalid`. Фаза 1 этой же работы завела **выдачу** кода на
  /// кассе, но сторону терминала — **ввод** — в план не включили: этот метод
  /// продолжал звать `register(name: ...)` без единого довода `code`, и
  /// каждая браузерная вкладка без сохранённого секрета (новая, или чей
  /// секрет только что отвергла касса) получала один и тот же отказ и
  /// показывала «Попробуйте ещё раз» — совет, от которого ничего не
  /// изменилось бы, потому что без кода эта ветка не проходит никогда.
  ///
  /// Живая проверка задачи 7 (`test/manual/wt_enrolment_probe.dart`) это
  /// подтвердила: браузерный вход не работал вовсе, набор при этом
  /// оставался зелёным — путь проверяли подделки
  /// (`FakeTerminalRepository.register`), которые довод `code` не смотрели.
  ///
  /// Правка не заводит новый маршрут и не открывает диалог: [needsEnrolmentCode]
  /// — состояние того же [LoginScreen], тем же приёмом, каким экран уже
  /// показывает `state.isLoading`/`state.sessionEndedReason`/`state.error`.
  /// Человек вводит код через [updateEnrolmentCode], кнопка «Привязать»
  /// зовёт [submitEnrolmentCode], который зовёт этот же метод повторно — на
  /// этот раз находя в [LoginState.enrolmentCode] то, чего не хватало.
  Future<int?> _resolveTerminalId() async {
    if (_capabilities.ownsData) {
      final remembered = await _identity.currentId();
      if (remembered != null) return remembered;
      try {
        final terminal = await _terminals.self();
        await _identity.remember(terminal.id);
        return terminal.id;
      } on InstallationNotConfiguredException {
        state = state.copyWith(
          error: 'error.till_not_configured',
          enteredPin: '',
        );
        return null;
      } catch (_) {
        state = state.copyWith(error: 'error.auth_unknown', enteredPin: '');
        return null;
      }
    }

    final cached = _browserTerminalId;
    if (cached != null) return cached;

    final secretStore = _secretStore;
    final remembered = secretStore?.read();
    if (remembered != null) {
      try {
        final terminal = await _terminals.resume(
          terminalId: remembered.terminalId,
          secret: remembered.secret,
        );
        _browserTerminalId = terminal.id;
        state = state.copyWith(
          needsEnrolmentCode: false,
          enrolmentCode: '',
          clearError: true,
        );
        return terminal.id;
      } on WireRefusal {
        // Касса доказала, что сохранённый секрет больше не годится —
        // терминал удалили (`terminals.delete`), у строки нет отпечатка
        // (заведена до миграции v35→v36, задача 4), или хранилище просто
        // испорчено/скопировано с чужого устройства. Единственный путь
        // вперёд — забыть его и завести терминал заново, кодом привязки
        // (ветка ниже): БЛОКЕР задачи 7 плана «знакомство терминала с
        // кассой» — с задачи 6 `register()` без кода привязки всегда
        // отказывает `pairing_code_invalid`, а до этой правки код спросить
        // было негде, и вкладка звала `register(code: '')` вслепую.
        // «Старое устройство без секрета» (пункт 7 брифа задачи 7) обязано
        // увидеть названную причину, а не общее «попробуйте ещё раз» —
        // `error.terminal_secret_invalid` здесь и есть эта причина.
        secretStore?.clear();
        state = state.copyWith(
          needsEnrolmentCode: true,
          error: 'error.terminal_secret_invalid',
          enteredPin: '',
        );
        // Не `return null` — код ниже решает, спрашивать код или уже введён
        // (вторая попытка [submitEnrolmentCode] после первого отказа).
      } on Object {
        // Обрыв провода/иной сбой resume — не доказывает, что секрет плохой:
        // хранилище не трогаем ([secretStore] остаётся как был), и следующий
        // вызов этого метода снова попробует его первым, а не сразу потребует
        // код. Но предъявить его прямо сейчас всё равно не вышло, а человек,
        // возможно, хочет войти немедленно — код ниже требует то же самое,
        // что и «секрета никогда не было», без второй копии этого текста.
        //
        // БЛОКЕР пункта 4 финальной волны: до этой строки `state.error`
        // оставался нетронутым, и человек видел гейт привязки нейтральным
        // текстом «это устройство ещё не привязано» — тем же, что и у
        // настоящего нового устройства (`login_screen.dart`, докстринг
        // `_EnrolmentGate`, случай «новое устройство»). Услышав это, он ввёл
        // бы код и сжёг настоящий, одноразовый — заведя вторую строку
        // терминала при живом и годном секрете. Названная причина здесь —
        // тот же ключ, что уже стоит на соседнем `catch` (`ownsData`-ветка
        // выше, строка ~600) на тот же смысл «касса не ответила».
        state = state.copyWith(error: 'error.auth_unknown');
      }
    }

    // Ни кэша, ни (годного) секрета: устройство новое, или касса только что
    // отвергла его секрет. Дальше нельзя звать `register()` вслепую —
    // задача 6 сделала код привязки обязательным доводом, и пустой код
    // всегда отказывает `pairing_code_invalid`. Экран обязан спросить
    // человека, а не тратить попытку на заведомый отказ.
    final code = state.enrolmentCode.trim();
    if (code.isEmpty) {
      state = state.copyWith(needsEnrolmentCode: true, enteredPin: '');
      return null;
    }

    try {
      final enrollment = await _terminals.register(
        name: _defaultBrowserTerminalName(),
        code: code,
      );
      final terminal = enrollment.terminal;
      _browserTerminalId = terminal.id;
      // Секрет сохраняется здесь и только здесь — ровно тот единственный
      // раз, когда касса вообще его выдаёт (докстринг
      // [TerminalRepository.register]). `secretStore` (не `_secretStore`
      // повторным чтением GetIt) — то же самое значение, которое уже читали
      // выше на этот же вызов [_resolveTerminalId]; вызывающий-двойник
      // теста, который тем временем перерегистрировал контракт под другим
      // экземпляром, увидел бы в этом расхождение, а не тихое использование
      // не того хранилища.
      secretStore?.write(terminal.id, enrollment.secret);
      state = state.copyWith(
        needsEnrolmentCode: false,
        enrolmentCode: '',
        clearError: true,
      );
      return terminal.id;
    } on InstallationNotConfiguredException {
      state = state.copyWith(
        error: 'error.till_not_configured',
        enteredPin: '',
      );
      return null;
    } on WireRefusal catch (error) {
      if (error.code == 'pairing_code_invalid') {
        // Названная причина с провода — БЛОКЕР 2 задачи 7 плана
        // «знакомство терминала с кассой»: до этой правки этот код тонул в
        // голом `catch (_)` ниже наравне с потолком терминалов, и человек
        // видел «попробуйте ещё раз» про код, который никогда не подойдёт
        // сам по себе. Код стирается ([enrolmentCode] очищается) — он
        // одноразовый на настоящей кассе, и держать отвергнутое значение в
        // поле незачем.
        state = state.copyWith(
          needsEnrolmentCode: true,
          error: 'error.pairing_code_invalid',
          enrolmentCode: '',
          enteredPin: '',
        );
        return null;
      }
      // Пункт 7 фазы 3/4 закрытия долга: потолок в 200 терминалов
      // (`LocalTerminalRepository.maxTerminals`) до этой правки тонул в
      // голом `catch (_)` ниже — человек видел «неизвестную ошибку», а код
      // `terminal_limit_reached` не читал никто. Путь освободить место есть
      // (`terminals.delete`), кнопки для него в этом круге правок нет — это
      // известно; человеку хотя бы называется, что случилось. Гейт кода
      // здесь ни при чём — снимается, чтобы экран вернулся к обычному
      // сообщению об ошибке, а не остался на форме ввода кода без причины.
      state = state.copyWith(
        needsEnrolmentCode: false,
        error: error.code == 'terminal_limit_reached'
            ? 'error.terminal_limit_reached'
            : 'error.auth_unknown',
        enteredPin: '',
      );
      return null;
    } catch (_) {
      // Обрыв провода на самом `register()` — код мог быть верным, узнать
      // неоткуда; гейт остаётся, чтобы можно было просто нажать «Привязать»
      // ещё раз, не перенабирая код заново.
      state = state.copyWith(
        needsEnrolmentCode: true,
        error: 'error.auth_unknown',
        enteredPin: '',
      );
      return null;
    }
  }

  /// Человек редактирует поле кода привязки на экране входа — задача 7
  /// плана «знакомство терминала с кассой», разбор блокера. `clearError`:
  /// начатое исправление затирает прежний отказ (`pairing_code_invalid`/
  /// `terminal_secret_invalid`) тем же приёмом, что и [addDigit] у PIN.
  void updateEnrolmentCode(String value) {
    state = state.copyWith(enrolmentCode: value, clearError: true);
  }

  /// Нажатие «Привязать» на форме кода — единственный путь, которым код,
  /// введённый человеком, доходит до [TerminalRepository.register].
  ///
  /// Пустой код не зовёт кассу: нечего спрашивать, и на настоящей кассе
  /// `register(code: '')` с задачи 6 всегда отказывает `pairing_code_invalid`
  /// — отвечать на пустое поле нажатием кнопки нечем, кроме как не отправлять
  /// вопрос вовсе.
  Future<void> submitEnrolmentCode() async {
    if (state.enrolmentCode.trim().isEmpty) return;
    await _resolveTerminalId();
  }

  /// Имя, под которым новый браузерный терминал впервые появляется в списке
  /// терминалов установки — с меткой времени, чтобы вторая открытая вкладка
  /// не оказалась тёзкой первой. Переименование — отдельная операция
  /// (`terminals.rename`, экран настроек терминалов), не единственный шанс.
  static String _defaultBrowserTerminalName() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return 'Терминал ${now.year}-${two(now.month)}-${two(now.day)} '
        '${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
  }

  Future<void> _verifyPin({bool autoVerify = false}) async {
    final terminalId = await _resolveTerminalId();
    if (terminalId == null) return;

    final generation = ++_verifyGeneration;
    final pin = state.enteredPin;

    AuthOutcome outcome;
    try {
      outcome = await _auth.login(
        AuthAttempt(
          pin: pin,
          terminalId: terminalId,
          // `null` — walk-up. Разрешён он или нет, решает касса: настройка
          // живёт там же, где база, и второй её копии в браузере быть не
          // должно.
          userId: state.selectedUser?.id,
        ),
      );
    } on UnknownTerminalException {
      // Терминал, которого касался этот `terminalId`, кассе больше не
      // известен — например, касса восстановлена из резервной копии,
      // терминалы пересозданы с новыми id, а `TerminalIdentity` этой
      // вкладки пережила восстановление и всё ещё называет старый (десктоп),
      // или терминал этой сессии удалили (`terminals.delete`) между
      // регистрацией и входом (браузер — редкая гонка, не рабочий путь).
      // Сброс и повторная заводка — ровно тот путь, для которого ленивое
      // добывание и писалось (докстринг [_resolveTerminalId]): следующий
      // вызов не находит закэшированного id и с задачи 5 пробует сохранённый
      // секрет ([TerminalRepository.resume]) первым делом — тот секрет
      // называет ровно этот же, только что удалённый `terminalId`, так что
      // касса откажет ([WireRefusal]), вызов сам очистит хранилище и
      // заведёт терминал заново — тем же кодом, что и у самого первого
      // входа. `_browserTerminalId = null` — тот же сброс для браузера, для
      // которого `_identity.forget()` с пункта 2 фазы 3/4 закрытия долга
      // больше ничего не делает (браузер не кэшируется через
      // `TerminalIdentity` вовсе).
      _browserTerminalId = null;
      await _identity.forget();
      final freshId = await _resolveTerminalId();
      if (freshId == null) {
        // `_resolveTerminalId` уже назвал причину и очистил ввод — здесь
        // добавить нечего.
        return;
      }
      try {
        outcome = await _auth.login(
          AuthAttempt(
            pin: pin,
            terminalId: freshId,
            userId: state.selectedUser?.id,
          ),
        );
      } on Object {
        if (generation != _verifyGeneration || state.enteredPin != pin) return;
        state = state.copyWith(enteredPin: '', error: 'error.auth_unknown');
        return;
      }
    } on Object {
      // Любая другая причина — провод недоступен, обмен разошёлся, кадр
      // отказа неопознанного рода. До этой правки `_auth.login` звался без
      // единого `catch`, и исключение уходило в необработанное будущее
      // (`unawaited(_inFlight = _verifyPin(...))`, `attemptLogin`/
      // `_scheduleVerify`) — экран не показывал ничего: ни ошибки, ни
      // ожидания, только замерший ввод. Достижимо тем же путём, что и
      // recovery выше: устаревший id, который почему-то не подошёл под
      // единственный опознаваемый провод текст.
      if (generation != _verifyGeneration || state.enteredPin != pin) return;
      state = state.copyWith(enteredPin: '', error: 'error.auth_unknown');
      return;
    }

    // Более поздняя проверка уже началась, либо набор очистили, пока эта
    // шла. В обоих случаях ответ — про PIN, которого уже нет на экране, и
    // действовать по нему значило бы отвечать не на тот вопрос.
    if (generation != _verifyGeneration || state.enteredPin != pin) return;

    switch (outcome) {
      case AuthSession():
        await _onSession(outcome);
        // Задача 2 фазы 2: свежий вход PIN-ом заводит ту же живую подписку,
        // какой [_restoreSession] уже пользуется после F5 — без неё касса,
        // отозвавшая только что выписанный сеанс, не доедет до этой вкладки
        // раньше следующей перезагрузки. `_watchSession` сама отменяет
        // прежнюю подписку первой строкой, так что второй не заведётся
        // поверх первой, даже если бы эта ветка когда-нибудь позвалась
        // повторно для уже слушаемого токена.
        _watchSession(outcome.token);
      case AuthRejection():
        // Гейт сохранён ровно для той же причины, для которой он стоял и
        // раньше: неверный PIN во время набора длинного (5-6 цифр) кода —
        // ожидаемое промежуточное состояние, а не ошибка, о которой стоит
        // кричать после четвёртой цифры. Остальные причины отказа не
        // рассосутся от того, что дописать ещё цифру, поэтому показываются
        // сразу.
        final showNow =
            !autoVerify ||
            state.isPinMaxLength ||
            outcome.reason != AuthRejectionReason.wrongPin;
        if (showNow) {
          state = state.copyWith(
            enteredPin: '',
            error: messageForRejection(outcome.reason),
          );
        }
    }
  }

  /// Токен, приведший к текущему `isAuthenticated`. Единственная копия в
  /// памяти процесса, а не только в [_tokenStore]: десктоп не регистрирует
  /// хранилище вовсе (он не переживает F5), и без этого поля [logout] на
  /// кассе не мог бы назвать кассе, какой сеанс гасить.
  String? _token;

  /// `expiresAt` последнего принятого сеанса — единственная улика, которой
  /// клиент располагает про срок, когда касса перестаёт называть его вовсе
  /// ([sessionLost] и «касса ответила `null`» в [_restoreSession] ниже).
  ///
  /// Пере-ревью финального разбора фазы 2, пункт 3: `SessionRegistry.watch`
  /// первой строкой чистит просроченные записи
  /// (`lib/backend/session_registry.dart`) — касса никогда не отдаёт сеанс с
  /// `expiresAt` в прошлом, она отдаёт `null`. Значит самый частый случай,
  /// истечение по бездействию, приходит клиенту тем же путём, что и отзыв
  /// владельцем, и до этой правки оба назывались одним и тем же
  /// `error.session_ended` — экран приписывал кассе действие («сеанс завершён
  /// на кассе»), которого она в этом, самом частом случае, не совершала.
  ///
  /// Касса называла срок при входе — вкладка его помнит. `null` от кассы
  /// сравнивается с этой отметкой в [_reasonForVanishedSession]: срок прошёл
  /// — `error.session_expired`, не прошёл — `error.session_ended`. Отзыв
  /// владельцем и выметание по бездействию до истечения срока в данных
  /// по-прежнему неразличимы — выдумывать различие, которого нет в данных,
  /// не входит в эту правку.
  ///
  /// Второй круг задачи 7, пункт 6 (2026-08-21): это поле — **не только**
  /// улика. До этой правки оно жило исключительно в памяти процесса, а F5
  /// заводит новый [LoginNotifier] с нуля — так что самый обыденный сценарий
  /// (закрыл вкладку вечером, открыл утром, касса уже вымела сеанс) приходил
  /// на **свежий** нотифаер первым же событием `null`, поле было `null` тоже,
  /// и [_reasonForVanishedSession] честно, но неверно называла это отзывом —
  /// та самая формулировка, ради устранения которой и делалась эта правка.
  /// [_restoreSession] теперь заранее заполняет поле из
  /// [SessionTokenStorage.readExpiresAt] — из того же места, что пережило
  /// перезагрузку и токен.
  DateTime? _lastKnownExpiresAt;

  /// Пробует поднять уже выписанный сеанс токеном из [_tokenStore] — вкладка
  /// пережила F5, а касса ещё не забыла её сеанс. Дальше остаётся его живой
  /// подписчик до конца жизни нотифаера: касса, погасившая или отозвавшая
  /// сеанс, доводит это до вкладки сама, без единого нажатия.
  ///
  /// До задачи 5 здесь стоял разовый `watchSession(token).first` — вкладка
  /// узнавала о живом сеансе на подъёме и тут же переставала слушать.
  /// `authSession` — подписка, задуманная как push от кассы («касса,
  /// погасившая сеанс, обязана сказать об этом сама», докстринг
  /// `TillOps.authSession`), а разовое чтение эту половину проедало впустую.
  ///
  /// [_lastKnownExpiresAt] заполняется здесь, **до** первого события
  /// подписки (второй круг задачи 7, пункт 6, см. докстринг поля) — если
  /// касса уже вымела сеанс, первым и единственным событием будет `null`, и
  /// без этой строки улики не было бы вовсе.
  Future<void> _restoreSession() async {
    final store = _tokenStore;
    if (store == null) return;

    final token = store.read();
    if (token == null) return;

    _lastKnownExpiresAt = store.readExpiresAt();
    _watchSession(token);
  }

  /// Заводит живую подписку на сеанс [token] — единственное место, где
  /// [_sessionSubscription] заводится, вызываемое из двух: [_restoreSession]
  /// (вкладка пережила F5) и [_verifyPin] (вход только что состоялся PIN-ом).
  ///
  /// Пере-ревью финального разбора фазы 2, пункт 2: до этой правки подписка
  /// заводилась только в [_restoreSession] — свежий вход PIN-ом получал сеанс
  /// от [_verifyPin] напрямую и никогда не заводил подписчика, поэтому
  /// вкладка узнавала об отзыве владельцем только после F5. Отменяет
  /// предыдущую подписку первой строкой ровно как и раньше делал
  /// `_restoreSession` — так что оба вызывающих безопасны, даже если бы
  /// второй раз позвали поверх первого: заведётся одна, не две.
  void _watchSession(String token) {
    _sessionSubscription?.cancel();
    _sessionSubscription = _auth
        .watchSession(token)
        .listen(
          (session) {
            // `session == null` — законное «сеанса больше нет». Просроченный, но
            // ещё не выметенный `expiresAt` — та же судьба, только клиент
            // проверяет его сам, а не доверяет кассе: сервер чистит его первой
            // строкой `SessionRegistry.watch` (`lib/backend/session_registry.dart`),
            // но эта проверка — вторая сторона той же дыры, а не дубль первой, —
            // если касса когда-нибудь снова отдаст неотфильтрованную запись
            // (старая версия, другой путь), просроченный токен не откроет вход
            // без PIN.
            final alive =
                session != null && session.expiresAt.isAfter(DateTime.now());
            if (alive) {
              unawaited(_onSession(session));
            } else if (session != null) {
              // У клиента есть прямая улика — `expiresAt` в прошлом, а не только
              // молчание кассы. Круг правок 1: два случая различаются ровно
              // настолько, насколько это доказано данными, — здесь доказано.
              _endSession('error.session_expired');
            } else {
              // Касса ответила `null` — сеанса больше нет. `SessionRegistry.watch`
              // чистит просроченное первой строкой (докстринг [_lastKnownExpiresAt]) —
              // поэтому `null` покрывает и отзыв владельцем, и самое частое:
              // истечение по бездействию. [_reasonForVanishedSession] отличает их
              // по последнему известному сроку, а не гадает вслепую.
              _endSession(_reasonForVanishedSession());
            }
          },
          onError: (Object _) {
            // Провод недоступен или ответ не разобрался. Токен остаётся —
            // следующая загрузка (или, если провод оживёт, следующее событие
            // этой же подписки) попробует снова, а эта просто показывает выбор
            // кассира, как будто токена не было вовсе. Тот же исход, каким был
            // разовый `.first`, пойманный общим `on Object` до этой правки.
          },
        );
  }

  /// Сеанс кончился не по нажатию: истёк, погашен на кассе, отозван, или его
  /// оборвала операция кодом `unauthorized` ([SessionLost],
  /// `lib/domain/wire/session_lost.dart`). Единая точка для обоих путей задачи 5 —
  /// живой подписки [_restoreSession] и [sessionLost] ниже.
  void _endSession(String reasonKey) {
    _sessionSubscription?.cancel();
    _sessionSubscription = null;

    _token = null;
    _tokenStore?.clear();

    ref.read(appStateProvider.notifier).logout();

    state = state.copyWith(
      enteredPin: '',
      isAuthenticated: false,
      sessionEndedReason: reasonKey,
    );
  }

  /// Реакция на [SessionLost], пойманный любой операцией провода — не только
  /// восстановлением сеанса. `WtDeviceCheck`, `WtDeviceBindingRepository` и
  /// `WtTerminalRepository` (задача 4) пропускают его наверх нетронутым
  /// ровно затем, чтобы привести терминал сюда: токен и состояние гасятся
  /// тем же путём, каким уже гасит их отозванный сеанс.
  ///
  /// `forbidden` сюда не попадает и не имеет права: у него другой тип
  /// (`WtProtocolError`), и он остаётся рядовым отказом операции — сеанс
  /// живой, кассиру просто не хватает права, и уводить его на вход значило
  /// бы завести круг, который уже нашла и закрыла задача 4.
  void sessionLost(SessionLost error) {
    // `WireDenied.unauthorized` — «токена нет, или сеанс по нему
    // неизвестен/истёк» (докстринг `wire_guard.dart`) — один код на все три
    // причины уже на кассе, до провода. Текст `error.detail` не разбираем:
    // канал текста исключения — секретный и закрытый (задача 2б), провод не
    // несёт причину, которую клиенту разрешено разобрать. Та же неполная
    // улика, что и у `null` от живой подписки — и то же разбирательство по
    // ней в [_reasonForVanishedSession].
    _endSession(_reasonForVanishedSession());
  }

  /// Срок прошёл, судя по последнему известному сеансу
  /// ([_lastKnownExpiresAt]), → `error.session_expired`. Не прошёл, или он и
  /// вовсе неизвестен (сеанс этой вкладки исчез раньше, чем клиент успел
  /// увидеть хоть один живой) → `error.session_ended`: без прямой улики —
  /// честный общий исход, а не догадка. Общая точка для обоих мест, которые
  /// узнают об исчезнувшем сеансе не от собственной проверки данных, а от
  /// молчания кассы — «касса ответила `null`» в [_restoreSession] и
  /// [sessionLost].
  String _reasonForVanishedSession() {
    final expiresAt = _lastKnownExpiresAt;
    if (expiresAt != null && !expiresAt.isAfter(DateTime.now())) {
      return 'error.session_expired';
    }
    return 'error.session_ended';
  }

  /// Сеанс, выписанный кассой, переносится в состояние приложения как есть.
  ///
  /// [AuthSession.permissions] — уже действующие права (роль ∩ режим точки),
  /// посчитанные на кассе; экрану нечего пересекать и неоткуда больше читать
  /// режим точки — оба поля уже в ответе.
  Future<void> _onSession(AuthSession session) async {
    _token = session.token;
    _tokenStore?.write(session.token, session.expiresAt);
    _lastKnownExpiresAt = session.expiresAt;

    final roleIndex = _getUserRoleIndex(session.role);

    ref
        .read(appStateProvider.notifier)
        .setUserInfo(
          id: session.userId,
          name: session.name,
          role: roleIndex,
          permissions: session.permissions,
        );
    ref.read(appStateProvider.notifier).setShiftOpened(session.shiftOpen);

    final modeIndex = session.operatingMode;
    final mode = modeIndex >= 0 && modeIndex < OperatingMode.values.length
        ? OperatingMode.values[modeIndex]
        : OperatingMode.retail;
    ref.read(appStateProvider.notifier).setOperatingMode(mode);

    state = state.copyWith(
      selectedUser: _userById(session.userId) ?? state.selectedUser,
      isAuthenticated: true,
      isShiftOpened: session.shiftOpen,
      clearError: true,
      // Свежий действующий сеанс закрывает любую прежнюю историю «сеанс
      // кончился»: если она и была, она больше не про текущее состояние.
      clearSessionEndedReason: true,
    );
  }

  UserItem? _userById(int id) {
    for (final user in state.users) {
      if (user.id == id) return user;
    }
    return null;
  }

  int _getUserRoleIndex(String? roleName) {
    if (roleName == null) return UserRole.cashier.index;

    for (final role in UserRole.values) {
      if (role.name == roleName || role.displayName == roleName) {
        return role.index;
      }
    }
    return UserRole.cashier.index;
  }

  void reset() {
    state = state.copyWith(
      enteredPin: '',
      clearError: true,
      isAuthenticated: false,
      // Выход — по нажатию, о причине человек и так знает: старой причине
      // «сеанс кончился сам» здесь взяться неоткуда, но если бы она уцелела
      // с прошлого раза, она была бы ложной именно сейчас.
      clearSessionEndedReason: true,
    );
  }

  /// Гасит сеанс: чистит местное состояние немедленно, сообщает кассе —
  /// сколько бы касса ни думала над ответом.
  ///
  /// До этой правки выход (`TerminalHomeScreen._logout`) чистил только
  /// `AppState` — ни `AuthRepository.logout`, ни [_tokenStore] не звал ни
  /// один вызывающий во всём рабочем коде. Следствия были два: сеанс на
  /// кассе оставался живым в `SessionRegistry` до истечения бездействия
  /// (до получаса), и токен оставался в `sessionStorage` — следующая
  /// загрузка той же вкладки нашла бы его в [_restoreSession] и вошла бы
  /// уже погашенным (на кассе) или, того хуже, всё ещё действующим сеансом,
  /// которого человек считал закрытым.
  ///
  /// Первая же правка этого чинила молча ждать: `AppState`/`_tokenStore`
  /// чистились **после** `await _auth.logout(token)`, а у `WtDispatcher.ask`
  /// нет ни таймаута, ни отмены (`lib/web/wt_dispatcher.dart`). Молчащий
  /// провод вешал бы саму кнопку выхода — человек оставался бы вошедшим на
  /// экране до бесконечности. Местное состояние чистится первым и
  /// синхронно с этим методом; обращение к кассе не просто идёт следом, а
  /// не awaits'ится вовсе — `logout()` обязан вернуться, что бы ни
  /// случилось с проводом. Сеанс на кассе, если провод подведёт, погаснет
  /// сам по истечении бездействия.
  Future<void> logout() async {
    // Отменяется здесь, а не только внутри `_endSession`/`dispose`: этот
    // выход зовёт `_auth.logout(token)` ниже, которое на настоящей кассе
    // погасит сеанс на сервере — и без отмены собственная же живая подписка
    // [_restoreSession] получила бы за это своё `null` и повторно прогнала
    // бы `_endSession` поверх состояния, которое человек уже покидает по
    // своей воле (а с новым логином той же вкладкой — поверх чужого, нового
    // сеанса, если бы отставшее событие пришло позже).
    _sessionSubscription?.cancel();
    _sessionSubscription = null;

    final token = _token ?? _tokenStore?.read();
    _token = null;
    _tokenStore?.clear();

    ref.read(appStateProvider.notifier).logout();
    reset();

    if (token != null) unawaited(_bestEffortRemoteLogout(token));
  }

  /// Сообщает кассе, что сеанс погашен — если получится и когда получится.
  /// Ошибки здесь некому показать: выход к этому моменту уже состоялся
  /// локально ([logout] выше), и это лучшее, что можно сделать.
  Future<void> _bestEffortRemoteLogout(String token) async {
    try {
      await _auth.logout(token);
    } on Object {
      // см. докстринг logout()
    }
  }

  /// Куда вести после входа.
  ///
  /// Спрашивается **возможность**, а не облик: `ownsData` ложно ровно там, где
  /// базы нет, то есть в браузерной вкладке, а там нет и экрана продажи — он
  /// тянет drift и не собирается под web. См. `HostCapabilities` и раздел 4
  /// управляющего документа. Касса и appliance (`ownsData == true`) идут по
  /// старому пути — на смену или сразу на продажу, — потому что для них он
  /// собирается и работает.
  String getPostLoginRoute() {
    if (!_capabilities.ownsData) return AppRoutes.terminalHome;
    if (!state.isShiftOpened) return AppRoutes.shift;
    final mode = ref.read(appStateProvider).operatingMode;
    return NavDestinations.defaultRoute(mode);
  }
}

final loginControllerProvider = NotifierProvider<LoginNotifier, LoginState>(
  LoginNotifier.new,
);
