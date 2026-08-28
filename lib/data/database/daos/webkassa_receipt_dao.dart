import 'package:drift/drift.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/tables/webkassa_tables.dart';

part 'webkassa_receipt_dao.g.dart';

@DriftAccessor(tables: [WebkassaReceipts, WebkassaConfigs])
class WebkassaReceiptDao extends DatabaseAccessor<AppDatabase>
    with _$WebkassaReceiptDaoMixin {
  WebkassaReceiptDao(super.db);

  Future<WebkassaReceipt?> findByIsSaleAndOperationId(
    bool isSale,
    int operationId,
  ) =>
      (select(webkassaReceipts)..where(
            (wr) =>
                wr.isSale.equals(isSale) & wr.operationId.equals(operationId),
          ))
          .getSingleOrNull();

  Future<WebkassaConfig?> getConfig(int posId) => (select(
    webkassaConfigs,
  )..where((c) => c.posId.equals(posId))).getSingleOrNull();

  Future<WebkassaConfig?> getFirstConfig() =>
      (select(webkassaConfigs)..limit(1)).getSingleOrNull();

  Future<int> insertReceipt(WebkassaReceiptsCompanion receipt) =>
      into(webkassaReceipts).insert(receipt);

  Future<void> upsertConfig(WebkassaConfigsCompanion config) async {
    final posId = config.posId.value;
    final existing = await getConfig(posId);
    if (existing == null) {
      await into(webkassaConfigs).insert(config);
    } else {
      await (update(
        webkassaConfigs,
      )..where((c) => c.posId.equals(posId))).write(config);
    }
  }

  Future<int> updateConfig(int posId, WebkassaConfigsCompanion config) =>
      (update(
        webkassaConfigs,
      )..where((c) => c.posId.equals(posId))).write(config);

  Future<int> setError(int posId, String errorMessage) =>
      (update(webkassaConfigs)..where((c) => c.posId.equals(posId))).write(
        WebkassaConfigsCompanion(
          lastErrorTime: Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
          errorString: Value(errorMessage),
        ),
      );

  Future<List<WebkassaReceipt>> findOfflineReceipts() => (select(
    webkassaReceipts,
  )..where((wr) => wr.wkOfflineMode.equals(true))).get();

  Future<int> countOfflineReceipts() async {
    final count =
        await (selectOnly(webkassaReceipts)
              ..where(webkassaReceipts.wkOfflineMode.equals(true))
              ..addColumns([webkassaReceipts.operationId.count()]))
            .map((row) => row.read(webkassaReceipts.operationId.count()))
            .getSingle();
    return count ?? 0;
  }

  Future<int> markAsSynced(int operationId, bool isSale) =>
      (update(webkassaReceipts)..where(
            (wr) =>
                wr.operationId.equals(operationId) & wr.isSale.equals(isSale),
          ))
          .write(const WebkassaReceiptsCompanion(wkOfflineMode: Value(false)));

  Future<int> updateFromServer({
    required int operationId,
    required bool isSale,
    String? fiscalNo,
    String? wkReceiptNo,
    String? ticketUrl,
  }) =>
      (update(webkassaReceipts)..where(
            (wr) =>
                wr.operationId.equals(operationId) & wr.isSale.equals(isSale),
          ))
          .write(
            WebkassaReceiptsCompanion(
              fiscalNo: fiscalNo != null
                  ? Value(fiscalNo)
                  : const Value.absent(),
              wkReceiptNo: wkReceiptNo != null
                  ? Value(wkReceiptNo)
                  : const Value.absent(),
              ticketUrl: ticketUrl != null
                  ? Value(ticketUrl)
                  : const Value.absent(),
              wkOfflineMode: const Value(false),
            ),
          );

  Future<List<WebkassaReceipt>> findPendingFiscalization() =>
      (select(webkassaReceipts)..where(
            (wr) =>
                wr.fiscalNo.isNull() |
                wr.fiscalNo.equals('') |
                wr.wkOfflineMode.equals(true),
          ))
          .get();

  Future<OfflineReceiptStats> getOfflineStats() async {
    final all = await findOfflineReceipts();

    int salesCount = 0;
    int refundsCount = 0;

    for (final receipt in all) {
      if (receipt.isSale == true) {
        salesCount++;
      } else {
        refundsCount++;
      }
    }

    return OfflineReceiptStats(
      totalCount: all.length,
      salesCount: salesCount,
      refundsCount: refundsCount,
    );
  }

  Future<void> createConfig({
    required int posId,
    String? posFactoryNo,
    String? taxDeptRegNo,
    String? ofdId,
    String? taxpayerName,
    String? iinBin,
    String? address,
    String? ofdName,
    String? ofdHost,
    bool isActive = false,
    bool isTaxpayer = false,
    String? taxpayerVatSerialNo,
    String? taxpayerVatNo,
  }) async {
    await upsertConfig(
      WebkassaConfigsCompanion(
        posId: Value(posId),
        posFactoryNo: Value(posFactoryNo),
        taxDeptRegNo: Value(taxDeptRegNo),
        ofdId: Value(ofdId),
        taxpayerName: Value(taxpayerName),
        iinBin: Value(iinBin),
        address: Value(address),
        ofdName: Value(ofdName),
        ofdHost: Value(ofdHost),
        isActive: Value(isActive),
        isTaxpayer: Value(isTaxpayer),
        taxpayerVatSerialNo: Value(taxpayerVatSerialNo),
        taxpayerVatNo: Value(taxpayerVatNo),
      ),
    );
  }
}

class OfflineReceiptStats {
  const OfflineReceiptStats({
    required this.totalCount,
    required this.salesCount,
    required this.refundsCount,
  });

  final int totalCount;

  final int salesCount;

  final int refundsCount;

  bool get hasOfflineReceipts => totalCount > 0;

  @override
  String toString() =>
      'OfflineReceiptStats(total: $totalCount, sales: $salesCount, refunds: $refundsCount)';
}
