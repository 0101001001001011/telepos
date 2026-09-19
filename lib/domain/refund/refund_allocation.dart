import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import 'package:telepos/domain/account/account_type.dart';
import 'package:telepos/domain/payment/payment_kind.dart';

/// Куда уходят деньги возврата — **одно место в домене**, задача 26.
///
/// Чистый Dart: ни Flutter, ни drift. Зовут его двое — касса, проводя
/// возврат (`RefundUseCaseImpl.perform`), и снимок черновика, показывая
/// кассиру и браузерному терминалу, куда уйдут деньги **до** подтверждения
/// (`LocalRefundService`). Второй копии правила нет ни на экране, ни на
/// проводе: терминал получает готовые строки.
///
/// # Правило: деньги уходят тем видом, каким пришли
///
/// Каждая строка оплаты чека отвечает на вопрос «куда вернуть свою долю»
/// сама — по виду из справочника ([routeOf]). Наличные — из ящика; карта —
/// на карту по транзакции эквайринга; QR — через провайдера по намерению;
/// сертификат — на бумажку; аванс — в аванс; бонус — на бонусный счёт;
/// долг — уменьшением долга.
///
/// # Правило частичного возврата: **живые деньги из ящика — последними**
///
/// Возврат целиком раскладывается одинаково при любом порядке: каждая
/// строка получает всё, что принесла. Порядок решает только частичный
/// возврат, и выбран он по сути, а не по удобству:
///
/// 1. **Долг** — первым. Покупатель возвращает товар, за который ещё не
///    заплатил. Выдать ему наличные при живом долге значит отдать деньги
///    человеку, который кассе должен: чек 400 наличными + 600 в долг,
///    возврат 500 пропорцией отдавал из ящика 200 и оставлял долг 300.
/// 2. **Бонус, сертификат, аванс** — затем, в порядке цепочки зачётов
///    продажи (`OffsetChain`). Это деньги, которых на этом чеке в ящик не
///    приходило, и превращать их в наличные — обнал, запрещённый уже у
///    сдачи (`PaymentKind.givesChange = false` у сертификата). Пропорция
///    отдавала с чека «500 сертификатом + 500 наличными» при возврате
///    половины 250 наличными — половину бумажки деньгами.
/// 3. **Безнал — QR и карта** — затем. Это живые деньги, но не из ящика:
///    они возвращаются туда, откуда пришли (правила платёжных систем
///    требуют возврата на ту же карту), и превращать карту в наличные —
///    тот же обнал.
/// 4. **Наличные** — последними.
///
/// Внутри одного класса строки идут в порядке чека (`seq`).
///
/// # Почему QR не стоит в цепочке зачётов, как в продаже
///
/// В `OffsetChain` QR идёт вторым, потому что там решается **чья комната
/// дороже** — у QR деньги уже взяты. Здесь решается другое: **что не
/// должно стать наличными**. QR — живые деньги покупателя в банке, а не
/// зачёт; поставить его перед сертификатом значило бы при частичном
/// возврате отдать в банк деньги сертификата.
///
/// # Прежних возвратов того же чека раскладка НЕ знает — замер 2026-09-19
///
/// И знать ей не нужно, но держится это не на ней. [allocate] отдаёт каждой
/// строке всё, что та принесла ([RefundSource.paid]), сколько раз её ни
/// спроси: второй возврат того же чека получил бы ту же раскладку и выдал
/// бы те же деньги второй раз. Измерено диверсией — с чека «300
/// сертификатом + 700 наличными» два возврата по 300 выпустили **две**
/// новые бумажки по 300 за одну строку оплаты на 300.
///
/// Невозможен этот второй возврат не здесь, а в **структуре**:
/// `Refunds.uniqueKeys = [{saleReceiptNo, salePosId}]` не даёт записать
/// вторую строку возврата на тот же чек, и `LocalRefundService` называет
/// эту причину кассиру дважды — при загрузке чека и при завершении
/// черновика. Проба обоих концов —
/// `test/data/refund/refund_repeat_partial_test.dart`.
///
/// **Меняешь одно — перечитай другое.** Снимут ключ (ради обмена между
/// кассами, ради частичных возвратов по частям) — и правило «каждая строка
/// отдаёт не больше, чем принесла» перестанет быть правдой, потому что оно
/// про **один** возврат, а не про их сумму.
///
/// # Остаток сверх строк чека
///
/// Сумма возврата не бывает больше суммы строк: касса ограничивает её
/// проданным. Но строк может не быть вовсе (возврат без чека, чек до v41
/// без строк оплаты), а округление может оставить копейки. Остаток уходит
/// **из ящика отдельной строкой** ([RefundPart.unmatched]) — как до задачи
/// 26, и видно это названием, а не молчанием.
abstract final class RefundAllocation {
  /// Разложить [amount] по строкам оплаты [sources].
  ///
  /// Каждая строка отдаёт не больше, чем принесла ([RefundSource.paid]).
  static List<RefundPart> allocate({
    required Decimal amount,
    required List<RefundSource> sources,
  }) {
    final ordered = [...sources]
      ..sort((a, b) {
        final byClass = a.route.priority.compareTo(b.route.priority);
        return byClass != 0 ? byClass : a.seq.compareTo(b.seq);
      });

    final parts = <RefundPart>[];
    var left = amount;
    for (final source in ordered) {
      if (left <= Decimal.zero) break;
      if (source.paid <= Decimal.zero) continue;
      final taken = source.paid < left ? source.paid : left;
      parts.add(RefundPart(source: source, amount: taken));
      left -= taken;
    }
    if (left > Decimal.zero) {
      parts.add(RefundPart.unmatched(left));
    }
    return List.unmodifiable(parts);
  }

  /// Куда возвращается доля строки этого вида.
  ///
  /// Спрашивается **справочник**, а не список ид: оператор вправе завести
  /// свой вид, и возврат обязан узнать его так же, как продажа.
  ///
  /// [bonusAccount] — строка лежит на бонусном счёте. Бонус узнаётся по
  /// **счёту**, а не по виду — тот же признак, что у журнала бонусов
  /// (`BonusAccountTypes.isBonus`), иначе одна и та же строка читалась бы
  /// бонусом в одном месте и авансом в другом.
  ///
  /// [transactionId] — строка карты, проведённая через терминал этой
  /// кассы. Без неё карта проводилась на отдельном устройстве, и вернуть
  /// её касса может только записью, а деньги кассир возвращает там же, где
  /// принимал ([RefundRoute.manual]).
  static RefundRoute routeOf({
    required PaymentKind? kind,
    required bool bonusAccount,
    String? transactionId,
  }) {
    if (bonusAccount) return RefundRoute.bonus;
    // Строка без вида — до v41. До задачи 26 такая строка уходила из
    // ящика в составе общей суммы, и перевыводить ей вид неоткуда.
    if (kind == null) return RefundRoute.drawer;
    if (kind.isDeferred) return RefundRoute.debt;
    if (kind.payeeAccountType == AccountType.certificateLiability) {
      return RefundRoute.certificate;
    }
    if (kind.settlement == PaymentSettlement.offset) return RefundRoute.advance;
    if (kind.requiresProvider) return RefundRoute.provider;
    if (kind.requiresAcquiring) {
      return transactionId == null || transactionId.isEmpty
          ? RefundRoute.manual
          : RefundRoute.card;
    }
    return kind.payeeAccountType == AccountType.pos
        ? RefundRoute.drawer
        : RefundRoute.manual;
  }
}

/// Куда уходит доля возврата.
///
/// Коды ([code]) едут по проводу строкой и лежат в переводах экрана:
/// **порядок членов не значим**, значимо имя.
enum RefundRoute {
  /// Уменьшение долга покупателя. Денег не выходит.
  debt(0),

  /// Обратно на бонусный счёт — записью журнала бонусов.
  bonus(1),

  /// Обратно на сертификат.
  certificate(2),

  /// Обратно в аванс покупателя.
  advance(3),

  /// Через провайдера QR/СБП — по намерению.
  provider(4),

  /// На карту — возврат транзакции через платёжный терминал кассы.
  card(4),

  /// Тем же способом, каким приняли, **вне кассы**: карта, проведённая на
  /// отдельном терминале, или вид оплаты оператора со своим счётом. Касса
  /// записывает возврат этим видом; деньги возвращает кассир там же.
  manual(4),

  /// Наличные из денежного ящика.
  drawer(5);

  const RefundRoute(this.priority);

  /// Класс в правиле частичного возврата — меньший отдаёт первым.
  final int priority;

  String get code => name;

  static RefundRoute? byCode(String? value) {
    for (final r in values) {
      if (r.name == value) return r;
    }
    return null;
  }

  /// Деньги этой доли идут через внешнюю систему, и касса обязана получить
  /// её согласие **до** записи возврата.
  bool get isExternal => this == card || this == provider;
}

/// Строка оплаты чека — то, из чего возвращают.
@immutable
class RefundSource {
  const RefundSource({
    required this.seq,
    required this.route,
    required this.paid,
    this.kindId,
    this.kindName,
    this.payeeAccountId,
    this.reference,
    this.transactionId,
    this.cardMask,
    this.refundAllowed = true,
  });

  /// Порядок строки в чеке.
  final int seq;

  final RefundRoute route;

  /// Сколько строка принесла.
  final Decimal paid;

  final int? kindId;

  /// Как вид назван в справочнике — для экрана и чека.
  final String? kindName;

  final int? payeeAccountId;

  /// Документ-основание: номер сертификата, аванса, ключ намерения QR.
  final String? reference;

  /// Транзакция эквайринга или ид намерения у провайдера.
  final String? transactionId;

  final String? cardMask;

  /// `PaymentKind.refundAllowed` вида этой строки.
  final bool refundAllowed;

  @override
  String toString() => 'RefundSource(#$seq ${route.code} $paid)';
}

/// Доля возврата, пришедшаяся на одну строку оплаты.
@immutable
class RefundPart {
  const RefundPart({required RefundSource this.source, required this.amount});

  /// Остаток сверх строк чека — из ящика (докстринг [RefundAllocation]).
  const RefundPart.unmatched(this.amount) : source = null;

  /// `null` — [unmatched].
  final RefundSource? source;

  final Decimal amount;

  bool get unmatched => source == null;

  RefundRoute get route => source?.route ?? RefundRoute.drawer;

  @override
  String toString() => 'RefundPart(${route.code} $amount)';
}
