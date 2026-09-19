/// Первые настоящие вызывающие журнала событий безопасности — задача 21
/// закрытия долга безопасности («замок кассы», фаза 8).
///
/// Задача 20 (`SecurityEventDao`, `lib/data/database/daos/security_event_dao.dart`)
/// построила таблицу и цепочку отпечатков, но до этого файла
/// `SecurityEventDao.record` не звала ни одна строка рабочего кода — сама
/// задача 20 говорит об этом прямым текстом в своём докстринге. Этот файл —
/// не вторая копия той работы, а обёртка, которую действительно зовут точки
/// вставки: `session_registry.dart`, `local_auth_repository.dart`,
/// `till_wire.dart` (через [buildWireDeniedJournalHandler]),
/// `terminal_repository_local.dart`, `user_management_screen.dart`,
/// `auth_settings_controller.dart` (волна закрытия долга безопасности,
/// 2026-08-22).
///
/// # Словарь родов события и исходов (задача 21)
///
/// `SecurityEvents.eventType`/`outcome` — свободный текст в схеме (задача 20
/// сознательно не завела для них перечисление: докстринг таблицы
/// (`security_tables.dart`) прямо говорит, что исчерпывающий список виден
/// только из настоящих точек вставки, а у задачи 20 их не было ни одной).
/// [SecurityEventType] — этот список, построенный по точкам вставки этой
/// задачи, а не выдуманный заранее.
///
/// `outcome` для успеха — [SecurityOutcome.success]. Для отказа этот класс
/// **не заводит вторую, параллельную таблицу кодов** — он переносит уже
/// канонический код, который решение и так назвало в другом месте:
/// `WireDenied.code` (`lib/domain/wire/wire_guard.dart`) для
/// [SecurityEventType.wireDenied], `AuthRejectionReason.name`
/// (`lib/domain/auth/auth_outcome.dart`) для [SecurityEventType.authLogin].
/// Второй словарь для тех же кодов означал бы, что коды могут разойтись:
/// один файл переименует причину, другой об этом не узнает. Ровно поэтому
/// здесь нет отдельных констант вида `wrongPin`/`forbidden` — вызывающий
/// передаёт уже существующую строку.
///
/// # Никогда не роняет операцию
///
/// [record] ловит всё, что бросит [SecurityEventDao.record] (диск занят,
/// база заперта, что угодно), и превращает это в `Talker.warning`, а не в
/// исключение наружу. Операция, ради которой позвали запись (вход, отзыв
/// сеанса, отказ сторожа), не имеет права упасть из-за того, что улика не
/// улеглась (осторожность, названная в брифе задачи 21). Молчать при этом
/// тоже нельзя — оператор, потерявший запись журнала без единого
/// предупреждения, не узнает об этом никогда; сообщение уходит тем же
/// `Talker`, что и остальной путь, через `safeErrorText` — не текст
/// исключения, тем же приёмом, что и везде в этой работе (секрет, попавший в
/// текст исключения записи, не должен уехать в лог вторым путём в обход
/// маскирования самой таблицы).
library;

import 'dart:async';

import 'package:talker/talker.dart';
import 'package:telepos/backend/certificate_throttle.dart';
import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/domain/payment/gift_certificate.dart'
    show certificateRateLimitedCode;
import 'package:telepos/data/database/daos/security_event_dao.dart';
import 'package:telepos/domain/wire/wire_guard.dart';
import 'package:uuid/uuid.dart';

/// Род события — весь список, который сегодня реально пишет хоть одна
/// строка рабочего кода. Новая точка вставки добавляет сюда новую константу,
/// а не набирает строку заново на месте.
abstract final class SecurityEventType {
  /// Попытка входа — `LocalAuthRepository.login`. Исход — либо
  /// [SecurityOutcome.success], либо `AuthRejectionReason.name` того отказа,
  /// которым закончилась попытка.
  static const authLogin = 'auth.login';

  /// Сторож провода отказал в операции — `WireGuard.check` вернул
  /// `WireDenied` (`till_wire.dart`, `_onRequest`). Исход — `WireDenied.code`
  /// (`unauthorized`/`forbidden`/`already_configured`/`unknown_op`/
  /// `cannot_delete_self`).
  static const wireDenied = 'wire.denied';

  /// Сеанс выписан — `SessionRegistry.mint`.
  static const sessionIssued = 'session.issued';

  /// Сеанс погашен — `SessionRegistry.revoke` (и, значит,
  /// `revokeSession`/`revokeForUser`, которые гасят по одному через него).
  static const sessionRevoked = 'session.revoked';

  /// Права кассира изменены — `UserManagementScreen._save`.
  static const permissionsChanged = 'user.permissionsChanged';

  /// PIN кассира сменён — `UserManagementScreen._save`.
  static const pinChanged = 'user.pinChanged';

  /// Кассир удалён — `UserManagementScreen._confirmDelete`.
  static const userDeleted = 'user.deleted';

  /// Новый кассир заведён — `UserManagementScreen._save`, ветка
  /// `isCreating`. Пункт 1 БЛОКЕРА закрытия долга безопасности (2026-08-22):
  /// до этой правки заведение кассира с PIN и полным набором прав было
  /// единственным действием формы, не оставлявшим ни одного следа в
  /// журнале — самый дешёвый бэкдор в продукте. `outcome` — название
  /// заведённой роли (`UserRole.name`), тот же приём, что и у
  /// [roleChanged].
  static const userCreated = 'user.created';

  /// Роль кассира изменена — `UserManagementScreen._save`. Пункт 1 БЛОКЕРА
  /// (2026-08-22): смена роли как таковая раньше не журналировалась вовсе —
  /// писалась только перезапись прав ([permissionsChanged]), которая роли
  /// не называет, и та вдобавок была не заведена при повышении до владельца
  /// (`if (_selectedRole != 0)`). Этот род событий пишется всегда, когда
  /// роль реально изменилась, независимо от того, пишутся ли права —
  /// кассир→владелец обязан оставить след ровно так же, как и
  /// кассир→администратор. `outcome` — `"$былаРоль->$сталаРоль"`
  /// (`UserRole.name` с обеих сторон): единственное поле схемы, способное
  /// нести переход, не выдуманное имя колонки поверх свободного текста.
  static const roleChanged = 'user.roleChanged';

  /// Терминал удалён безвозвратно — `LocalTerminalRepository.delete`,
  /// единственная реализация, зовётся и с провода (`terminals.delete`), и
  /// напрямую с десктопных настроек.
  static const terminalDeleted = 'terminal.deleted';

  /// Политика входа этой кассы изменена — `AuthSettingsController
  /// .setWalkUpEnabled`/`.setSessionIdleMinutes`. Пункт 7 брифа закрытия
  /// долга безопасности (2026-08-22): раздел 15 архитектуры называет
  /// «изменение настроек» точкой, обязанной оставлять след, — до этой
  /// правки `/auth-settings` (вход без называния себя, срок сеанса) не
  /// писал в журнал вовсе. `outcome` — что именно изменилось и на что
  /// (`"walkUp=true"`/`"sessionIdleMinutes=45"`): здесь нет отдельного
  /// субъекта, только сама настройка, так что `outcome` несёт то, что в
  /// других родах события несла бы одноимённая колонка, которой здесь для
  /// одной настройки заводить не за что.
  static const authSettingsChanged = 'auth.settingsChanged';

  /// Проверка целостности журнала на подъёме кассы —
  /// [checkSecurityJournalIntegrityAtBoot], пункт 6 брифа закрытия долга
  /// безопасности (2026-08-22). `outcome` — `'intact'`, либо список найденных
  /// проблем через запятую (`broken_link:<id>`, `tail_truncated`).
  static const journalIntegrityChecked = 'security.journalIntegrityChecked';

  /// Замок перебора сертификатов отказал — `CertificateThrottle.admit`,
  /// пункт 4 A7 (2026-09-15). До этой правки срабатывание не оставляло следа
  /// (живая приёмка 2026-09-13), хотя это ровно то событие, ради которого
  /// журнал ведётся: кто-то перебирает номера или ПИНы.
  ///
  /// Пишется **одна запись на запирание**, а не на каждый стук в запертое
  /// ([certificateLockJournalHandler]). `outcome` —
  /// `certificate_rate_limited(<оси>)`, где оси — какие счёты заперты:
  /// `number`, `cashier`, `terminal`. Номер сертификата в запись не едет.
  static const certificateRateLimited = 'certificate.rateLimited';
}

/// Исходы, общие для нескольких родов события. Исходы отказа — не здесь, см.
/// докстринг класса про то, почему они переиспользуют уже канонический код,
/// а не заводятся заново.
abstract final class SecurityOutcome {
  static const success = 'success';
}

/// Пишет строки в [SecurityEventDao], не роняя вызывающую операцию.
class SecurityJournal {
  SecurityJournal(this._dao, {Talker? logger, String Function()? newCorrelationId})
    : _logger = logger,
      _newCorrelationId = newCorrelationId ?? _randomCorrelationId;

  final SecurityEventDao _dao;
  final Talker? _logger;
  final String Function() _newCorrelationId;

  /// Пишет одну запись. Никогда не бросает — см. докстринг класса.
  ///
  /// [correlationId] по умолчанию — свежий случайный идентификатор на этот
  /// вызов: у точек вставки этой задачи одна запись всегда и есть всё
  /// действие целиком (вход — один вызов, отзыв сеанса — один вызов), так
  /// что заводить его доводом снаружи было бы лишним параметром без
  /// вызывающего, которому он нужен. Довод оставлен на случай, если будущая
  /// точка вставки настоящий раз объединит несколько записей одним
  /// действием.
  Future<void> record({
    required String eventType,
    required String outcome,
    required int terminalId,
    int? userId,
    String? correlationId,
  }) async {
    try {
      await _dao.record(
        occurredAtEpochMs: DateTime.now().millisecondsSinceEpoch,
        userId: userId,
        terminalId: terminalId,
        eventType: eventType,
        outcome: outcome,
        correlationId: correlationId ?? _newCorrelationId(),
      );
    } catch (error, stack) {
      _logger?.warning(
        'журнал безопасности: запись "$eventType/$outcome" не удалась '
        '(${safeErrorText(error)}) — событие потеряно, операция не '
        'остановлена',
        null,
        stack,
      );
    }
  }
}

String _randomCorrelationId() => const Uuid().v4();

/// Собирает обработчик `TillWire.onDenied` — задача 21.
///
/// Живёт здесь, рядом с [SecurityJournal], а не заводится на месте в
/// `main.dart`, тем же приёмом, что `wireGuardForTill`
/// (`lib/backend/till_wire_guard.dart`): так у разрешения терминала есть
/// тест без поднятия всей кассы.
///
/// # Откуда `terminalId`
///
/// `till_wire.dart` намеренно не знает базы (докстринг файла) — к моменту
/// отказа сторож уже решил всё, что мог решить по сеансу, и остальное
/// приходится собирать по крохам:
///
/// 1. [WireDenied.session] — сеанс уже найден (коды `forbidden`,
///    `cannot_delete_self`): его `terminalId`/`userId` точны, потому что
///    сеанс проверен по-настоящему.
/// 2. [resolveTerminal] — терминал, который эта же QUIC-сессия сама завела
///    через `terminals.register`/`terminals.selfEnsure`
///    (`TillOperations.terminalForSessionKey`, тот же источник, которым
///    уже пользуется `auth.login`). Сессию не подделать, но конкретный
///    вопрос мог быть не про тот терминал, который она заводила.
/// 3. `body['terminalId']`, если это целое, — то, чем сам вызывающий назвал
///    терминал в теле запроса. Ничем не проверено (для `unauthorized`
///    сторож ничего не сверял), но это улика о заявленном терминале, а не
///    пустота.
/// 4. `0` — терминал не назвался никак. Сентинел, не настоящий id: строки
///    `terminals` заводятся автоинкрементом от 1 (`TerminalDao`), нулевой
///    строки не существует ни на одной кассе.
///
/// # БЛОКЕР 3 закрытия долга безопасности (2026-08-22): неаутентифицированный
/// не может расти боевую базу без предела
///
/// ## Что нашёл разбор
///
/// Каждый отказ сторожа писал строку транзакцией в тот же файл SQLite,
/// которым касса принимает деньги, — без ограничителя, склейки и потолка.
/// Соединение по QUIC предшествует входу (докстринг `TillWire`, «сторож
/// решает по сеансу», и `wire_guard.dart`, `SetupOnlyAccess`/`OpenAccess`):
/// значит любой, кто может открыть WebTransport-сессию, шлёт
/// `{"op":"nope"}` (или любой другой отказ) сколько угодно раз на одной
/// открытой сессии — каждый кадр стоит sha256 (`SecurityEventDao
/// ._fingerprintOfRow`) и транзакции записи, и растит боевую базу
/// **навсегда**: `LoginThrottle` покрывает только `auth.login`, здесь
/// ограничителя не было вовсе.
///
/// ## Решение — оба хода брифа, не один
///
/// 1. **`unknown_op` не журналируется вовсе.** Это расхождение протокола
///    (имя операции, которого нет в словаре доступа), а не событие
///    безопасности — тот же довод, каким `wire_guard.dart` уже объясняет,
///    почему `unknownOp` в рабочей сборке недостижим штатным путём: словарь
///    доступа строится из того же каталога, что и карты обработчиков.
///    Достижим он ровно тем нападающим, которого описывает этот раздел —
///    `{"op":"любая ерунда"}` бьёт по нему первым, раньше любой проверки
///    сеанса (`WireGuard.check`, ветка `_access[op] == null`), и это
///    единственный код, который неаутентифицированный может вызвать без
///    единого верного довода вовсе. Не журналировать его — не «прятать
///    улику»: расхождение каталога не говорит ничего ни о ком, кто спросил,
///    только о том, что было спрошено, а спросить можно что угодно.
/// 2. **Повторные отказы одной и той же QUIC-сессии в окне склеиваются.**
///    Ключ — `sessionKey` (составной, уже [_sessionKey], тот же, каким
///    `till_wire.dart` называет сессию для обработчиков): первый отказ
///    сессии в окне пишется как обычно, следующие отказы **этой же
///    сессии** в пределах [coalesceWindow] — не пишутся вовсе. Приём тот
///    же, что уже стоит в `LoginThrottle._forget()`
///    (`lib/backend/login_throttle.dart`) — ленивая карта «когда виделись
///    последний раз», без будильника и без второго процесса, убирается на
///    каждом обращении.
///
///    **Не потеряно**: `forbidden`/`unauthorized` — настоящее событие
///    безопасности, и склейка не прячет серию целиком — она делает то же,
///    что и throttle: не даёт **одной** сессии написать неограниченно
///    много строк за секунды, но не отключает запись для кода вовсе (в
///    отличие от `unknown_op` выше). Серия, растянутая дольше
///    [coalesceWindow] (например, кассир, у которого несколько раз подряд с
///    паузами не хватает права), по-прежнему пишет по строке на каждый
///    выход за окно — журнал остаётся уликой «эта сессия систематически
///    получает отказ», а не превращается в ноль строк.
///
/// ## Граница, названная явно
///
/// Ключ — `sessionKey`, не `userId` и не IP: нападающий, готовый платить
/// цену новой QUIC-сессии на каждый залп (полный TLS-хендшейк, не одна
/// строка кадра), получает по одной новой строке склейки на каждую новую
/// сессию — тем же порядком, каким `LoginThrottle` не останавливает
/// перебор целиком, только делает его дороже (докстринг `LoginThrottle`,
/// «Правка 1 БЛОКЕРА»). Полного потолка на число сессий эта правка не
/// заводит — тот же потолок регистрации терминалов (200,
/// `TillOperations._pruneUnusedTerminals`), что уже ограничивает
/// параллельный `auth.login`, ограничивает и это, транзитивно, не
/// собственной константой этого файла.
void Function(
  String op,
  WireDenied denied,
  int sessionKey,
  Map<String, Object?> body,
)
buildWireDeniedJournalHandler({
  required SecurityJournal journal,
  required int? Function(int sessionKey) resolveTerminal,
  /// Окно склейки повторных отказов одной сессии — см. докстринг функции,
  /// «БЛОКЕР 3». 5 секунд — на порядок больше, чем нужно, чтобы кассир,
  /// дважды подряд щёлкнувший кнопку без прав, не породил вторую строку по
  /// ошибке ввода, и на много порядков меньше, чем нужно, чтобы спрятать
  /// растянутую во времени серию (см. границу).
  Duration coalesceWindow = const Duration(seconds: 5),
  DateTime Function()? clock,
}) {
  final effectiveClock = clock ?? DateTime.now;

  /// Когда эта сессия последний раз написала строку журнала. Тот же приём,
  /// что `LoginThrottle._failures`/`_touchedAt`: один map, ленивая уборка
  /// на каждом обращении, без будильника.
  final lastWrittenAt = <int, DateTime>{};

  void forgetStale(DateTime now) {
    // Хранить записи дольше одного окна нет смысла: запись старше
    // [coalesceWindow] уже не влияет ни на одно будущее решение — новый
    // отказ той же сессии в любом случае пройдёт склейку заново. Уборка не
    // про безопасность (как и у `LoginThrottle`), только про то, чтобы
    // карта не росла на каждую новую сессию без предела на кассе, работающей
    // месяцами без перезапуска.
    lastWrittenAt.removeWhere(
      (_, writtenAt) => now.difference(writtenAt) >= coalesceWindow,
    );
  }

  return (op, denied, sessionKey, body) {
    if (denied.code == WireDenied.unknownOp) {
      // БЛОКЕР 3, ход 1: расхождение протокола — не событие безопасности.
      // Не входит даже в счёт склейки ниже: ключ никогда не заводится по
      // этому коду.
      return;
    }

    final now = effectiveClock();
    forgetStale(now);

    final lastWritten = lastWrittenAt[sessionKey];
    if (lastWritten != null && now.difference(lastWritten) < coalesceWindow) {
      // БЛОКЕР 3, ход 2: та же сессия уже написала строку в пределах окна —
      // не растим базу на каждый повторный отказ подряд.
      return;
    }
    lastWrittenAt[sessionKey] = now;

    final rawTerminalId = body['terminalId'];
    final terminalId =
        denied.session?.terminalId ??
        resolveTerminal(sessionKey) ??
        (rawTerminalId is int ? rawTerminalId : null) ??
        0;
    unawaited(
      journal.record(
        eventType: SecurityEventType.wireDenied,
        outcome: denied.code,
        terminalId: terminalId,
        userId: denied.session?.userId,
      ),
    );
  };
}

/// Обработчик `CertificateThrottle.onLocked` — пункт 4 A7 (2026-09-15).
///
/// Живёт здесь, рядом с [buildWireDeniedJournalHandler], по тому же доводу:
/// у записи есть проба без поднятия кассы. Склейки здесь нет — её делает
/// сам замок (одна запись на запирание ключа, докстринг `onLocked`).
///
/// `terminalId` без рабочего места — `0`, тот же сентинел, что у
/// `wire.denied`.
void Function(CertificateLock lock) certificateLockJournalHandler(
  SecurityJournal journal,
) => (lock) => unawaited(
  journal.record(
    eventType: SecurityEventType.certificateRateLimited,
    outcome: '$certificateRateLimitedCode(${(lock.axes.toList()..sort()).join(',')})',
    terminalId: lock.terminalId ?? 0,
    userId: lock.userId,
  ),
);

/// Проверка целостности журнала на подъёме кассы — пункт 6 брифа закрытия
/// долга безопасности (2026-08-22).
///
/// # Читателя не было вовсе
///
/// `findAll`, `firstBrokenLinkId`, `fingerprintOfSecret` (последняя снята,
/// см. докстринг `SecurityEventDao`) — ноль вызывающих в `lib/` до этой
/// правки. Проверка целостности цепочки (И67) в продукте не выполнялась
/// никогда: таблица росла, `firstBrokenLinkId` существовал и был доказанно
/// правильным (`security_journal_test.dart`), но никто и никогда его не
/// звал — то же самое несоответствие «код есть, вызывающего нет», ради
/// искоренения которого затевалась вся волна (докстринг задачи 21).
///
/// # Минимум, названный брифом
///
/// «Минимум — проверка целостности при подъёме кассы, с записью
/// результата». Ни экрана, ни операции провода эта правка не заводит:
/// операция провода без вызывающего — тот же урок, что уже назван про
/// `revokeAll()` (докстринг `SecurityEventType`) — заводить её здесь
/// значило бы повторить ровно ту же ошибку внутри правки, которая её
/// исправляет. Экран для чтения журнала — тоже не заведён: ни один из
/// названных в брифе достижимых путей его не требует, и добавлять UI без
/// названной надобности значило бы золотить то, чего не просили.
///
/// # Что проверяется и что пишется
///
/// [SecurityEventDao.firstBrokenLinkId] — разрыв цепочки (вырезание из
/// середины/начала) и [SecurityEventDao.isTailTruncated] — усечение хвоста
/// (БЛОКЕР 2, оба закрывают разные половины И67). Результат — одна строка
/// `SecurityEventType.journalIntegrityChecked`, `outcome` — `'intact'` либо
/// список найденных проблем через запятую. Пишется даже если журнал
/// разорван: проверка добавляет запись ПОСЛЕ разрыва (та же цепочка, тот же
/// DAO — `record` не знает и не обязан знать, что где-то раньше есть дыра),
/// и это не самообман — не «делаем вид, что не было» — а честная запись
/// «на этот момент проверка прошла и нашла проблему»; следующая проверка на
/// следующем подъёме увидит ту же самую дыру снова, `firstBrokenLinkId`
/// каждый раз идёт от genesis заново.
///
/// Отказ самой проверки (база заперта, диск занят) не роняет подъём кассы —
/// `logger?.error` тем же приёмом, что и остальной путь; касса, которая не
/// поднимается из-за отказавшей проверки журнала, была бы хуже кассы,
/// поднявшейся без гарантии его целостности.
Future<void> checkSecurityJournalIntegrityAtBoot({
  required SecurityEventDao dao,
  required SecurityJournal journal,
  required int terminalId,
  Talker? logger,
}) async {
  try {
    final brokenAt = await dao.firstBrokenLinkId();
    final tailTruncated = await dao.isTailTruncated();
    final problems = <String>[
      if (brokenAt != null) 'broken_link:$brokenAt',
      if (tailTruncated) 'tail_truncated',
    ];
    final outcome = problems.isEmpty ? 'intact' : problems.join(',');

    if (problems.isEmpty) {
      logger?.info('журнал событий безопасности: целостность подтверждена');
    } else {
      logger?.error(
        'журнал событий безопасности: целостность НЕ подтверждена '
        '($outcome) — И67, docs/system-architecture.md, раздел 15',
      );
    }

    await journal.record(
      eventType: SecurityEventType.journalIntegrityChecked,
      outcome: outcome,
      terminalId: terminalId,
    );
  } catch (error, stack) {
    logger?.error(
      'журнал событий безопасности: проверка целостности на подъёме не '
      'удалась (${safeErrorText(error)}) — касса продолжает подниматься',
      null,
      stack,
    );
  }
}
