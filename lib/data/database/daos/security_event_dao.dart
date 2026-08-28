import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/security_tables.dart';

part 'security_event_dao.g.dart';

/// Журнал событий безопасности — только пополняется.
///
/// **Ни правки, ни удаления.** Этот класс намеренно не содержит ни `update`,
/// ни `delete` ни в каком виде — единственный метод, который меняет
/// содержимое таблицы, это [record], и он только вставляет. Это требование
/// задачи 20 (план «замок кассы», фаза 8), а не то, что метод правки просто
/// не понадобился: журнал, который можно исправить или стереть тем же
/// доступом, каким его читают, не годится в улику против того, кто этим
/// доступом злоупотребил.
///
/// # Цепочка отпечатков (И67)
///
/// Каждая запись несёт в [SecurityEvents.previousFingerprint] отпечаток
/// **предыдущей** записи — sha256 от её собственного содержимого плюс её же
/// `previousFingerprint`, см. [_fingerprintOfRow]. Отпечаток вычисляется от
/// содержимого, а не хранится отдельной колонкой у самой записи: строка
/// `i+1` уже несёт его как свой `previousFingerprint`, второй копии не
/// нужно.
///
/// Проверка ([firstBrokenLinkId]) идёт по возрастанию `id` и на каждом шаге
/// сверяет, что `previousFingerprint` текущей строки равен отпечатку,
/// вычисленному из предыдущей **уцелевшей**. Вырезание записи из середины
/// рвёт эту сверку ровно на следующей уцелевшей строке: та по-прежнему
/// ссылается на отпечаток вырезанной, а вычисленный отпечаток предыдущей
/// уцелевшей — уже другой. Обнаруживается сам факт разрыва и то, где он
/// начинается (id первой строки после дыры) — не то, что именно было
/// вырезано: содержимого вырезанной строки в базе больше нет, и цепочка
/// его не хранит нигде отдельно.
///
/// Первая запись журнала не имеет предшественника — её
/// `previousFingerprint` равен [genesisFingerprint], фиксированной
/// константе. У этого есть граница, которую нужно называть, а не прятать:
/// константа сама по себе ничего не доказывает — она просто отмечает
/// «отсюда начинается цепочка». У кого есть прямой доступ к файлу базы (не
/// к DAO, не к проводу — к самому файлу), может стереть журнал целиком и
/// завести новый, снова начинающийся с того же genesis, — новая цепочка
/// будет внутренне цельной, и [firstBrokenLinkId] не найдёт в ней разрыва,
/// потому что разрыва в ней и не будет. Эта проверка защищает от вырезания
/// записи **из уже существующей цепочки**, а не от подмены журнала целиком
/// тем, у кого есть доступ к самому файлу базы, — это разные угрозы, и
/// вторую эта задача не решает. Защита от неё потребовала бы якоря вне этой
/// базы (подпись, синхронизация отпечатка на другую машину/сервер) — вне
/// охвата задачи 20.
///
/// # Маскирование (И68)
///
/// [record] принимает только структурные поля — ни одно из них не названо
/// «pin»/«hash»/«token». Если вызывающему нужно привязать событие к секрету
/// (например к токену сеанса), секрет несёт его отпечаток в одном из
/// текстовых полей (обычно [SecurityEvents.correlationId]), не значение как
/// есть.
///
/// До правки волны закрытия долга безопасности (2026-08-22) здесь стоял
/// `fingerprintOfSecret` — несолёный, неитерированный `sha256`, статический
/// метод этого класса, ни разу не позванный ни одной строкой `lib/` (только
/// тестами). Снят целиком, а не оставлен «на будущее»: докстринг приглашал
/// применять его «к паролю — к чему угодно», а настоящий секрет продукта —
/// четырёхзначный PIN, для которого несолёный `sha256` не отпечаток, а
/// обратимое кодирование (10⁴ прообразов перебираются за микросекунды, И68
/// говорит именно про это). Функция без вызывающего — тот самый шаблон,
/// ради искоренения которого затевалась эта волна (`docs/…`, брифы задач
/// 20–21): держать её «про запас» значило бы оставить готовую дыру для дня,
/// когда кто-то и правда позовёт её на PIN, не читая это предупреждение.
/// Когда появится настоящий вызывающий с высокоэнтропийным секретом (не
/// PIN — токен сеанса, ключ), функцию заводят заново рядом с ним, солёной и
/// названной по секрету, который она в самом деле маскирует, а не заранее и
/// не универсальной.
@DriftAccessor(tables: [SecurityEvents])
class SecurityEventDao extends DatabaseAccessor<AppDatabase>
    with _$SecurityEventDaoMixin {
  SecurityEventDao(super.db);

  /// `previousFingerprint` самой первой записи журнала — фиксированная
  /// константа, не производная ни от какого секрета. 64 нуля — не sha256
  /// ни от чего, просто строка той же длины, что и hex-sha256 настоящих
  /// записей, ради единообразного вида колонки. См. докстринг класса про
  /// то, что эта константа доказывает и чего нет.
  static const String genesisFingerprint =
      '0000000000000000000000000000000000000000000000000000000000000000';

  /// Единственный способ дописать запись в журнал.
  ///
  /// Отпечаток предыдущей записи вычисляется внутри одной транзакции с
  /// вставкой: между чтением последней записи и вставкой новой не должно
  /// пройти ни одной чужой записи, иначе `previousFingerprint` новой строки
  /// сослался бы не на действительно предыдущую.
  Future<SecurityEvent> record({
    required int occurredAtEpochMs,
    int? userId,
    required int terminalId,
    required String eventType,
    required String outcome,
    required String correlationId,
  }) {
    return transaction(() async {
      final last =
          await (select(securityEvents)
                ..orderBy([(t) => OrderingTerm.desc(t.id)])
                ..limit(1))
              .getSingleOrNull();

      final previousFingerprint = last == null
          ? genesisFingerprint
          : _fingerprintOfRow(last);

      final id = await into(securityEvents).insert(
        SecurityEventsCompanion.insert(
          occurredAtEpochMs: occurredAtEpochMs,
          userId: Value(userId),
          terminalId: terminalId,
          eventType: eventType,
          outcome: outcome,
          correlationId: correlationId,
          previousFingerprint: previousFingerprint,
        ),
      );

      return (select(
        securityEvents,
      )..where((t) => t.id.equals(id))).getSingle();
    });
  }

  /// Весь журнал по возрастанию `id` — порядок, в котором его обязана
  /// проверять цепочка.
  Future<List<SecurityEvent>> findAll() =>
      (select(securityEvents)..orderBy([(t) => OrderingTerm.asc(t.id)])).get();

  /// И67: пробегает журнал по [findAll] и сверяет цепочку отпечатков.
  ///
  /// Возвращает `id` первой строки, чей `previousFingerprint` не совпал с
  /// отпечатком, вычисленным из предыдущей уцелевшей строки (или с
  /// [genesisFingerprint] для самой первой), либо `null`, если цепочка цела
  /// целиком (включая пустой журнал — в нём нечему рваться). См. докстринг
  /// класса про то, что это обнаруживает и чего нет.
  Future<int?> firstBrokenLinkId() async {
    final rows = await findAll();
    var expectedPrevious = genesisFingerprint;
    for (final row in rows) {
      if (row.previousFingerprint != expectedPrevious) {
        return row.id;
      }
      expectedPrevious = _fingerprintOfRow(row);
    }
    return null;
  }

  /// sha256(содержимое строки + её собственный `previousFingerprint`),
  /// hex. Это значение — то, что следующая по цепочке запись обязана нести
  /// как свой `previousFingerprint`; здесь же используется, чтобы построить
  /// его для новой вставки ([record]) и чтобы сверить его при проверке
  /// ([firstBrokenLinkId]) — одна и та же формула для обоих направлений,
  /// иначе они могли бы разойтись.
  static String _fingerprintOfRow(SecurityEvent row) => _fingerprintOf(
    occurredAtEpochMs: row.occurredAtEpochMs,
    userId: row.userId,
    terminalId: row.terminalId,
    eventType: row.eventType,
    outcome: row.outcome,
    correlationId: row.correlationId,
    previousFingerprint: row.previousFingerprint,
  );

  static String _fingerprintOf({
    required int occurredAtEpochMs,
    required int? userId,
    required int terminalId,
    required String eventType,
    required String outcome,
    required String correlationId,
    required String previousFingerprint,
  }) {
    // Разделитель полей — управляющий символ с кодом 0 (недопустим в
    // обычном тексте): без разделителя конкатенация могла бы случайно
    // совпасть у двух разных наборов полей (например `eventType: 'ab'` +
    // `outcome: 'c'` и `eventType: 'a'` + `outcome: 'bc'`). Строится через
    // fromCharCode, а не как литерал в исходнике, чтобы редактор и
    // инструменты форматирования не тронули невидимый байт.
    final separator = String.fromCharCode(0);
    final payload = <String>[
      occurredAtEpochMs.toString(),
      userId?.toString() ?? '',
      terminalId.toString(),
      eventType,
      outcome,
      correlationId,
      previousFingerprint,
    ].join(separator);
    return sha256.convert(utf8.encode(payload)).toString();
  }

  /// И67, БЛОКЕР 2 закрытия долга безопасности (2026-08-22): усечение
  /// **хвоста** журнала — вырезание последних N строк целиком.
  ///
  /// [firstBrokenLinkId] проверяет цепочку только вперёд от genesis и
  /// останавливается на последней **уцелевшей** строке — вырезание записей
  /// с конца не оставляет по себе ни одной строки, чей `previousFingerprint`
  /// не совпал бы: цепочка обрывается ровно там, где кончился физический
  /// список строк, и это неотличимо от «журнал был таким всегда». Это ровно
  /// то, чего хочет злоумышленник со сквозным доступом к DAO: стереть то,
  /// что он только что сделал, не оставив разрыва, который ловит
  /// [firstBrokenLinkId].
  ///
  /// Дешёвое закрытие: [SecurityEvents.id] объявлен `autoIncrement()`
  /// (`security_tables.dart`), drift компилирует это в
  /// `PRIMARY KEY AUTOINCREMENT` — подтверждено по сгенерированной таблице
  /// (`app_database.g.dart`, `$SecurityEventsTable.id`,
  /// `defaultConstraints: 'PRIMARY KEY AUTOINCREMENT'`), а не только по
  /// докстрингу класса — SQLite для этого заводит служебную таблицу
  /// `sqlite_sequence` со строкой `(name='security_events', seq=<высший
  /// когда-либо выданный id>)`. `seq` растёт только на вставке и никогда не
  /// уменьшается сам — в отличие от `MAX(id)` текущей таблицы, который
  /// падает, когда вырезают строки с самым большим `id`. Значит: `seq >
  /// MAX(id)` **ровно тогда**, когда были вырезаны одна или несколько строк
  /// с конца, и не может быть истинным ни при вырезании из середины (не
  /// трогает максимальный id), ни при нетронутой таблице.
  ///
  /// Возвращает `false` для пустого журнала (стирать нечего — как и
  /// [firstBrokenLinkId], нечему рваться) и для журнала, где ни разу не
  /// было ни одной вставки (`sqlite_sequence` строки для таблицы ещё нет —
  /// тот же смысл, что и для пустого).
  ///
  /// # Граница, названная явно
  ///
  /// Это ловит усечение хвоста **уже существующей** цепочки — тем же
  /// периметром, что и [firstBrokenLinkId] про вырезание из середины (см.
  /// докстринг класса). Подмену журнала **целиком** — новую цельную
  /// цепочку, снова начинающуюся с genesis, заведённую тем, у кого есть
  /// доступ к самому файлу базы (не к DAO) — эта проверка не ловит и не
  /// может: у новой таблицы `sqlite_sequence.seq` был бы сброшен вместе с
  /// самой таблицей, и `seq == MAX(id)` держалось бы тривиально. Тот же
  /// якорь вне базы, что уже назван докстрингом класса про genesis,
  /// понадобился бы и здесь.
  Future<bool> isTailTruncated() async {
    final maxIdRow = await customSelect(
      'SELECT MAX(id) AS max_id FROM security_events',
    ).getSingleOrNull();
    final maxId = maxIdRow?.data['max_id'] as int?;
    if (maxId == null) {
      // Пустой журнал — ни одной вставки не было, стирать нечего.
      return false;
    }

    final seqRow = await customSelect(
      "SELECT seq AS seq FROM sqlite_sequence WHERE name = 'security_events'",
    ).getSingleOrNull();
    final seq = seqRow?.data['seq'] as int?;
    if (seq == null) {
      // Непустая таблица без строки sqlite_sequence не должна встречаться
      // на практике (AUTOINCREMENT заводит её на первой же вставке), но
      // отсутствие данных — не повод утверждать усечение, которого нечем
      // подтвердить.
      return false;
    }

    return seq > maxId;
  }
}
