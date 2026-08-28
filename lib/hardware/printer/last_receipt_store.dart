import 'dart:typed_data';

import 'package:telepos/hardware/printer/receipt_printer.dart';

class LastReceiptStore {
  LastReceiptStore._();
  static final instance = LastReceiptStore._();

  StoredReceipt? _lastSaleReceipt;

  StoredReceipt? _lastRefundReceipt;

  StoredReceipt? _lastXReport;

  StoredReceipt? _lastZReport;

  StoredReceipt? _lastCashOperationReceipt;

  static const int maxHistorySize = 10;

  final List<StoredReceipt> _salesHistory = [];

  StoredReceipt? get lastSaleReceipt => _lastSaleReceipt;

  StoredReceipt? get lastRefundReceipt => _lastRefundReceipt;

  StoredReceipt? get lastXReport => _lastXReport;

  StoredReceipt? get lastZReport => _lastZReport;

  StoredReceipt? get lastCashOperationReceipt => _lastCashOperationReceipt;

  StoredReceipt? get lastReceipt {
    StoredReceipt? latest;
    DateTime? latestTime;

    for (final receipt in [
      _lastSaleReceipt,
      _lastRefundReceipt,
      _lastXReport,
      _lastZReport,
      _lastCashOperationReceipt,
    ]) {
      if (receipt != null) {
        if (latestTime == null || receipt.timestamp.isAfter(latestTime)) {
          latest = receipt;
          latestTime = receipt.timestamp;
        }
      }
    }

    return latest;
  }

  List<StoredReceipt> get salesHistory => List.unmodifiable(_salesHistory);

  void storeSaleReceipt({
    required Uint8List data,
    required SaleReceiptData receiptData,
  }) {
    _lastSaleReceipt = StoredReceipt(
      type: ReceiptType.sale,
      data: data,
      metadata: _saleToMetadata(receiptData),
      timestamp: DateTime.now(),
    );

    _salesHistory.insert(0, _lastSaleReceipt!);
    if (_salesHistory.length > maxHistorySize) {
      _salesHistory.removeLast();
    }
  }

  void storeRefundReceipt({
    required Uint8List data,
    required RefundReceiptData receiptData,
  }) {
    _lastRefundReceipt = StoredReceipt(
      type: ReceiptType.refund,
      data: data,
      metadata: _refundToMetadata(receiptData),
      timestamp: DateTime.now(),
    );
  }

  void storeXReport({
    required Uint8List data,
    required ShiftClosingData reportData,
  }) {
    _lastXReport = StoredReceipt(
      type: ReceiptType.xReport,
      data: data,
      metadata: _shiftToMetadata(reportData),
      timestamp: DateTime.now(),
    );
  }

  void storeZReport({
    required Uint8List data,
    required ShiftClosingData reportData,
  }) {
    _lastZReport = StoredReceipt(
      type: ReceiptType.zReport,
      data: data,
      metadata: _shiftToMetadata(reportData),
      timestamp: DateTime.now(),
    );
  }

  void storeCashOperationReceipt({
    required Uint8List data,
    required CashOperationReceiptData receiptData,
  }) {
    _lastCashOperationReceipt = StoredReceipt(
      type: ReceiptType.cashOperation,
      data: data,
      metadata: _cashOperationToMetadata(receiptData),
      timestamp: DateTime.now(),
    );
  }

  void clear() {
    _lastSaleReceipt = null;
    _lastRefundReceipt = null;
    _lastXReport = null;
    _lastZReport = null;
    _lastCashOperationReceipt = null;
    _salesHistory.clear();
  }

  void clearOlderThan(Duration duration) {
    final threshold = DateTime.now().subtract(duration);

    if (_lastSaleReceipt != null &&
        _lastSaleReceipt!.timestamp.isBefore(threshold)) {
      _lastSaleReceipt = null;
    }
    if (_lastRefundReceipt != null &&
        _lastRefundReceipt!.timestamp.isBefore(threshold)) {
      _lastRefundReceipt = null;
    }
    if (_lastXReport != null && _lastXReport!.timestamp.isBefore(threshold)) {
      _lastXReport = null;
    }
    if (_lastZReport != null && _lastZReport!.timestamp.isBefore(threshold)) {
      _lastZReport = null;
    }
    if (_lastCashOperationReceipt != null &&
        _lastCashOperationReceipt!.timestamp.isBefore(threshold)) {
      _lastCashOperationReceipt = null;
    }

    _salesHistory.removeWhere((r) => r.timestamp.isBefore(threshold));
  }

  Map<String, dynamic> _saleToMetadata(SaleReceiptData data) => {
    'receiptNo': data.receiptNo,
    'posId': data.posId,
    'total': data.total.toString(),
    'cashierName': data.cashierName,
    'customerName': data.customerName,
    'itemsCount': data.items.length,
  };

  Map<String, dynamic> _refundToMetadata(RefundReceiptData data) => {
    'refundNo': data.refundNo,
    'originalReceiptNo': data.originalReceiptNo,
    'total': data.total.toString(),
    'cashierName': data.cashierName,
    'reason': data.reason,
  };

  Map<String, dynamic> _shiftToMetadata(ShiftClosingData data) => {
    'shiftNo': data.shiftNo,
    'cashierName': data.cashierName,
    'salesCount': data.salesCount,
    'salesTotal': data.salesTotal.toString(),
    'revenue': data.revenue.toString(),
  };

  Map<String, dynamic> _cashOperationToMetadata(
    CashOperationReceiptData data,
  ) => {
    'operationType': data.operationType.name,
    'amount': data.amount.toString(),
    'cashierName': data.cashierName,
    'description': data.description,
  };
}

class StoredReceipt {
  const StoredReceipt({
    required this.type,
    required this.data,
    required this.metadata,
    required this.timestamp,
  });

  final ReceiptType type;

  final Uint8List data;

  final Map<String, dynamic> metadata;

  final DateTime timestamp;

  int? get receiptNo => metadata['receiptNo'] as int?;

  String? get total => metadata['total'] as String?;

  String get description {
    switch (type) {
      case ReceiptType.sale:
        return 'Чек №${receiptNo ?? "?"} - ${total ?? "?"}';
      case ReceiptType.refund:
        return 'Возврат №${metadata['refundNo']} - ${total ?? "?"}';
      case ReceiptType.xReport:
        return 'X-отчёт смены №${metadata['shiftNo']}';
      case ReceiptType.zReport:
        return 'Z-отчёт смены №${metadata['shiftNo']}';
      case ReceiptType.cashOperation:
        return '${_operationLabel()} - ${metadata['amount']}';
    }
  }

  String _operationLabel() {
    switch (metadata['operationType']) {
      case 'investment':
        return 'Внесение';
      case 'expense':
        return 'Выплата';
      case 'dividend':
        return 'Инкассация';
      default:
        return 'Операция';
    }
  }
}

enum ReceiptType {
  sale('Продажа'),
  refund('Возврат'),
  xReport('X-отчёт'),
  zReport('Z-отчёт'),
  cashOperation('Касса');

  const ReceiptType(this.label);
  final String label;
}

class ReprintService {
  ReprintService({required this.store, required this.onPrint});

  final LastReceiptStore store;
  final Future<bool> Function(Uint8List data) onPrint;

  Future<ReprintResult> reprintLast() async {
    final receipt = store.lastReceipt;
    if (receipt == null) {
      return ReprintResult.noReceipt();
    }

    return _reprint(receipt);
  }

  Future<ReprintResult> reprintLastSale() async {
    final receipt = store.lastSaleReceipt;
    if (receipt == null) {
      return ReprintResult.noReceipt();
    }

    return _reprint(receipt);
  }

  Future<ReprintResult> reprintLastRefund() async {
    final receipt = store.lastRefundReceipt;
    if (receipt == null) {
      return ReprintResult.noReceipt();
    }

    return _reprint(receipt);
  }

  Future<ReprintResult> reprintFromHistory(int index) async {
    final history = store.salesHistory;
    if (index < 0 || index >= history.length) {
      return ReprintResult.noReceipt();
    }

    return _reprint(history[index]);
  }

  Future<ReprintResult> _reprint(StoredReceipt receipt) async {
    try {
      final success = await onPrint(receipt.data);
      if (success) {
        return ReprintResult.success(receipt);
      } else {
        return ReprintResult.failed('Ошибка печати');
      }
    } catch (e) {
      return ReprintResult.failed(e.toString());
    }
  }
}

class ReprintResult {
  const ReprintResult._({required this.status, this.receipt, this.error});

  factory ReprintResult.success(StoredReceipt receipt) =>
      ReprintResult._(status: ReprintStatus.success, receipt: receipt);

  factory ReprintResult.noReceipt() =>
      const ReprintResult._(status: ReprintStatus.noReceipt);

  factory ReprintResult.failed(String error) =>
      ReprintResult._(status: ReprintStatus.failed, error: error);

  final ReprintStatus status;
  final StoredReceipt? receipt;
  final String? error;

  bool get isSuccess => status == ReprintStatus.success;
  bool get hasNoReceipt => status == ReprintStatus.noReceipt;
  bool get isFailed => status == ReprintStatus.failed;
}

enum ReprintStatus { success, noReceipt, failed }
