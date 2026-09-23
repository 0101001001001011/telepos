/// Слова кассовых операций — для человека, на языке интерфейса.
///
/// # Что здесь уже было правильно, а что нет
///
/// Расширение [ExpenseTypeLocalization] жило в `cash_operation_form.dart` и
/// работало: выпадающий список родов расхода на английской кассе был
/// английским. Оно и переехало сюда — целиком, без второй редакции, —
/// потому что у него появился ВТОРОЙ вызывающий: список операций на экране
/// смены.
///
/// Неправильным было другое, и не в форме, а в базе. Основание операции не
/// имело столбца: касса склеивала русское слово с комментарием человека
/// (`'Зарплата: за август'`, `'Погашение рассрочки №12'`) и писала эту
/// строку в `cash_operations.note`. Слово для человека, записанное в
/// историю, нельзя ни перевести, ни просуммировать — «сколько ушло на
/// зарплату» пришлось бы считать разбором русской прозы по двоеточию.
/// С v58 основание хранится числом (`CashOperations.reasonCode`),
/// примечание несёт только напечатанное человеком, а склейка происходит
/// ПРИ ПОКАЗЕ — [cashOperationSubtitle].
///
/// Попутно снят мёртвый набор ключей `cashSalary`, `cashUtilities`,
/// `cashOther`, `cashSupplies`, `cashRent`: он остался от времени до этого
/// расширения, лежал во всех пяти словарях и не спрашивался нигде. Мёртвый
/// ключ опаснее отсутствующего — по словарю кажется, что переведено. Живой
/// набор один: `expenseType*`.
///
/// Сторож — `test/architecture/display_words_live_in_l10n_test.dart`.
library;

import 'package:telepos/domain/cash/cash_operation_kind.dart';
import 'package:telepos/domain/usecases/cash_operation/cash_in_out_controller.dart';
import 'package:telepos/l10n/app_localizations.dart';

/// Локализованное имя [ExpenseType].
///
/// Раньше жило в домене как метод самого перечисления — единственное, ради
/// чего домен тянул `package:telepos/l10n/`, а тот, в свою очередь,
/// `package:flutter/...`. Язык интерфейса — дело презентации, и слово
/// живёт здесь.
extension ExpenseTypeLocalization on ExpenseType {
  String localizedName(AppLocalizations l10n) {
    switch (this) {
      case ExpenseType.other:
        return l10n.expenseTypeOther;
      case ExpenseType.smallPurchases:
        return l10n.expenseTypeSmallPurchases;
      case ExpenseType.salary:
        return l10n.expenseTypeSalary;
      case ExpenseType.utilities:
        return l10n.expenseTypeUtilities;
      case ExpenseType.collection:
        return l10n.expenseTypeCollection;
      case ExpenseType.custom:
        return l10n.expenseTypeCustom;
    }
  }
}

/// Слово по коду основания из базы; `null` — основание не записано.
///
/// Пусто у строк старше v58: у них основание осталось внутри примечания, и
/// притворяться, будто оно известно, нельзя — подпись таким строкам даёт
/// само примечание. Разбирать прозу ради них значило бы закрепить ту самую
/// ошибку, из-за которой столбец и заведён.
///
/// Пространство кодов — в `domain/cash/cash_operation_kind.dart`: 0–5 роды
/// расхода, от 100 основания, которые ставит сама касса.
String? cashReasonLabel(int? code, AppLocalizations l10n) {
  if (code == null) return null;
  switch (code) {
    case kCashReasonCreditRepayment:
      return l10n.cashReasonCreditRepayment;
    case kCashReasonCustomerTopUp:
      return l10n.cashReasonCustomerTopUp;
  }
  if (code < 0 || code >= ExpenseType.values.length) return null;
  return ExpenseType.values[code].localizedName(l10n);
}

/// Подпись кассовой операции: род расхода, комментарий человека, или оба.
///
/// Порядок тот же, каким до v58 склеивала касса, — род, двоеточие,
/// комментарий. Разница в том, что теперь склейка происходит при показе и
/// на языке интерфейса, а в истории лежат раздельно число и текст.
String? cashOperationSubtitle({
  required int? reasonCode,
  required String? note,
  required AppLocalizations l10n,
}) {
  final typed = cashReasonLabel(reasonCode, l10n);
  final human = (note != null && note.trim().isNotEmpty) ? note.trim() : null;

  if (typed == null) return human;
  if (human == null) return typed;
  return '$typed: $human';
}
