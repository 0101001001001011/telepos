import 'package:injectable/injectable.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/payment_kind_dao.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/payment/payment_kind_catalog.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

/// Справочник видов оплаты поверх базы кассы.
///
/// # Что делает эта реализация сверх чтения
///
/// **Проверяет связность при записи.** Без неё справочник становится
/// способом уронить кассу настройкой: вид без счёта-получателя выбирается
/// на экране и падает при первой оплате сырым отказом базы, а тендер,
/// объявленный «не платежом», молча завышает базу налога. Семь правил
/// живут в домене ([PaymentKindRules]) — здесь только их применение и
/// перевод в отказ значением (I144).
@LazySingleton(as: PaymentKindCatalog)
class PaymentKindCatalogImpl implements PaymentKindCatalog {
  PaymentKindCatalogImpl(this._db);

  final AppDatabase _db;

  @override
  Future<List<PaymentKind>> all() async {
    final rows = await _db.paymentKindDao.allRows();
    // Строка, которую не разобрать (справочник приехал от более новой
    // сборки), **выбрасывается из списка, а не подставляется
    // умолчанием**: вид с выдуманными свойствами хуже отсутствующего —
    // его выберут.
    return [
      for (final row in rows)
        if (PaymentKindDao.toDomain(row) case final kind?) kind,
    ];
  }

  @override
  Future<List<PaymentKind>> selectable() async => [
    for (final kind in await all())
      if (kind.isActive && kind.isSelectable) kind,
  ];

  @override
  Future<PaymentKind?> byId(int id) async {
    final row = await _db.paymentKindDao.rowById(id);
    return row == null ? null : PaymentKindDao.toDomain(row);
  }

  @override
  Future<PaymentKind?> byCode(String code) async {
    final row = await _db.paymentKindDao.rowByCode(code);
    return row == null ? null : PaymentKindDao.toDomain(row);
  }

  @override
  Future<void> upsert(PaymentKind kind) async {
    final existing = await byId(kind.id);

    // Код занят **другим** видом — отдельная проверка, потому что
    // уникальный ключ по коду пришёл бы сюда сырым
    // `SqliteException(2067)` с именами столбцов схемы, уезжающими во
    // вкладку браузера. Тот же довод, что был у снятого
    // `payment_account_conflict`: отказ обязан прийти значением до
    // записи.
    final byTheCode = await byCode(kind.code);
    if (byTheCode != null && byTheCode.id != kind.id) {
      throw WireRefusal(
        kindSystemImmutableCode,
        'код «${kind.code}» уже занят видом ${byTheCode.id}',
      );
    }

    final refusal = PaymentKindRules.validate(kind, existing: existing);
    if (refusal != null) {
      throw WireRefusal(refusal, _explain(refusal, kind));
    }

    await _db.paymentKindDao.put(kind);
  }

  String _explain(String code, PaymentKind kind) => switch (code) {
    kindTenderCannotDiscountCode =>
      'вид «${kind.name}» приносит живые деньги — объявить его не платежом '
          'значит завысить базу налога',
    kindAccountMissingCode =>
      'виду «${kind.name}» не назван счёт-получатель — строке оплаты некуда '
          'лечь',
    kindCounterpartyRequiredCode =>
      'вид «${kind.name}» — обязательство, и требует названного покупателя',
    kindProviderRequiredCode =>
      'вид «${kind.name}» разговаривает с внешним провайдером — его надо '
          'требовать, иначе подтверждение не с чем сверить',
    kindFiscalKindRequiredCode =>
      'виду «${kind.name}» не названа фискальная трактовка',
    kindChangeNotATenderCode =>
      'сдачу даёт только вид, принёсший живые деньги: «${kind.name}» их не '
          'приносит',
    kindSystemImmutableCode =>
      'системный вид «${kind.name}» так менять нельзя, и системные ид заняты',
    _ => 'вид «${kind.name}» не связен',
  };
}
