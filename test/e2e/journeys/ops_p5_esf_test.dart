library;

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:telepos/data/esf/esf_outbox_store.dart';
import 'package:telepos/data/esf/kgd_esf_provider.dart';
import 'package:telepos/data/esf/offline_esf_provider.dart';
import 'package:telepos/data/esf/prefs_esf_outbox_store.dart';
import 'package:telepos/domain/entities/sale/sale_entity.dart';
import 'package:telepos/domain/entities/sale/sale_product_entity.dart';
import 'package:telepos/domain/esf/esf_draft_builder.dart';
import 'package:telepos/domain/esf/esf_models.dart';
import 'package:telepos/domain/esf/esf_settings.dart';

EsfSettings _vatPayerSettings() => EsfSettings(
  operatorType: EsfOperatorType.kgdEsf,
  enabled: true,
  supplierBin: '123456789012',
  supplierName: 'ТОО Поставщик',
  supplierVatSeries: '12345',
  supplierVatNumber: '0000123',
  isVatPayer: true,
  vatRatePercent: Decimal.fromInt(12),
  b2bOnly: true,
);

SaleEntity _sale({String? bin, required int time}) => SaleEntity(
  receiptNo: 1001,
  posId: 7,
  userId: 5,
  amount: Decimal.fromInt(2240),
  time: time,
  customerBin: bin,
  state: 4,
);

List<EsfLineSpec> _lines() => [
  EsfLineSpec(
    product: SaleProductEntity(
      ucode: 10,
      quantity: Decimal.fromInt(2),
      price: Decimal.fromInt(560),
      priceBefore: Decimal.fromInt(560),
    ),
    name: 'Молоко 1л',
    ntin: 'KZ-NTIN-0001',
    tnved: '0401',
    unitCode: 796,
    vatMode: EsfTaxMode.vat,
    vatRatePercent: Decimal.fromInt(12),
    virtualWarehouse: true,
    warehouseProductId: 'WP-10',
  ),
  EsfLineSpec(
    product: SaleProductEntity(
      ucode: 20,
      quantity: Decimal.fromInt(1),
      price: Decimal.fromInt(1120),
      priceBefore: Decimal.fromInt(1120),
    ),
    name: 'Хлеб (льгота)',
    ntin: 'KZ-NTIN-0002',
    unitCode: 796,
    vatMode: EsfTaxMode.vat,
    vatRatePercent: Decimal.zero,
  ),
];

void main() {
  const builder = EsfDraftBuilder();
  final now = DateTime(2026, 6, 1, 12, 0, 0);
  final saleTime = now.millisecondsSinceEpoch ~/ 1000;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('B2B sale builds a correct ЭСФ draft (parties, per-rate НДС, lines), '
      'queues it durably, survives a restart, and stays offline-safe with an '
      'HONEST account-gated skeleton (no faked registration number)', () async {
    final prefs = await SharedPreferences.getInstance();
    final settings = _vatPayerSettings();

    final sale = _sale(bin: '987654321098', time: saleTime);
    final outcome = builder.buildFromSale(
      sale: sale,
      lines: _lines(),
      settings: settings,
      idempotencyKey: 'ESF-GUID-0001',
      accountingNumber: '7-1001',
      buyerName: 'ТОО Покупатель',
      now: now,
    );

    expect(outcome.built, isTrue, reason: 'B2B sale must build an ЭСФ draft');
    final inv = outcome.invoice!;

    expect(inv.supplier.binIin, '123456789012');
    expect(
      inv.supplier.isVatPayer,
      isTrue,
      reason: 'supplier declares НДС свидетельство',
    );
    expect(
      inv.buyer.binIin,
      '987654321098',
      reason: 'buyer БИН taken from the sale',
    );
    expect(inv.direction, EsfDirection.outgoing);
    expect(inv.documentType, EsfDocumentType.basic);
    expect(inv.sourceSaleReceiptNo, 1001);
    expect(inv.sourceSalePosId, 7);

    expect(inv.lines, hasLength(2));
    expect(inv.lines.first.ntin, 'KZ-NTIN-0001');
    expect(inv.lines.first.tnved, '0401');
    expect(inv.lines.first.warehouseProductId, 'WP-10');
    expect(inv.lines.first.virtualWarehouse, isTrue);

    expect(
      inv.vatBuckets,
      hasLength(2),
      reason: 'НДС must be bucketed per rate (12% and 0%)',
    );
    final bucket12 = inv.vatBuckets.firstWhere(
      (b) => b.ratePercent == Decimal.fromInt(12),
    );
    final bucket0 = inv.vatBuckets.firstWhere(
      (b) => b.ratePercent == Decimal.zero,
    );

    expect(bucket12.vatAmount, Decimal.parse('120.00'));
    expect(bucket12.taxableAmount, Decimal.parse('1000.00'));
    expect(bucket0.vatAmount, Decimal.zero);
    expect(bucket0.taxableAmount, Decimal.fromInt(1120));

    expect(inv.totalVat, Decimal.parse('120.00'));
    expect(inv.totalTaxable, Decimal.parse('2120.00'));
    expect(
      inv.totalWithVat,
      Decimal.parse('2240.00'),
      reason: 'reconciles to the sale gross',
    );
    final lineVatSum = inv.lines.fold(Decimal.zero, (s, l) => s + l.tax.amount);
    expect(lineVatSum, inv.totalVat);

    final store = PrefsEsfOutboxStore(prefs);
    await store.enqueue(EsfOutboxEntry(invoice: inv));
    expect(await store.pendingCount(), 1, reason: 'draft is queued');

    await store.enqueue(EsfOutboxEntry(invoice: inv));
    expect(await store.pendingCount(), 1);

    final afterRestart = PrefsEsfOutboxStore(prefs);
    final survived = await afterRestart.find('ESF-GUID-0001');
    expect(survived, isNotNull, reason: 'queued draft survived the restart');
    expect(
      survived!.invoice.buyer.binIin,
      '987654321098',
      reason: 'draft re-hydrated from persisted JSON',
    );
    expect(survived.invoice.vatBuckets, hasLength(2));

    final provider = OfflineEsfProvider(
      inner: const KgdEsfProvider(transport: null),
      store: afterRestart,
      isReachable: () async => true,
    );

    final result = await provider.submit(survived.invoice);
    expect(result.success, isFalse);
    expect(
      result.errorCode,
      EsfErrorCode.accountRequired,
      reason: 'no ЭЦП → honest accountRequired, never faked',
    );
    expect(result.registrationNumber, isNull);

    final afterSubmit = await afterRestart.find('ESF-GUID-0001');
    expect(afterSubmit, isNotNull);
    expect(afterSubmit!.status, EsfStatus.error);
    expect(afterSubmit.invoice.isRegistered, isFalse);

    final offlineProvider = OfflineEsfProvider(
      inner: const KgdEsfProvider(transport: null),
      store: InMemoryEsfOutboxStore(),
      isReachable: () async => false,
    );
    final offlineResult = await offlineProvider.submit(inv);
    expect(offlineResult.success, isTrue, reason: 'offline never blocks');
    expect(offlineResult.queued, isTrue);
    expect(await offlineProvider.pendingCount(), 1);
  });

  test('non-B2B sale (no buyer БИН) builds NO ЭСФ (honest skip)', () async {
    final settings = _vatPayerSettings();
    final retailSale = _sale(bin: null, time: saleTime);

    final outcome = builder.buildFromSale(
      sale: retailSale,
      lines: _lines(),
      settings: settings,
      idempotencyKey: 'ESF-GUID-RETAIL',
      accountingNumber: '7-1002',
      now: now,
    );

    expect(
      outcome.built,
      isFalse,
      reason: 'розница физлицу за наличные не требует ЭСФ',
    );
    expect(outcome.invoice, isNull);
    expect(outcome.skipReason, EsfSkipReason.notB2b);
  });

  test('disabled ЭСФ settings build nothing even for a B2B sale', () async {
    final disabled = EsfSettings.disabled();
    final b2bSale = _sale(bin: '987654321098', time: saleTime);

    final outcome = builder.buildFromSale(
      sale: b2bSale,
      lines: _lines(),
      settings: disabled,
      idempotencyKey: 'ESF-GUID-OFF',
      accountingNumber: '7-1003',
      now: now,
    );

    expect(outcome.built, isFalse);
    expect(outcome.skipReason, EsfSkipReason.disabled);
  });
}
