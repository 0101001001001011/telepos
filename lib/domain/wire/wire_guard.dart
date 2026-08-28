import 'package:telepos/domain/auth/auth_session.dart';
import 'package:telepos/domain/auth/session_lookup.dart';
import 'package:telepos/domain/wire/wire_access.dart';

/// Чем закончилась проверка запроса.
sealed class WireVerdict {
  const WireVerdict();
}

/// Пускаем. [session] есть у всего, что требовало сеанса, и `null` у открытых.
///
/// Задача 9 закрытия долга ненадолго довела это поле до самого обработчика —
/// вторым, необязательным доводом `WireHandler` (`till_wire.dart`), — потому
/// что единственный тогдашний читатель, `terminals.delete`
/// (`lib/backend/till_operations.dart`), сверял `terminalId` из тела с
/// `session.terminalId` сам. Задача 10 забрала эту сверку сюда, в сторож —
/// `SessionAccess.ownTerminal` (`wire_access.dart`) — и заодно закрыла
/// одноимённую дыру у `terminals.rename`, `deviceBindings`,
/// `deviceBindingSave` и `deviceCheck`, у которых читателя не было вовсе.
/// Второй довод `WireHandler` с этим снят: обработчику сверять больше нечего,
/// и держать неиспользуемый параметр значило бы оставить шов, который через
/// месяц прочитают как разрешение проверять владение где попало — ровно то,
/// от чего уже один раз отказались, когда сторожа не было (`wire_access.dart`,
/// «Владение терминалом — задача 10»).
final class WireAllowed extends WireVerdict {
  const WireAllowed(this.session);
  final AuthSession? session;
}

/// Не пускаем — с кодом для терминала и причиной словами для лога.
///
/// # Почему код, а не один `unauthorized` на все четыре случая
///
/// До задачи 4 (круг правок 1) все четыре ветки ниже уходили одним и тем же
/// кадром `ErrorFrame('unauthorized', …)`, и терминал не мог отличить «сеанс
/// истёк — войди заново» от «сеанс жив, просто не хватает права». Задача 4
/// завела `SessionLost` (`lib/domain/wire/session_lost.dart`) и тут же обнаружила
/// это смешение: [SessionLost] должна вести на экран входа, но кассир с
/// живым сеансом без права `settings.hardware` от входа заново не выигрывает
/// ничего — он войдёт той же учёткой и упрётся в тот же отказ, кругом.
///
/// Поэтому здесь четыре кода, а не один:
///
/// - [unauthorized] — токена нет, или сеанс по нему неизвестен/истёк. Лечится
///   входом, и только этот код [WtDispatcher] переводит в `SessionLost`
///   (`lib/web/wt_dispatcher.dart`).
/// - [forbidden] — сеанс живой, права не хватает. Входом не лечится вовсе:
///   человеку с той же учёткой нужно другое право, а не новый сеанс. Остаётся
///   рядовым `WtProtocolError`, идёт прежним путём отказа операции. С задачи
///   10 закрытия долга тем же кодом уходит и отказ `SessionAccess.ownTerminal`
///   при [TerminalOwnership.same]: чужой терминал в теле — то же самое «сеанс
///   живой, но не для этого» — вход не даёт права на терминал, за которым
///   вкладка не сидит.
/// - [alreadyConfigured] — [SetupOnlyAccess] отказала, потому что касса уже
///   настроена. Это не про сеанс вообще: анонимный вопрос отклонён составом
///   кассы, а не тем, кто спросил, — валить его в один код с «войди заново»
///   значило бы отправить оператора мастера настройки логиниться туда, где
///   входа не бывает.
/// - [unknownOp] — имени нет в словаре доступа. В рабочей сборке недостижимо
///   (словарь строится из того же `TillOps.all`, что и карты обработчиков —
///   см. `till_wire.dart`, ветка-страховка `_onRequest`), но код тот же, что
///   и у настоящей ветки-страховки: расхождение каталога и обработчиков —
///   не отказ по сеансу ни в каком смысле.
///
/// Пятый код здесь не заведён нарочно. `SessionAccess.ownTerminal` при
/// [TerminalOwnership.different] (сегодня — только `terminals.delete`) уходит
/// кодом `cannot_delete_self`: тем же, которым уже отвечает репозиторный
/// `isSelf`-отказ (`LocalTerminalRepository.delete`,
/// `terminal_repository_local.dart`) и который проверен поимённо
/// (`test/backend/terminal_delete_test.dart`). Это тот же самый запрет «не
/// удаляй себя», приведённый к настоящему смыслу («терминал вкладки», а не
/// «терминал кассы»), а не второй код в придачу к первому — заводить для него
/// `forbidden` значило бы заставить терминал различать два разных отказа
/// одним и тем же именем.
final class WireDenied extends WireVerdict {
  const WireDenied(this.code, this.reason, {this.session});

  /// Токена нет, или сеанс по нему неизвестен/истёк.
  static const unauthorized = 'unauthorized';

  /// Сеанс живой, права не хватает.
  static const forbidden = 'forbidden';

  /// [SetupOnlyAccess] отказала — касса уже настроена.
  static const alreadyConfigured = 'already_configured';

  /// Имени нет в словаре доступа.
  static const unknownOp = 'unknown_op';

  /// Код, которым уйдёт [ErrorFrame] — то же поле, что [WireRefusal.code].
  final String code;

  /// Причина словами — для лога и для текста кадра отказа.
  final String reason;

  /// Сеанс, который сторож уже нашёл к моменту отказа — задача 21 закрытия
  /// долга безопасности (журнал событий безопасности).
  ///
  /// `null` для [unauthorized] (сеанса нет вовсе — отказать раньше, чем он
  /// нашёлся) и для [alreadyConfigured]/[unknownOp] (эти коды не про сеанс).
  /// Заполнен для [forbidden] и для `cannot_delete_self`
  /// (`TerminalOwnership.different`, ниже в [check]) — обеим веткам уже
  /// известен настоящий, проверенный сеанс, и терять его на пути к журналу
  /// означало бы просить журнал угадывать `terminalId`/`userId` там, где их
  /// уже кто-то посчитал точно.
  final AuthSession? session;
}

/// Решает, пускать ли запрос.
///
/// Живёт в домене и ничего не знает ни о транспорте, ни о базе: словарь
/// требований приходит доводом, сеанс — портом, состояние настройки — функцией.
class WireGuard {
  const WireGuard({
    required Map<String, WireAccess> access,
    required SessionLookup sessions,
    required Future<bool> Function() isTillConfigured,
    required Future<int?> Function() selfTerminalId,
  }) : _access = access,
       _sessions = sessions,
       _isTillConfigured = isTillConfigured,
       _selfTerminalId = selfTerminalId;

  final Map<String, WireAccess> _access;
  final SessionLookup _sessions;
  final Future<bool> Function() _isTillConfigured;

  /// `id` терминала, которым касса пользуется сама (`isSelf`), или `null`,
  /// если его ещё нет (мастер настройки не проходил). Довод, не поле — как и
  /// [_isTillConfigured]: сторож живёт в домене и не знает, как это читается
  /// (`terminalDao.self()` у настоящей кассы, `till_wire_guard.dart`).
  ///
  /// Нужен только для регрессии фазы 3/4 закрытия долга, разобранной ниже,
  /// в [check] — четыре ветки `TerminalOwnership.same` за пределами этого
  /// поля не выходят.
  final Future<int?> Function() _selfTerminalId;

  /// [body] — доводом, а не типом транспорта: `SessionAccess.ownTerminal`
  /// сверяет `terminalId` из тела с сеансом, и это единственная причина,
  /// по которой сторож вообще видит тело запроса. Пустое тело (`const {}`)
  /// годится для операций без [SessionAccess.ownTerminal] — им нечего в нём
  /// искать.
  Future<WireVerdict> check(
    String op,
    Map<String, Object?> body,
    String? token,
  ) async {
    final access = _access[op];
    if (access == null) {
      // Умолчание закрыто. Имя не из словаря сюда попасть не должно — карты
      // обработчиков собираются из того же каталога, — но если попало, это
      // расхождение, и пускать по нему нельзя. Тот же код, что и у
      // ветки-страховки в `till_wire.dart`: расхождение каталога и карт
      // обработчиков — не про сеанс.
      return const WireDenied(
        WireDenied.unknownOp,
        'операция не объявлена в словаре доступа',
      );
    }

    switch (access) {
      case OpenAccess():
        return const WireAllowed(null);

      case EnrolmentAccess():
        // Пропуск, а не проверка — см. докстринг [EnrolmentAccess]
        // (`wire_access.dart`) про то, почему довод (код привязки) сверяет
        // обработчик, а не сторож: `PairingInvites` — зависимость
        // `lib/backend/`, сторож живёт в `lib/domain/` и не имеет права её
        // знать.
        return const WireAllowed(null);

      case SetupOnlyAccess():
        if (await _isTillConfigured()) {
          return const WireDenied(
            WireDenied.alreadyConfigured,
            'касса уже настроена',
          );
        }
        return const WireAllowed(null);

      case SessionAccess(needs: final needs, ownTerminal: final ownTerminal):
        if (token == null || token.isEmpty) {
          return const WireDenied(WireDenied.unauthorized, 'нужен сеанс');
        }
        final session = _sessions.sessionFor(token);
        if (session == null) {
          return const WireDenied(
            WireDenied.unauthorized,
            'сеанс неизвестен или истёк',
          );
        }
        if (needs != null && !session.permissions.contains(needs)) {
          return WireDenied(
            WireDenied.forbidden,
            'нет права $needs',
            session: session,
          );
        }
        if (ownTerminal != null) {
          final requested = body['terminalId'];
          if (requested is! int) {
            // Тело без `terminalId` — отказ, а не проход умолчанием: молчаливо
            // пропустить операцию, которой нечем подтвердить владение, значило
            // бы вернуть ту самую дыру, ради которой заведён этот довод.
            return WireDenied(
              WireDenied.forbidden,
              'операция требует terminalId в теле запроса',
              session: session,
            );
          }
          final isOwnTerminal = requested == session.terminalId;
          switch (ownTerminal) {
            case TerminalOwnership.same:
              // Регрессия фазы 3/4 закрытия долга (найдена разбором
              // 2026-08-21, до этой правки исправлена не была): четыре
              // экрана настроек оборудования (`hardware_settings_screen
              // .dart`, `printer_settings_screen.dart`,
              // `label_printer_settings_screen.dart`) берут `terminalId` не
              // из сеанса, а через `TerminalRepository.self()` —
              // `terminals.selfEnsure` по проводу, который в браузере всегда
              // отдаёт строку **самой кассы** (`isSelf`), а не терминал
              // вызывающей вкладки. `HostCapabilities.browser` называет это
              // прямым текстом: «устройства настраивает у кассы, к которой
              // подключена» — то есть у **своего оборудования** в задуманном
              // смысле этой операции два законных владельца: терминал этого
              // сеанса (десктоп, где `self()` и сеанс совпадают всегда) и
              // терминал самой кассы (браузер, который спрашивает про
              // оборудование кассы, а не про несуществующее оборудование
              // вкладки). `session.terminalId` для браузера — третье число
              // (`terminals.register`), не совпадающее ни с одним из первых
              // двух никогда — и до этой правки сторож требовал именно его,
              // так что все четыре операции отвечали `forbidden` на каждый
              // браузерный запрос, а `catch (_)` в `_loadSettings` глотал
              // отказ и открывал экран пустым.
              if (!isOwnTerminal && requested != await _selfTerminalId()) {
                return WireDenied(
                  WireDenied.forbidden,
                  'terminalId=$requested — не терминал этого сеанса и не '
                  'терминал самой кассы '
                  '(session.terminalId=${session.terminalId})',
                  session: session,
                );
              }
            case TerminalOwnership.different:
              if (isOwnTerminal) {
                // Код `cannot_delete_self`, а не `WireDenied.forbidden` —
                // обоснование в докстринге `WireDenied` выше.
                return WireDenied(
                  'cannot_delete_self',
                  'нельзя удалить терминал, под которым сидит сама вкладка',
                  session: session,
                );
              }
          }
        }
        return WireAllowed(session);
    }
  }
}
