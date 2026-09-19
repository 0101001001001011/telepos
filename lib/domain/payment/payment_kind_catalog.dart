import 'package:telepos/domain/payment/payment_kind.dart';

/// Справочник видов оплаты как контракт.
///
/// Чистый Dart: ни Flutter, ни drift. Реализация кассовая
/// (`PaymentKindCatalogImpl` поверх `PaymentKindDao`).
///
/// # Удаления нет
///
/// У контракта **нет** метода `delete`, и это не забывчивость.
/// `Payments.kindId` ссылается на строку справочника навсегда: чек
/// трёхлетней давности обязан читаться. Вид убирается из селектора
/// значением [PaymentKind.isActive] и остаётся в истории.
abstract class PaymentKindCatalog {
  /// Все виды, включая выключенные и нескрываемые. Порядок —
  /// [PaymentKind.sortOrder], затем ид.
  Future<List<PaymentKind>> all();

  /// Виды, которые можно предложить кассиру: [PaymentKind.isActive] и
  /// [PaymentKind.isSelectable].
  Future<List<PaymentKind>> selectable();

  Future<PaymentKind?> byId(int id);

  Future<PaymentKind?> byCode(String code);

  /// Завести или изменить вид. Проверяет связность семью правилами
  /// ([PaymentKindRules]) и отказывает **значением** (`WireRefusal`), а не
  /// исключением наружу (I144).
  Future<void> upsert(PaymentKind kind);
}

/// Тендер объявлен «не платежом» в фискальном документе.
///
/// Живые деньги, не попавшие в фискальный документ платежом, — это
/// **завышенная база налога**: сумма чека остаётся, а платёж исчезает.
/// Ровно поэтому бонус ([PaymentSettlement.offset]) объявлять не-платежом
/// можно и нужно, а наличные — нельзя никогда.
const kindTenderCannotDiscountCode = 'kind_tender_cannot_discount';

/// Виду, приносящему или зачитывающему деньги, не назван счёт-получатель.
///
/// Без счёта строка `Payments` лечь **некуда**: у неё
/// `payeeAccountId NOT NULL`. Справочник без этой проверки становится
/// способом уронить кассу настройкой — вид выбирается, оплата падает.
const kindAccountMissingCode = 'kind_account_missing';

/// Обязательство без обязанного.
///
/// [PaymentSettlement.deferred] означает «деньги вместо денег обещаны», а
/// обещание без названного покупателя — деньги, отданные в никуда.
const kindCounterpartyRequiredCode = 'kind_counterparty_required';

/// Вид разговаривает с внешним провайдером, но провайдера не требует.
///
/// [FiscalTreatment.mobile] — это QR/СБП: подтверждение приходит снаружи,
/// и без `Payments.providerCode` строку потом не с чем сверить.
const kindProviderRequiredCode = 'kind_provider_required';

/// Фискальная трактовка не названа или не разобрана.
///
/// Умолчания здесь нет и быть не может: «как вид называется оператору» —
/// страновое решение, и выдуманное значение уехало бы в ОФД молча.
const kindFiscalKindRequiredCode = 'kind_fiscal_kind_required';

/// Сдача с не-тендера.
///
/// Сертификат со сдачей — это способ **обналичить** сертификат; зачёт со
/// сдачей — способ обналичить бонус. Живые деньги из ящика выдаёт только
/// вид, который живые деньги в ящик принёс.
const kindChangeNotATenderCode = 'kind_change_not_a_tender';

/// Попытка изменить неизменяемое у системного вида — или занять
/// системный ид.
///
/// Ид и код системного вида лежат в `Payments.kindId` на всех кассах
/// сети. Настраивать у него можно всё остальное: имя, счёт, фискальную
/// трактовку, возврат, включённость.
const kindSystemImmutableCode = 'kind_system_immutable';

/// Семь правил связности справочника — **чистая функция, читаемая и
/// кассой, и пробой**.
///
/// Возвращает код отказа или `null`, если вид связен. Живёт в домене, а
/// не в реализации, ровно затем, чтобы у проверки был **один** текст:
/// вторая копия правил в экране настроек разошлась бы с первой молча.
abstract final class PaymentKindRules {
  /// Все семь кодов — в порядке проверки. Читается сторожем: правило без
  /// кода и код без правила одинаково бесполезны.
  static const List<String> codes = <String>[
    kindSystemImmutableCode,
    kindFiscalKindRequiredCode,
    kindTenderCannotDiscountCode,
    kindAccountMissingCode,
    kindCounterpartyRequiredCode,
    kindProviderRequiredCode,
    kindChangeNotATenderCode,
  ];

  /// [existing] — строка справочника, которую [kind] заменяет, или `null`
  /// при заведении нового вида.
  static String? validate(PaymentKind kind, {PaymentKind? existing}) {
    // 1. Системное неизменяемо, системные ид заняты.
    if (existing != null && existing.isSystem) {
      if (kind.code != existing.code ||
          kind.id != existing.id ||
          !kind.isSystem ||
          kind.settlement != existing.settlement) {
        return kindSystemImmutableCode;
      }
    }
    if (existing == null &&
        (kind.id < SystemPaymentKindIds.firstUserId || kind.isSystem)) {
      return kindSystemImmutableCode;
    }

    // 2. Фискальная трактовка названа. Проверка здесь выглядит
    // тавтологией (тип не позволяет `null`), и она ею **не является**:
    // вид приезжает с экрана настроек и из выгрузки строкой, и
    // `FiscalTreatment.byCode` на незнакомом слове отдаёт `null`. Ветка
    // достижима ровно оттуда.
    if (!FiscalTreatment.values.contains(kind.fiscalTreatment)) {
      return kindFiscalKindRequiredCode;
    }

    // 3. Тендер не бывает «не платежом».
    if (kind.settlement == PaymentSettlement.tender &&
        kind.fiscalTreatment == FiscalTreatment.notAPayment) {
      return kindTenderCannotDiscountCode;
    }

    // 4. Тендеру и зачёту нужен счёт-получатель — **у включённого вида**.
    //
    // Оговорка про включённость не поблажка, а место проверки. Виды 5–8
    // заведены выключенными и без счёта нарочно: назвать счёт за
    // оператора значило бы записать решение, которого он не принимал.
    // Спрашивается счёт ровно в тот момент, когда вид включают, — и
    // тогда отказ читается как «включить вид, которому деньги некуда
    // класть, нельзя», а не как загадка при первой продаже.
    if (kind.isActive &&
        kind.settlement != PaymentSettlement.deferred &&
        kind.payeeAccountType == null &&
        kind.payeeAccountId == null) {
      return kindAccountMissingCode;
    }

    // 5. Обязательство требует обязанного — **всегда**, включён вид или
    // нет: это утверждение о смысле, а не о готовности к работе.
    if (kind.settlement == PaymentSettlement.deferred &&
        !kind.requiresCounterparty) {
      return kindCounterpartyRequiredCode;
    }

    // 6. Внешний провайдер обязан быть назван — у включённого, по тому же
    // доводу, что и счёт.
    if (kind.isActive &&
        kind.fiscalTreatment == FiscalTreatment.mobile &&
        !kind.requiresProvider) {
      return kindProviderRequiredCode;
    }

    // 7. Сдачу даёт только тендер.
    if (kind.givesChange && kind.settlement != PaymentSettlement.tender) {
      return kindChangeNotATenderCode;
    }

    return null;
  }
}
