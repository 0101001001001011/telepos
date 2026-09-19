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

import 'package:telepos/domain/fiscal/fiscal_doc_kind.dart';
import 'package:decimal/decimal.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/usecases/fiscal/fiscal_position_builder.dart';
import 'package:telepos/domain/services/receipt_print_service.dart';
import 'package:telepos/domain/usecases/fiscal/fiscal_service.dart';
import 'package:telepos/domain/usecases/fiscal/vat_calculator.dart';

class ReceiptRequisites {
  const ReceiptRequisites({
    required this.seller,
    required this.fiscal,
    required this.isVatPayer,
    required this.vatRatePercent,
    required this.currencySymbol,
  });

  final ReceiptSellerInfo seller;
  final ReceiptFiscalInfo? fiscal;
  final bool isVatPayer;
  final int vatRatePercent;
  final String currencySymbol;

  Decimal? vatFromGross(Decimal grossTotal) => isVatPayer
      ? FiscalPositionBuilder.vatFromGross(
          grossTotal,
          Decimal.fromInt(vatRatePercent),
        )
      : null;
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
  String? address;
  String? ofdName;
  String? rnm;
  String? znm;
  int vatRatePercent = VatCalculator.standardRatePercent;

  try {
    final pos = await db.thisPosDao.get();
    binIin = pos?.iinbin;
    isVatPayer = pos?.isVatPayer ?? true;
    if (pos?.currencySymbol != null && pos!.currencySymbol!.isNotEmpty) {
      currencySymbol = pos.currencySymbol!;
    }
  } catch (_) {}

  try {
    if (GetIt.I.isRegistered<FiscalSettingsSource>()) {
      final fs = await GetIt.I<FiscalSettingsSource>().load();
      isVatPayer = fs.isVatPayer;
      vatRatePercent = fs.vatRatePercent.toBigInt().toInt();
    }
  } catch (_) {}

  WebkassaConfig? config;
  try {
    final dao = db.webkassaReceiptDao;
    config = posId != null
        ? await dao.getConfig(posId)
        : await dao.getFirstConfig();
    if (config != null) {
      address = config.address;
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
  );
}
