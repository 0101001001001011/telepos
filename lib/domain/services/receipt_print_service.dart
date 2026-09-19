import 'package:decimal/decimal.dart';

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
  const SaleReceiptData({
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
    this.vatRatePercent = 16,
    this.currencySymbol = '₸',
    this.fiscalState,
  });

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

  final int vatRatePercent;

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
  const RefundReceiptData({
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
    this.vatRatePercent = 16,
    this.currencySymbol = '₸',
  });

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

  final int vatRatePercent;

  final String currencySymbol;

  bool get isFiscal =>
      fiscal?.hasAny ?? (fiscalNumber != null && fiscalNumber!.isNotEmpty);

  int get itemCount => products.length;
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
  }) : discountAmount = discountAmount ?? Decimal.zero;

  final String name;
  final Decimal quantity;
  final Decimal price;
  final Decimal total;
  final Decimal discountAmount;
  final Decimal? originalPrice;

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
