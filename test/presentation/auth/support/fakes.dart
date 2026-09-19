/// Подставные договоры для тестов входа — общие вместо трёх независимых
/// копий, которые разошлись формой ровно настолько, насколько каждому файлу
/// было нужно чуть другое (задача 7 волны правок фазы 2).
///
/// Было три отдельных `_FakeAuth`/`_FakeTerminalRepository` и две
/// побайтово одинаковых `_FakeTerminalIdentity`/`_FakeSessionTokenStorage` —
/// в `test/presentation/auth/session_expiry_test.dart`,
/// `test/presentation/auth/login_controller_test.dart` и
/// `test/web/wt_setup_router_test.dart`. Каждая копия жила порознь и могла
/// разойтись с соседями молча — образец `test/web/support/fake_dispatcher.dart`
/// уже показывал, как это чинится: общий файл, а не третья (или четвёртая)
/// копия одного и того же.
library;

import 'dart:async';

import 'package:telepos/domain/auth/auth_attempt.dart';
import 'package:telepos/domain/auth/auth_outcome.dart';
import 'package:telepos/domain/auth/auth_repository.dart';
import 'package:telepos/domain/auth/auth_user.dart';
import 'package:telepos/domain/auth/session_token_storage.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/terminal/terminal.dart';
import 'package:telepos/domain/terminal/terminal_identity.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/terminal/terminal_secret_storage.dart';

/// Личность терминала, которую вкладка уже «запомнила» — id зафиксирован на
/// 1, `remember`/`forget` не делают ничего. Тестам, которым важно различить
/// «ещё не запомнено» от «уже запомнено» от «забыто снова» (устаревший
/// terminalId, личность браузерного терминала), нужен другой двойник — тот
/// не копия этого и здесь не живёт (`_StatefulTerminalIdentity`,
/// `login_controller_test.dart`).
class FakeTerminalIdentity implements TerminalIdentity {
  @override
  Future<int?> currentId() async => 1;

  @override
  Future<void> remember(int terminalId) async {}

  @override
  Future<void> forget() async {}
}

/// Хранилище токена вкладки, которое на самом деле помнит. `expiresAt` —
/// пункт 6 второго круга задачи 7 (2026-08-21): настоящее хранилище
/// (`SessionTokenStore`, `lib/web/wt_session_token_store.dart`) переживает
/// F5 вместе с токеном, и эта подделка обязана вести себя так же, иначе
/// тесты на восстановление после F5 не смогли бы отличить «улики нет» от
/// «улика была, но подделка её потеряла».
class FakeSessionTokenStorage implements SessionTokenStorage {
  String? _token;
  DateTime? _expiresAt;

  int clearCallCount = 0;

  @override
  String? read() => _token;

  @override
  DateTime? readExpiresAt() => _expiresAt;

  @override
  void write(String token, DateTime expiresAt) {
    _token = token;
    _expiresAt = expiresAt;
  }

  @override
  void clear() {
    clearCallCount++;
    _token = null;
    _expiresAt = null;
  }
}

/// Провод `AuthRepository`.
///
/// [login] по умолчанию отдаёт `AuthRejection(wrongPin)` — самый частый,
/// «ничего интересного не происходит» исход подавляющего большинства
/// тестов входа; конструктор принимает другой [outcome] там, где тесту нужен
/// успешный вход или другая причина отказа. [throwOnLogin] — очередь
/// исключений, каждое на одну попытку, впереди [outcome] — нужна тесту на
/// восстановление после `UnknownTerminalException`.
///
/// [watchSession] соединяет два разных способа, которыми исходные три копии
/// отвечали на этот вопрос, а не выбирает один в ущерб другому:
/// - разовый снимок из [sessions] — не установлен для токена, подписка
///   получает только то, что придёт через [pushSession] (или ничего);
///   установлен — первое, что видит подписчик, ровно значение из карты на
///   момент вызова `watchSession`, тем же приёмом, каким `SessionRegistry.watch`
///   на кассе (`lib/backend/session_registry.dart`) отдаёт `_live[token]`
///   первой строкой `onListen`;
/// - управляемый канал поверх снимка — [pushSession] шлёт в него любое число
///   дальнейших событий без закрытия потока между ними, ровно то отличие
///   живой подписки от `Stream.value`, которое и проверяет задача 5.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository([
    this.outcome = const AuthRejection(AuthRejectionReason.wrongPin),
  ]);

  /// Ответ `login()`, когда [throwOnLogin] пуста.
  final AuthOutcome outcome;

  /// Кассиры, которых отдаёт `watchUsers()` — один и тот же список во всех
  /// трёх исходных копиях (Айгуль, кассир, PIN есть); меняется там, где
  /// тесту важен другой.
  List<AuthUser> users = const [
    AuthUser(id: 7, name: 'Айгуль', role: 'Кассир', hasPin: true),
  ];

  /// Последняя попытка, которую на самом деле спросили.
  AuthAttempt? seen;

  /// Сколько раз касса на самом деле была спрошена.
  int callCount = 0;

  /// Каждый вызов `login` до исчерпания этой очереди бросает своё значение
  /// вместо ответа [outcome] — по одному исключению на попытку.
  final List<Object> throwOnLogin = [];

  /// Управляемый канал кассиров — для тестов, которым нужно **несколько**
  /// событий подряд, а не один снимок.
  ///
  /// `Stream.value(users)` ниже отдаёт список ровно один раз и на этом
  /// закрывается, а именно вторым событием и отличается живая подписка от
  /// снимка: касса заводит кассира, когда экран входа уже открыт. Пока
  /// канала нет, поведение прежнее — ни один существующий тест не задет.
  StreamController<List<AuthUser>>? usersController;

  /// Отправить кассиров в открытую подписку. Заводит [usersController], если
  /// его ещё нет, — значит звать `pushUsers` можно и до `watchUsers`.
  void pushUsers(List<AuthUser> next) {
    users = next;
    (usersController ??= StreamController<List<AuthUser>>.broadcast()).add(next);
  }

  /// Уронить подписку на кассиров — обрыв провода с точки зрения экрана.
  ///
  /// Отдельно от [pushUsers], потому что это другое событие: не «список
  /// изменился», а «подписки больше нет». Экран обязан различать их.
  void failUsers(Object error) {
    (usersController ??= StreamController<List<AuthUser>>.broadcast())
        .addError(error);
  }

  @override
  Stream<List<AuthUser>> watchUsers() {
    final controller = usersController;
    if (controller == null) return Stream.value(users);
    // Снимок первым, дальше живые события — тем же приёмом, что [watchSession]
    // ниже и `SessionRegistry.watch` на кассе.
    return controller.stream;
  }

  @override
  Future<AuthOutcome> login(AuthAttempt attempt) async {
    seen = attempt;
    callCount++;
    if (throwOnLogin.isNotEmpty) throw throwOnLogin.removeAt(0);
    return outcome;
  }

  /// Токен, с которым в последний раз позвали `logout` — `null`, если ни
  /// разу.
  String? loggedOutToken;

  int logoutCallCount = 0;

  /// `logout` не отвечает никогда — подставной недоступный провод: у
  /// `WtDispatcher.ask` нет ни таймаута, ни отмены.
  bool hangOnLogout = false;

  @override
  Future<void> logout(String token) {
    loggedOutToken = token;
    logoutCallCount++;
    if (hangOnLogout) return Completer<void>().future;
    return Future<void>.value();
  }

  /// Разовый снимок для `watchSession(token)` — см. докстринг класса.
  final Map<String, AuthSession?> sessions = {};

  final Map<String, StreamController<AuthSession?>> _channels = {};

  StreamController<AuthSession?> _channel(String token) => _channels
      .putIfAbsent(token, () => StreamController<AuthSession?>.broadcast());

  /// Живой push поверх снимка [sessions] — тест решает сам, когда прийти
  /// первому событию и когда следующему.
  void pushSession(String token, AuthSession? session) =>
      _channel(token).add(session);

  @override
  Stream<AuthSession?> watchSession(String token) {
    final upstream = _channel(token);
    late final StreamController<AuthSession?> out;
    StreamSubscription<AuthSession?>? subscription;
    out = StreamController<AuthSession?>(
      onListen: () {
        subscription = upstream.stream.listen(out.add, onError: out.addError);
        if (sessions.containsKey(token)) out.add(sessions[token]);
      },
      onCancel: () async => subscription?.cancel(),
    );
    return out.stream;
  }
}

/// Провод `TerminalRepository`.
///
/// [self] — не значение, а функция, как и было в `login_controller_test.dart`'s
/// оригинале: один и тот же двойник отдаёт как найденный терминал, так и
/// `InstallationNotConfiguredException`, чем бы вызывающий тест ни попросил.
/// Умолчание — бросает `UnimplementedError` с тем же текстом, каким отвечал
/// `session_expiry_test.dart`'s оригинал («этому набору терминал спрашивать
/// не о чем»): в его тестах `self()`/`register()` не должны звучать вовсе.
class FakeTerminalRepository implements TerminalRepository {
  FakeTerminalRepository({
    Future<Terminal> Function()? self,
    Future<Terminal> Function(String name, String code)? register,
    Future<Terminal> Function(int terminalId, String secret)? resume,
  }) : _self = self ?? _neverAsked,
       _register = register,
       _resume = resume;

  static Future<Terminal> _neverAsked() async =>
      throw UnimplementedError('этому набору терминал спрашивать не о чем');

  final Future<Terminal> Function() _self;
  final Future<Terminal> Function(String name, String code)? _register;
  final Future<Terminal> Function(int terminalId, String secret)? _resume;

  /// Сколько раз касса на самом деле была спрошена про свою личность.
  int selfCallCount = 0;

  /// Сколько раз терминал завёл себе новую строку.
  int registerCallCount = 0;

  /// Имя, с которым звали `register` последний раз.
  String? lastRegisterName;

  /// Код привязки, с которым звали `register` последний раз — задача 7
  /// плана «знакомство терминала с кассой», разбор блокера: подделка,
  /// которая не смотрела на этот довод вовсе, и была причиной, по которой
  /// набор оставался зелёным при сломанном браузерном входе.
  String? lastRegisterCode;

  /// Сколько раз вкладка предъявляла сохранённый секрет обратно — задача 5
  /// плана «знакомство терминала с кассой» (шаг 2 спеки).
  int resumeCallCount = 0;

  /// Довод, с которым звали `resume` последний раз.
  ({int terminalId, String secret})? lastResumeArgs;

  @override
  Future<Terminal> self() {
    selfCallCount++;
    return _self();
  }

  @override
  Future<List<Terminal>> list() async => const [];

  @override
  Stream<List<Terminal>> watchAll() => const Stream.empty();

  @override
  Stream<Terminal?> watchSelf() => const Stream.empty();

  /// Секрет фиксированный, не случайный: тесты этого двойника, которым
  /// секрет сам по себе не интересен, проверяют поведение
  /// `login_controller.dart` вокруг факта его выдачи, а не форму
  /// (`TerminalSecret` — предмет `terminal_secret_test.dart`). Значение
  /// значения не несёт — только то, что оно есть, и совпадает с тем, что
  /// [FakeTerminalSecretStorage] отдаёт умолчанием, чтобы тесты, которым
  /// нужен настоящий круг «завели → сохранили → предъявили», могли сверить
  /// оба конца одной константой.
  static const fakeSecret = 'fake-secret-not-a-real-terminal-secret';

  @override
  Future<TerminalEnrollment> register({
    required String name,
    String code = '',
  }) async {
    registerCallCount++;
    lastRegisterName = name;
    lastRegisterCode = code;
    final register = _register;
    if (register == null) throw UnimplementedError();
    final terminal = await register(name, code);
    return (terminal: terminal, secret: fakeSecret);
  }

  @override
  Future<Terminal> resume({
    required int terminalId,
    required String secret,
  }) async {
    resumeCallCount++;
    lastResumeArgs = (terminalId: terminalId, secret: secret);
    final resume = _resume;
    if (resume == null) throw UnimplementedError();
    return resume(terminalId, secret);
  }

  @override
  Future<void> rename(int terminalId, String name) async {}

  @override
  Future<void> setAllowedPaymentTypes(
    int terminalId,
    Set<PaymentType> types,
  ) async {}

  @override
  Future<void> delete(int terminalId) async {}
}

/// Хранилище секрета терминала, которое на самом деле помнит — тот же
/// приём, что [FakeSessionTokenStorage] выше, для другого контракта
/// ([TerminalSecretStorage], `lib/domain/terminal/terminal_secret_storage.dart`
/// — задача 5 плана «знакомство терминала с кассой», шаг 2 спеки).
///
/// Отдельный класс, а не второй метод на [FakeSessionTokenStorage]: два
/// контракта, две подделки, тот же довод, каким в рабочем коде разведены
/// [TerminalSecretStorage] и `SessionTokenStorage` — разное время жизни,
/// разное хранилище, и смешать их здесь значило бы стереть в тесте ровно то
/// различие, которое проверяет рабочий код.
class FakeTerminalSecretStorage implements TerminalSecretStorage {
  StoredTerminalSecret? _stored;

  /// Сколько раз хранилище на самом деле очищали — тот же приём, что
  /// [FakeSessionTokenStorage.clearCallCount]: тестам, которым важно
  /// отличить «секрет отвергнут и забыт» от «секрет просто не читали»,
  /// нужно видеть сам факт вызова, а не только его следствие.
  int clearCallCount = 0;

  @override
  StoredTerminalSecret? read() => _stored;

  @override
  void write(int terminalId, String secret) {
    _stored = (terminalId: terminalId, secret: secret);
  }

  @override
  void clear() {
    clearCallCount++;
    _stored = null;
  }
}
