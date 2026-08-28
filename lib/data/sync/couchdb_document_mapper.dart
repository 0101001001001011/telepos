class CouchDbDocumentMapper {
  const CouchDbDocumentMapper._();

  static String productDocId(int ucode) => 'product:$ucode';
  static String categoryDocId(int id) => 'category:$id';
  static String saleDocId(int receiptNo, int posId) => 'sale:$receiptNo:$posId';
  static String refundDocId(int localId) => 'refund:$localId';
  static String shiftDocId(int id) => 'shift:$id';
  static String agentDocId(int localId) => 'agent:$localId';
  static String supplyDocId(int id) => 'supply:$id';
  static String configDocId(String key) => 'config:$key';
  static String employeeDocId(int id) => 'employee:$id';
  static String writeoffDocId(int id) => 'writeoff:$id';
  static String movementDocId(int id) => 'movement:$id';
  static String inventoryDocId(int id) => 'inventory:$id';
  static String supplierReturnDocId(int id) => 'supplier_return:$id';

  static String? typeFromDocId(String docId) {
    final idx = docId.indexOf(':');
    return idx > 0 ? docId.substring(0, idx) : null;
  }

  static Map<String, dynamic> productToDoc({
    required Map<String, dynamic> productInfo,
    Map<String, dynamic>? productPrice,
    String? rev,
  }) {
    final ucode = productInfo['ucode'] as int;
    return {
      '_id': productDocId(ucode),
      if (rev != null) '_rev': rev,
      'type': 'product',
      'ucode': ucode,
      'barcode': productInfo['barcode'],
      'name': productInfo['name'],
      'category_id': productInfo['category_id'],
      'product_type': productInfo['type'],
      'measure': productInfo['measure'],
      'quantity': productInfo['quantity']?.toString(),
      'description': productInfo['description'],
      'image_path': productInfo['image_path'],
      'is_deleted': productInfo['is_deleted'] ?? false,
      'local_edit_time': productInfo['local_edit_time'],
      'server_edit_time': productInfo['server_edit_time'],
      if (productPrice != null) ...{
        'selling_price': productPrice['selling_price']?.toString(),
        'wholesale_price': productPrice['wholesale_price']?.toString(),
        'price_edit_time': productPrice['edit_time'],
      },
    };
  }

  static Map<String, dynamic> docToProductInfo(Map<String, dynamic> doc) {
    return {
      'ucode': doc['ucode'],
      'barcode': doc['barcode'],
      'name': doc['name'],
      'category_id': doc['category_id'],
      'type': doc['product_type'],
      'measure': doc['measure'],
      'quantity': doc['quantity'],
      'description': doc['description'],
      'image_path': doc['image_path'],
      'is_deleted': doc['is_deleted'] ?? false,
      'local_edit_time': doc['local_edit_time'],
      'server_edit_time': doc['server_edit_time'],
    };
  }

  static Map<String, dynamic>? docToProductPrice(Map<String, dynamic> doc) {
    if (doc['selling_price'] == null) return null;
    return {
      'ucode': doc['ucode'],
      'barcode': doc['barcode'],
      'selling_price': doc['selling_price'],
      'wholesale_price': doc['wholesale_price'],
      'edit_time': doc['price_edit_time'],
    };
  }

  static Map<String, dynamic> saleToDoc({
    required Map<String, dynamic> sale,
    List<Map<String, dynamic>> products = const [],
    List<Map<String, dynamic>> payments = const [],
    String? rev,
  }) {
    final receiptNo = sale['receipt_no'] as int;
    final posId = sale['pos_id'] as int;
    return {
      '_id': saleDocId(receiptNo, posId),
      if (rev != null) '_rev': rev,
      'type': 'sale',
      'receipt_no': receiptNo,
      'pos_id': posId,
      'sale_id': sale['sale_id'],
      'user_id': sale['user_id'],
      'amount': sale['amount']?.toString(),
      'change': sale['change']?.toString(),
      'time': sale['time'],
      'store_id': sale['store_id'],
      'customer_local_id': sale['customer_local_id'],
      'customer_server_id': sale['customer_server_id'],
      'is_ofd': sale['is_ofd'],
      'state': sale['state'],
      'sync_state': sale['state'] == 3 ? 'synced' : 'pending',
      'is_wholesale': sale['is_wholesale'],
      'products': products,
      'payments': payments,
    };
  }

  static Map<String, dynamic> docToSale(Map<String, dynamic> doc) {
    return {
      'receipt_no': doc['receipt_no'],
      'pos_id': doc['pos_id'],
      'sale_id': doc['sale_id'],
      'user_id': doc['user_id'],
      'amount': doc['amount'],
      'change': doc['change'],
      'time': doc['time'],
      'store_id': doc['store_id'],
      'customer_local_id': doc['customer_local_id'],
      'customer_server_id': doc['customer_server_id'],
      'is_ofd': doc['is_ofd'],
      'state': doc['state'],
      'is_wholesale': doc['is_wholesale'],
    };
  }

  static Map<String, dynamic> shiftToDoc({
    required Map<String, dynamic> shift,
    String? rev,
  }) {
    final id = shift['id'] as int;
    return {
      '_id': shiftDocId(id),
      if (rev != null) '_rev': rev,
      'type': 'shift',
      'shift_id': id,
      'user_id': shift['user_id'],
      'open_time': shift['open_time'],
      'is_opened': shift['is_opened'] ?? false,
      'close_time': shift['close_time'],
      'cash_in_pos_on_shift_close': shift['cash_in_pos_on_shift_close']
          ?.toString(),
      'is_synced': shift['is_synced'] ?? false,
    };
  }

  static Map<String, dynamic> docToShift(Map<String, dynamic> doc) {
    return {
      'id': doc['shift_id'],
      'user_id': doc['user_id'],
      'open_time': doc['open_time'],
      'is_opened': doc['is_opened'],
      'close_time': doc['close_time'],
      'cash_in_pos_on_shift_close': doc['cash_in_pos_on_shift_close'],
      'is_synced': doc['is_synced'],
    };
  }

  static Map<String, dynamic> agentToDoc({
    required Map<String, dynamic> agent,
    String? rev,
  }) {
    final localId = agent['local_id'] as int;
    return {
      '_id': agentDocId(localId),
      if (rev != null) '_rev': rev,
      'type': 'agent',
      'local_id': localId,
      'server_id': agent['server_id'],
      'agent_type': agent['type'],
      'store_id': agent['store_id'],
      'name': agent['name'],
      'phone': agent['phone'],
      'bin': agent['bin'],
      'legal_type': agent['legal_type'],
      'legal_address': agent['legal_address'],
      'actual_address': agent['actual_address'],
      'note': agent['note'],
      'legal_name': agent['legal_name'],
      'is_deleted': agent['is_deleted'] ?? false,
      'edit_time': agent['edit_time'],
      'server_edit_time': agent['server_edit_time'],
      'state': agent['state'],
    };
  }

  static Map<String, dynamic> docToAgent(Map<String, dynamic> doc) {
    return {
      'local_id': doc['local_id'],
      'server_id': doc['server_id'],
      'type': doc['agent_type'],
      'store_id': doc['store_id'],
      'name': doc['name'],
      'phone': doc['phone'],
      'bin': doc['bin'],
      'legal_type': doc['legal_type'],
      'legal_address': doc['legal_address'],
      'actual_address': doc['actual_address'],
      'note': doc['note'],
      'legal_name': doc['legal_name'],
      'is_deleted': doc['is_deleted'],
      'edit_time': doc['edit_time'],
      'server_edit_time': doc['server_edit_time'],
      'state': doc['state'],
    };
  }

  static Map<String, dynamic> categoryToDoc({
    required Map<String, dynamic> category,
    String? rev,
  }) {
    final id = category['id'] as int;
    return {
      '_id': categoryDocId(id),
      if (rev != null) '_rev': rev,
      'type': 'category',
      'category_id': id,
      'parent_id': category['parent_id'],
      'name': category['name'],
      'global_category': category['global_category'],
      'create_time': category['create_time'],
      'edit_time': category['edit_time'],
    };
  }

  static Map<String, dynamic> docToCategory(Map<String, dynamic> doc) {
    return {
      'id': doc['category_id'],
      'parent_id': doc['parent_id'],
      'name': doc['name'],
      'global_category': doc['global_category'],
      'create_time': doc['create_time'],
      'edit_time': doc['edit_time'],
    };
  }

  static Map<String, dynamic> refundToDoc({
    required Map<String, dynamic> refund,
    List<Map<String, dynamic>> products = const [],
    String? rev,
  }) {
    final localId = refund['local_id'] as int;
    return {
      '_id': refundDocId(localId),
      if (rev != null) '_rev': rev,
      'type': 'refund',
      'local_id': localId,
      'server_id': refund['server_id'],
      'sale_receipt_no': refund['sale_receipt_no'],
      'sale_pos_id': refund['sale_pos_id'],
      'user_id': refund['user_id'],
      'amount': refund['amount']?.toString(),
      'cashback_amount': refund['cashback_amount']?.toString(),
      'time': refund['time'],
      'state': refund['state'],
      'is_ofd': refund['is_ofd'],
      'products': products,
    };
  }

  static Map<String, dynamic> docToRefund(Map<String, dynamic> doc) {
    return {
      'local_id': doc['local_id'],
      'server_id': doc['server_id'],
      'sale_receipt_no': doc['sale_receipt_no'],
      'sale_pos_id': doc['sale_pos_id'],
      'user_id': doc['user_id'],
      'amount': doc['amount'],
      'cashback_amount': doc['cashback_amount'],
      'time': doc['time'],
      'state': doc['state'],
      'is_ofd': doc['is_ofd'],
    };
  }

  static Map<String, dynamic> supplyToDoc({
    required Map<String, dynamic> supply,
    List<Map<String, dynamic>> products = const [],
    String? rev,
  }) {
    final id = supply['id'] as int;
    return {
      '_id': supplyDocId(id),
      if (rev != null) '_rev': rev,
      'type': 'supply',
      'supply_id': id,
      'operation_type': supply['operation_type'],
      'user_id': supply['user_id'],
      'supplier_id': supply['supplier_id'],
      'edit_time': supply['edit_time'],
      'amount': supply['amount']?.toString(),
      'payment_type': supply['payment_type'],
      'comment': supply['comment'],
      'state': supply['state'],
      'status': supply['status'],
      'products': products,
    };
  }

  static Map<String, dynamic> docToSupply(Map<String, dynamic> doc) {
    return {
      'id': doc['supply_id'],
      'operation_type': doc['operation_type'],
      'user_id': doc['user_id'],
      'supplier_id': doc['supplier_id'],
      'edit_time': doc['edit_time'],
      'amount': doc['amount'],
      'payment_type': doc['payment_type'],
      'comment': doc['comment'],
      'state': doc['state'],
      'status': doc['status'],
    };
  }

  static Map<String, dynamic> writeoffToDoc({
    required Map<String, dynamic> writeoff,
    List<Map<String, dynamic>> products = const [],
    String? rev,
  }) {
    final id = writeoff['id'] as int;
    return {
      '_id': writeoffDocId(id),
      if (rev != null) '_rev': rev,
      'type': 'writeoff',
      'writeoff_id': id,
      'user_id': writeoff['user_id'],
      'doc_time': writeoff['doc_time'],
      'reason': writeoff['reason'],
      'comment': writeoff['comment'],
      'amount': writeoff['amount']?.toString(),
      'state': writeoff['state'],
      'products': products,
    };
  }

  static Map<String, dynamic> docToWriteoff(Map<String, dynamic> doc) {
    return {
      'id': doc['writeoff_id'],
      'user_id': doc['user_id'],
      'doc_time': doc['doc_time'],
      'reason': doc['reason'],
      'comment': doc['comment'],
      'amount': doc['amount'],
      'state': doc['state'],
    };
  }

  static Map<String, dynamic> movementToDoc({
    required Map<String, dynamic> movement,
    List<Map<String, dynamic>> products = const [],
    String? rev,
  }) {
    final id = movement['id'] as int;
    return {
      '_id': movementDocId(id),
      if (rev != null) '_rev': rev,
      'type': 'movement',
      'movement_id': id,
      'user_id': movement['user_id'],
      'edit_time': movement['edit_time'],
      'amount': movement['amount']?.toString(),
      'comment': movement['comment'],
      'from_location': movement['from_location'],
      'to_location': movement['to_location'],
      'state': movement['state'],
      'status': movement['status'],
      'products': products,
    };
  }

  static Map<String, dynamic> docToMovement(Map<String, dynamic> doc) {
    return {
      'id': doc['movement_id'],
      'user_id': doc['user_id'],
      'edit_time': doc['edit_time'],
      'amount': doc['amount'],
      'comment': doc['comment'],
      'from_location': doc['from_location'],
      'to_location': doc['to_location'],
      'state': doc['state'],
      'status': doc['status'],
    };
  }

  static Map<String, dynamic> inventoryToDoc({
    required Map<String, dynamic> inventory,
    List<Map<String, dynamic>> products = const [],
    String? rev,
  }) {
    final id = inventory['id'] as int;
    return {
      '_id': inventoryDocId(id),
      if (rev != null) '_rev': rev,
      'type': 'inventory',
      'inventory_id': id,
      'user_id': inventory['user_id'],
      'start_time': inventory['start_time'],
      'end_time': inventory['end_time'],
      'status': inventory['status'],
      'comment': inventory['comment'],
      'discrepancy_count': inventory['discrepancy_count'],
      'is_full_count': inventory['is_full_count'],
      'state': inventory['state'],
      'products': products,
    };
  }

  static Map<String, dynamic> docToInventory(Map<String, dynamic> doc) {
    return {
      'id': doc['inventory_id'],
      'user_id': doc['user_id'],
      'start_time': doc['start_time'],
      'end_time': doc['end_time'],
      'status': doc['status'],
      'comment': doc['comment'],
      'discrepancy_count': doc['discrepancy_count'],
      'is_full_count': doc['is_full_count'],
      'state': doc['state'],
    };
  }

  static Map<String, dynamic> supplierReturnToDoc({
    required Map<String, dynamic> supplierReturn,
    List<Map<String, dynamic>> products = const [],
    String? rev,
  }) {
    final id = supplierReturn['id'] as int;
    return {
      '_id': supplierReturnDocId(id),
      if (rev != null) '_rev': rev,
      'type': 'supplier_return',
      'supplier_return_id': id,
      'user_id': supplierReturn['user_id'],
      'supplier_id': supplierReturn['supplier_id'],
      'edit_time': supplierReturn['edit_time'],
      'amount': supplierReturn['amount']?.toString(),
      'account_id': supplierReturn['account_id'],
      'comment': supplierReturn['comment'],
      'supply_id': supplierReturn['supply_id'],
      'state': supplierReturn['state'],
      'status': supplierReturn['status'],
      'products': products,
    };
  }

  static Map<String, dynamic> docToSupplierReturn(Map<String, dynamic> doc) {
    return {
      'id': doc['supplier_return_id'],
      'user_id': doc['user_id'],
      'supplier_id': doc['supplier_id'],
      'edit_time': doc['edit_time'],
      'amount': doc['amount'],
      'account_id': doc['account_id'],
      'comment': doc['comment'],
      'supply_id': doc['supply_id'],
      'state': doc['state'],
      'status': doc['status'],
    };
  }
}
