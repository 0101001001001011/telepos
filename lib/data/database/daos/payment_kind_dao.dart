import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/payment_kind_tables.dart';
import 'package:telepos/domain/payment/payment_kind.dart';

part 'payment_kind_dao.g.dart';

/// Чтение и запись справочника видов оплаты.
///
/// **Метода `delete` здесь нет намеренно.** `Payments.kindId` ссылается на
/// строку навсегда: чек трёхлетней давности обязан читаться. Вид убирается
/// значением `isActive`.
@DriftAccessor(tables: [PaymentKinds])
class PaymentKindDao extends DatabaseAccessor<AppDatabase>
    with _$PaymentKindDaoMixin {
  PaymentKindDao(super.db);

  Future<List<PaymentKindEntry>> allRows() =>
      (select(paymentKinds)..orderBy([
            (k) => OrderingTerm(expression: k.sortOrder),
            (k) => OrderingTerm(expression: k.id),
          ]))
          .get();

  Future<PaymentKindEntry?> rowById(int id) =>
      (select(paymentKinds)..where((k) => k.id.equals(id))).getSingleOrNull();

  Future<PaymentKindEntry?> rowByCode(String code) => (select(
    paymentKinds,
  )..where((k) => k.code.equals(code))).getSingleOrNull();

  /// Записать вид целиком. `insertOnConflictUpdate` по первичному ключу:
  /// ид присвоен руками, и повторная запись того же ида — это правка, а не
  /// вторая строка.
  Future<void> put(PaymentKind kind) =>
      into(paymentKinds).insertOnConflictUpdate(companionOf(kind));

  /// Посеять вид, **не трогая уже заведённый**.
  ///
  /// `insertOrIgnore`, а не `insertOnConflictUpdate`: установка, прошедшая
  /// v41 и открытая заново (или откатившаяся к прежней сборке и поднятая
  /// снова), придёт сюда второй раз, и `insertOnConflictUpdate` **стёр бы
  /// настройку оператора** — вернул бы бонусу «карту», а выключенному
  /// сертификату включённость. Тот же довод, что у
  /// `_ensureDefaultDiscountLimit`.
  Future<void> seed(PaymentKind kind) => into(
    paymentKinds,
  ).insert(companionOf(kind), mode: InsertMode.insertOrIgnore);

  static PaymentKindsCompanion companionOf(PaymentKind kind) =>
      PaymentKindsCompanion.insert(
        id: Value(kind.id),
        code: kind.code,
        name: kind.name,
        settlement: kind.settlement.index,
        fiscalTreatment: kind.fiscalTreatment.code,
        payeeAccountType: Value(kind.payeeAccountType),
        payeeAccountId: Value(kind.payeeAccountId),
        requiresAcquiring: Value(kind.requiresAcquiring),
        requiresCounterparty: Value(kind.requiresCounterparty),
        requiresProvider: Value(kind.requiresProvider),
        givesChange: Value(kind.givesChange),
        refundAllowed: Value(kind.refundAllowed),
        isActive: Value(kind.isActive),
        isSystem: Value(kind.isSystem),
        isSelectable: Value(kind.isSelectable),
        sortOrder: Value(kind.sortOrder),
      );

  /// Строка справочника → домен.
  ///
  /// Незнакомые `settlement`/`fiscalTreatment` (строка приехала от более
  /// новой сборки) дают `null`, а не выдуманное значение: разбор — в
  /// `PaymentSettlement.byIndex`.
  static PaymentKind? toDomain(PaymentKindEntry row) {
    final settlement = PaymentSettlement.byIndex(row.settlement);
    final treatment = FiscalTreatment.byCode(row.fiscalTreatment);
    if (settlement == null || treatment == null) return null;
    return PaymentKind(
      id: row.id,
      code: row.code,
      name: row.name,
      settlement: settlement,
      fiscalTreatment: treatment,
      payeeAccountType: row.payeeAccountType,
      payeeAccountId: row.payeeAccountId,
      requiresAcquiring: row.requiresAcquiring,
      requiresCounterparty: row.requiresCounterparty,
      requiresProvider: row.requiresProvider,
      givesChange: row.givesChange,
      refundAllowed: row.refundAllowed,
      isActive: row.isActive,
      isSystem: row.isSystem,
      isSelectable: row.isSelectable,
      sortOrder: row.sortOrder,
    );
  }
}
