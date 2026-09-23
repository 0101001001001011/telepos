/// Занятие отложенного чека через общий CouchDB.
///
/// Тонкая обёртка: вся работа — в `CouchDbSyncCoordinator.claimDeferred`,
/// здесь только граница, за которой корзина не знает про обмен.
library;

import 'package:telepos/data/sync/couchdb_sync_coordinator.dart';
import 'package:telepos/domain/sale/deferred_claim_port.dart';

class CouchDbDeferredClaim implements DeferredClaimPort {
  const CouchDbDeferredClaim(this._coordinator);

  final CouchDbSyncCoordinator _coordinator;

  @override
  Future<int?> claim({
    required int receiptNo,
    required int posId,
    required int byPosId,
  }) => _coordinator.claimDeferred(
    receiptNo: receiptNo,
    posId: posId,
    byPosId: byPosId,
  );

  @override
  Future<void> withdraw({required int receiptNo, required int posId}) =>
      _coordinator.withdrawDeferred(receiptNo: receiptNo, posId: posId);
}
