import 'dart:typed_data';

import 'package:drift/drift.dart';

import 'package:telepos/data/database/app_database.dart' as db;
import 'package:telepos/domain/print/print_job.dart';
import 'package:telepos/domain/print/print_job_store.dart';

/// Имена состояний, из которых задание само дальше не пойдёт, — в форме,
/// пригодной для `WHERE state IN (...)`.
///
/// **Вычислены из домена, а не переписаны сюда списком.** Второй список
/// `{printed, expired, cancelled}`, живущий рядом с `PrintJob.isTerminal`,
/// разошёлся бы с ним при добавлении состояния, и разошёлся бы молча: уборка
/// перестала бы замечать новое терминальное состояние, а заметить это было бы
/// нечем. Здесь тот же самый предикат домена, только опрошенный заранее.
///
/// Длина этого списка равна числу значений перечисления и **не зависит от
/// числа строк в таблице** — именно поэтому им можно пользоваться в `IN`, в
/// отличие от списка идентификаторов, который упирался в предел SQLite на
/// число переменных.
final List<String> _terminalStateNames = [
  for (final state in PrintJobState.values)
    if (_probeInState(state).isTerminal) state.name,
];

/// Одноразовое задание, существующее только чтобы спросить у домена, считает
/// ли он [state] терминальным.
PrintJob _probeInState(PrintJobState state) => PrintJob(
  id: 'probe',
  terminalId: 1,
  posId: 1,
  payloadBytes: Uint8List.fromList(const [0x00]),
  createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  expiresAt: DateTime.fromMillisecondsSinceEpoch(1, isUtc: true),
  state: state,
);

/// [PrintJobStore] поверх drift — задания и подтверждения лежат на диске,
/// в таблицах `PrintJobs` и `PrintJobConfirmations`
/// (`lib/data/database/tables/print_tables.dart`, схема v29).
///
/// Смысл существования — переживание перезапуска процесса. Реализация,
/// держащая задания в поле класса, была бы неотличима от сегодняшнего дефекта,
/// перенесённого на уровень выше, поэтому здесь нет ни одного кеша в памяти:
/// каждый запрос читает базу.
class DriftPrintJobStore implements PrintJobStore {
  /// [clock] — часы, которыми проставляются `updatedAtEpochMs` и момент
  /// подтверждения. Домен часов не знает (см. доку конструктора `PrintJob`),
  /// и здесь они вносятся явно: тест, которому нужно состарить подтверждение
  /// на три месяца, не должен ждать три месяца.
  ///
  /// [confirmationRetention] и [maxRememberedConfirmations] по умолчанию
  /// берутся из [PrintJobStore] — правило хранения объявлено в контракте, а не
  /// придумано реализацией. Переопределяются только для проверки самого
  /// правила: потолок в сто тысяч строк иначе пришлось бы проверять ста
  /// тысячами строк.
  DriftPrintJobStore(
    this._db, {
    DateTime Function()? clock,
    Duration? confirmationRetention,
    int? maxRememberedConfirmations,
  }) : _clock = clock ?? DateTime.now,
       _confirmationRetention =
           confirmationRetention ?? PrintJobStore.confirmationRetention,
       _maxRememberedConfirmations =
           maxRememberedConfirmations ??
           PrintJobStore.maxRememberedConfirmations {
    if (_confirmationRetention <= Duration.zero) {
      throw ArgumentError.value(
        _confirmationRetention.toString(),
        'confirmationRetention',
        'память о подтверждённых заданиях с нулевым сроком — это отсутствие '
            'идемпотентности',
      );
    }
    if (_maxRememberedConfirmations <= 0) {
      throw ArgumentError.value(
        _maxRememberedConfirmations,
        'maxRememberedConfirmations',
        'потолок в ноль строк означает, что не помнится ничего',
      );
    }
  }

  final db.AppDatabase _db;
  final DateTime Function() _clock;
  final Duration _confirmationRetention;
  final int _maxRememberedConfirmations;

  @override
  Future<void> put(PrintJob job) async {
    final nowEpochMs = _clock().millisecondsSinceEpoch;
    await _db.transaction(() async {
      if (PrintJobStore.contradictsConfirmation(job) &&
          await isConfirmedPrinted(job.id)) {
        // Условие взято из контракта, а не повторено здесь своими словами:
        // ровно этот повтор и разошёлся с очередью, которая проверяла
        // «нетерминальное», пока тут проверялось «не `printed`». См.
        // [PrintJobStore.contradictsConfirmation] — там же и обоснование,
        // почему `printed`, а не «терминальное».
        throw StateError(
          'задание ${job.id} уже подтверждено принтером — записать его в '
          'состояние ${job.state.name} значит либо напечатать второй чек, '
          'либо оставить в журнале неправду о напечатанном',
        );
      }

      await _db
          .into(_db.printJobs)
          .insertOnConflictUpdate(
            db.PrintJobsCompanion.insert(
              jobId: job.id,
              terminalId: job.terminalId,
              posId: job.posId,
              payloadBytes: job.payloadBytes,
              createdAtEpochMs: job.createdAt.millisecondsSinceEpoch,
              expiresAtEpochMs: job.expiresAt.millisecondsSinceEpoch,
              updatedAtEpochMs: nowEpochMs,
              attempts: Value(job.attempts),
              state: job.state.name,
              failureReason: Value(job.failureReason),
            ),
          );

      if (job.state == PrintJobState.printed) {
        // `insertOrIgnore`: момент **первого** подтверждения не сдвигается
        // повторной записью того же задания — иначе строка, которую кто-то
        // регулярно перезаписывает, никогда бы не выпала из памяти.
        await _db
            .into(_db.printJobConfirmations)
            .insert(
              db.PrintJobConfirmationsCompanion.insert(
                jobId: job.id,
                confirmedAtEpochMs: nowEpochMs,
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }
    });
  }

  @override
  Future<PrintJob?> jobById(String jobId) async {
    final row = await (_db.select(
      _db.printJobs,
    )..where((j) => j.jobId.equals(jobId))).getSingleOrNull();
    return row == null ? null : _toJob(row);
  }

  @override
  Future<bool> isConfirmedPrinted(String jobId) async {
    final row = await (_db.select(
      _db.printJobConfirmations,
    )..where((c) => c.jobId.equals(jobId))).getSingleOrNull();
    return row != null;
  }

  @override
  Future<List<PrintJob>> jobs({
    int? terminalId,
    bool activeOnly = false,
  }) async {
    final rows = await _jobsQuery(terminalId).get();
    return _mapped(rows, activeOnly: activeOnly);
  }

  @override
  Stream<List<PrintJob>> watchJobs({int? terminalId, bool activeOnly = false}) {
    return _jobsQuery(
      terminalId,
    ).watch().map((rows) => _mapped(rows, activeOnly: activeOnly));
  }

  @override
  Future<List<PrintJob>> failInterruptedPrinting(String reason) async {
    if (reason.trim().isEmpty) {
      throw ArgumentError.value(
        reason,
        'reason',
        'причина обрыва видна оператору и не может быть пустой',
      );
    }
    // Имя состояния, а не индекс, — здесь тоже: это тот же столбец и то же
    // правило.
    final interrupted = await (_db.select(
      _db.printJobs,
    )..where((j) => j.state.equals(PrintJobState.printing.name))).get();

    final recovered = <PrintJob>[];
    for (final row in interrupted) {
      // Переход делает домен (`failWith`), а не UPDATE по колонке: правило
      // «из терминального состояния перехода нет» должно проверяться там, где
      // оно записано, а не повторяться здесь вторым экземпляром.
      final failed = _toJob(row).failWith(reason);
      await put(failed);
      recovered.add(failed);
    }
    return recovered;
  }

  @override
  Future<int> removeFinishedBefore(DateTime cutoff) async {
    final cutoffEpochMs = cutoff.millisecondsSinceEpoch;

    // Один `DELETE ... WHERE`, и ни одного связанного параметра на строку.
    //
    // Прошлая версия читала все подходящие строки, отбирала терминальные в
    // Dart и удаляла их по списку идентификаторов. У этого было **две**
    // цены, и обе оплачивались ровно тогда, когда уборка нужнее всего.
    // Во-первых, список длиннее 32 766 значений упирается в предел SQLite на
    // число переменных в запросе — то есть уборка отказывала на большой
    // таблице, а уменьшить таблицу могла только она сама. Во-вторых, чтобы
    // спросить у строки `isTerminal`, приходилось поднять её целиком —
    // вместе с байтами чека, которые здесь никому не нужны.
    //
    // Терминальность по-прежнему решает домен: [_terminalStateNames]
    // вычислены из `PrintJob.isTerminal`, а не переписаны сюда вторым
    // списком. Их ровно столько, сколько значений в перечислении, и от числа
    // строк это не зависит.
    //
    // Подтверждения не трогаются здесь ни при каких условиях — в этом весь
    // смысл раздельной уборки (см. `PrintJobStore`).
    return (_db.delete(_db.printJobs)..where(
          (j) =>
              j.updatedAtEpochMs.isSmallerThanValue(cutoffEpochMs) &
              j.state.isIn(_terminalStateNames),
        ))
        .go();
  }

  @override
  Future<int> forgetExpiredConfirmations(DateTime now) async {
    return _db.transaction(() async {
      final cutoffEpochMs = now
          .subtract(_confirmationRetention)
          .millisecondsSinceEpoch;
      var forgotten =
          await (_db.delete(_db.printJobConfirmations)..where(
                (c) => c.confirmedAtEpochMs.isSmallerThanValue(cutoffEpochMs),
              ))
              .go();

      final remaining = await _db.printJobConfirmations.count().getSingle();
      final excess = remaining - _maxRememberedConfirmations;
      if (excess > 0) {
        // Отбор самых старых сделан **подзапросом**, а не списком
        // идентификаторов, и это здесь не оптимизация, а условие
        // работоспособности правила.
        //
        // Число лишних строк равно `remaining - потолок`, поэтому длинным
        // список становится ровно тогда, когда потолок наконец сработал бы, —
        // при потолке в сто тысяч превысить предел SQLite в 32 766 переменных
        // можно только на таблице, которая давно вышла из берегов. А так как
        // весь метод идёт одной транзакцией, отказ здесь откатывал бы и
        // удаление по сроку выше. Получалось правило, которое не могло
        // сработать ни одной из двух границ, и починить себя тоже не могло:
        // сократить таблицу была способна только та самая уборка.
        //
        // `jobId` во вторичной сортировке — чтобы при совпадающем моменте
        // подтверждения выбор был определённым, а не зависел от порядка строк
        // в файле.
        final table = _db.printJobConfirmations;
        forgotten += await _db.customUpdate(
          'DELETE FROM ${table.actualTableName} '
          'WHERE ${table.jobId.name} IN ('
          '  SELECT ${table.jobId.name} FROM ${table.actualTableName}'
          '  ORDER BY ${table.confirmedAtEpochMs.name} ASC, ${table.jobId.name} ASC'
          '  LIMIT ?'
          ')',
          variables: [Variable.withInt(excess)],
          updates: {table},
        );
      }
      return forgotten;
    });
  }

  SimpleSelectStatement<db.$PrintJobsTable, db.PrintJobRow> _jobsQuery(
    int? terminalId,
  ) {
    final query = _db.select(_db.printJobs)
      ..orderBy([
        (j) => OrderingTerm(expression: j.createdAtEpochMs),
        (j) => OrderingTerm(expression: j.jobId),
      ]);
    if (terminalId != null) {
      query.where((j) => j.terminalId.equals(terminalId));
    }
    return query;
  }

  List<PrintJob> _mapped(
    List<db.PrintJobRow> rows, {
    required bool activeOnly,
  }) {
    final jobs = rows.map(_toJob);
    return [
      for (final job in jobs)
        if (!activeOnly || !job.isTerminal) job,
    ];
  }

  PrintJob _toJob(db.PrintJobRow row) => PrintJob(
    id: row.jobId,
    terminalId: row.terminalId,
    posId: row.posId,
    payloadBytes: row.payloadBytes,
    // UTC и только UTC: момент восстанавливается тот же самый, а часовой пояс
    // читателя на него не влияет. Сравнивать такие значения надо по моменту
    // (`isAtSameMomentAs`), а не по полям календаря.
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      row.createdAtEpochMs,
      isUtc: true,
    ),
    expiresAt: DateTime.fromMillisecondsSinceEpoch(
      row.expiresAtEpochMs,
      isUtc: true,
    ),
    attempts: row.attempts,
    state: _stateFromStoredName(row.state, row.jobId),
    failureReason: row.failureReason,
  );

  /// Имя состояния → значение. Неизвестное имя — **громкая** ошибка.
  ///
  /// Пропустить такую строку (как поступает
  /// `LocalDeviceBindingRepository._classFromStored` с неизвестным классом
  /// устройства) здесь нельзя: там пропуск означает «устройство не настроено»,
  /// а тут — «чек исчез», ровно тот дефект, ради которого это хранилище
  /// существует. Подставить правдоподобное состояние тем более нельзя: это
  /// заглушка из скилла `anti-gaps` в чистом виде.
  ///
  /// **Радиус поражения ограничен чтением.** [removeFinishedBefore] строки
  /// больше не разбирает — она отбирает их предикатом в SQL, — поэтому
  /// испорченная строка портит перечисление заданий, но **не** запирает
  /// уборку. Раньше запирала, и это было хуже вдвойне: убрать испорченную
  /// строку могла только та уборка, которую она же и останавливала.
  PrintJobState _stateFromStoredName(String stored, String jobId) {
    for (final value in PrintJobState.values) {
      if (value.name == stored) return value;
    }
    throw FormatException(
      'задание $jobId лежит в базе с неизвестным состоянием "$stored" — '
      'запись сделана другой сборкой; состояние не угадывается',
    );
  }
}
