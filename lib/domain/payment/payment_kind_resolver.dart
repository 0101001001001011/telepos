import 'package:telepos/domain/account/account_type.dart';
import 'package:telepos/domain/fiscal/bonus_account_types.dart';
import 'package:telepos/domain/payment/payment_kind.dart';

/// **«Вид оплаты выводится из типа счёта получателя» — объявлено здесь и
/// больше нигде.**
///
/// # Зачем отдельный файл под одно выражение
///
/// Тот же довод, что у [BonusAccountTypes], и он измерен на этом дереве:
/// у таблицы `Payments` **не было колонки вида оплаты вообще**, и десять
/// мест выводили вид из рода счёта-получателя каждое по-своему. Восемь
/// решающих:
///
/// - `ofd_policy.dart` — отправлять ли чек в ОФД (только безнал);
/// - `local_payment_service.dart` — раскладка наличной и безналичной части;
/// - `sale_receipt_composer.dart` — слово на печатном чеке;
/// - `on_refund_payments_use_case_impl.dart` — три ветки возврата (файл
///   снесён 2026-09-19: юзкейс был зарегистрирован в контейнере и не
///   спрошен оттуда ни разу — замер в сообщении того коммита);
/// - `refund_validation_service_impl.dart` — можно ли вернуть;
/// - `sale_use_case_impl.dart` — знак движения по счёту;
/// - `custom_bank_payments_sum_use_case_impl.dart` — банковская часть смены;
/// - `history_controller.dart` — как показать оплату в истории;
///
/// и два переносящих род наружу как вид: `sale_history_service_impl.dart`,
/// `account_visible_to_pos_use_case_impl.dart`.
///
/// Разъезжались бы они молча — и уже разъехались: род `AccountType.agentMain`
/// один считал наличными (потому что «не банк — значит касса»), другой не
/// считал ничем.
///
/// # Правило чтения: **сначала колонка, потом вывод**
///
/// [derive] зовётся **только** при `kindId == null`, то есть на строках,
/// написанных до v41. У строк, написанных после, вид записан, и
/// перевыводить его из счёта значило бы затирать правду догадкой: две
/// строки на один счёт с разными видами — законны и нужны (см. снятие
/// `payment_account_conflict`).
///
/// # Чего здесь нет
///
/// Здесь нет самого справочника: [derive] отвечает числом-ид, а свойства
/// вида (сдача, фискальная трактовка, возврат) лежат в
/// `PaymentKindCatalog` и **настраиваются**. Разделение то же, что у
/// [BonusAccountTypes] и `AccountPosting`: «какой это вид» — факт о
/// строке, «что с ним делать» — правило, которое читает факт.
abstract final class PaymentKindDerivation {
  /// Вид оплаты по роду счёта-получателя — **единственное выражение на
  /// дерево**.
  ///
  /// `null` — «классифицировать нечем», и это **не** «наличные по
  /// умолчанию». Строка со снесённым счётом честнее без вида, чем с
  /// выдуманным: выдуманный уедет в отчёт смены и в ОФД как правда.
  static int? derive(int? accountType) {
    if (accountType == null) return null;
    if (BonusAccountTypes.isBonus(accountType)) {
      return SystemPaymentKindIds.bonus;
    }
    return switch (accountType) {
      AccountType.pos || AccountType.customCash => SystemPaymentKindIds.cash,
      AccountType.customBank => SystemPaymentKindIds.card,
      // Расчёт с контрагентом — **не тендер продажи**. До v41 такие
      // строки читались «наличными» всюду, где вид выводился по правилу
      // «не банк — значит касса», и попадали в выручку смены.
      AccountType.agentMain => SystemPaymentKindIds.agentSettlement,
      _ => null,
    };
  }

  /// То же выражение для SQL — миграция v41 ходит `customStatement`-ом и
  /// никакого Dart-типа не видит.
  ///
  /// Собирается из [derive], а не пишется руками: `CASE`, отставший от
  /// правила на один род, — ровно та порча, ради которой этот файл и
  /// заведён, и покраснеть ей негде.
  static String sqlCase(String accountTypeExpr) {
    final buffer = StringBuffer('CASE $accountTypeExpr');
    final seen = <int>{};
    for (final type in <int>[
      AccountType.pos,
      AccountType.customBank,
      AccountType.customCash,
      AccountType.agentMain,
      AccountType.agentCashback,
      AccountType.teleposMain,
      AccountType.teleposBonus,
      AccountType.cashback,
    ]) {
      final kind = derive(type);
      if (kind == null || !seen.add(type)) continue;
      buffer.write(' WHEN $type THEN $kind');
    }
    buffer.write(' ELSE NULL END');
    return buffer.toString();
  }
}
