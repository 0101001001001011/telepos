import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/prepayment_intake_tables.dart';
import 'package:telepos/domain/money/money_millis.dart';

part 'prepayment_intake_dao.g.dart';

/// Память кассы о принятых авансах — чтение по ключу заявки и запись исхода.
///
/// # Почему здесь нет метода «забыть»
///
/// Потому что он и есть тот дефект, от которого эта таблица сторожит: строка,
/// стёртая после ответа, превращает следующий повтор того же ключа во второй
/// приём денег. Отсутствие метода — не забывчивость; любому, кому он
/// понадобится, придётся сначала объяснить, чем его случай отличается от
/// оборванного провода.
///
/// # Почему нет и «записать исход целиком одним вызовом»
///
/// Потому что исход рождается в два приёма, и разнести их — не небрежность, а
/// единственная честная форма. Деньги ([remember]) ложатся **внутри
/// транзакции**, вместе с самой проводкой; фискальный чек ([rememberFiscal]) —
/// снаружи, потому что это поход в сеть, а сеть внутри транзакции держит
/// запись открытой ровно столько, сколько отвечает оператор. Слить их в один
/// вызов значило бы либо втащить сеть в транзакцию, либо вынести ключ из неё —
/// и второе вернуло бы дефект целиком.
@DriftAccessor(tables: [PrepaymentIntakes])
class PrepaymentIntakeDao extends DatabaseAccessor<AppDatabase>
    with _$PrepaymentIntakeDaoMixin {
  PrepaymentIntakeDao(super.db);

  /// Что касса уже ответила на эту заявку. `null` — заявка новая.
  ///
  /// Читается **первой линией** заслона: до всякой записи, чтобы кассир
  /// получил прежний исход, а не второй взнос. Вторая линия — уникальный ключ
  /// таблицы, она закрывает окно между этим чтением и вставкой.
  Future<PrepaymentIntakeRow?> byKey(String intakeKey) =>
      (select(prepaymentIntakes)
            ..where((r) => r.intakeKey.equals(intakeKey))
            ..limit(1))
          .getSingleOrNull();

  /// Запомнить приём — **только внутри транзакции денег**.
  ///
  /// Вызывается из `CustomerPaymentUseCaseImpl._writeMoney` рядом со вставкой
  /// `cash_operations` и правкой счетов. Отдельным шагом после транзакции
  /// вызов был бы бесполезен: падение кассы между деньгами и ключом оставило
  /// бы принятые деньги без памяти о них, то есть ровно ту беду, ради которой
  /// таблица заведена.
  ///
  /// Вставка **без** `insertOrIgnore`: столкновение ключей обязано быть
  /// слышным. Молчаливое «уже есть» здесь означало бы принятые второй раз
  /// деньги, о которых никто не узнал.
  Future<int> remember({
    required String intakeKey,
    required int operationId,
    required Decimal balance,
    required int time,
  }) => into(prepaymentIntakes).insert(
    PrepaymentIntakesCompanion.insert(
      intakeKey: intakeKey,
      operationId: operationId,
      balanceMillis: MoneyMillis.of(balance),
      time: time,
    ),
  );

  /// Дописать в память исход фискального чека.
  ///
  /// # Почему дописывается, а не кладётся сразу
  ///
  /// Чек уходит оператору **после** того, как деньги записаны, и уходит по
  /// сети. Держать ради него открытой транзакцию денег значило бы дать
  /// молчащему оператору запирать кассу.
  ///
  /// Отсюда узкое окно: повтор, доехавший между записью денег и этой
  /// дописью, получит прежний исход **без** фискального признака. Это не
  /// ложь и не потеря: `fiscalSign == null` у контракта уже означает «чека не
  /// было» — законный случай (настройка выключена, весь взнос ушёл на
  /// погашение долга), и кассир на него не действует никак. Соврать в
  /// обратную сторону — ответить признаком чека, которого ещё нет, — было бы
  /// хуже: этот признак печатается.
  Future<void> rememberFiscal({
    required String intakeKey,
    String? sign,
    String? error,
  }) async {
    if (sign == null && error == null) return;
    await (update(
      prepaymentIntakes,
    )..where((r) => r.intakeKey.equals(intakeKey))).write(
      PrepaymentIntakesCompanion(
        fiscalSign: Value(sign),
        fiscalError: Value(error),
      ),
    );
  }
}
