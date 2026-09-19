import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/webkassa_tables.dart';

part 'fiscal_owed_report_dao.g.dart';

/// Долг по Z-отчёту: записать, прочитать, погасить.
///
/// # Почему долг **один**, а не по одному на смену
///
/// Долг относится к смене оператора, а она у кассы одна и та же, пока её
/// не закрыл Z. Две смены кассы, закрывшиеся подряд без отчёта, — это
/// по-прежнему **один** незакрытый отчёт оператора, и гасит его один Z.
/// Поэтому [owe] при уже висящем долге новой строки не заводит, а
/// [settleAll] гасит всё разом.
///
/// # Почему строки не удаляются
///
/// Долг по Z — след денежного расхождения: был день, чей отчёт ушёл
/// позже. Удалённая строка оставила бы на этом месте пустоту,
/// неотличимую от «такого не случалось». Погашенная строка отвечает
/// «случалось, вот когда и чем закрылось».
@DriftAccessor(tables: [FiscalOwedReports])
class FiscalOwedReportDao extends DatabaseAccessor<AppDatabase>
    with _$FiscalOwedReportDaoMixin {
  FiscalOwedReportDao(super.db);

  /// Самый старый непогашенный долг, если он есть.
  Future<FiscalOwedReport?> current() =>
      (select(fiscalOwedReports)
            ..where((r) => r.settledAt.isNull())
            ..orderBy([(r) => OrderingTerm.asc(r.owedAt)])
            ..limit(1))
          .getSingleOrNull();

  /// Записать долг. Уже висящий возвращается как есть — см. докстринг
  /// класса, почему второй строки не заводится.
  Future<FiscalOwedReport> owe({
    required int shiftId,
    required DateTime at,
    required int documentsWaiting,
  }) async {
    final existing = await current();
    if (existing != null) return existing;
    final id = await into(fiscalOwedReports).insert(
      FiscalOwedReportsCompanion.insert(
        shiftId: shiftId,
        owedAt: at.millisecondsSinceEpoch ~/ 1000,
        documentsWaiting: Value(documentsWaiting),
      ),
    );
    return (select(
      fiscalOwedReports,
    )..where((r) => r.id.equals(id))).getSingle();
  }

  /// Попытка была и не удалась: причина названа, счётчик сдвинут.
  ///
  /// Счётчик двигает **sqlite**, а не Dart (`attempts = attempts + 1` в
  /// одной инструкции): читать в память и писать посчитанное — тот самый
  /// приём, которым теряются чужие записи между чтением и записью.
  Future<void> noteAttempt({required int id, required String reason}) =>
      (update(fiscalOwedReports)..where((r) => r.id.equals(id))).write(
        FiscalOwedReportsCompanion.custom(
          attempts: fiscalOwedReports.attempts + const Constant(1),
          lastError: Variable(reason),
        ),
      );

  /// Погасить **все** висящие долги: один Z закрывает смену оператора
  /// целиком, сколько бы смен кассы в неё ни попало.
  ///
  /// Возвращает число погашенных строк — ноль означает «долга не было», и
  /// вызывающий обязан отличать его от «погасили», а не считать, что
  /// сработало.
  Future<int> settleAll({required DateTime at, required String by}) =>
      (update(fiscalOwedReports)..where((r) => r.settledAt.isNull())).write(
        FiscalOwedReportsCompanion(
          settledAt: Value(at.millisecondsSinceEpoch ~/ 1000),
          settledBy: Value(by),
        ),
      );
}
