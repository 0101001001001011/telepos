import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/refund/recent_receipts.dart';

/// Последние чеки этой кассы — из её же базы.
///
/// Тот же запрос, что стоял внутри `ReceiptInputDialog._loadRecent`
/// (`saleDao.findRecentCompleted`), только теперь он за контрактом и потому
/// не мешает диалогу собираться под браузер.
class LocalRecentReceipts implements RecentReceipts {
  const LocalRecentReceipts(this._db);

  final AppDatabase _db;

  @override
  Future<List<RecentReceipt>> recent({int limit = 30}) async {
    final rows = await _db.saleDao.findRecentCompleted(limit: limit);
    return [
      for (final sale in rows)
        RecentReceipt(
          receiptNo: sale.receiptNo,
          posId: sale.posId,
          time: sale.time,
          amount: sale.amount,
        ),
    ];
  }
}
