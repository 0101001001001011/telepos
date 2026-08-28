import 'package:decimal/decimal.dart';
import 'package:telepos/domain/entities/shift/shift_receipt.dart';

abstract class AssembleShiftReceiptUseCase {
  Future<ShiftReceipt?> assemble(int shiftId, Decimal cashInPos);
}
