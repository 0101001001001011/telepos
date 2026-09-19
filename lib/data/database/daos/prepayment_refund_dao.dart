import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/prepayment_intake_tables.dart';
import 'package:telepos/domain/money/money_millis.dart';

part 'prepayment_refund_dao.g.dart';

/// Память кассы о выданных авансах — близнец `PrepaymentIntakeDao`.
///
/// # Почему близнец, а не один DAO на две таблицы
///
/// Потому что таблицы две (разбор — в докстринге `PrepaymentRefunds`), а
/// общий DAO пришлось бы учить роду доводом — то есть завести ровно то
/// место, где однажды подставят не тот род и ответят исходом соседней
/// операции. Три метода повторены дословно; расходиться им негде — у
/// каждого по одному вызывающему, и оба в одном файле
/// (`CustomerPaymentUseCaseImpl`).
///
/// # Метода «забыть» здесь нет по той же причине
///
/// Строка, стёртая после ответа, превращает следующий повтор того же ключа
/// во **вторую выдачу живых денег из ящика**.
@DriftAccessor(tables: [PrepaymentRefunds])
class PrepaymentRefundDao extends DatabaseAccessor<AppDatabase>
    with _$PrepaymentRefundDaoMixin {
  PrepaymentRefundDao(super.db);

  /// Что касса уже ответила на эту заявку. `null` — заявка новая.
  ///
  /// Читается **первой линией** заслона, до всякой записи. Вторая линия —
  /// уникальный ключ таблицы: он закрывает окно между этим чтением и
  /// вставкой, в которое помещается второй такой же кадр.
  Future<PrepaymentRefundRow?> byKey(String refundKey) =>
      (select(prepaymentRefunds)
            ..where((r) => r.refundKey.equals(refundKey))
            ..limit(1))
          .getSingleOrNull();

  /// Запомнить выдачу — **только внутри транзакции денег**.
  ///
  /// Вставка **без** `insertOrIgnore`: столкновение ключей обязано быть
  /// слышным. Молчаливое «уже есть» здесь означало бы выданные второй раз
  /// деньги, о которых никто не узнал.
  Future<int> remember({
    required String refundKey,
    required int operationId,
    required Decimal balance,
    required int time,
  }) => into(prepaymentRefunds).insert(
    PrepaymentRefundsCompanion.insert(
      refundKey: refundKey,
      operationId: operationId,
      balanceMillis: MoneyMillis.of(balance),
      time: time,
    ),
  );

  /// Дописать в память исход фискального документа возврата.
  ///
  /// Снаружи транзакции денег и по той же причине, что у приёма: это поход в
  /// сеть, а сеть внутри транзакции держит запись открытой ровно столько,
  /// сколько отвечает оператор. Отсюда то же узкое окно: повтор, доехавший
  /// между записью денег и этой дописью, получит прежний исход **без**
  /// фискального признака — законный случай, `null` у контракта уже означает
  /// «документа не было».
  Future<void> rememberFiscal({
    required String refundKey,
    String? sign,
    String? error,
  }) async {
    if (sign == null && error == null) return;
    await (update(prepaymentRefunds)
          ..where((r) => r.refundKey.equals(refundKey)))
        .write(
          PrepaymentRefundsCompanion(
            fiscalSign: Value(sign),
            fiscalError: Value(error),
          ),
        );
  }
}
