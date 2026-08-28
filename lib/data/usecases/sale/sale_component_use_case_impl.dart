import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/sale/sale_component_use_case.dart';
import 'package:telepos/domain/usecases/sale/universal_product_use_case.dart';

class SaleComponentUseCaseImpl implements SaleComponentUseCase {
  SaleComponentUseCaseImpl({required AppDatabase db, required Talker logger})
    : _db = db,
      _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  @override
  Future<SaleComponent?> get({
    required int receiptNo,
    required int posId,
  }) async {
    final sales =
        await (_db.select(_db.sales)..where(
              (s) => s.receiptNo.equals(receiptNo) & s.posId.equals(posId),
            ))
            .get();

    if (sales.isEmpty) {
      _logger.warning(
        'SaleComponent: sale not found receipt=$receiptNo, pos=$posId',
      );
      return null;
    }
    final sale = sales.first;

    final saleProducts = await _db.saleProductDao.findBySale(receiptNo, posId);

    final products = <SaleComponentProduct>[];
    for (final sp in saleProducts) {
      products.add(
        SaleComponentProduct(
          id: sp.id,
          ucode: sp.ucode,
          quantity: sp.quantity,
          price: sp.price,
          priceBefore: sp.priceBefore,
          isUniversal: false,
          barcode: sp.barcode,
          categoryId: sp.categoryId,
        ),
      );
    }

    final universalProducts = await _db.saleProductDao.findUniversalBySale(
      receiptNo,
      posId,
    );
    for (final up in universalProducts) {
      products.add(
        SaleComponentProduct(
          id: up.id,
          ucode: UniversalProductUseCase.universalUcode,
          quantity: up.quantity,
          price: up.price,
          priceBefore: up.priceBefore ?? up.price,
          isUniversal: true,
        ),
      );
    }

    final marks = <int, List<String>>{};
    for (final sp in saleProducts) {
      if (sp.ucode == UniversalProductUseCase.universalUcode) continue;
      final productMarks = await _db.saleProductDao.findMarksBySaleProduct(
        sp.id,
      );
      final markStrings = productMarks
          .where((m) => m.mark != null)
          .map((m) => m.mark!)
          .toList();
      if (markStrings.isNotEmpty) {
        marks[sp.ucode] = markStrings;
      }
    }

    final paymentsDb = await _db.paymentDao.findBySale(receiptNo, posId);
    final payments = paymentsDb
        .map(
          (p) => SaleComponentPayment(
            id: p.id,
            userId: p.userId,
            payeeAccountId: p.payeeAccountId,
            amount: p.amount,
            time: p.time,
            state: p.state,
            customerLocalId: p.customerLocalId,
          ),
        )
        .toList();

    final customFieldsDb = await _db.saleProductDao.findCustomFieldsByReceiptNo(
      receiptNo,
    );
    final customFields = customFieldsDb
        .where((cf) => cf.customFieldId != null && cf.customFieldItemId != null)
        .map(
          (cf) => SaleComponentCustomField(
            customFieldId: cf.customFieldId!,
            customFieldItemId: cf.customFieldItemId!,
          ),
        )
        .toList();

    final withdrawalDb = await _db.saleDao.findWithdrawalBySale(
      receiptNo,
      posId,
    );
    SaleComponentWithdrawal? withdrawal;
    if (withdrawalDb != null &&
        withdrawalDb.agentAccountId != null &&
        withdrawalDb.amount != null) {
      withdrawal = SaleComponentWithdrawal(
        agentAccountId: withdrawalDb.agentAccountId!,
        amount: withdrawalDb.amount!,
      );
    }

    SaleComponentWebkassaReceipt? webkassaReceipt;
    if (sale.saleId != null) {
      final wkReceipt = await _db.webkassaReceiptDao.findByIsSaleAndOperationId(
        true,
        sale.saleId!,
      );
      if (wkReceipt != null) {
        webkassaReceipt = SaleComponentWebkassaReceipt(
          operationId: wkReceipt.operationId,
          receiptNo: wkReceipt.receiptNo,
          fiscalNo: wkReceipt.fiscalNo,
          wkReceiptNo: wkReceipt.wkReceiptNo,
          wkTime: wkReceipt.wkTime,
          wkOfflineMode: wkReceipt.wkOfflineMode,
          ticketUrl: wkReceipt.ticketUrl,
          isSale: wkReceipt.isSale,
        );
      }
    }

    _logger.info(
      'SaleComponent: assembled receipt=$receiptNo, '
      '${products.length} products, ${payments.length} payments',
    );

    return SaleComponent(
      receiptNo: sale.receiptNo,
      posId: sale.posId,
      saleId: sale.saleId,
      userId: sale.userId,
      amount: sale.amount,
      change: sale.change ?? Decimal.zero,
      time: sale.time,
      isOfd: sale.isOfd,
      isWholesale: sale.isWholesale,
      state: sale.state,
      storeId: sale.storeId,
      customerLocalId: sale.customerLocalId,
      customerServerId: sale.customerServerId,
      loyalCustomerPhone: sale.loyalCustomerPhone,
      customerBin: sale.customerBin,
      weightProductRoundType: sale.weightProductRoundType,
      discountsRoundType: sale.discountsRoundType,
      saleProducts: products,
      payments: payments,
      marks: marks,
      saleCustomFields: customFields,
      saleWithdrawal: withdrawal,
      webkassaReceipt: webkassaReceipt,
    );
  }
}
