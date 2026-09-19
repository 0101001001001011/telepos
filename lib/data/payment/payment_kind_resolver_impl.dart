import 'package:injectable/injectable.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/payment_kind_dao.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/payment/payment_kind_resolver.dart';

/// Чем оплачена **эта строка** `Payments` — один ответ на дерево.
///
/// # Что было вместо него
///
/// Десять мест, каждое со своим `if` по роду счёта-получателя
/// (`PaymentKindDerivation` перечисляет их поимённо). Разъезжались они
/// молча и уже разъехались: род `agentMain` один считал наличными
/// («не банк — значит касса»), другой не считал ничем.
///
/// # Правило: сначала колонка, потом вывод
///
/// [resolve] читает `Payments.kindId`, и только при `null` (строки до
/// v41, и строки со снесённым счётом) спрашивает
/// [PaymentKindDerivation.derive]. Перевыводить записанный вид из счёта
/// значило бы затирать правду догадкой: две строки на один счёт с
/// разными видами — законны и нужны с задачи 14.
///
/// # `null` — это ответ
///
/// [resolve] возвращает `null`, когда сказать нечего: вида не записано,
/// счёт снесён, рода нет. Читатель обязан назвать это состояние
/// («Оплата» на чеке, «не знаю» в отчёте), а **не** подставлять
/// «наличные».
@LazySingleton()
class PaymentKindResolver {
  PaymentKindResolver(this._db);

  final AppDatabase _db;

  /// Кэш справочника на время одного разбора чека.
  ///
  /// Чек на десять строк оплаты иначе сходил бы в базу десять раз за
  /// одними и теми же девятью строками.
  final Map<int, PaymentKind?> _cache = <int, PaymentKind?>{};

  Future<PaymentKind?> byId(int id) async {
    if (_cache.containsKey(id)) return _cache[id];
    final row = await _db.paymentKindDao.rowById(id);
    final kind = row == null ? null : PaymentKindDao.toDomain(row);
    _cache[id] = kind;
    return kind;
  }

  /// Вид оплаты строки: записанный, иначе выведенный по роду счёта.
  Future<PaymentKind?> resolve({
    required int? kindId,
    required int? payeeAccountId,
  }) async {
    if (kindId != null) {
      final written = await byId(kindId);
      if (written != null) return written;
      // Ид записан, а строки справочника нет: чек приехал с кассы, где
      // оператор завёл свой вид. Выводить по счёту здесь **нельзя** —
      // это дало бы чужому виду наше имя. Честный ответ — «не знаю».
      return null;
    }
    if (payeeAccountId == null) return null;
    final account = await _db.accountDao.findById(payeeAccountId);
    final derived = PaymentKindDerivation.derive(account?.type);
    return derived == null ? null : byId(derived);
  }
}
