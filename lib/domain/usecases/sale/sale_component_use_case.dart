import 'package:decimal/decimal.dart';

abstract class SaleComponentUseCase {
  Future<SaleComponent?> get({required int receiptNo, required int posId});
}

class SaleComponent {
  const SaleComponent({
    required this.receiptNo,
    required this.posId,
    required this.saleId,
    required this.userId,
    required this.amount,
    required this.change,
    required this.time,
    required this.isOfd,
    required this.isWholesale,
    required this.state,
    required this.saleProducts,
    required this.payments,
    required this.marks,
    this.storeId,
    this.customerLocalId,
    this.customerServerId,
    this.loyalCustomerPhone,
    this.customerBin,
    this.weightProductRoundType,
    this.discountsRoundType,
    this.saleCustomFields = const [],
    this.saleWithdrawal,
    this.webkassaReceipt,
  });

  final int receiptNo;
  final int posId;
  final int? saleId;
  final int userId;
  final Decimal amount;
  final Decimal change;
  final int time;
  final bool isOfd;
  final bool isWholesale;
  final int? state;
  final int? storeId;
  final int? customerLocalId;
  final int? customerServerId;
  final int? loyalCustomerPhone;
  final String? customerBin;
  final int? weightProductRoundType;
  final int? discountsRoundType;

  final List<SaleComponentProduct> saleProducts;

  final List<SaleComponentPayment> payments;

  final Map<int, List<String>> marks;

  final List<SaleComponentCustomField> saleCustomFields;

  final SaleComponentWithdrawal? saleWithdrawal;

  final SaleComponentWebkassaReceipt? webkassaReceipt;
}

class SaleComponentProduct {
  const SaleComponentProduct({
    required this.id,
    required this.ucode,
    required this.quantity,
    required this.price,
    required this.priceBefore,
    required this.isUniversal,
    this.barcode,
    this.categoryId,
  });

  final int id;
  final int ucode;
  final Decimal quantity;
  final Decimal price;
  final Decimal priceBefore;
  final bool isUniversal;
  final int? barcode;
  final int? categoryId;
}

class SaleComponentPayment {
  const SaleComponentPayment({
    required this.id,
    required this.userId,
    required this.payeeAccountId,
    required this.amount,
    required this.time,
    this.state,
    this.customerLocalId,
  });

  final int id;
  final int userId;
  final int payeeAccountId;
  final Decimal amount;
  final int time;
  final int? state;
  final int? customerLocalId;
}

class SaleComponentCustomField {
  const SaleComponentCustomField({
    required this.customFieldId,
    required this.customFieldItemId,
  });

  final int customFieldId;
  final int customFieldItemId;
}

class SaleComponentWithdrawal {
  const SaleComponentWithdrawal({
    required this.agentAccountId,
    required this.amount,
  });

  final int agentAccountId;
  final Decimal amount;
}

class SaleComponentWebkassaReceipt {
  const SaleComponentWebkassaReceipt({
    required this.operationId,
    this.receiptNo,
    this.fiscalNo,
    this.wkReceiptNo,
    this.wkTime,
    this.wkOfflineMode,
    this.ticketUrl,
    this.isSale,
  });

  final int operationId;
  final int? receiptNo;
  final String? fiscalNo;
  final String? wkReceiptNo;
  final int? wkTime;
  final bool? wkOfflineMode;
  final String? ticketUrl;
  final bool? isSale;
}
