/// Живые сеансы кассиров. В памяти процесса кассы и нигде больше.
///
/// # Почему не в базе
///
/// База уезжает в резервную копию и приезжает на другую машину. Живой сеанс,
/// приехавший вместе с ней, — это чужой вход, воскресший на чужом железе.
/// Перезапуск кассы гасит все сеансы, и это **свойство**: то же решение и по
/// той же причине принято для `PairingInvites` (`lib/backend/pairing_invites.dart`).
///
/// # Почему токен, а не «сеанс = QUIC-сессия»
///
/// Терминал теряет связь посреди чека и перезагружает страницу по F5. Сеанс,
/// привязанный к соединению, в обоих случаях означал бы выход кассира с
/// недобитым чеком. Токен переживает и то, и другое, а умирает с вкладкой:
/// браузер держит его в `sessionStorage`.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:telepos/backend/security_journal.dart';
import 'package:telepos/domain/auth/auth_session.dart';
import 'package:telepos/domain/auth/live_session.dart';
import 'package:telepos/domain/auth/session_admin.dart';
import 'package:telepos/domain/auth/session_lookup.dart';
import 'package:telepos/domain/auth/terminal_session_check.dart';
import 'package:telepos/domain/shift/shift_status.dart';

class SessionRegistry
    implements SessionLookup, TerminalSessionCheck, SessionAdmin {
  SessionRegistry({
    this.idleTimeout = const Duration(minutes: 30),
    Random? random,
    DateTime Function()? clock,
    SecurityJournal? journal,
  }) : _random = random ?? Random.secure(),
       _clock = clock ?? DateTime.now,
       _journal = journal;

  /// Журнал событий безопасности — задача 21 закрытия долга безопасности.
  /// `null` тем же приёмом, что и весь остальной опциональный довод в этой
  /// работе (`TillOperations._sessions`, `_deviceDiscovery`, ...): тесты,
  /// которым запись не нужна, не обязаны знать о новом доводе, и настоящая
  /// касса собирает его в `service_locator.dart`.
  final SecurityJournal? _journal;

  /// Сколько сеанс живёт без обращений. Настройка точки, а не число в коде:
  /// значение приезжает из `ThisPos.sessionIdleMinutes` (задача 5).
  ///
  /// Не `final` (задача 18, закрытие И31): экран `AuthSettingsScreen` пишет
  /// новое значение сюда сразу после успешной записи в базу — тем же
  /// синглтоном, что и весь процесс кассы (см. докстринг класса и комментарий
  /// у регистрации в `service_locator.dart`). Действует немедленно на все
  /// операции, которые ссылаются на это поле, — [mint] для новых сеансов и
  /// [lookup] для продления уже открытых; ни те, ни другие поле не
  /// кешируют. Перечитывать его из базы при каждом вызове было бы отдельным,
  /// более тяжёлым решением (лишний запрос на каждый вход/каждую операцию) —
  /// мутируемое поле даёт тот же результат («новое значение действует сразу»)
  /// без него.
  Duration idleTimeout;

  final Random _random;
  final DateTime Function() _clock;

  final Map<String, AuthSession> _live = <String, AuthSession>{};

  /// Когда подписчикам этого токена в последний раз реально сообщили о
  /// продлении срока — не о каждом продлении, только о тех, что дошли до
  /// [_notify] (правка 3 разбора, 2026-08-21, см. [lookup]). Ключ убирается
  /// вместе с самим сеансом, в [_forget] и [revoke] (а значит, и в
  /// [revokeSession]/[revokeForUser], которые гасят через него же).
  final Map<String, DateTime> _lastNotifiedExpiry = <String, DateTime>{};

  /// Порог «заметного сдвига срока» для [lookup]: продление меньше этого
  /// уведомления не стоит — половина [idleTimeout] держит вкладку не
  /// дальше половины окна бездействия от настоящего `expiresAt`, а трафика
  /// просит не чаще раза в эти же полокна на сеанс. См. докстринг [lookup].
  Duration get _notifyThreshold => idleTimeout ~/ 2;

  /// Один широковещательный источник на токен, к которому подключаются все
  /// подписчики `watch()` этого токена. Живёт, пока у него есть хоть один
  /// слушатель — закрывается и убирается из карты в `onCancel` последней
  /// подписки, см. `watch()`.
  final Map<String, StreamController<AuthSession?>> _watchers =
      <String, StreamController<AuthSession?>>{};

  /// Сигнал «множество живых сеансов могло измениться» — задача 19 закрытия
  /// долга безопасности, экран списка сеансов ([watchLiveSessions]).
  /// Содержимое не несёт — подписчик читает его через [live] сам, тем же
  /// приёмом, что уже устроен для [outstanding]/[watcherCount]: значение
  /// всегда свежее на момент чтения, а не кэшируется в событии. Один
  /// контроллер на весь реестр, не по токену, как [_watchers]: список — это
  /// не сеанс, а множество сеансов разом, и адресовать сигнал некому
  /// конкретно.
  final StreamController<void> _liveChanges =
      StreamController<void>.broadcast();

  /// Сколько сеансов сейчас живо. Наблюдаемая величина: сеансы, которые
  /// копятся и не гаснут, иначе ничем не видны.
  int get outstanding {
    _forget();
    return _live.length;
  }

  /// Сколько токенов сейчас имеют хоть одного слушателя `watch()`.
  /// Наблюдаемая величина ради теста: заброшенная подписка, которую забыли
  /// убрать из `_watchers`, иначе ничем не видна на кассе, что работает
  /// месяцами без перезапуска.
  int get watcherCount => _watchers.length;

  /// Выписать сеанс.
  ///
  /// # За одним рабочим местом одновременно один человек
  ///
  /// Выдача гасит живые сеансы **того же терминала, принадлежащие другому
  /// человеку** — круг правки 2 задачи 19 плана «Продажа с браузерного
  /// терминала». Это физика кассы, а не мера предосторожности: за одним
  /// рабочим местом в одну минуту стоит один кассир, и два одновременно
  /// действующих человека на нём — состояние, которого в зале не бывает.
  ///
  /// **Измеренная проба, которая проходила до этой правки.** Личность
  /// рабочего места (`terminalId` и его секрет) живёт в общем для всех
  /// вкладок хранилище, а токен — в своём у каждой; значит две вкладки
  /// одного места делят номер штатным путём (`terminals.resume`). Уборка
  /// черновика возврата по входу (`RefundService.abandon`, тот же круг)
  /// событие **однократное**, и обходилась она очерёдностью:
  ///
  /// ```
  /// вкладка Б: младший (только op.refund) входит ПЕРВЫМ → уборка вхолостую
  /// вкладка А: старший входит, начинает возврат без чека → черновик на месте
  /// вкладка Б: младший добавляет товар  → успех
  /// вкладка Б: младший завершает        → успех, касса 0 → −500
  /// ```
  ///
  /// То есть роль, которой возврат без чека закрыт правом, отдавала по нему
  /// деньги **собственным действующим токеном**. Гашение при выдаче
  /// закрывает это в корне: сеанс младшего перестаёт существовать в тот
  /// момент, когда за то же место входит старший, и следующая команда
  /// младшего получает `unauthorized` от сторожа.
  ///
  /// **Тот же человек не гасит сам себя** — две вкладки одного кассира на
  /// одном месте законны (F5, второе окно), и различать их незачем.
  ///
  /// # Исключений нет — и одно было и снято
  ///
  /// Круг правки 3 завёл здесь исключение для строки самой кассы (`isSelf`):
  /// вкладка, вошедшая на неё через открытый `terminals.selfEnsure`, гасила
  /// сеанс кассира за экраном кассы. Круг правки 4 измерил цену этого
  /// исключения — оно возвращало на ту же строку двух человек сразу, а с ними
  /// и общий черновик возврата (остаток +10, касса −5000 кадрами провода) — и
  /// **снял его**, вырезав причину: `terminals.selfEnsure` больше не
  /// привязывает место к QUIC-сессии, войти по проводу на строку кассы
  /// нельзя. Правило действует без изъятий.
  ///
  /// **Обратная сторона, названная прямо:** вход второй вкладки под другим
  /// человеком сносит работу первой посреди дела — не только возврат, а
  /// любой её сеанс. Это и есть смысл правила «за местом один человек»;
  /// цена его — кассир, чью вкладку выбило чужим входом, увидит экран
  /// входа, а не свою работу. Прежде поведение было противоположным и
  /// стоило дороже: два человека работали за одним местом одновременно, и
  /// младший тратил права старшего.
  ///
  /// Гашение идёт через [revoke], как и у [revokeSession]/[revokeForUser],
  /// — значит подписчики токена узнают о нём кадром, а не молчанием, и
  /// запись в журнал безопасности делает та же единственная точка.
  ///
  /// **Предел, записанный, а не починенный: причина гашения человеку не
  /// видна.** Вкладка узнаёт о конце сеанса одним и тем же `null` в
  /// [watch], и `login_controller.dart` показывает родовой текст — «за ваше
  /// место сел другой» человек не отличит от «истёк по бездействию» и от
  /// «отозвал администратор». Отличать их надо не текстом, а полем причины в
  /// кадре сеанса, и это правка [AuthSession]/`session_lost.dart`, за
  /// границей задачи 19.
  AuthSession mint({
    required int userId,
    required String name,
    required String role,
    required Set<String> permissions,
    required int operatingMode,
    required String pointMode,
    required bool shiftOpen,
    required int terminalId,
  }) {
    _forget();
    // Гашение — до выдачи, а не после: между ними нет ни одной строки, но
    // порядок здесь читается как утверждение «место освобождено, и только
    // потом занято». Список снимается заранее (`toList`), потому что
    // [revoke] правит `_live` под собой.
    for (final token
        in _live.entries
            .where(
              (e) =>
                  e.value.terminalId == terminalId && e.value.userId != userId,
            )
            .map((e) => e.key)
            .toList()) {
      revoke(token);
    }
    final now = _clock();
    final session = AuthSession(
      token: _mintToken(),
      userId: userId,
      name: name,
      role: role,
      permissions: permissions,
      operatingMode: operatingMode,
      pointMode: pointMode,
      // Касса смену измерила — третьего состояния здесь не бывает.
      shift: shiftOpen ? ShiftStatus.open : ShiftStatus.closed,
      issuedAt: now,
      expiresAt: now.add(idleTimeout),
      terminalId: terminalId,
    );
    _live[session.token] = session;
    _liveChanges.add(null);
    // Задача 21 закрытия долга безопасности: до неё выдача сеанса не
    // оставляла ни одного следа в журнале событий безопасности — вход по
    // проводу логировал `LocalAuthRepository.login`, но сама выдача (то,
    // что реально даёт кассиру доступ) не была отдельной записью нигде.
    // `unawaited`: запись не имеет права задержать выдачу сеанса, и её
    // отказ здесь не роняет `mint` (см. докстринг `SecurityJournal.record`).
    unawaited(
      _journal?.record(
        eventType: SecurityEventType.sessionIssued,
        outcome: SecurityOutcome.success,
        terminalId: terminalId,
        userId: userId,
      ),
    );
    return session;
  }

  /// Найти сеанс и **продлить** его.
  ///
  /// Продление здесь, а не отдельным методом: сеанс спрашивают ради действия,
  /// а действие и есть активность. Отдельный `touch()` рано или поздно забыли
  /// бы позвать, и кассир вылетал бы посреди работы.
  ///
  /// # Правка 3 разбора (2026-08-21): продление теперь иногда доходит до
  /// подписчиков
  ///
  /// До этой правки `lookup` продлевал `expiresAt` молча — `_notify`
  /// вызывался только со значением `null` (гашение), никогда с продлённым
  /// сеансом. Вкладка узнаёт срок только через `watch()`, а `watch()`
  /// отдаёт снимок лишь при подписке (F5) — значит вкладка, простоявшая
  /// открытой дольше [idleTimeout] без перезагрузки, помнила бы срок с
  /// момента своей последней подписки и посчитала бы себя истёкшей, даже
  /// если каждую минуту этого времени касса реально продлевала сеанс по
  /// операциям с провода. Зеркало задачи про отзыв сеанса: там врали, что
  /// истёк сеанс, отозванный владельцем; здесь врали бы, что истёк сеанс,
  /// который на самом деле жив и продлевается.
  ///
  /// Честный выбор — возить продлённый срок до вкладки, а не переставать
  /// называть его уликой: цена по трафику мала и посчитана, не угадана —
  /// см. [_notifyThreshold]. Не на каждом обращении (`lookup` может звать
  /// провод на каждую операцию кассира, десятки раз в минуту в кассовой
  /// смене) — только когда срок сдвинулся заметно, не меньше чем на
  /// половину [idleTimeout] от последнего разосланного значения. При
  /// 30-минутном [idleTimeout] по умолчанию это не больше одного
  /// уведомления в 15 минут на живой сеанс — на восьмичасовую смену это
  /// ~32 события, по одному крошечному JSON на канал провода, а не поток.
  /// Настоящее гашение (`revoke`/[_forget]) уведомляет
  /// немедленно, как и раньше — этот порог касается только продления.
  AuthSession? lookup(String token) {
    _forget();
    final session = _live[token];
    if (session == null) return null;

    final extended = session.copyWith(expiresAt: _clock().add(idleTimeout));
    _live[token] = extended;

    final lastNotified = _lastNotifiedExpiry[token];
    if (lastNotified == null ||
        extended.expiresAt.difference(lastNotified) >= _notifyThreshold) {
      _lastNotifiedExpiry[token] = extended.expiresAt;
      _notify(token, extended);
    }

    return extended;
  }

  @override
  AuthSession? sessionFor(String token) => lookup(token);

  /// [TerminalSessionCheck] — довесок фазы 3/4 закрытия долга, уборка
  /// неиспользуемых строк `terminals` (`TillOperations._pruneUnusedTerminals`).
  ///
  /// Не продлевает ничей срок и не считается обращением к конкретному
  /// сеансу — только смотрит, вызывает [_forget] первой строкой (тем же
  /// приёмом, что [outstanding]/[lookup]/[watch]) ради того же самого:
  /// просроченная, но ещё не убранная запись не должна выдаваться за живую и
  /// тем самым удерживать терминал от уборки, которая иначе была бы
  /// безопасна.
  @override
  bool hasLiveSession(int terminalId) {
    _forget();
    return _live.values.any((session) => session.terminalId == terminalId);
  }

  /// Погасить сеанс. `true` ровно один раз на каждый живой.
  ///
  /// # Колонка «кто» хранит «над кем» — то же самое, что и в
  /// `user_management_screen.dart` (пункт 4 брифа закрытия долга
  /// безопасности, 2026-08-22)
  ///
  /// `userId` в записи [SecurityEventType.sessionRevoked] ниже — владелец
  /// гашённого сеанса (субъект), не тот, кто позвал отзыв (действующий).
  /// Для самостоятельного выхода (`AuthRepository.logout`) это одно и то же
  /// лицо — тем же смыслом, каким это поле уже несёт `auth.login`/
  /// `session.issued`. Но `revoke` вызывается и через [revokeSession]
  /// (`SessionsScreen`, десктопный админ гасит чужой сеанс) — там субъект и
  /// действующий уже разные, ровно как у `pinChanged`/`permissionsChanged`.
  /// Не разведено по той же причине, названной там: колонки для
  /// действующего в схеме нет (потребовала бы регенерации
  /// `app_database.g.dart` целиком), а место, откуда его было бы дёшево
  /// взять (`SessionsController`, `ref.read(appStateProvider).userId`), не
  /// протянуто через [revokeSession] — этот метод общий и с проводом
  /// (`TillOps.authSessionRevoke`, `till_operations.dart`), где действующего
  /// взять НЕЧЕМ дёшево (докстринг `WireHandler`, `till_wire.dart`: обработчик
  /// получает `sessionId`, не разрешённый `AuthSession`). Граница названа
  /// явно, не спрятана.
  bool revoke(String token) {
    final removedSession = _live.remove(token);
    _lastNotifiedExpiry.remove(token);
    _notify(token, null);
    if (removedSession != null) {
      _liveChanges.add(null);
      // Задача 21 закрытия долга безопасности: единственная точка, через
      // которую проходит любой отзыв — [revokeSession] и [revokeForUser]
      // гасят каждый свой токен через этот же метод (см. их докстринги),
      // так что им не нужна отдельная запись — эта уже покрывает обоих.
      // Только для настоящего гашения (`removedSession != null`): токен,
      // которого уже не было, не породил события — отзывать нечего.
      unawaited(
        _journal?.record(
          eventType: SecurityEventType.sessionRevoked,
          outcome: SecurityOutcome.success,
          terminalId: removedSession.terminalId,
          userId: removedSession.userId,
        ),
      );
    }
    return removedSession != null;
  }

  /// Погасить все сеансы одного пользователя — не всей кассы.
  ///
  /// Заведён после того, как задача 19 закрытия долга безопасности назвала
  /// `revokeAll()` слишком широким для смены PIN и деактивации: у одной
  /// кассы одновременно может работать несколько кассиров, и смена PIN
  /// одного не делает чужие сеансы недействительными — гасить их было
  /// побочным ущербом первой версии `user_management_screen.dart`
  /// (`_revokeAllLiveSessions`), а не решением. `revokeAll()` сам по себе
  /// снят задачей 21 закрытия долга безопасности: с этого сужения он не
  /// звался ни одной строкой рабочего кода — см. `test/backend/session_registry_test.dart`,
  /// история удалённых тестов там же.
  ///
  /// Тот же приём, что у [revokeSession] рядом: фильтр по полю сеанса
  /// (там — `terminalId`, здесь — [userId]), затем отзыв по одному через
  /// [revoke] — уведомление подписчиков токена и широковещательный сигнал
  /// [watchLiveSessions] уже устроены там и переиспользуются, а не
  /// дублируются здесь заново.
  void revokeForUser(int userId) {
    final tokens = [
      for (final entry in _live.entries)
        if (entry.value.userId == userId) entry.key,
    ];
    for (final token in tokens) {
      revoke(token);
    }
  }

  /// Живые сеансы этой кассы — без токена, см. докстринг [LiveSession].
  /// Задача 19 закрытия долга безопасности: экран списка сеансов читает не
  /// хозяин сеанса, а тот, кто решает его отозвать.
  List<LiveSession> get live {
    _forget();
    return [
      for (final session in _live.values)
        (
          terminalId: session.terminalId,
          userId: session.userId,
          name: session.name,
          role: session.role,
          issuedAt: session.issuedAt,
          expiresAt: session.expiresAt,
        ),
    ];
  }

  /// [SessionAdmin.watchLiveSessions] — список живых сеансов, обновляемый
  /// по событию, не по опросу.
  ///
  /// Тот же приём, что [watch] выше, и по той же причине (см. докстринг
  /// [watch], «Почему не `async*`»): подписка на источник изменений —
  /// синхронно, в `onListen`, до первого снимка. `_liveChanges` —
  /// широковещательный контроллер без активного слушателя между вызовами;
  /// не подписавшись первым делом, эта функция рисковала бы тем же самым
  /// разрывом — событие, случившееся между «отдать снимок» и «подписаться
  /// на поток изменений», ушло бы в пустоту молча.
  @override
  Stream<List<LiveSession>> watchLiveSessions() {
    late final StreamController<List<LiveSession>> out;
    StreamSubscription<void>? subscription;
    out = StreamController<List<LiveSession>>(
      onListen: () {
        subscription = _liveChanges.stream.listen((_) => out.add(live));
        out.add(live);
      },
      onCancel: () => subscription?.cancel(),
    );
    return out.stream;
  }

  /// [SessionAdmin.revokeSession] — гасит сеанс по терминалу, не по токену:
  /// список ([live]/[watchLiveSessions]) токена не показывает, значит и
  /// отзыв не может его требовать. Обычно у терминала не больше одного
  /// живого сеанса разом, но гасит все найденные — тот же довод
  /// осторожности, что у [hasLiveSession]: угадывать «который из них
  /// главный» здесь не входит в задачу.
  @override
  Future<bool> revokeSession(int terminalId) async {
    final tokens = [
      for (final entry in _live.entries)
        if (entry.value.terminalId == terminalId) entry.key,
    ];
    var revoked = false;
    for (final token in tokens) {
      revoked = revoke(token) || revoked;
    }
    return revoked;
  }

  /// Следить за одним сеансом. Первое значение — текущее состояние, дальше —
  /// изменения; `null` означает, что сеанс погас.
  ///
  /// # Почему не `async*`
  ///
  /// Генератор `async*` холодный: его тело не выполняется до `.listen()`, и
  /// между «отдать снимок» и «подписаться на поток изменений» у него есть
  /// асинхронный разрыв. Широковещательный `StreamController` без активного
  /// слушателя молча роняет добавленное в этом разрыве событие — если
  /// гашение случится ровно в этом окне, подписчик не узнает о нём никогда,
  /// без ошибки и без следа. Здесь порядок обратный: сначала подписка на
  /// исходный поток (в `onListen`, синхронно с вызовом `.listen()`), потом
  /// снимок. Окна для потери события в этом порядке нет.
  Stream<AuthSession?> watch(String token) {
    // Просроченные сеансы убираются первой строкой — до этой правки только
    // `mint`/`lookup`/`outstanding` звали `_forget()`, а рабочий код зовёт
    // из них только `mint`: подписка (`authSession` в `till_operations.dart`,
    // единственный путь, которым терминал спрашивает про сеанс) отдавала
    // `_live[token]` как есть, включая запись с `expiresAt` в прошлом — та
    // висела в карте, пока на кассе не случится `mint`/`lookup` от кого-то
    // ещё. Тихая касса: F5 через два часа бездействия воскрешал вход без
    // единого нажатия PIN.
    _forget();
    final upstream = _watchers.putIfAbsent(
      token,
      () => StreamController<AuthSession?>.broadcast(),
    );

    late final StreamController<AuthSession?> out;
    StreamSubscription<AuthSession?>? subscription;

    out = StreamController<AuthSession?>(
      onListen: () {
        subscription = upstream.stream.listen(
          out.add,
          onError: out.addError,
          onDone: out.close,
        );
        out.add(_live[token]);
      },
      onCancel: () async {
        await subscription?.cancel();
        // Последний слушатель этого токена ушёл — убрать запись и закрыть
        // источник, иначе `_watchers` растёт без предела: токен минтится
        // заново на каждый вход, и старые источники копились бы вечно.
        //
        // Удаление из карты обязано случиться ДО close(), а не после: между
        // концом синхронного кода здесь и завершением `await
        // upstream.close()` терминал успевает пережить F5 с тем же токеном
        // из `sessionStorage` и позвать watch() заново. Если запись всё ещё
        // в карте, `putIfAbsent` находит именно этот, уже умирающий
        // контроллер — новый слушатель подписывается на него и тут же
        // получает `onDone` вместо наблюдения. Удалив запись первой, мы
        // делаем эту гонку невозможной по устройству: `putIfAbsent` в этом
        // окне уже не находит умирающий контроллер и заводит свежий.
        //
        // Проверка identical() защищает от удаления чужой, уже более новой
        // записи — на случай, если за время `subscription?.cancel()` кто-то
        // успел завести новый контроллер для того же токена.
        if (!upstream.hasListener && identical(_watchers[token], upstream)) {
          _watchers.remove(token);
          await upstream.close();
        }
      },
    );

    return out.stream;
  }

  void _notify(String token, AuthSession? session) {
    final controller = _watchers[token];
    if (controller != null && !controller.isClosed) {
      controller.add(session);
    }
  }

  /// 32 байта из `Random.secure()`. Не 12, как у кода привязки: тот человек
  /// читает вслух, этот не читает никто, и укорачивать его незачем.
  String _mintToken() {
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Убирает погасшие сеансы из `_live`. Зовётся на каждом действии, чтобы
  /// карта живых сеансов не росла на кассе, которая работает месяцами без
  /// перезапуска. Карту подписчиков `_watchers` чистит не она — это
  /// `watch()`, при отмене последней подписки на токен (см. `onCancel`).
  /// Заодно убирает и `_lastNotifiedExpiry` погасшего токена (правка 3
  /// разбора, 2026-08-21) — без этого запись пережила бы сеанс и осталась
  /// бы в карте безадресной.
  void _forget() {
    final now = _clock();
    final dead = _live.entries
        .where((e) => !e.value.expiresAt.isAfter(now))
        .map((e) => e.key)
        .toList();
    for (final token in dead) {
      _live.remove(token);
      _lastNotifiedExpiry.remove(token);
      _notify(token, null);
    }
    if (dead.isNotEmpty) _liveChanges.add(null);
  }
}
