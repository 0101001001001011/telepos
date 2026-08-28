import 'package:decimal/decimal.dart';
import 'package:telepos/domain/entities/cash_operation/cash_operation_receipt_data.dart';
import 'package:telepos/domain/print/print_queue.dart';
import 'package:telepos/domain/usecases/cash_operation/cash_in_out_controller.dart';

/// Квитанция кассовой операции: внесения, изъятия, расхода, инкассации.
///
/// Единственный контракт, через который экран кассовой операции просит бумагу.
/// Второго нет намеренно: `CashInOutController.printReceipt` был вторым, писал
/// в принтер напрямую и потому терял квитанцию на недоступном принтере — он
/// удалён, а не оставлен «на всякий случай».
abstract class CashOperationReceiptService {
  Future<CashOperationReceiptData?> buildReceiptData(int operationId);

  /// Ставит квитанцию в очередь печати и возвращается **сразу**.
  ///
  /// Ответ — [PrintSubmitOutcome], а не `bool`, и разница существенна:
  /// «принято» ([PrintSubmitStatus.accepted]) и «уже печаталось»
  /// ([PrintSubmitStatus.duplicate]) — оба успех, но это разные события, а
  /// `true` на обоих не отличает повтор от новой квитанции. Отказ
  /// ([PrintSubmitStatus.rejected]) всегда называет причину.
  ///
  /// **«Принято» — это не «напечатано».** Бумага появится, когда принтер
  /// сможет; вызывающему знать это не нужно и ждать этого нельзя (И30).
  ///
  /// Не бросает: к моменту вызова деньги уже записаны.
  Future<PrintSubmitOutcome> printReceipt(int operationId);
}

class CashOperationReceiptDataBuilder {
  String? _companyName;
  int? _receiptNumber;
  CashInOutType? _type;
  DateTime? _docTime;
  String? _cashierName;
  Decimal? _amount;
  String? _currencySymbol;
  String? _note;

  CashOperationReceiptDataBuilder setCompanyName(String value) {
    _companyName = value;
    return this;
  }

  CashOperationReceiptDataBuilder setReceiptNumber(int value) {
    _receiptNumber = value;
    return this;
  }

  CashOperationReceiptDataBuilder setType(CashInOutType value) {
    _type = value;
    return this;
  }

  CashOperationReceiptDataBuilder setDocTime(DateTime value) {
    _docTime = value;
    return this;
  }

  CashOperationReceiptDataBuilder setCashierName(String? value) {
    _cashierName = value;
    return this;
  }

  CashOperationReceiptDataBuilder setAmount(Decimal value) {
    _amount = value;
    return this;
  }

  CashOperationReceiptDataBuilder setCurrencySymbol(String value) {
    _currencySymbol = value;
    return this;
  }

  CashOperationReceiptDataBuilder setNote(String? value) {
    _note = value;
    return this;
  }

  CashOperationReceiptData build() {
    assert(_companyName != null, 'companyName is required');
    assert(_receiptNumber != null, 'receiptNumber is required');
    assert(_type != null, 'type is required');
    assert(_docTime != null, 'docTime is required');
    assert(_amount != null, 'amount is required');
    assert(_currencySymbol != null, 'currencySymbol is required');

    return CashOperationReceiptData(
      companyName: _companyName!,
      receiptNumber: _receiptNumber.toString().padLeft(6, '0'),
      type: _type!,
      docTime: _docTime!,
      cashierName: _cashierName,
      amount: _amount!,
      currencySymbol: _currencySymbol!,
      note: _note,
    );
  }
}
