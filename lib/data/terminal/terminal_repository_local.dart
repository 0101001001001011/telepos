import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:telepos/backend/security_journal.dart';
import 'package:telepos/data/database/app_database.dart' as db;
import 'package:telepos/data/database/watch_source.dart';
import 'package:telepos/domain/terminal/terminal.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/terminal/terminal_secret.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

/// Терминалы из локальной базы.
///
/// Устройства терминала не читаются/пишутся здесь — см.
/// `DeviceBindingRepository`/`LocalDeviceBindingRepository`
/// (`lib/domain/terminal/device_binding_repository.dart`,
/// `lib/data/terminal/device_binding_repository_local.dart`, план 2, задача
/// 4) для того, почему это отдельный контракт.
class LocalTerminalRepository implements TerminalRepository {
  LocalTerminalRepository(this._db, {SecurityJournal? journal})
    : _journal = journal;

  final db.AppDatabase _db;

  /// Журнал событий безопасности — задача 21 закрытия долга безопасности.
  /// `null` по умолчанию, тем же приёмом, что и весь остальной опциональный
  /// довод в этой работе: тесты, которым запись не нужна, не обязаны знать
  /// о новом доводе.
  final SecurityJournal? _journal;

  @override
  Future<List<Terminal>> list() async =>
      (await _db.terminalDao.all()).map(_toDomain).toList();

  /// Читает тем же [list], которым отвечает и на одноразовый вопрос: подписка
  /// и вопрос, читающие по-разному, дали бы два ответа на один вопрос. Как
  /// устроен сигнал — `lib/data/database/watch_source.dart`.
  @override
  Stream<List<Terminal>> watchAll() => watchTables(_db, [_db.terminals], list);

  /// Строку **не создаёт**, в отличие от [self]: наблюдение не имеет права
  /// менять то, за чем наблюдает — иначе открытая вкладка заводила бы терминал.
  /// Поэтому читает `terminalDao.self()` напрямую, а не через `ensureSelf`.
  @override
  Stream<Terminal?> watchSelf() => watchTables(_db, [_db.terminals], () async {
    final row = await _db.terminalDao.self();
    return row == null ? null : _toDomain(row);
  });

  @override
  Future<Terminal> self() async {
    final pos = await _db.thisPosDao.get();
    final name = pos?.cashBoxName?.trim();
    // Тот же дефект, что уже закрыт для миграции v25→v26 (см. комментарий у
    // неё в app_database.dart), только со второго входа: до прохождения
    // мастера настройки настоящего имени кассы нет, и плейсхолдер вроде
    // 'Касса-1' создал бы isSelf-строку, которую ensureSelf() потом нашёл бы
    // как уже существующую и никогда не заменил бы на настоящее имя.
    // GET /api/terminals/self, доступный ещё до мастера настройки, — второй
    // путь в ту же ловушку. Отказ явно, а не молчаливое имя-угадайка.
    if (name == null || name.isEmpty) {
      throw const InstallationNotConfiguredException();
    }
    return _toDomain(await _db.terminalDao.ensureSelf(fallbackName: name));
  }

  /// Потолок числа терминалов, которые [register] заводит, — задача 7
  /// закрытия долга.
  ///
  /// # Почему это здесь и почему именно это число
  ///
  /// `terminals.register` зовёт сам вход раньше `auth.login`, и без этого
  /// потолка вставляла бы новую строку на любой кадр, ничем не ограниченная:
  /// тот, кто дотянулся до кассы по QUIC напрямую, минуя экран, мог бы звать
  /// её сколько угодно раз с новым именем на каждый вызов. Дедупликация по
  /// имени такую ротацию не ловила бы всё равно — имя нападающий как раз и
  /// меняет, — а с пункта 6 фазы 3/4 закрытия долга её и не осталось: она
  /// была дырой, см. докстринг у [register].
  ///
  /// **Неверно с задачи 6 плана «знакомство терминала с кассой»:**
  /// `TillOps.terminalRegister` здесь называлась `access: OpenAccess()` — с
  /// задачи 6 это `access: EnrolmentAccess()` (`till_ops.dart`): запрос
  /// обязан нести действующий код привязки, который тратит обработчик
  /// (`TillOperations.askHandlers[terminalRegister.name]`), не сторож. Этот
  /// потолок остаётся в силе и после задачи 6 не как единственная защита, а
  /// как вторая линия — код привязки закрывает саму заводку, `maxTerminals`
  /// по-прежнему ограничивает, сколько раз можно заводить (в том числе
  /// действующим кодом, повторно выданным честному, но забывчивому
  /// оператору) прежде чем касса откажет по числу строк.
  ///
  /// 200 — заведомо выше любого настоящего магазина: [_defaultBrowserTerminalName]
  /// (`lib/presentation/controllers/auth/login_controller.dart`) заводит по
  /// одному браузерному терминалу на клиента, и даже крупный гипермаркет с
  /// несколькими десятками касс, киосков самообслуживания и кухонных экранов
  /// не подходит к этому числу и на четверть. При этом 200 — заведомо ниже
  /// стоимости перебора: это меньше, чем пространство четырёхзначного PIN
  /// (10 000 — `LoginThrottle`, `lib/backend/login_throttle.dart`), и в
  /// отличие от подбора PIN каждая попытка здесь требует не догадки, а
  /// целого нового кадра по живому QUIC-соединению с кассой — то есть
  /// нападающий получает не более 200 бесплатных `terminalId` за всё время
  /// жизни установки, а не бесконечную ротацию, которой опасалась задача 6.
  ///
  /// Настоящий магазин, упёршийся в потолок (сам по себе маловероятный
  /// случай — см. выше), получает отказ [WireRefusal] с кодом
  /// `terminal_limit_reached`: уже заведённые терминалы продолжают работать
  /// как прежде (`list`/`self`/`rename`/вход не тронуты), отказывает только
  /// заводка ещё одного. Удаления терминала пока нет — это следующая задача
  /// (8); до неё разбор такого потолка на настоящей установке потребовал бы
  /// прямого вмешательства в базу.
  static const int maxTerminals = 200;

  /// Дедупликация по имени, снятая пунктом 6 фазы 3/4 закрытия долга
  /// (2026-08-21) — **решение, а не упущение**, и связано с пунктом 2 той же
  /// волны, а не только с точностью подсчёта строк.
  ///
  /// Было: клиент, предъявивший известное имя, получал существующую строку
  /// вместо новой (`findByName`, ниже по файлу до правки). Разбор нашёл две
  /// причины, по которым это не работало как задумано и работало как дыра:
  ///
  /// - **Назначения не выполняла.** Единственный вызывающий —
  ///   [_defaultBrowserTerminalName] (`login_controller.dart`) — шлёт имя со
  ///   штампом времени до секунды на каждый новый браузерный терминал, так
  ///   что совпадений не бывает вовсе. Дедупликация не ловила ни одного
  ///   настоящего повтора за всё время, что была в коде.
  /// - **Была дырой.** `terminals.register` — `OpenAccess`, сеанса не
  ///   требует. `terminals.rename` даёт имя выбрать человеку — то есть оно
  ///   не секрет, — а `terminals.list` показывает имена любому сеансу.
  ///   Значит нападающий, узнавший (или угадавший) чужое имя терминала, мог
  ///   вызвать `register` этим именем и получить **ту же строку**, что и
  ///   настоящий владелец, — без единого пароля. Это в точности тот обход,
  ///   которым пункт 2 фазы 3/4 (`terminalId` для `auth.login` берётся из
  ///   того, что сессия сама зарегистрировала) обесценивался бы, останься
  ///   дедупликация на месте: подделать `terminalId` в теле кадра стало
  ///   нельзя, но переприсвоить себе чужой `terminalId` через `register`
  ///   по известному имени — можно было бы по-прежнему.
  ///
  /// `findByName` (`terminal_dao.dart`) остаётся в DAO — контракт публичный,
  /// и находка «не крашится на двух строках» верна независимо от того, кто
  /// его зовёт, — но `register` его больше не зовёт. Повторный вызов честного
  /// клиента (десктопная касса тоже проходит этим путём, минуя провод) теперь
  /// заводит новую строку каждый раз; цена — та же самая накопление, от
  /// которого защищает [maxTerminals] ниже, только чуть быстрее без
  /// дедупликации. **Полное лечение — привязка терминала по одноразовому
  /// коду — тогда (2026-08-21) было отдельной, ещё не начатой работой (задел
  /// был только пакетом, `rk_pki` 0.4.0). Это ровно план «знакомство
  /// терминала с кассой», и с задачи 6 он реализован** — см. [code] ниже и
  /// докстринг `TillOps.terminalRegister`/`EnrolmentAccess`
  /// (`till_ops.dart`, `wire_access.dart`): накопление от честного повтора
  /// без дедупликации по-прежнему возможно (создатель по-прежнему заводит
  /// новую строку на каждый вызов), но каждый такой вызов с задачи 6 требует
  /// действующего, ещё не потраченного кода привязки — «дёшево накопить
  /// строк» это больше не значит «дёшево нападающему», раз строки не
  /// заводятся без предъявленного кода.
  ///
  /// # Секрет — задача 4 плана «знакомство терминала с кассой»
  ///
  /// Заводит терминал и его секрет — задача 4 плана «знакомство терминала с
  /// кассой» (шаг 2 спеки). Секрет ([TerminalSecret.generate]) едет
  /// вызывающему единственный раз, этим самым возвратом; хранится на кассе
  /// только его отпечаток ([TerminalSecret.fingerprint],
  /// `Terminals.secretFingerprint`) — значение секрета в этой строке не
  /// оседает нигде, ни временно, ни постоянно: `trimmed`/`total`/остальные
  /// локальные здесь не удерживают его дольше одного вызова, а колонка,
  /// которая переживает вызов, несёт только отпечаток.
  ///
  /// [code] не проверяется здесь — эта реализация не проходит по проводу
  /// (десктопная касса зовёт [self], не этот метод — `login_controller.dart`,
  /// `_resolveTerminalId`), и у неё нет `PairingInvites`, которым его было бы
  /// чем сверить. Гейт — `TillOperations.askHandlers[terminalRegister.name]`
  /// (`lib/backend/till_operations.dart`), задача 6 плана «знакомство
  /// терминала с кассой»: см. докстринг [TerminalRepository.register] про
  /// то, почему довод здесь, а не второй метод.
  @override
  Future<TerminalEnrollment> register({
    required String name,
    String code = '',
  }) async {
    final trimmed = _requireName(name);
    final secret = TerminalSecret.generate();
    final fingerprint = TerminalSecret.fingerprint(secret);

    final terminal = await _db.transaction(() async {
      final total = await _db.terminalDao.count();
      if (total >= maxTerminals) {
        throw WireRefusal(
          'terminal_limit_reached',
          'на этой кассе уже заведено $maxTerminals терминалов — новый не '
              'добавлен',
        );
      }

      final id = await _db
          .into(_db.terminals)
          .insert(
            db.TerminalsCompanion.insert(
              name: trimmed,
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              secretFingerprint: Value(fingerprint),
            ),
          );
      final row = await (_db.select(
        _db.terminals,
      )..where((t) => t.id.equals(id))).getSingle();
      return _toDomain(row);
    });
    return (terminal: terminal, secret: secret);
  }

  /// Возвращает уже заведённый терминал на новую QUIC-сессию, предъявив его
  /// секрет — задача 5 плана «знакомство терминала с кассой», шаг 2 спеки.
  /// Полный договор — докстринг `TerminalRepository.resume`.
  ///
  /// Один и тот же [WireRefusal] на три разные причины (id не существует,
  /// отпечатка нет — строка старше миграции v35→v36, секрет не сходится) —
  /// это решение, названное там же, а не три отдельных отказа здесь.
  /// [TerminalSecret.matches] уже отвечает `false` на первые две причины
  /// (`null`-отпечаток), так что здесь ровно один `if`, а не три.
  @override
  Future<Terminal> resume({
    required int terminalId,
    required String secret,
  }) async {
    final row = await _db.terminalDao.findById(terminalId);
    if (row == null || !TerminalSecret.matches(secret, row.secretFingerprint)) {
      throw const WireRefusal(
        'terminal_secret_invalid',
        'терминал не найден или предъявленный секрет не подходит',
      );
    }
    return _toDomain(row);
  }

  @override
  Future<void> rename(int terminalId, String name) =>
      _db.terminalDao.rename(terminalId, _requireName(name));

  /// Удаляет терминал безвозвратно — задача 8 закрытия долга.
  ///
  /// # Почему отказ, а не молчаливое «нечего удалять», на несуществующем id
  ///
  /// Тот же код `unknown_terminal`, которым уже отвечает `auth.login`
  /// (`TillOperations.askHandlers`, `lib/backend/till_operations.dart`) на
  /// чужой `terminalId`: обе причины — «клиент называет терминал, которого
  /// касса не знает» — и терминалу нет смысла отличать их по тексту.
  ///
  /// # Почему нельзя удалить `isSelf`-терминал
  ///
  /// Проверка здесь, а не только у `TillOperations` — десктопная касса зовёт
  /// этот репозиторий напрямую, минуя провод, и без второй проверки один и
  /// тот же контракт молча вёл бы себя по-разному на двух сторонах (тот же
  /// приём, что у [_requireName]).
  ///
  /// «Свой терминал» здесь означает `isSelf`, а не терминал конкретной
  /// браузерной вкладки, отправившей этот запрос — и это осознанный выбор,
  /// а не то же самое под другим именем. Этот метод не видит ни кадра, ни
  /// токена, ни сеанса — только `terminalId` доводом, ровно тем же путём,
  /// которым его зовёт и десктопная касса напрямую, минуя провод целиком.
  /// Единственное понятие «своего терминала», которое известно **этому
  /// методу**, — `isSelf`: терминал, которым касса пользуется сама
  /// (`self`/`ensureSelf` выше). Он и защищён здесь.
  ///
  /// Терминал вызывающей браузерной вкладки (обычный зарегистрированный, не
  /// `isSelf`) эта проверка не остановит — и до задачи 9 закрытия долга это
  /// было названной, не закрытой дырой: `AuthSession`
  /// (`lib/domain/auth/auth_outcome.dart`) не хранил `terminalId`, а
  /// `RequestFrame` (`lib/domain/wire/wire_frame.dart`) везёт с каждым
  /// вопросом только токен сеанса — сверить запрошенный `terminalId` с
  /// личностью вызывающей вкладки было решительно не с чем. С задачи 9
  /// `AuthSession.terminalId` есть, и сверка сделана — но не здесь, а в
  /// `TillOperations.askHandlers[TillOps.terminalDelete]`
  /// (`lib/backend/till_operations.dart`), единственном месте, которому
  /// вообще достаётся сеанс вызывающей стороны. Здесь по-прежнему нечем
  /// сверять: десктопный вызов этого метода сеанса какой-либо вкладки не
  /// несёт вовсе, и это не пробел, а причина, по которой сверка не может
  /// переехать сюда целиком.
  @override
  Future<void> delete(int terminalId) async {
    final row = await _db.terminalDao.findById(terminalId);
    if (row == null) {
      throw WireRefusal(
        'unknown_terminal',
        'терминала с таким id не существует: $terminalId',
      );
    }
    if (row.isSelf) {
      throw const WireRefusal(
        'cannot_delete_self',
        'нельзя удалить терминал, которым касса пользуется сама',
      );
    }
    await _db.terminalDao.remove(terminalId);
    // Задача 21 закрытия долга безопасности: единственная реализация
    // (докстринг класса) — и с провода (`TillOperations.askHandlers
    // [TillOps.terminalDelete]`), и с десктопных настроек напрямую, оба пути
    // сходятся здесь, значит и запись в журнал нужна ровно одна.
    //
    // `terminalId` здесь — терминал, который **удалён** (предмет события),
    // а не терминал, с которого пришла команда на удаление: этот метод, по
    // его же докстрингу выше, «не видит ни кадра, ни токена, ни сеанса» —
    // источник команды здесь неизвестен структурно, и выдумывать его значило
    // бы соврать. `userId` по той же причине не заполнен: узнать, кто
    // удалил, можно только протащив сеанс через оба вызывающих пути
    // (`TillOperations`, десктопный экран) до этого метода — отдельная
    // правка сигнатуры контракта, которая не входит в задачу 21 (она про
    // первых вызывающих журнала, а не про новый контракт `TerminalRepository`).
    unawaited(
      _journal?.record(
        eventType: SecurityEventType.terminalDeleted,
        outcome: SecurityOutcome.success,
        terminalId: terminalId,
      ),
    );
  }

  /// Обрезает имя и отклоняет пустое — правило описано на
  /// `TerminalRepository.register`/`.rename`. Проверка живёт и здесь, а не
  /// только на границе провода: десктопная касса зовёт этот репозиторий
  /// напрямую, минуя `TillOperations`, — и без второй проверки один и тот же
  /// контракт молча вёл бы себя по-разному на двух сторонах.
  static String _requireName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(
        name,
        'name',
        'имя терминала обязательно и не может быть пустым после trim()',
      );
    }
    return trimmed;
  }

  Terminal _toDomain(db.Terminal row) => Terminal(
    id: row.id,
    name: row.name,
    pointMode: _pointModeFromStored(row.pointMode, terminalId: row.id),
  );

  /// Переводит хранимое имя в [PointMode].
  ///
  /// Хранится имя, а не порядковый номер — вставка нового `PointMode` не в
  /// конец перечисления не должна незаметно менять режим уже сохранённых
  /// терминалов (docs/system-architecture.md). Нераспознанное имя означает,
  /// что строку писала более новая версия приложения — с режимом, которого
  /// этот `PointMode.values` ещё не знает — а откатившийся старый клиент её
  /// читает. Молчаливая замена на близкий валидный режим незаметно выдаёт
  /// один режим за другой: `unattended`/`kitchen` не всегда безопаснее
  /// заменить на `cashier` (или наоборот) — это вопрос прав доступа, а не
  /// отображения. Здесь это решается явным отказом вместо угадывания: лучше
  /// терминал, который не открылся, чем терминал, который открылся с чужими
  /// правами.
  ///
  /// **`LocalAuthRepository._issue` (`lib/data/auth/local_auth_repository.dart`)
  /// на тот же случай решает наоборот** — молча откатывается на
  /// `PointMode.selfService` вместо отказа — и это не забытая копия этого
  /// правила, а другая ставка для другой операции: выдача прав входа только
  /// сужает их (`PointModePermissions.effective`), так что откат на самый
  /// узкий режим не может выдать лишнее, а отказ там означал бы остановку
  /// торговли там, где можно было бы торговать с урезанными правами. Если
  /// решение здесь когда-нибудь поменяется, стоит перечитать довод там же.
  static PointMode _pointModeFromStored(
    String stored, {
    required int terminalId,
  }) {
    for (final mode in PointMode.values) {
      if (mode.name == stored) return mode;
    }
    throw StateError(
      'Терминал #$terminalId хранит pointMode="$stored", которого не знает '
      'PointMode.values (${PointMode.values.map((m) => m.name).join(', ')}). '
      'Похоже, запись сделала более новая версия приложения. Отказываюсь '
      'угадывать режим — это вопрос прав доступа, а не отображения.',
    );
  }
}
