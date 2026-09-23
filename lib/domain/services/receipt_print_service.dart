import 'package:telepos/core/constants/enums/tax_treatment.dart';
import 'package:decimal/decimal.dart';
import 'package:telepos/domain/tax/tax_amounts.dart';

import 'package:telepos/domain/entities/receipt/receipt_options.dart';
import 'package:telepos/domain/print/print_document_id.dart';
import 'package:telepos/domain/print/print_queue.dart';
import 'package:telepos/domain/sale/payment_service.dart' show FiscalState;

class ReceiptSellerInfo {
  const ReceiptSellerInfo({this.binIin, this.address});

  final String? binIin;

  final String? address;
}

class ReceiptFiscalInfo {
  const ReceiptFiscalInfo({
    this.fiscalNumber,
    this.fiscalSign,
    this.rnm,
    this.znm,
    this.ofdName,
    this.ticketUrl,
    this.isOffline = false,
  });

  final String? fiscalNumber;

  final String? fiscalSign;

  final String? rnm;

  final String? znm;

  final String? ofdName;

  final String? ticketUrl;

  final bool isOffline;

  bool get hasAny =>
      fiscalNumber != null || fiscalSign != null || rnm != null || znm != null;
}

class SaleReceiptData {
  SaleReceiptData({
    required this.receiptNo,
    required this.posId,
    required this.posName,
    required this.storeName,
    required this.dateTime,
    required this.cashierName,
    required this.products,
    required this.payments,
    required this.totalAmount,
    this.change,
    this.customerName,
    this.customerPhone,
    this.fiscalNumber,
    this.isDuplicate = false,
    this.tableName,
    this.zoneName,
    this.guestCount,
    this.waiterName,
    this.serviceChargeAmount,
    this.seller,
    this.fiscal,
    this.isVatPayer = false,
    this.vatAmount,
    Decimal? vatRatePercent,
    this.taxTreatment = TaxTreatment.inclusive,
    this.hasFiscalisation = true,
    this.taxJurisdictions = const [],
    this.currencyBeforeAmount = false,
    this.currencySymbol = '₸',
    this.fiscalState,
  }) : vatRatePercent = vatRatePercent ?? Decimal.zero {
    // Сумма составляющих обязана равняться объявленной ставке.
    //
    // Расхождение — ОТКАЗ, а не молчаливое округление: чек с разбивкой,
    // которая не сходится, врёт покупателю о налоговом документе. Лучше не
    // собрать такой чек вовсе и починить настройку, чем выдать красивую
    // неправду и узнать о ней от налоговой.
    if (taxJurisdictions.isNotEmpty) {
      final sum = taxJurisdictions.fold<Decimal>(
        Decimal.zero,
        (a, j) => a + j.ratePercent,
      );
      if (sum != this.vatRatePercent) {
        throw ArgumentError(
          'Разбивка по юрисдикциям даёт $sum%, а ставка чека — '
          '${this.vatRatePercent}%. Эти два числа обязаны совпадать: '
          'покупатель читает разбивку как объяснение ставки.',
        );
      }
    }
  }

  /// Из каких юрисдикций сложилась ставка. Пусто — разбивки нет.
  final List<TaxJurisdiction> taxJurisdictions;

  /// Печатать ли знак валюты перед суммами итогов.
  ///
  /// Соглашение страны, а не налоговое правило: в США пишут `$11.93`, в
  /// Казахстане сумму оставляют голой, а `₸` ставят только у сдачи. В
  /// справочнике стран это уже есть — `currencyAfterAmount`, и у доллара
  /// он `false`.
  ///
  /// До 2026-09-21 знак валюты попадал на чек ТОЛЬКО в строке сдачи. При
  /// оплате картой сдачи нет, и в американском чеке не оказывалось ни
  /// одного доллара — нашлось на сборке демонстрационного документа.
  ///
  /// Умолчание `false` оставляет казахстанскую ленту байт в байт прежней.
  final bool currencyBeforeAmount;

  /// Сумма позиций ВНЕ обложения.
  ///
  /// Названа отдельно, а не растворена в итоге: покупатель по ней понимает,
  /// почему налог меньше, чем он прикинул по сумме чека.
  Decimal get exemptTotal => products
      .where((l) => l.isTaxExempt)
      .fold<Decimal>(Decimal.zero, (sum, l) => sum + l.total);

  /// Налог, разложенный по ставкам.
  ///
  /// Ставка позиции, если задана; иначе ставка чека. Группы идут по
  /// убыванию ставки: облагаемое выше освобождённого, как на бумаге и
  /// принято.
  ///
  /// Налог считается ПО СТРОКАМ и суммируется — так же, как его считает
  /// фискальный документ. Разница с расчётом «от итога» не теоретическая:
  /// на чеке из шести позиций при 16% она составила копейку, и бумага у
  /// покупателя расходилась с документом у налоговой.
  List<ReceiptTaxGroup> get taxByRate {
    // «Плательщик НДС» выключает налог только там, где такой регистр
    // существует.
    //
    // В США его нет: налог с продаж собирает любой продавец, у которого
    // есть облагаемые продажи, и флаг из фискальных настроек — понятие
    // чужой страны. До этой правки он выключал налоговый блок на
    // американском чеке целиком; измерено на дубле урока 1.3, 2026-09-21.
    //
    // Для уклада «налог сверху» заслонкой служит сама ставка: ноль — и
    // групп не будет без всякого флага.
    if (taxTreatment == TaxTreatment.inclusive && !isVatPayer) {
      return const [];
    }

    final bases =
        <
          String,
          ({
            Decimal rate,
            Decimal base,
            Decimal tax,
            List<TaxJurisdiction> shares,
          })
        >{};
    for (final line in products) {
      // Освобождённое в облагаемую базу не входит — ни в какую группу.
      if (line.isTaxExempt) continue;
      final rate = line.taxRatePercent ?? vatRatePercent;
      final key = rate.toString();
      final lineTax = taxTreatment == TaxTreatment.exclusive
          ? taxOnNet(line.total, rate)
          : taxFromGross(line.total, rate);
      final prev = bases[key];
      bases[key] = prev == null
          ? (rate: rate, base: line.total, tax: lineTax, shares: line.taxShares)
          : (
              rate: rate,
              base: prev.base + line.total,
              tax: prev.tax + lineTax,
              // Доли берутся у первой строки группы: у одинаковой ставки
              // состав одинаков по построению — он её и даёт.
              shares: prev.shares.isEmpty ? line.taxShares : prev.shares,
            );
    }

    final groups =
        bases.values
            .map(
              (g) => ReceiptTaxGroup(
                ratePercent: g.rate,
                base: g.base,
                tax: g.tax,
                jurisdictions: g.shares,
              ),
            )
            .toList()
          ..sort((a, b) => b.ratePercent.compareTo(a.ratePercent));
    return groups;
  }

  final int receiptNo;
  final int posId;
  final String posName;
  final String storeName;
  final DateTime dateTime;
  final String cashierName;
  final List<ReceiptProductLine> products;
  final List<ReceiptPaymentLine> payments;
  final Decimal totalAmount;
  final Decimal? change;
  final String? customerName;
  final String? customerPhone;
  final String? fiscalNumber;
  final bool isDuplicate;

  final String? tableName;
  final String? zoneName;
  final int? guestCount;
  final String? waiterName;
  final Decimal? serviceChargeAmount;

  final ReceiptSellerInfo? seller;

  final ReceiptFiscalInfo? fiscal;

  final bool isVatPayer;

  final Decimal? vatAmount;

  /// Ставка налога в процентах — дробная.
  ///
  /// Была `int`, и 8,25% ввести было нельзя вовсе: комбинированные ставки
  /// США почти всегда дробные, и целое число отсекало не «сложные штаты», а
  /// почти все. См. план `2026-09-21-us-tax-engine.md`, этап 1.
  final Decimal vatRatePercent;

  /// Как налог относится к цене в стране кассы.
  ///
  /// Умолчание — «включён в цену»: так печатали все чеки до 2026-09-21, и
  /// касса, которую не перенастраивали, обязана печатать ровно так же.
  final TaxTreatment taxTreatment;

  /// Есть ли в стране фискализация как обязанность кассы.
  ///
  /// Где её нет (США), отметка «нефискальный чек» не печатается: покупатель
  /// читает её как «чек недействителен», а не как справку о законе, которого
  /// в его стране не существует.
  final bool hasFiscalisation;

  final String currencySymbol;

  /// Чем кончилась фискализация **этого** чека, если её спрашивали.
  ///
  /// `null` — «не спрашивали»: дубликат из истории, чек, собранный не
  /// оплатой, или старая запись. Это не то же, что
  /// [FiscalState.notRequired], и печатать по `null` утверждение о
  /// причине нельзя — по той же причине, по которой
  /// `FiscalStateCodes.unknown` не совпадает ни с одним живым
  /// состоянием.
  ///
  /// Нужно затем, чтобы «НЕФИСКАЛЬНЫЙ ЧЕК» в подвале перестал быть одной
  /// строкой на три разные причины: покупателю и кассиру важно, чек не
  /// фискален потому, что так настроено, потому, что касса собрана без
  /// узла фискализации, или потому, что документ этому чеку не положен.
  final FiscalState? fiscalState;

  bool get isFiscal =>
      fiscal?.hasAny ?? (fiscalNumber != null && fiscalNumber!.isNotEmpty);

  Decimal get subtotal =>
      products.fold(Decimal.zero, (sum, p) => sum + p.total);

  Decimal get totalDiscount =>
      products.fold(Decimal.zero, (sum, p) => sum + p.discountAmount);

  int get itemCount => products.length;
}

class RefundReceiptData {
  RefundReceiptData({
    required this.refundId,
    required this.originalReceiptNo,
    required this.posId,
    required this.posName,
    required this.storeName,
    required this.dateTime,
    required this.cashierName,
    required this.products,
    required this.payments,
    required this.totalAmount,
    this.customerName,
    this.fiscalNumber,
    this.isDuplicate = false,
    this.seller,
    this.fiscal,
    this.isVatPayer = false,
    this.vatAmount,
    Decimal? vatRatePercent,
    this.taxTreatment = TaxTreatment.inclusive,
    this.hasFiscalisation = true,
    this.currencySymbol = '₸',
  }) : vatRatePercent = vatRatePercent ?? Decimal.zero;

  final int refundId;
  final int? originalReceiptNo;
  final int posId;
  final String posName;
  final String storeName;
  final DateTime dateTime;
  final String cashierName;
  final List<ReceiptProductLine> products;
  final List<ReceiptPaymentLine> payments;
  final Decimal totalAmount;
  final String? customerName;
  final String? fiscalNumber;
  final bool isDuplicate;

  final ReceiptSellerInfo? seller;

  final ReceiptFiscalInfo? fiscal;

  final bool isVatPayer;

  final Decimal? vatAmount;

  /// Ставка налога в процентах — дробная.
  ///
  /// Была `int`, и 8,25% ввести было нельзя вовсе: комбинированные ставки
  /// США почти всегда дробные, и целое число отсекало не «сложные штаты», а
  /// почти все. См. план `2026-09-21-us-tax-engine.md`, этап 1.
  final Decimal vatRatePercent;

  /// Как налог относится к цене в стране кассы.
  ///
  /// Умолчание — «включён в цену»: так печатали все чеки до 2026-09-21, и
  /// касса, которую не перенастраивали, обязана печатать ровно так же.
  final TaxTreatment taxTreatment;

  /// Есть ли в стране фискализация как обязанность кассы.
  ///
  /// Где её нет (США), отметка «нефискальный чек» не печатается: покупатель
  /// читает её как «чек недействителен», а не как справку о законе, которого
  /// в его стране не существует.
  final bool hasFiscalisation;

  final String currencySymbol;

  bool get isFiscal =>
      fiscal?.hasAny ?? (fiscalNumber != null && fiscalNumber!.isNotEmpty);

  int get itemCount => products.length;
}

/// Доля одной юрисдикции в общей ставке налога.
///
/// В США ставка складывается: штат + округ + город + спецрайоны. В Колорадо
/// города с самоуправлением администрируют свою часть сами, и разбивка на
/// чеке там не украшение. В СНГ ставка одна, и список пуст — требовать
/// разбивку везде значило бы сломать всё, что работало.
class TaxJurisdiction {
  const TaxJurisdiction({required this.name, required this.ratePercent});

  /// Название как его печатают: «State», «Denver», «RTD».
  ///
  /// Данные настройки, а не словарь: имена юрисдикций не переводятся — это
  /// названия органов, а не слова интерфейса.
  final String name;

  /// Доля этой юрисдикции в процентах.
  final Decimal ratePercent;
}

/// Сводка налога по одной ставке: сколько облагалось и сколько начислено.
///
/// Чек с разными ставками обязан показать их порознь — иначе покупатель не
/// поймёт, с чего именно взят налог. В Евросоюзе разбивка по ставкам
/// требуется прямо, в США она обычна.
class ReceiptTaxGroup {
  const ReceiptTaxGroup({
    required this.ratePercent,
    required this.base,
    required this.tax,
    this.jurisdictions = const [],
  });

  /// Ставка в процентах.
  final Decimal ratePercent;

  /// Облагаемая база — сумма позиций, облагаемых по этой ставке.
  final Decimal base;

  /// Начисленный налог.
  final Decimal tax;

  /// Из чего сложилась ИМЕННО ЭТА ставка.
  final List<TaxJurisdiction> jurisdictions;
}

class ReceiptProductLine {
  ReceiptProductLine({
    required this.name,
    required this.quantity,
    required this.price,
    required this.total,
    Decimal? discountAmount,
    this.originalPrice,
    this.discountLabel,
    this.taxRatePercent,
    this.isTaxExempt = false,
    this.taxShares = const [],
  }) : discountAmount = discountAmount ?? Decimal.zero;

  final String name;
  final Decimal quantity;
  final Decimal price;
  final Decimal total;
  final Decimal discountAmount;
  final Decimal? originalPrice;

  /// Ставка налога ИМЕННО ЭТОЙ позиции, в процентах.
  ///
  /// `null` — ставка не задана, берётся ставка чека. Так живёт Казахстан:
  /// одна ставка на всё, и правка этапа 2 его не касается.
  ///
  /// Задана — позиция облагается по ней. В США это обычное дело: продукты
  /// освобождены, готовая еда облагается, и одна ставка на чек даёт неверный
  /// налог, сколько её ни подбирай. Поле у товара в базе было
  /// (`nomenclature_tables.dart`) и доезжало до фискального оператора, но до
  /// денег и до чека не доходило никогда.
  final Decimal? taxRatePercent;

  /// Позиция ВНЕ обложения — не то же, что ставка ноль.
  ///
  /// Ставка ноль означает «облагается, но по нулевой ставке»: позиция входит
  /// в облагаемую базу, и налоговая ждёт её в отчёте. Освобождение означает
  /// «вне обложения»: в базу позиция не входит вовсе.
  ///
  /// До 2026-09-21 различить их было нечем, и на чеке обе выглядели
  /// одинаково — «0 %».
  final bool isTaxExempt;

  /// Из каких юрисдикций сложилась ставка ЭТОЙ строки.
  ///
  /// У строки, а не у чека: в Денвере еда для дома облагается городом и
  /// освобождена штатом, и состав её 6,25 % — не тот, что у обычных
  /// 9,15 %. Одна разбивка на чек утверждала бы про обе ставки один
  /// состав, и для одной из них это была бы неправда.
  final List<TaxJurisdiction> taxShares;

  /// Откуда скидка — словами, для покупателя: «подарок акции», «скидка
  /// кассира». `null` — происхождение не записано.
  ///
  /// # Почему это на бумаге, а не только в отчёте
  ///
  /// Чек — единственное, что покупатель уносит с собой, и до задачи 13
  /// он называл подарок акции просто числом: разность `priceBefore −
  /// price` не помнит, откуда взялась. Покупатель, которому пообещали
  /// «две пачки — третья даром», в чеке видел скидку без имени и не мог
  /// проверить, что акцию ему вообще применили.
  ///
  /// `null` там, где происхождения нет: чеки, проданные до v40, его не
  /// несут, и выдумывать им имя нельзя — «скидка кассира» на подарке
  /// акции хуже, чем молчание.
  final String? discountLabel;

  bool get hasDiscount => discountAmount > Decimal.zero;
}

class ReceiptPaymentLine {
  const ReceiptPaymentLine({
    required this.name,
    required this.amount,
    required this.isCash,
  });

  final String name;
  final Decimal amount;
  final bool isCash;
}

/// Печать чеков и отчётов.
///
/// ## «Принято» — это не «напечатано»
///
/// Каждый метод печати здесь **сдаёт задание в очередь** ([PrintQueue]) и
/// возвращает её ответ. Раньше эти методы возвращали `bool` и никогда причину,
/// а `true` означало «байты ушли в принтер прямо сейчас». Теперь не означает:
/// задание может напечататься через секунду, может подождать, пока в принтер
/// вложат бумагу, и может быть повторено. Разница названа в типе намеренно —
/// вызывающий, который продолжает читать ответ как «бумага вышла», должен об
/// это споткнуться при сборке, а не догадаться из поведения.
///
/// Что вызывающему **действительно** надо знать, [PrintSubmitOutcome] и
/// говорит, и ровно тремя ответами:
///
/// - [PrintSubmitStatus.accepted] — чек будет напечатан; если принтер сейчас
///   недоступен, задание лежит в хранилище и переживёт перезапуск программы;
/// - [PrintSubmitStatus.duplicate] — такой документ уже принимался, второй
///   бумаги не будет. Это **успех**, а не отказ: так выглядит корректный
///   повтор;
/// - [PrintSubmitStatus.rejected] — задание не принято, и
///   [PrintSubmitOutcome.message] говорит почему, текстом для оператора.
///
/// Экрану, которому нужно одно «показывать ли предупреждение», хватает
/// [PrintSubmitOutcome.isRejected].
///
/// ## Ни один из этих методов не является частью продажи
///
/// И30 (docs/system-architecture.md, раздел 8): отказ устройства не блокирует
/// приём денег. Сдача задания возвращается сразу и не ждёт ни соединения с
/// принтером, ни бумаги.
abstract class ReceiptPrintService {
  Future<PrintSubmitOutcome> printSaleReceipt(SaleReceiptData data);

  Future<PrintSubmitOutcome> printRefundReceipt(RefundReceiptData data);

  /// Второй экземпляр того же чека — **другое** задание, а не повтор первого:
  /// у дубликата свой номер копии в идентификаторе, поэтому очередь не примет
  /// его за уже напечатанный оригинал.
  Future<PrintSubmitOutcome> printSaleDuplicate(SaleReceiptData data);

  Future<PrintSubmitOutcome> printRefundDuplicate(RefundReceiptData data);

  /// Пробная печать с экрана настройки чека (И31).
  ///
  /// Отдельный метод, а не [printSaleReceipt] с образцом данных, и это не
  /// косметика. У образца фиксированный `receiptNo` (1024), то есть по
  /// идентификатору он **столкнулся бы с настоящим чеком №1024** той же кассы
  /// и той же смены: один из двух не напечатался бы. Пробная печать — это
  /// событие проверки оборудования, а не документ с номером, и в
  /// идентификаторе она стоит своим видом
  /// ([PrintDocumentKind.sample]).
  Future<PrintSubmitOutcome> printSampleReceipt(SaleReceiptData data);

  /// Слип подарочного сертификата — **нефискальный документ**, решение
  /// заказчика 2026-09-16: «без печати схема у прилавка не работает,
  /// покупатель уходит с пустыми руками».
  ///
  /// Печатается дважды за жизнь бумажки и обоими путями её появления:
  /// выпуском при продаже (`pay.certificateIssue`) и выпуском новой при
  /// возврате (`RefundRoute.certificate`). Фискального документа у слипа нет
  /// и быть не должно: деньги за сертификат приходят обычной строкой оплаты
  /// того чека, которым его продали, — разбор в докстринге
  /// [CertificateSlipData].
  Future<PrintSubmitOutcome> printCertificateSlip(CertificateSlipData data);

  /// # Про [certificatesIssued] и [certificatesRedeemed] — у обоих отчётов
  ///
  /// Два числа, а не одно, и оба **обязательные доводы**, а не поля с
  /// умолчанием. Довод тот же, по которому обязательна фискальная
  /// трактовка вида оплаты: забыть их нельзя по сборке. Умолчание
  /// `Decimal.zero` печатало бы честный с виду ноль на кассе, где
  /// сертификаты работают, и узнать об этом было бы неоткуда.
  ///
  /// **Они отвечают на разные вопросы и не складываются:**
  ///
  /// - [certificatesIssued] — на сколько за смену выросло обязательство
  ///   магазина. Это деньги в ящике, которые магазин ещё должен: товара на
  ///   них не отдано. Источник — номиналы бумажек
  ///   (`CertificateDao.issuedNominalBetween`).
  /// - [certificatesRedeemed] — сколько товара отдано **без живых денег**.
  ///   Источник — строки оплаты на счёт рода `certificateLiability`
  ///   (`PaymentDao.sumCertificateRedemptionsBetween`).
  ///
  /// Взять оба из одного места нельзя: строки оплаты чека, которым продали
  /// бумажку, говорят, **чем** за неё заплатили, а не какая бумажка
  /// выпущена; остаток бумажки — снимок на сейчас, а не движение за смену.
  /// Сложенные из одного источника, они разойдутся с учётом молча.
  ///
  /// # Чего эти строки НЕ делают
  ///
  /// Не уменьшают [saleTotal] и не входят в [cashInDrawer] отдельным
  /// вычетом: выручка считается по чекам целиком, а деньги в ящике — по
  /// ящику. Строки стоят рядом с итогом затем, чтобы кассир и владелец
  /// **не складывали** обязательство с выручкой, а не затем, чтобы касса
  /// пересчитала им итог.
  Future<PrintSubmitOutcome> printXReport({
    required String storeName,
    required String posName,
    required String cashierName,
    required DateTime dateTime,
    required int saleCount,
    required Decimal saleTotal,
    required int refundCount,
    required Decimal refundTotal,
    required Decimal cashInDrawer,
    required Decimal certificatesIssued,
    required Decimal certificatesRedeemed,
  });

  /// Строки сертификатов — в докстринге [printXReport]: довод, источники и
  /// чего они не делают, у обоих отчётов одни.
  Future<PrintSubmitOutcome> printZReport({
    required String storeName,
    required String posName,
    required String cashierName,
    required DateTime shiftStart,
    required DateTime shiftEnd,
    required int saleCount,
    required Decimal saleTotal,
    required int refundCount,
    required Decimal refundTotal,
    required Decimal cashStart,
    required Decimal cashEnd,
    required Decimal cashIncome,
    required Decimal cashExpense,

    /// Расхождение пересчёта с ожиданием; ноль — строки на бумаге не
    /// будет. Без него денежный блок бланка не сходился бы при любом
    /// пересчитанном ящике: «итого» не равнялось бы `начало + приход −
    /// расход`, и прочитать, откуда разница, было бы неоткуда.
    required Decimal cashDiscrepancy,
    required Decimal certificatesIssued,
    required Decimal certificatesRedeemed,
  });

  Future<PrintSubmitOutcome> printPreCheck(PreCheckData data);

  Future<PrintSubmitOutcome> printServiceIntake(ServiceReceiptData data);

  Future<PrintSubmitOutcome> printServiceCompletion(ServiceReceiptData data);

  /// Открывает денежный ящик — **мимо очереди печати, и это решение**.
  ///
  /// Импульс ящика не является заданием печати: у него нет ничего, из чего
  /// задание состоит, — ни документа, ни номера копии, ни срока. Тот же довод
  /// уже записан в `PrintQueueLocal` про опрос состояния принтера, и здесь он
  /// сильнее: очередь заставила бы ящик ждать за застрявшим чеком, то есть
  /// **отказ принтера не дал бы кассиру выдать сдачу** — ровно то, что И30
  /// запрещает. Гонка за сокетом при этом настоящая и закрыта там же, где для
  /// опроса: замком внутри драйвера. Чек уходит одной записью, поэтому
  /// импульс может встать только до или после целого чека, но не внутрь него.
  ///
  /// Возвращает `bool`, а не [PrintSubmitOutcome]: очереди здесь нет, и
  /// «принято» с «сделано» не расходятся.
  Future<bool> openCashDrawer();

  Future<bool> isPrinterAvailable();

  void invalidateReceiptOptionsCache();

  /// Ширина ленты, на которой **сейчас** напечатается чек этой кассы, — из
  /// привязки чекового принтера (`ReceiptPaperWidthSource`). Экран шаблона
  /// показывает предпросмотр именно на ней.
  Future<ReceiptPaperWidth> currentPaperWidth();

  String renderSalePreviewText(
    SaleReceiptData data,
    ReceiptOptions options, {
    required ReceiptPaperWidth paperWidth,
  });

  String renderZReportPreview({
    required ReceiptPaperWidth paperWidth,
    required String storeName,
    required String posName,
    required String cashierName,
    required DateTime shiftStart,
    required DateTime shiftEnd,
    required int saleCount,
    required Decimal saleTotal,
    required int refundCount,
    required Decimal refundTotal,
    required Decimal cashStart,
    required Decimal cashEnd,
    required Decimal cashIncome,
    required Decimal cashExpense,
    required Decimal cashDiscrepancy,
    required Decimal certificatesIssued,
    required Decimal certificatesRedeemed,
  });

  String renderXReportPreview({
    required ReceiptPaperWidth paperWidth,
    required String storeName,
    required String posName,
    required String cashierName,
    required DateTime dateTime,
    required int saleCount,
    required Decimal saleTotal,
    required int refundCount,
    required Decimal refundTotal,
    required Decimal cashInDrawer,
    required Decimal certificatesIssued,
    required Decimal certificatesRedeemed,
  });

  /// Предпросмотр слипа — **те же байты**, разобранные в текст, а не вторая
  /// раскладка. Тот же довод, что у [renderSalePreviewText].
  String renderCertificateSlipPreviewText(
    CertificateSlipData data,
    ReceiptOptions options, {
    required ReceiptPaperWidth paperWidth,
  });
}

/// Слип подарочного сертификата — то, с чем покупатель отходит от прилавка.
///
/// # Это не чек, и документ говорит об этом сам
///
/// Фискального документа у выпуска нет и быть не должно: деньги за
/// сертификат приходят обычной строкой оплаты того чека, которым его
/// продали, — сертификат в нём то, что покупают, а не то, чем платят
/// (докстринг `CertificateIssuer`). Поэтому на слипе стоит прямая пометка
/// «не фискальный документ»: без неё бумажка с номером, суммой и реквизитами
/// продавца неотличима от чека и будет предъявлена как чек.
///
/// # ПИНа здесь нет **полем**, а не по забывчивости
///
/// Печатается факт [hasPin], и только он. Номер и ПИН рядом на одной
/// бумажке — это найденная бумажка, отоваренная кем угодно; тот же довод, по
/// которому `pinHash` не едет на провод (`certificateToWireJson`). Поля под
/// ПИН нет затем, чтобы его нельзя было напечатать случайно.
///
/// # Две дороги, один документ
///
/// Слип печатается обоими путями появления бумажки: выпуском при продаже
/// (`pay.certificateIssue`) и выпуском новой при возврате
/// (`RefundRoute.certificate`). У второй [refundLocalId] и [sourceNumber]
/// названы — покупатель обязан увидеть, почему бумажка новая, иначе он
/// придёт со старой, а она погашена навсегда (решение 2, 2026-09-16).
class CertificateSlipData {
  const CertificateSlipData({
    required this.number,
    required this.amount,
    required this.dateTime,
    required this.posId,
    required this.posName,
    required this.storeName,
    required this.cashierName,
    this.expiresAt,
    this.hasPin = false,
    this.seller,
    this.refundLocalId,
    this.sourceNumber,
    this.isDuplicate = false,
  });

  /// Номер, напечатанный на бумажке. У выпущенной возвратом —
  /// `<исходный>-R<возврат>`.
  final String number;

  /// На что бумажка годна: номинал при выпуске, закрытая сумма — у
  /// выпущенной возвратом.
  final Decimal amount;

  final DateTime dateTime;

  final int posId;
  final String posName;
  final String storeName;
  final String cashierName;

  /// Когда истекает. `null` — бессрочная, и на бумаге это **слово**, а не
  /// пустое место.
  final DateTime? expiresAt;

  /// У бумажки есть ПИН. Самого ПИНа здесь нет — см. докстринг класса.
  final bool hasPin;

  final ReceiptSellerInfo? seller;

  /// Возврат, которым бумажка выпущена. `null` — обычный выпуск при продаже.
  final int? refundLocalId;

  /// Исходная бумажка, взамен которой выпущена эта.
  final String? sourceNumber;

  final bool isDuplicate;
}

class PreCheckData {
  const PreCheckData({
    required this.tableName,
    this.zoneName,
    required this.waiterName,
    required this.guestCount,
    required this.products,
    required this.totalAmount,
    this.serviceChargeAmount,
    required this.dateTime,
    required this.storeName,
  });

  final String tableName;
  final String? zoneName;
  final String waiterName;
  final int guestCount;
  final List<ReceiptProductLine> products;
  final Decimal totalAmount;
  final Decimal? serviceChargeAmount;
  final DateTime dateTime;
  final String storeName;
}

class ServiceReceiptData {
  const ServiceReceiptData({
    required this.orderNumber,
    required this.clientName,
    this.clientPhone,
    this.deviceDescription,
    this.serialNumber,
    this.complaint,
    required this.intakeDate,
    this.estimatedDate,
    this.estimatedAmount,
    this.marks = const [],
    this.totalCost,
    this.prepaidAmount,
    this.remainingAmount,
    required this.storeName,
    required this.posName,
    required this.cashierName,
  });

  final String orderNumber;
  final String clientName;
  final String? clientPhone;
  final String? deviceDescription;
  final String? serialNumber;
  final String? complaint;
  final DateTime intakeDate;
  final DateTime? estimatedDate;
  final Decimal? estimatedAmount;
  final List<ServiceReceiptMark> marks;
  final Decimal? totalCost;
  final Decimal? prepaidAmount;
  final Decimal? remainingAmount;
  final String storeName;
  final String posName;
  final String cashierName;
}

class ServiceReceiptMark {
  const ServiceReceiptMark({required this.description, this.cost});

  final String description;
  final Decimal? cost;
}
