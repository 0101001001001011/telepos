import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/refund/refund_component_use_case.dart';

class RefundComponentUseCaseImpl implements RefundComponentUseCase {
  RefundComponentUseCaseImpl({required AppDatabase db, required Talker logger})
    : _db = db,
      _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  @override
  Future<RefundComponent> get({required int refundLocalId}) async {
    final refunds = await (_db.select(
      _db.refunds,
    )..where((r) => r.localId.equals(refundLocalId))).get();

    if (refunds.isEmpty) {
      throw StateError('Refund $refundLocalId not found');
    }

    final refund = refunds.first;

    final refundProducts = await _db.refundDao.findProductsByRefund(
      refundLocalId,
    );

    final products = <RefundComponentProduct>[];
    for (final rp in refundProducts) {
      final marks = await _db.refundDao.findMarksByRefundProduct(rp.id);
      products.add(
        RefundComponentProduct(
          id: rp.id,
          ucode: rp.ucode,
          quantity: rp.quantity,
          price: rp.price,
          inSalePrice: rp.inSalePrice,
          inSaleQuantity: rp.inSaleQuantity,
          inSalePriceBefore: rp.inSalePriceBefore,
          marks: marks
              .where((m) => m.mark != null)
              .map((m) => m.mark!)
              .toList(),
        ),
      );
    }

    final universalProductsRaw = await _db.saleProductDao.findUniversalByRefund(
      refundLocalId,
    );
    final universalProducts = universalProductsRaw
        .map(
          (up) => RefundComponentUniversal(
            id: up.id,
            quantity: up.quantity,
            price: up.price,
            priceBefore: up.priceBefore,
            inSalePrice: up.inSalePrice,
            inSaleQuantity: up.inSaleQuantity,
          ),
        )
        .toList();

    final paymentsRaw = await _db.paymentDao.findByRefund(refundLocalId);
    final payments = paymentsRaw
        .map(
          (p) => RefundComponentPayment(
            id: p.id,
            payeeAccountId: p.payeeAccountId,
            amount: p.amount,
            time: p.time,
          ),
        )
        .toList();

    _logger.info(
      'RefundComponent: loaded refund=$refundLocalId, '
      'products=${products.length}, universal=${universalProducts.length}, '
      'payments=${payments.length}',
    );

    return RefundComponent(
      refundLocalId: refund.localId,
      amount: refund.amount,
      time: refund.time,
      userId: refund.userId,
      saleReceiptNo: refund.saleReceiptNo,
      salePosId: refund.salePosId,
      saleId: refund.saleId,
      customerLocalId: refund.customerLocalId,
      customerServerId: refund.customerServerId,
      cashbackAmount: refund.cashbackAmount,
      isOfd: refund.isOfd,
      state: refund.state,
      products: products,
      universalProducts: universalProducts,
      payments: payments,
    );
  }
}
