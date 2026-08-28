import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/core/constants/enums/operating_mode.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/presentation/common/navigation/nav_destinations.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Mode persistence', () {
    test('save restaurant mode → read → mode is restaurant', () async {
      await db.thisPosDao.upsert(
        const ThisPosEntriesCompanion(
          companyName: Value('Test'),
          operatingMode: Value(1),
        ),
      );

      final thisPos = await db.thisPosDao.get();
      expect(thisPos, isNotNull);
      expect(thisPos!.operatingMode, equals(1));

      final mode = OperatingMode.values[thisPos.operatingMode];
      expect(mode, equals(OperatingMode.restaurant));
    });

    test('save service mode → read → mode is service', () async {
      await db.thisPosDao.upsert(
        const ThisPosEntriesCompanion(
          companyName: Value('Test'),
          operatingMode: Value(2),
        ),
      );

      final thisPos = await db.thisPosDao.get();
      expect(thisPos, isNotNull);
      expect(thisPos!.operatingMode, equals(2));

      final mode = OperatingMode.values[thisPos.operatingMode];
      expect(mode, equals(OperatingMode.service));
    });

    test('default operatingMode is 0 (retail)', () async {
      await db.thisPosDao.upsert(
        const ThisPosEntriesCompanion(companyName: Value('Test')),
      );

      final thisPos = await db.thisPosDao.get();
      expect(thisPos, isNotNull);
      expect(thisPos!.operatingMode, equals(0));
    });

    test('updateOperatingMode changes persisted mode', () async {
      await db.thisPosDao.upsert(
        const ThisPosEntriesCompanion(
          companyName: Value('Test'),
          operatingMode: Value(0),
        ),
      );

      await db.thisPosDao.updateOperatingMode(2);

      final thisPos = await db.thisPosDao.get();
      expect(thisPos!.operatingMode, equals(2));
    });
  });

  group('Login routing by mode', () {
    test('retail mode → default route is /sale', () {
      expect(
        NavDestinations.defaultRoute(OperatingMode.retail),
        equals('/sale'),
      );
    });

    test('restaurant mode → default route is /tables', () {
      expect(
        NavDestinations.defaultRoute(OperatingMode.restaurant),
        equals('/tables'),
      );
    });

    test('service mode → default route is /service-queue', () {
      expect(
        NavDestinations.defaultRoute(OperatingMode.service),
        equals('/service-queue'),
      );
    });
  });

  group('Navigation items by mode', () {
    test('retail mode → nav has 8 primary items', () {
      final primary = NavDestinations.primaryForMode(OperatingMode.retail);
      expect(primary.length, equals(8));
    });

    test('restaurant mode → nav has 8 primary items including tables', () {
      final primary = NavDestinations.primaryForMode(OperatingMode.restaurant);
      expect(primary.length, equals(8));
      expect(primary.any((d) => d.route == '/tables'), true);
      expect(primary.any((d) => d.route == '/orders'), true);
    });

    test('service mode → nav has 8 primary items including queue', () {
      final primary = NavDestinations.primaryForMode(OperatingMode.service);
      expect(primary.length, equals(8));
      expect(primary.any((d) => d.route == '/service-queue'), true);
      expect(primary.any((d) => d.route == '/service-intake'), true);
    });
  });

  group('New tables CRUD', () {
    test('RestaurantTables insert and read', () async {
      final id = await db.restaurantTableDao.insert(
        RestaurantTablesCompanion.insert(name: 'Table 1'),
      );

      final table = await db.restaurantTableDao.findById(id);
      expect(table, isNotNull);
      expect(table!.name, equals('Table 1'));
      expect(table.capacity, equals(4));
      expect(table.status, equals(0));
      expect(table.isActive, true);
    });

    test('ServiceOrders insert and read', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      final id = await db.serviceOrderDao.insert(
        ServiceOrdersCompanion.insert(
          orderNumber: 'SO-20260227-001',
          userId: 1,
          intakeTime: now,
          clientName: const Value('Test Client'),
        ),
      );

      final order = await db.serviceOrderDao.findById(id);
      expect(order, isNotNull);
      expect(order!.orderNumber, equals('SO-20260227-001'));
      expect(order.status, equals(0));
      expect(order.clientName, equals('Test Client'));
    });

    test('ServiceMarks with Decimal cost', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      final orderId = await db.serviceOrderDao.insert(
        ServiceOrdersCompanion.insert(
          orderNumber: 'SO-20260227-001',
          userId: 1,
          intakeTime: now,
        ),
      );

      await db.serviceMarkDao.insert(
        ServiceMarksCompanion.insert(
          serviceOrderId: orderId,
          description: 'Repair',
          userId: 1,
          createdAt: now,
          cost: Value(Decimal.parse('150.500')),
        ),
      );

      final cost = await db.serviceMarkDao.sumCostByOrder(orderId);
      expect(cost, isA<Decimal>());
      expect(cost, equals(Decimal.parse('150.5')));
    });

    test('GuestSplits with Decimal shareQuantity', () async {
      await db.guestSplitDao.insert(
        GuestSplitsCompanion.insert(
          orderId: 1,
          guestNumber: 1,
          saleProductId: 100,
          shareQuantity: Decimal.parse('0.333'),
        ),
      );

      final splits = await db.guestSplitDao.getByOrder(1);
      expect(splits.length, equals(1));
      expect(splits.first.shareQuantity, isA<Decimal>());
      expect(splits.first.shareQuantity.toDouble(), closeTo(0.333, 0.001));
    });
  });

  group('Composite FK', () {
    test('RestaurantOrders links to Sales(receiptNo, posId)', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await db
          .into(db.sales)
          .insert(
            SalesCompanion.insert(
              receiptNo: 100,
              posId: 1,
              userId: 1,
              amount: Decimal.zero,
              time: now,
            ),
          );

      final orderId = await db.restaurantOrderDao.insert(
        RestaurantOrdersCompanion.insert(
          openTime: now,
          receiptNo: const Value(100),
          posId: const Value(1),
          tableId: const Value(1),
        ),
      );

      final order = await db.restaurantOrderDao.findBySale(100, 1);
      expect(order, isNotNull);
      expect(order!.id, equals(orderId));
    });
  });

  group('DB schema v3', () {
    test('restaurant_tables table exists', () async {
      final result = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='restaurant_tables'",
          )
          .get();
      expect(result.length, equals(1));
    });

    test('restaurant_orders table exists', () async {
      final result = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='restaurant_orders'",
          )
          .get();
      expect(result.length, equals(1));
    });

    test('guest_splits table exists', () async {
      final result = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='guest_splits'",
          )
          .get();
      expect(result.length, equals(1));
    });

    test('service_orders table exists', () async {
      final result = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='service_orders'",
          )
          .get();
      expect(result.length, equals(1));
    });

    test('service_marks table exists', () async {
      final result = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='service_marks'",
          )
          .get();
      expect(result.length, equals(1));
    });

    test('service_types table exists', () async {
      final result = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='service_types'",
          )
          .get();
      expect(result.length, equals(1));
    });

    test('this_pos_entries has operating_mode column', () async {
      await db.thisPosDao.upsert(
        const ThisPosEntriesCompanion(
          companyName: Value('Test'),
          operatingMode: Value(1),
        ),
      );

      final row = await db.thisPosDao.get();
      expect(row!.operatingMode, equals(1));
    });

    test('sales has order_type column', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await db
          .into(db.sales)
          .insert(
            SalesCompanion.insert(
              receiptNo: 1,
              posId: 1,
              userId: 1,
              amount: Decimal.zero,
              time: now,
              orderType: const Value(2),
            ),
          );

      final row = await db
          .customSelect(
            'SELECT order_type FROM sales WHERE receipt_no = 1 AND pos_id = 1',
          )
          .getSingle();
      expect(row.read<int>('order_type'), equals(2));
    });
  });
}
