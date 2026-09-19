// Сторож контракта отказывающих провайдеров, одной строкой:
// **каждый член возвращает названный отказ; ни один не возвращает успех.**
//
// Сторож перечисляет члены поимённо и вызывает каждый, а не читает исходник.
// Поэтому он краснеет в обе стороны: если вернуть ложь (успех) — падает
// список `lying`; если сломать форму (переименовать метод, сменить
// сигнатуру) — файл не компилируется. Молча пережить правку он не может.
//
// Число 29 — не украшение: оно ловит **добавленный** член, который сторож
// не проверяет. Новый метод в интерфейсе, забытый здесь, роняет счёт.
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/esf/esf_models.dart';
import 'package:telepos/domain/esf/esf_settings.dart';
import 'package:telepos/domain/esf/refusing_esf_provider.dart';
import 'package:telepos/domain/fiscal/fiscal_models.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';
import 'package:telepos/domain/fiscal/refusing_fiscal_provider.dart';
import 'package:telepos/domain/ismpt/ismpt_models.dart';
import 'package:telepos/domain/ismpt/refusing_ismpt_provider.dart';
import 'package:telepos/domain/snt/refusing_snt_provider.dart';
import 'package:telepos/domain/snt/snt_models.dart';
import 'package:telepos/domain/snt/snt_settings.dart';

FiscalSaleRequest _sale() => FiscalSaleRequest(
  idempotencyKey: 'K',
  localOperationId: 1,
  positions: const [],
  payments: const [],
  totalDiscount: Decimal.zero,
  totalMarkup: Decimal.zero,
  occurredAt: DateTime(2026),
);

FiscalRefundRequest _refund() => FiscalRefundRequest(
  sale: _sale(),
  basis: FiscalRefundBasis(
    originalFiscalSign: 'X',
    originalDateTime: DateTime(2026),
    originalRegistrationNumber: 'R',
    originalTotal: Decimal.zero,
  ),
);

FiscalMoneyRequest _money() => FiscalMoneyRequest(
  idempotencyKey: 'K',
  amount: Decimal.one,
  occurredAt: DateTime(2026),
);

void main() {
  test('ни один член отказывающих провайдеров не возвращает успеха', () async {
    final lying = <String>[];
    final honest = <String>[];

    void verdict(String name, bool isSuccess) {
      (isSuccess ? lying : honest).add(name);
    }

    // ---- FiscalProvider: 13 методов ----
    const f = RefusingFiscalProvider();
    verdict('fiscal.authorize', (await f.authorize(FiscalSettings())).success);
    verdict('fiscal.validateConfig', f.validateConfig(FiscalSettings()) == null);
    verdict('fiscal.fiscalizeSale', (await f.fiscalizeSale(_sale())).success);
    verdict(
      'fiscal.fiscalizeRefund',
      (await f.fiscalizeRefund(_refund())).success,
    );
    verdict(
      'fiscal.fiscalizePurchase',
      (await f.fiscalizePurchase(_sale())).success,
    );
    verdict(
      'fiscal.fiscalizePurchaseReturn',
      (await f.fiscalizePurchaseReturn(_refund())).success,
    );
    verdict('fiscal.moneyIn', (await f.moneyIn(_money())).success);
    verdict('fiscal.moneyOut', (await f.moneyOut(_money())).success);
    verdict(
      'fiscal.openShift',
      (await f.openShift(const FiscalShiftRequest())).success,
    );
    verdict(
      'fiscal.closeShift',
      (await f.closeShift(const FiscalShiftRequest())).result.success,
    );
    verdict(
      'fiscal.xReport',
      (await f.xReport(const FiscalShiftRequest())).result.success,
    );
    verdict(
      'fiscal.correctionReceipt',
      (await f.correctionReceipt(
        const FiscalCorrectionRequest(
          idempotencyKey: 'K',
          positions: [],
          payments: [],
        ),
      )).success,
    );
    verdict('fiscal.getStatus', (await f.getStatus()).canFiscalize);

    // ---- SntProvider: 5 методов + 1 объявление возможностей ----
    const s = RefusingSntProvider();
    verdict('snt.capabilities.canConfirmInbound', s.capabilities.canConfirmInbound);
    verdict('snt.validateConfig', s.validateConfig(const SntSettings()) == null);
    verdict('snt.authorize', (await s.authorize(const SntSettings())).success);
    final doc = SntDocument(
      idempotencyKey: 'K',
      direction: SntDirection.inbound,
      operationType: SntOperationType.supply,
      sender: const SntParty(bin: '111111111111'),
      recipient: const SntParty(bin: '222222222222'),
      lines: const [],
      occurredAt: DateTime(2026),
    );
    verdict('snt.submit', (await s.submit(doc)).success);
    verdict('snt.confirmInbound', (await s.confirmInbound(doc)).success);
    verdict('snt.rejectInbound', (await s.rejectInbound(doc)).success);
    verdict('snt.revoke', (await s.revoke(doc)).success);

    // ---- EsfProvider: 4 метода ----
    const e = RefusingEsfProvider();
    verdict('esf.validateConfig', e.validateConfig(EsfSettings()) == null);
    final inv = EsfInvoice(
      idempotencyKey: 'K',
      accountingNumber: 'A-1',
      direction: EsfDirection.outgoing,
      documentType: EsfDocumentType.basic,
      supplier: const EsfParty(binIin: '111111111111', name: 'S'),
      buyer: const EsfParty(binIin: '222222222222', name: 'B'),
      lines: const [],
      vatBuckets: const [],
      turnoverDate: DateTime(2026),
      issueDate: DateTime(2026),
    );
    verdict('esf.submit', (await e.submit(inv)).success);
    verdict('esf.getStatus', (await e.getStatus('R')).success);
    verdict('esf.revoke', (await e.revoke(inv)).success);
    verdict(
      'esf.providerStatus',
      (await e.providerStatus(EsfSettings())).configured,
    );

    // ---- IsMptService: 4 метода ----
    const i = RefusingIsMptProvider();
    verdict('ismpt.authorize', (await i.authorize()).success);
    verdict('ismpt.verifyCodes', (await i.verifyCodes(const [])).success);
    verdict(
      'ismpt.submitDocument',
      (await i.submitDocument(
        IsMptDocRequest(idempotencyKey: 'K', type: IsMptDocType.acceptance, codes: const []),
      )).success,
    );
    verdict('ismpt.getStatus', (await i.getStatus()).configured);

    expect(lying, isEmpty, reason: 'члены, возвращающие успех: $lying');
    expect(lying.length + honest.length, 29);
  });
}
