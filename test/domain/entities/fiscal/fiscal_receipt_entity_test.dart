import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/entities/fiscal/fiscal_receipt_entity.dart';

void main() {
  group('FiscalReceiptEntity', () {
    final receipt = FiscalReceiptEntity(
      operationId: 1,
      receiptNo: 10,
      fiscalNo: 'FISC-001',
      wkReceiptNo: 'WK-001',
      wkTime: 1700000000,
      ticketUrl: 'https://ticket.webkassa.kz/abc',
    );

    test('creates with fields', () {
      expect(receipt.operationId, 1);
      expect(receipt.receiptNo, 10);
      expect(receipt.fiscalNo, 'FISC-001');
      expect(receipt.ticketUrl, 'https://ticket.webkassa.kz/abc');
    });

    test('defaults', () {
      expect(receipt.wkOfflineMode, false);
      expect(receipt.isSale, true);
    });

    test('copyWith', () {
      final refundReceipt = receipt.copyWith(isSale: false);
      expect(refundReceipt.isSale, false);
      expect(refundReceipt.operationId, 1);
      expect(refundReceipt.receiptNo, 10);
    });
  });
}
