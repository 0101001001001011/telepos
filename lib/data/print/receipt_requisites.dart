/// Реквизиты чека — продавец, НДС, фискальный признак.
///
/// **Жил в `lib/presentation/screens/payment/receipt_data_enricher.dart`
/// до задачи 16.** Переехал не ради порядка: с задачи 16 чек собирает и
/// печатает **касса** (`LocalPaymentService`), а не экран, и файл в
/// `lib/presentation/` кассе недоступен — импорт `data → presentation`
/// перевернул бы слои. Второй читатель, `refund_screen.dart`, остался на
/// месте: возврат за контракт ещё не ушёл (фаза 7 плана), и трогать его
/// здесь значило бы делать чужую задачу.
library;

import 'package:telepos/core/constants/enums/country_code.dart';
import 'package:telepos/core/constants/enums/tax_treatment.dart';
import 'package:telepos/domain/fiscal/fiscal_doc_kind.dart';
import 'package:decimal/decimal.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/usecases/fiscal/fiscal_position_builder.dart';
import 'package:telepos/domain/services/receipt_print_service.dart';
import 'package:telepos/domain/usecases/fiscal/fiscal_service.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';

class ReceiptRequisites {
  const ReceiptRequisites({
    required this.seller,
    required this.fiscal,
    required this.isVatPayer,
    required this.vatRatePercent,
    required this.currencySymbol,
    // Умолчания равны поведению до правки: «налог в цене», знак после
    // суммы, фискализация есть. Обязательными их делать незачем — в бою
    // реквизиты собираются ровно одним местом, которое их задаёт, а
    // десяткам проб пришлось бы повторять казахстанскую тройку ради
    // вопроса, о котором они не спрашивают.
    this.taxTreatment = TaxTreatment.inclusive,
    this.currencyBeforeAmount = false,
    this.hasFiscalisation = true,
  });

  final ReceiptSellerInfo seller;
  final ReceiptFiscalInfo? fiscal;
  final bool isVatPayer;

  /// Ставка налога в процентах — дробная (этап 1 плана налогового
  /// движка). Была `int`, и 8,25% ввести было нельзя.
  final Decimal vatRatePercent;
  final String currencySymbol;

  /// Налог в цене или сверх неё.
  ///
  /// Настройкой кассы, а не выводом из страны: страна даёт умолчание, но
  /// последнее слово за пользователем. До этой правки чек всегда собирался
  /// как «налог включён в цену» — на кассе США это молча меняло суммы.
  final TaxTreatment taxTreatment;

  /// `$11.93`, а не `11.93$`.
  ///
  /// Свойство страны, а не вкуса: до этой правки знак всегда печатался
  /// после суммы, и американский чек выглядел чужим.
  final bool currencyBeforeAmount;

  /// Есть ли в стране фискализация как обязанность кассы.
  ///
  /// В США её нет, и печатать пустой фискальный блок значит обещать
  /// покупателю документ, которого не существует.
  final bool hasFiscalisation;

  Decimal? vatFromGross(Decimal grossTotal) => isVatPayer
      ? FiscalPositionBuilder.vatFromGross(grossTotal, vatRatePercent)
      : null;

  /// Налог по СТРОКАМ, с суммированием, — так же, как его считает
  /// фискальный документ.
  ///
  /// # Зачем отдельно от [vatFromGross]
  ///
  /// Фискальный документ везёт налог **по каждой позиции**
  /// (`FiscalPositionBuilder.buildTax` → `vatFromGross(lineTotal, rate)`), а
  /// чек до 2026-09-21 считал его **один раз от суммы чека**. Это не одно и
  /// то же: округление по строкам накапливается.
  ///
  /// Замерено на чеке из шести позиций при ставке 16%: по строкам 615.24,
  /// от суммы 615.23. Копейка — но бумага у покупателя и документ у
  /// налоговой расходились, и расходились молча.
  ///
  /// Главным считается построчный способ: его видит налоговая, и чек обязан
  /// совпадать с документом, а не наоборот.
  Decimal? vatFromLines(Iterable<Decimal> lineTotals) {
    if (!isVatPayer) return null;
    final rate = vatRatePercent;
    return lineTotals
        .map((total) => FiscalPositionBuilder.vatFromGross(total, rate))
        .fold<Decimal>(Decimal.zero, (sum, vat) => sum + vat);
  }
}

Future<ReceiptRequisites> buildReceiptRequisites(
  AppDatabase db, {
  required int? posId,
  required int? operationId,
  required bool isSale,
  String? fallbackFiscalNumber,
}) async {
  String? binIin;
  bool isVatPayer = true;
  String currencySymbol = '₸';
  String? ofdName;
  String? rnm;
  String? znm;
  // Дробная: настройки фискализации везут `Decimal`, и до 2026-09-21 его
  // усекали ровно здесь — `fs.vatRatePercent.toBigInt().toInt()`. То есть
  // дробная ставка в продукте частично БЫЛА, и терялась на одной строке
  // по дороге к чеку.
  Decimal vatRatePercent = FiscalDefaults.vatRatePercent;
  String? address;
  var taxTreatment = TaxTreatment.inclusive;
  var currencyBeforeAmount = false;
  var hasFiscalisation = true;

  try {
    final pos = await db.thisPosDao.get();
    binIin = pos?.iinbin;
    isVatPayer = pos?.isVatPayer ?? true;
    if (pos?.currencySymbol != null && pos!.currencySymbol!.isNotEmpty) {
      currencySymbol = pos.currencySymbol!;
    }

    // Уклад — из настройки кассы; сторона знака и фискализация — свойства
    // страны. До этой правки все три брались умолчанием конструктора, и
    // чек США собирался как казахстанский: налог в цене, знак после суммы,
    // пустой фискальный блок.
    // Адрес кассы главнее конфига ОФД: он есть в любой стране, а конфиг —
    // только там, где фискализация обязательна.
    if (pos?.storeAddress != null && pos!.storeAddress!.isNotEmpty) {
      address = pos.storeAddress;
    }

    taxTreatment = TaxTreatment.values[pos?.taxTreatment ?? 0];
    final code = pos?.countryCode;
    if (code != null && code >= 0 && code < CountryCode.values.length) {
      final country = CountryCode.values[code];
      currencyBeforeAmount = !country.currencyAfterAmount;
      hasFiscalisation = country.hasFiscalisation;
      // Разделители — по маске страны: «84-1234567», а не «841234567».
      // Девять голых цифр на американском чеке читаются как чужой номер.
      if (binIin != null && binIin.isNotEmpty) {
        binIin = country.formatTaxId(binIin);
      }
    }
  } catch (_) {}

  try {
    if (GetIt.I.isRegistered<FiscalSettingsSource>()) {
      final fs = await GetIt.I<FiscalSettingsSource>().load();
      // Только там, где фискализация есть. Настройки фискального оператора
      // — понятия его страны, и в США их нет: `isVatPayer` там по
      // умолчанию `false` и выключал бы налог с продаж целиком.
      if (hasFiscalisation) {
        isVatPayer = fs.isVatPayer;
        vatRatePercent = fs.vatRatePercent;
      }
    }
  } catch (_) {}

  WebkassaConfig? config;
  try {
    final dao = db.webkassaReceiptDao;
    config = posId != null
        ? await dao.getConfig(posId)
        : await dao.getFirstConfig();
    if (config != null) {
      address ??= config.address;
      ofdName = config.ofdName;
      rnm = config.taxDeptRegNo;
      znm = config.posFactoryNo;
      if ((binIin == null || binIin.isEmpty) &&
          (config.iinBin?.isNotEmpty ?? false)) {
        binIin = config.iinBin;
      }
      isVatPayer = isVatPayer && config.isTaxpayer;
    }
  } catch (_) {}

  String? fiscalNo = fallbackFiscalNumber;
  String? ticketUrl;
  bool isOffline = false;
  try {
    if (operationId != null) {
      final receipt = await db.webkassaReceiptDao.findByKindAndOperationId(
        isSale ? FiscalDocKind.sale : FiscalDocKind.refund,
        operationId,
      );
      if (receipt != null) {
        fiscalNo = receipt.fiscalNo ?? fiscalNo;
        ticketUrl = receipt.ticketUrl;
        isOffline = receipt.wkOfflineMode ?? false;
        rnm = receipt.registrationNumber ?? rnm;
      }
    }
  } catch (_) {}

  ReceiptFiscalInfo? fiscal;
  final hasFiscalData =
      (fiscalNo?.isNotEmpty ?? false) ||
      (rnm?.isNotEmpty ?? false) ||
      (znm?.isNotEmpty ?? false);
  if (hasFiscalData) {
    fiscal = ReceiptFiscalInfo(
      fiscalNumber: fiscalNo,
      rnm: rnm,
      znm: znm,
      ofdName: ofdName,
      ticketUrl: ticketUrl,
      isOffline: isOffline,
    );
  }

  return ReceiptRequisites(
    seller: ReceiptSellerInfo(binIin: binIin, address: address),
    fiscal: fiscal,
    isVatPayer: isVatPayer,
    vatRatePercent: vatRatePercent,
    currencySymbol: currencySymbol,
    taxTreatment: taxTreatment,
    currencyBeforeAmount: currencyBeforeAmount,
    hasFiscalisation: hasFiscalisation,
  );
}
