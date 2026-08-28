import 'package:decimal/decimal.dart';

import 'package:telepos/domain/entities/sale/sale_entity.dart';
import 'package:telepos/domain/entities/sale/sale_product_entity.dart';
import 'package:telepos/domain/esf/esf_models.dart';
import 'package:telepos/domain/esf/esf_settings.dart';

class EsfLineSpec {
  const EsfLineSpec({
    required this.product,
    required this.name,
    this.unitCode = 796,
    this.ntin,
    this.tnved,
    this.warehouseProductId,
    this.virtualWarehouse = false,
    this.vatMode,
    this.vatRatePercent,
  });

  final SaleProductEntity product;

  final String name;

  final int unitCode;

  final String? ntin;
  final String? tnved;
  final String? warehouseProductId;
  final bool virtualWarehouse;

  final EsfTaxMode? vatMode;
  final Decimal? vatRatePercent;
}

enum EsfSkipReason { notB2b, disabled, noSupplierRequisites, empty }

class EsfBuildOutcome {
  const EsfBuildOutcome._({this.invoice, this.skipReason});

  final EsfInvoice? invoice;

  final EsfSkipReason? skipReason;

  bool get built => invoice != null;

  factory EsfBuildOutcome.built(EsfInvoice invoice) =>
      EsfBuildOutcome._(invoice: invoice);

  factory EsfBuildOutcome.skipped(EsfSkipReason reason) =>
      EsfBuildOutcome._(skipReason: reason);
}

class EsfDraftBuilder {
  const EsfDraftBuilder();

  EsfBuildOutcome buildFromSale({
    required SaleEntity sale,
    required List<EsfLineSpec> lines,
    required EsfSettings settings,
    required String idempotencyKey,
    required String accountingNumber,
    String? buyerName,
    EsfPartyType buyerType = EsfPartyType.legalEntity,
    DateTime? now,
  }) {
    if (!settings.isEnabled) {
      return EsfBuildOutcome.skipped(EsfSkipReason.disabled);
    }
    if (!settings.hasSupplierRequisites) {
      return EsfBuildOutcome.skipped(EsfSkipReason.noSupplierRequisites);
    }

    final buyerBin = sale.customerBin?.trim();
    final isB2b = buyerBin != null && buyerBin.isNotEmpty;
    if (settings.b2bOnly && !isB2b) {
      return EsfBuildOutcome.skipped(EsfSkipReason.notB2b);
    }
    if (lines.isEmpty) {
      return EsfBuildOutcome.skipped(EsfSkipReason.empty);
    }

    final issuedAt = now ?? DateTime.now();
    final turnoverAt = DateTime.fromMillisecondsSinceEpoch(
      sale.time * 1000,
      isUtc: false,
    );

    final supplier = EsfParty(
      binIin: settings.supplierBin!,
      name: settings.supplierName ?? 'Поставщик',
      type: EsfPartyType.legalEntity,
      vatSeries: settings.supplierVatSeries,
      vatNumber: settings.supplierVatNumber,
      address: settings.supplierAddress,
    );

    final buyer = EsfParty(
      binIin: buyerBin ?? '',
      name: buyerName ?? 'Покупатель',
      type: buyerType,
    );

    final esfLines = <EsfLine>[];
    final Map<String, _VatAccum> buckets = {};
    var lineNo = 1;

    for (final spec in lines) {
      final p = spec.product;
      final qty = p.quantity;
      final unitPrice = p.price;
      final lineTotal = qty * unitPrice;
      final discount = p.hasDiscount ? p.discountAmount : Decimal.zero;

      final mode =
          spec.vatMode ??
          (settings.isVatPayer ? EsfTaxMode.vat : EsfTaxMode.none);
      final ratePercent = mode == EsfTaxMode.vat
          ? (spec.vatRatePercent ?? settings.vatRatePercent)
          : Decimal.zero;
      final vatAmount = mode == EsfTaxMode.vat
          ? _vatFromGross(lineTotal, ratePercent)
          : Decimal.zero;
      final taxable = mode == EsfTaxMode.vat
          ? (lineTotal - vatAmount)
          : lineTotal;

      esfLines.add(
        EsfLine(
          lineNumber: lineNo++,
          name: spec.name,
          quantity: qty,
          unitPrice: unitPrice,
          lineTotal: taxable,
          tax: EsfTax(mode: mode, ratePercent: ratePercent, amount: vatAmount),
          discount: discount,
          unitCode: spec.unitCode,
          ntin: spec.ntin,
          tnved: spec.tnved,
          warehouseProductId: spec.warehouseProductId,
          virtualWarehouse: spec.virtualWarehouse,
        ),
      );

      final key = ratePercent.toString();
      final accum = buckets.putIfAbsent(key, () => _VatAccum(ratePercent));
      accum.taxable += taxable;
      accum.vat += vatAmount;
    }

    final vatBuckets =
        buckets.values
            .map(
              (a) => EsfVatBucket(
                ratePercent: a.ratePercent,
                taxableAmount: a.taxable,
                vatAmount: a.vat,
              ),
            )
            .toList()
          ..sort((a, b) => b.ratePercent.compareTo(a.ratePercent));

    final invoice = EsfInvoice(
      idempotencyKey: idempotencyKey,
      accountingNumber: accountingNumber,
      direction: EsfDirection.outgoing,
      documentType: EsfDocumentType.basic,
      supplier: supplier,
      buyer: buyer,
      lines: esfLines,
      vatBuckets: vatBuckets,
      turnoverDate: turnoverAt,
      issueDate: issuedAt,
      sourceSaleReceiptNo: sale.receiptNo,
      sourceSalePosId: sale.posId,
    );

    return EsfBuildOutcome.built(invoice);
  }

  static Decimal _vatFromGross(Decimal gross, Decimal ratePercent) {
    if (ratePercent == Decimal.zero) return Decimal.zero;
    final numerator = gross * ratePercent;
    final denominator = Decimal.fromInt(100) + ratePercent;
    final rational = (numerator / denominator);
    return rational.toDecimal(scaleOnInfinitePrecision: 3).round(scale: 2);
  }
}

class _VatAccum {
  _VatAccum(this.ratePercent);
  final Decimal ratePercent;
  Decimal taxable = Decimal.zero;
  Decimal vat = Decimal.zero;
}
