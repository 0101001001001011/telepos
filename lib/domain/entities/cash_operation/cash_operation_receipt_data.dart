import 'package:decimal/decimal.dart';
import 'package:telepos/domain/usecases/cash_operation/cash_in_out_controller.dart';

/// Plain receipt data for a cash-in/cash-out operation.
///
/// Lives in the domain layer: it carries no printer- or ESC/POS-specific
/// concerns. Formatting it onto paper is a hardware concern and belongs to
/// `CashOperationReceiptBuilder`.
class CashOperationReceiptData {
  const CashOperationReceiptData({
    required this.companyName,
    required this.receiptNumber,
    required this.type,
    required this.docTime,
    this.cashierName,
    required this.amount,
    required this.currencySymbol,
    this.note,
  });

  final String companyName;

  final String receiptNumber;

  final CashInOutType type;

  final DateTime docTime;

  final String? cashierName;

  final Decimal amount;

  final String currencySymbol;

  final String? note;
}
