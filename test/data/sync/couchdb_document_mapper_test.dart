import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/sync/couchdb_document_mapper.dart';

void main() {
  group('Document ID generation', () {
    test('productDocId', () {
      expect(CouchDbDocumentMapper.productDocId(12345), 'product:12345');
    });

    test('saleDocId', () {
      expect(CouchDbDocumentMapper.saleDocId(1, 100), 'sale:1:100');
    });

    test('shiftDocId', () {
      expect(CouchDbDocumentMapper.shiftDocId(42), 'shift:42');
    });

    test('agentDocId', () {
      expect(CouchDbDocumentMapper.agentDocId(7), 'agent:7');
    });

    test('categoryDocId', () {
      expect(CouchDbDocumentMapper.categoryDocId(3), 'category:3');
    });

    test('refundDocId', () {
      expect(CouchDbDocumentMapper.refundDocId(99), 'refund:99');
    });

    test('supplyDocId', () {
      expect(CouchDbDocumentMapper.supplyDocId(5), 'supply:5');
    });

    test('configDocId', () {
      expect(
        CouchDbDocumentMapper.configDocId('pos_settings'),
        'config:pos_settings',
      );
    });
  });

  group('typeFromDocId', () {
    test('extracts type from standard doc ID', () {
      expect(CouchDbDocumentMapper.typeFromDocId('product:123'), 'product');
      expect(CouchDbDocumentMapper.typeFromDocId('sale:1:100'), 'sale');
      expect(CouchDbDocumentMapper.typeFromDocId('shift:42'), 'shift');
    });

    test('returns null for invalid doc ID', () {
      expect(CouchDbDocumentMapper.typeFromDocId('nocolon'), isNull);
      expect(CouchDbDocumentMapper.typeFromDocId(''), isNull);
    });
  });

  group('Product mapping', () {
    test('productToDoc creates correct document', () {
      final doc = CouchDbDocumentMapper.productToDoc(
        productInfo: {
          'ucode': 12345,
          'barcode': '4607001234567',
          'name': 'Test Product',
          'category_id': 3,
          'type': 0,
          'measure': 'pcs',
          'quantity': '100.000',
          'description': null,
          'image_path': null,
          'is_deleted': false,
          'local_edit_time': 1700000000,
          'server_edit_time': 1700000000,
        },
        productPrice: {
          'selling_price': '1500.000',
          'wholesale_price': '1200.000',
          'edit_time': 1700000000,
        },
      );

      expect(doc['_id'], 'product:12345');
      expect(doc['type'], 'product');
      expect(doc['ucode'], 12345);
      expect(doc['barcode'], '4607001234567');
      expect(doc['name'], 'Test Product');
      expect(doc['selling_price'], '1500.000');
      expect(doc['wholesale_price'], '1200.000');
      expect(doc['is_deleted'], false);
    });

    test('productToDoc without price data', () {
      final doc = CouchDbDocumentMapper.productToDoc(
        productInfo: {
          'ucode': 1,
          'barcode': '123',
          'name': 'Simple',
          'category_id': null,
          'type': null,
          'measure': null,
          'quantity': null,
          'description': null,
          'image_path': null,
          'is_deleted': false,
          'local_edit_time': null,
          'server_edit_time': null,
        },
      );

      expect(doc['selling_price'], isNull);
      expect(doc.containsKey('selling_price'), false);
    });

    test('docToProductInfo round-trips correctly', () {
      final original = {
        'ucode': 999,
        'barcode': '000',
        'name': 'Round Trip',
        'category_id': 5,
        'type': 1,
        'measure': 'kg',
        'quantity': '50.500',
        'description': 'desc',
        'image_path': '/path.jpg',
        'is_deleted': false,
        'local_edit_time': 123,
        'server_edit_time': 456,
      };

      final doc = CouchDbDocumentMapper.productToDoc(productInfo: original);
      final restored = CouchDbDocumentMapper.docToProductInfo(doc);

      expect(restored['ucode'], original['ucode']);
      expect(restored['barcode'], original['barcode']);
      expect(restored['name'], original['name']);
      expect(restored['category_id'], original['category_id']);
    });
  });

  group('Sale mapping', () {
    test('saleToDoc creates correct document', () {
      final doc = CouchDbDocumentMapper.saleToDoc(
        sale: {
          'receipt_no': 1,
          'pos_id': 100,
          'sale_id': null,
          'user_id': 42,
          'amount': '5000.000',
          'change': '0.000',
          'time': 1700000000,
          'store_id': 1,
          'customer_local_id': null,
          'customer_server_id': null,
          'is_ofd': true,
          'state': 1,
          'is_wholesale': false,
        },
        products: [
          {'ucode': 111, 'quantity': '2.000', 'price': '2500.000'},
        ],
        payments: [
          {'type': 'cash', 'amount': '5000.000'},
        ],
      );

      expect(doc['_id'], 'sale:1:100');
      expect(doc['type'], 'sale');
      expect(doc['receipt_no'], 1);
      expect(doc['pos_id'], 100);
      expect(doc['amount'], '5000.000');
      expect(doc['products'], hasLength(1));
      expect(doc['payments'], hasLength(1));
      expect(doc['sync_state'], 'pending');
    });

    test('saleToDoc with synced state', () {
      final doc = CouchDbDocumentMapper.saleToDoc(
        sale: {'receipt_no': 1, 'pos_id': 1, 'state': 3},
      );
      expect(doc['sync_state'], 'synced');
    });
  });

  group('Shift mapping', () {
    test('shiftToDoc round-trips', () {
      final original = {
        'id': 10,
        'user_id': 42,
        'open_time': 1700000000,
        'is_opened': true,
        'close_time': null,
        'cash_in_pos_on_shift_close': null,
        'is_synced': false,
      };

      final doc = CouchDbDocumentMapper.shiftToDoc(shift: original);
      expect(doc['_id'], 'shift:10');
      expect(doc['type'], 'shift');
      expect(doc['is_opened'], true);

      final restored = CouchDbDocumentMapper.docToShift(doc);
      expect(restored['id'], 10);
      expect(restored['user_id'], 42);
      expect(restored['is_opened'], true);
    });
  });

  group('Agent mapping', () {
    test('agentToDoc round-trips', () {
      final original = {
        'local_id': 5,
        'server_id': 100,
        'type': 1,
        'store_id': 1,
        'name': 'Test Agent',
        'phone': '+77001234567',
        'bin': '123456789012',
        'legal_type': null,
        'legal_address': null,
        'actual_address': 'Address',
        'note': null,
        'legal_name': null,
        'is_deleted': false,
        'edit_time': 1700000000,
        'server_edit_time': null,
        'state': 0,
      };

      final doc = CouchDbDocumentMapper.agentToDoc(agent: original);
      expect(doc['_id'], 'agent:5');
      expect(doc['type'], 'agent');
      expect(doc['name'], 'Test Agent');

      final restored = CouchDbDocumentMapper.docToAgent(doc);
      expect(restored['local_id'], 5);
      expect(restored['name'], 'Test Agent');
      expect(restored['phone'], '+77001234567');
    });
  });

  group('Category mapping', () {
    test('categoryToDoc round-trips', () {
      final doc = CouchDbDocumentMapper.categoryToDoc(
        category: {
          'id': 3,
          'parent_id': null,
          'name': 'Root',
          'global_category': null,
          'create_time': 100,
          'edit_time': 200,
        },
      );
      expect(doc['_id'], 'category:3');
      expect(doc['type'], 'category');

      final restored = CouchDbDocumentMapper.docToCategory(doc);
      expect(restored['id'], 3);
      expect(restored['name'], 'Root');
    });
  });

  group('Refund mapping', () {
    test('refundToDoc creates correct document', () {
      final doc = CouchDbDocumentMapper.refundToDoc(
        refund: {
          'local_id': 99,
          'server_id': null,
          'sale_receipt_no': 1,
          'sale_pos_id': 100,
          'user_id': 42,
          'amount': '2500.000',
          'cashback_amount': '0.000',
          'time': 1700000000,
          'state': 1,
          'is_ofd': true,
        },
        products: [
          {'ucode': 111, 'quantity': '1.000', 'price': '2500.000'},
        ],
      );

      expect(doc['_id'], 'refund:99');
      expect(doc['type'], 'refund');
      expect(doc['products'], hasLength(1));
    });
  });

  group('Supply mapping', () {
    test('supplyToDoc creates correct document', () {
      final doc = CouchDbDocumentMapper.supplyToDoc(
        supply: {
          'id': 5,
          'operation_type': 0,
          'user_id': 42,
          'supplier_id': 3,
          'edit_time': 1700000000,
          'amount': '50000.000',
          'payment_type': 0,
          'comment': 'Test supply',
          'state': 1,
          'status': 0,
        },
      );

      expect(doc['_id'], 'supply:5');
      expect(doc['type'], 'supply');
      expect(doc['amount'], '50000.000');
    });
  });
}
