import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

  group('RestaurantTableDao', () {
    test('insert should create a table and return its id', () async {
      final id = await db.restaurantTableDao.insert(
        RestaurantTablesCompanion.insert(
          name: 'Table 1',
          capacity: const Value(4),
          zone: const Value('Main'),
        ),
      );

      expect(id, isPositive);

      final table = await db.restaurantTableDao.findById(id);
      expect(table, isNotNull);
      expect(table!.name, equals('Table 1'));
      expect(table.capacity, equals(4));
      expect(table.zone, equals('Main'));
      expect(table.isActive, isTrue);
      expect(table.status, equals(0));
    });

    test('getActive should return active tables sorted by sortOrder', () async {
      await db.restaurantTableDao.insert(
        RestaurantTablesCompanion.insert(
          name: 'Table C',
          sortOrder: const Value(3),
        ),
      );
      await db.restaurantTableDao.insert(
        RestaurantTablesCompanion.insert(
          name: 'Table A',
          sortOrder: const Value(1),
        ),
      );
      await db.restaurantTableDao.insert(
        RestaurantTablesCompanion.insert(
          name: 'Table B',
          sortOrder: const Value(2),
        ),
      );
      await db.restaurantTableDao.insert(
        RestaurantTablesCompanion.insert(
          name: 'Inactive Table',
          isActive: const Value(false),
          sortOrder: const Value(0),
        ),
      );

      final tables = await db.restaurantTableDao.getActive();
      expect(tables.length, equals(3));
      expect(tables[0].name, equals('Table A'));
      expect(tables[1].name, equals('Table B'));
      expect(tables[2].name, equals('Table C'));
    });

    test('findById should return null for non-existent id', () async {
      final table = await db.restaurantTableDao.findById(999);
      expect(table, isNull);
    });

    test('updateStatus should change table status', () async {
      final id = await db.restaurantTableDao.insert(
        RestaurantTablesCompanion.insert(name: 'Table 5'),
      );

      var table = await db.restaurantTableDao.findById(id);
      expect(table!.status, equals(0));

      await db.restaurantTableDao.updateStatus(id, 1);
      table = await db.restaurantTableDao.findById(id);
      expect(table!.status, equals(1));

      await db.restaurantTableDao.updateStatus(id, 2);
      table = await db.restaurantTableDao.findById(id);
      expect(table!.status, equals(2));

      await db.restaurantTableDao.updateStatus(id, 3);
      table = await db.restaurantTableDao.findById(id);
      expect(table!.status, equals(3));
    });

    test('getByZone should return active tables filtered by zone', () async {
      await db.restaurantTableDao.insert(
        RestaurantTablesCompanion.insert(
          name: 'Main 1',
          zone: const Value('Main'),
          sortOrder: const Value(2),
        ),
      );
      await db.restaurantTableDao.insert(
        RestaurantTablesCompanion.insert(
          name: 'Main 2',
          zone: const Value('Main'),
          sortOrder: const Value(1),
        ),
      );
      await db.restaurantTableDao.insert(
        RestaurantTablesCompanion.insert(
          name: 'VIP 1',
          zone: const Value('VIP'),
        ),
      );
      await db.restaurantTableDao.insert(
        RestaurantTablesCompanion.insert(
          name: 'Main Inactive',
          zone: const Value('Main'),
          isActive: const Value(false),
        ),
      );

      final mainTables = await db.restaurantTableDao.getByZone('Main');
      expect(mainTables.length, equals(2));
      expect(mainTables[0].name, equals('Main 2'));
      expect(mainTables[1].name, equals('Main 1'));

      final vipTables = await db.restaurantTableDao.getByZone('VIP');
      expect(vipTables.length, equals(1));
      expect(vipTables.first.name, equals('VIP 1'));

      final terraceTables = await db.restaurantTableDao.getByZone('Terrace');
      expect(terraceTables, isEmpty);
    });

    test(
      'countByStatus should return count of active tables with given status',
      () async {
        for (var i = 1; i <= 3; i++) {
          await db.restaurantTableDao.insert(
            RestaurantTablesCompanion.insert(name: 'Free $i'),
          );
        }
        for (var i = 1; i <= 2; i++) {
          final id = await db.restaurantTableDao.insert(
            RestaurantTablesCompanion.insert(name: 'Occupied $i'),
          );
          await db.restaurantTableDao.updateStatus(id, 1);
        }
        await db.restaurantTableDao.insert(
          RestaurantTablesCompanion.insert(
            name: 'Inactive Free',
            isActive: const Value(false),
          ),
        );

        expect(await db.restaurantTableDao.countByStatus(0), equals(3));
        expect(await db.restaurantTableDao.countByStatus(1), equals(2));
        expect(await db.restaurantTableDao.countByStatus(2), equals(0));
      },
    );

    test('deactivate should set isActive to false (soft delete)', () async {
      final id = await db.restaurantTableDao.insert(
        RestaurantTablesCompanion.insert(name: 'To Deactivate'),
      );

      var table = await db.restaurantTableDao.findById(id);
      expect(table!.isActive, isTrue);

      await db.restaurantTableDao.deactivate(id);

      table = await db.restaurantTableDao.findById(id);
      expect(table!.isActive, isFalse);

      final active = await db.restaurantTableDao.getActive();
      expect(active.where((t) => t.id == id), isEmpty);
    });
  });

  group('RestaurantOrderDao', () {
    test('insert should create an order and return its id', () async {
      final id = await db.restaurantOrderDao.insert(
        RestaurantOrdersCompanion.insert(openTime: now),
      );

      expect(id, isPositive);

      final order = await db.restaurantOrderDao.findById(id);
      expect(order, isNotNull);
      expect(order!.openTime, equals(now));
      expect(order.closeTime, isNull);
      expect(order.partySize, equals(1));
      expect(order.orderType, equals(0));
    });

    test(
      'getOpenOrders should return orders where closeTime IS NULL ordered by openTime asc',
      () async {
        await db.restaurantOrderDao.insert(
          RestaurantOrdersCompanion.insert(openTime: now + 200),
        );
        await db.restaurantOrderDao.insert(
          RestaurantOrdersCompanion.insert(openTime: now + 100),
        );
        await db.restaurantOrderDao.insert(
          RestaurantOrdersCompanion.insert(openTime: now),
        );

        final closedId = await db.restaurantOrderDao.insert(
          RestaurantOrdersCompanion.insert(openTime: now + 50),
        );
        await db.restaurantOrderDao.closeOrder(closedId, now + 300);

        final openOrders = await db.restaurantOrderDao.getOpenOrders();
        expect(openOrders.length, equals(3));
        expect(openOrders[0].openTime, equals(now));
        expect(openOrders[1].openTime, equals(now + 100));
        expect(openOrders[2].openTime, equals(now + 200));
      },
    );

    test(
      'findOpenByTable should return the open order for a given table',
      () async {
        final tableId = await db.restaurantTableDao.insert(
          RestaurantTablesCompanion.insert(name: 'Table 1'),
        );

        final orderId = await db.restaurantOrderDao.insert(
          RestaurantOrdersCompanion.insert(
            openTime: now,
            tableId: Value(tableId),
          ),
        );

        final openOrder = await db.restaurantOrderDao.findOpenByTable(tableId);
        expect(openOrder, isNotNull);
        expect(openOrder!.id, equals(orderId));
        expect(openOrder.tableId, equals(tableId));

        await db.restaurantOrderDao.closeOrder(orderId, now + 3600);

        final afterClose = await db.restaurantOrderDao.findOpenByTable(tableId);
        expect(afterClose, isNull);
      },
    );

    test('findById should return null for non-existent id', () async {
      final order = await db.restaurantOrderDao.findById(999);
      expect(order, isNull);
    });

    test('findBySale should return order linked to a specific sale', () async {
      final orderId = await db.restaurantOrderDao.insert(
        RestaurantOrdersCompanion.insert(
          openTime: now,
          receiptNo: const Value(1001),
          posId: const Value(42),
        ),
      );

      await db.restaurantOrderDao.insert(
        RestaurantOrdersCompanion.insert(openTime: now + 100),
      );

      final found = await db.restaurantOrderDao.findBySale(1001, 42);
      expect(found, isNotNull);
      expect(found!.id, equals(orderId));
      expect(found.receiptNo, equals(1001));
      expect(found.posId, equals(42));

      final notFound = await db.restaurantOrderDao.findBySale(9999, 1);
      expect(notFound, isNull);
    });

    test('closeOrder should set closeTime', () async {
      final orderId = await db.restaurantOrderDao.insert(
        RestaurantOrdersCompanion.insert(openTime: now),
      );

      final closeTime = now + 7200;
      await db.restaurantOrderDao.closeOrder(orderId, closeTime);

      final order = await db.restaurantOrderDao.findById(orderId);
      expect(order, isNotNull);
      expect(order!.closeTime, equals(closeTime));
    });

    test('updateTips should set the tips Decimal value', () async {
      final orderId = await db.restaurantOrderDao.insert(
        RestaurantOrdersCompanion.insert(openTime: now),
      );

      var order = await db.restaurantOrderDao.findById(orderId);
      expect(order!.tips, isNull);

      final tips = Decimal.parse('5.50');
      await db.restaurantOrderDao.updateTips(orderId, tips);

      order = await db.restaurantOrderDao.findById(orderId);
      expect(order!.tips, isNotNull);
      expect(order.tips!.toDouble(), closeTo(5.50, 0.001));

      await db.restaurantOrderDao.updateTips(orderId, null);
      order = await db.restaurantOrderDao.findById(orderId);
      expect(order!.tips, isNull);
    });
  });

  group('GuestSplitDao', () {
    late int orderId;

    setUp(() async {
      orderId = await db.restaurantOrderDao.insert(
        RestaurantOrdersCompanion.insert(openTime: now),
      );
    });

    test('insert should create a guest split record', () async {
      final id = await db.guestSplitDao.insert(
        GuestSplitsCompanion.insert(
          orderId: orderId,
          guestNumber: 1,
          saleProductId: 1,
          shareQuantity: Decimal.parse('0.5'),
        ),
      );

      expect(id, isPositive);
    });

    test(
      'getByOrder should return splits sorted by guestNumber then saleProductId',
      () async {
        await db.guestSplitDao.insert(
          GuestSplitsCompanion.insert(
            orderId: orderId,
            guestNumber: 2,
            saleProductId: 1,
            shareQuantity: Decimal.parse('0.5'),
          ),
        );
        await db.guestSplitDao.insert(
          GuestSplitsCompanion.insert(
            orderId: orderId,
            guestNumber: 1,
            saleProductId: 2,
            shareQuantity: Decimal.parse('0.3'),
          ),
        );
        await db.guestSplitDao.insert(
          GuestSplitsCompanion.insert(
            orderId: orderId,
            guestNumber: 1,
            saleProductId: 1,
            shareQuantity: Decimal.parse('0.7'),
          ),
        );

        final splits = await db.guestSplitDao.getByOrder(orderId);
        expect(splits.length, equals(3));
        expect(splits[0].guestNumber, equals(1));
        expect(splits[0].saleProductId, equals(1));
        expect(splits[1].guestNumber, equals(1));
        expect(splits[1].saleProductId, equals(2));
        expect(splits[2].guestNumber, equals(2));
        expect(splits[2].saleProductId, equals(1));
      },
    );

    test(
      'getByGuest should return splits filtered by order and guest number',
      () async {
        await db.guestSplitDao.insert(
          GuestSplitsCompanion.insert(
            orderId: orderId,
            guestNumber: 1,
            saleProductId: 10,
            shareQuantity: Decimal.parse('1.0'),
          ),
        );
        await db.guestSplitDao.insert(
          GuestSplitsCompanion.insert(
            orderId: orderId,
            guestNumber: 1,
            saleProductId: 20,
            shareQuantity: Decimal.parse('0.5'),
          ),
        );
        await db.guestSplitDao.insert(
          GuestSplitsCompanion.insert(
            orderId: orderId,
            guestNumber: 2,
            saleProductId: 10,
            shareQuantity: Decimal.parse('0.5'),
          ),
        );

        final guest1Splits = await db.guestSplitDao.getByGuest(orderId, 1);
        expect(guest1Splits.length, equals(2));
        for (final s in guest1Splits) {
          expect(s.guestNumber, equals(1));
        }

        final guest2Splits = await db.guestSplitDao.getByGuest(orderId, 2);
        expect(guest2Splits.length, equals(1));
        expect(guest2Splits.first.guestNumber, equals(2));

        final guest3Splits = await db.guestSplitDao.getByGuest(orderId, 3);
        expect(guest3Splits, isEmpty);
      },
    );

    test('deleteByOrder should remove all splits for the order', () async {
      await db.guestSplitDao.insert(
        GuestSplitsCompanion.insert(
          orderId: orderId,
          guestNumber: 1,
          saleProductId: 1,
          shareQuantity: Decimal.parse('0.5'),
        ),
      );
      await db.guestSplitDao.insert(
        GuestSplitsCompanion.insert(
          orderId: orderId,
          guestNumber: 2,
          saleProductId: 1,
          shareQuantity: Decimal.parse('0.5'),
        ),
      );

      final otherOrderId = await db.restaurantOrderDao.insert(
        RestaurantOrdersCompanion.insert(openTime: now + 100),
      );
      await db.guestSplitDao.insert(
        GuestSplitsCompanion.insert(
          orderId: otherOrderId,
          guestNumber: 1,
          saleProductId: 5,
          shareQuantity: Decimal.parse('1.0'),
        ),
      );

      final deletedCount = await db.guestSplitDao.deleteByOrder(orderId);
      expect(deletedCount, equals(2));

      final remaining = await db.guestSplitDao.getByOrder(orderId);
      expect(remaining, isEmpty);

      final otherSplits = await db.guestSplitDao.getByOrder(otherOrderId);
      expect(otherSplits.length, equals(1));
    });

    test('countGuests should return COUNT(DISTINCT guest_number)', () async {
      await db.guestSplitDao.insert(
        GuestSplitsCompanion.insert(
          orderId: orderId,
          guestNumber: 1,
          saleProductId: 1,
          shareQuantity: Decimal.parse('0.5'),
        ),
      );
      await db.guestSplitDao.insert(
        GuestSplitsCompanion.insert(
          orderId: orderId,
          guestNumber: 1,
          saleProductId: 2,
          shareQuantity: Decimal.parse('1.0'),
        ),
      );
      await db.guestSplitDao.insert(
        GuestSplitsCompanion.insert(
          orderId: orderId,
          guestNumber: 2,
          saleProductId: 1,
          shareQuantity: Decimal.parse('0.5'),
        ),
      );

      final count = await db.guestSplitDao.countGuests(orderId);
      expect(count, equals(2));
    });
  });

  group('ServiceOrderDao', () {
    test('insert should create a service order and return its id', () async {
      final id = await db.serviceOrderDao.insert(
        ServiceOrdersCompanion.insert(
          orderNumber: 'SO-20260227-001',
          userId: 1,
          intakeTime: now,
        ),
      );

      expect(id, isPositive);

      final order = await db.serviceOrderDao.findById(id);
      expect(order, isNotNull);
      expect(order!.orderNumber, equals('SO-20260227-001'));
      expect(order.userId, equals(1));
      expect(order.intakeTime, equals(now));
      expect(order.status, equals(0));
      expect(order.receiptNo, isNull);
      expect(order.posId, isNull);
    });

    test('getByStatus should return orders filtered by status', () async {
      await db.serviceOrderDao.insert(
        ServiceOrdersCompanion.insert(
          orderNumber: 'SO-001',
          userId: 1,
          intakeTime: now,
        ),
      );
      await db.serviceOrderDao.insert(
        ServiceOrdersCompanion.insert(
          orderNumber: 'SO-002',
          userId: 1,
          intakeTime: now + 100,
        ),
      );
      final inProgressId = await db.serviceOrderDao.insert(
        ServiceOrdersCompanion.insert(
          orderNumber: 'SO-003',
          userId: 1,
          intakeTime: now + 200,
        ),
      );
      await db.serviceOrderDao.updateStatus(inProgressId, 1);

      final intakeOrders = await db.serviceOrderDao.getByStatus(0);
      expect(intakeOrders.length, equals(2));

      final inProgressOrders = await db.serviceOrderDao.getByStatus(1);
      expect(inProgressOrders.length, equals(1));
      expect(inProgressOrders.first.orderNumber, equals('SO-003'));

      final completedOrders = await db.serviceOrderDao.getByStatus(2);
      expect(completedOrders, isEmpty);
    });

    test('getActive should return orders with status < 3', () async {
      await db.serviceOrderDao.insert(
        ServiceOrdersCompanion.insert(
          orderNumber: 'SO-A',
          userId: 1,
          intakeTime: now,
        ),
      );
      final ipId = await db.serviceOrderDao.insert(
        ServiceOrdersCompanion.insert(
          orderNumber: 'SO-B',
          userId: 1,
          intakeTime: now + 100,
        ),
      );
      await db.serviceOrderDao.updateStatus(ipId, 1);

      final compId = await db.serviceOrderDao.insert(
        ServiceOrdersCompanion.insert(
          orderNumber: 'SO-C',
          userId: 1,
          intakeTime: now + 200,
        ),
      );
      await db.serviceOrderDao.updateStatus(compId, 2);

      final closedId = await db.serviceOrderDao.insert(
        ServiceOrdersCompanion.insert(
          orderNumber: 'SO-D',
          userId: 1,
          intakeTime: now + 300,
        ),
      );
      await db.serviceOrderDao.updateStatus(closedId, 3);

      final cancelledId = await db.serviceOrderDao.insert(
        ServiceOrdersCompanion.insert(
          orderNumber: 'SO-E',
          userId: 1,
          intakeTime: now + 400,
        ),
      );
      await db.serviceOrderDao.updateStatus(cancelledId, 4);

      final active = await db.serviceOrderDao.getActive();
      expect(active.length, equals(3));
      for (final order in active) {
        expect(order.status, lessThan(3));
      }
    });

    test('findById should return order or null', () async {
      final id = await db.serviceOrderDao.insert(
        ServiceOrdersCompanion.insert(
          orderNumber: 'SO-FIND',
          userId: 1,
          intakeTime: now,
        ),
      );

      final found = await db.serviceOrderDao.findById(id);
      expect(found, isNotNull);
      expect(found!.orderNumber, equals('SO-FIND'));

      final notFound = await db.serviceOrderDao.findById(999);
      expect(notFound, isNull);
    });

    test(
      'findByOrderNumber should return order by its unique number',
      () async {
        await db.serviceOrderDao.insert(
          ServiceOrdersCompanion.insert(
            orderNumber: 'SO-20260227-001',
            userId: 1,
            intakeTime: now,
          ),
        );

        final found = await db.serviceOrderDao.findByOrderNumber(
          'SO-20260227-001',
        );
        expect(found, isNotNull);
        expect(found!.orderNumber, equals('SO-20260227-001'));

        final notFound = await db.serviceOrderDao.findByOrderNumber(
          'SO-NONEXISTENT',
        );
        expect(notFound, isNull);
      },
    );

    test(
      'searchByClientNameOrPhone should find by partial name or phone',
      () async {
        await db.serviceOrderDao.insert(
          ServiceOrdersCompanion.insert(
            orderNumber: 'SO-SEARCH-1',
            userId: 1,
            intakeTime: now,
            clientName: const Value('John Doe'),
            clientPhone: const Value('+1234567890'),
          ),
        );
        await db.serviceOrderDao.insert(
          ServiceOrdersCompanion.insert(
            orderNumber: 'SO-SEARCH-2',
            userId: 1,
            intakeTime: now + 100,
            clientName: const Value('Jane Smith'),
            clientPhone: const Value('+9876543210'),
          ),
        );
        await db.serviceOrderDao.insert(
          ServiceOrdersCompanion.insert(
            orderNumber: 'SO-SEARCH-3',
            userId: 1,
            intakeTime: now + 200,
            clientName: const Value('Bob Johnson'),
            clientPhone: const Value('+1234000000'),
          ),
        );

        final johns = await db.serviceOrderDao.searchByClientNameOrPhone(
          'John',
        );
        expect(johns.length, equals(2));
        final johnNames = johns.map((o) => o.clientName).toList();
        expect(johnNames, containsAll(['John Doe', 'Bob Johnson']));

        final phone1234 = await db.serviceOrderDao.searchByClientNameOrPhone(
          '1234',
        );
        expect(phone1234.length, equals(2));

        final noMatch = await db.serviceOrderDao.searchByClientNameOrPhone(
          'ZZZZZ',
        );
        expect(noMatch, isEmpty);
      },
    );

    test(
      'linkToSale should set receiptNo and posId on the service order',
      () async {
        final id = await db.serviceOrderDao.insert(
          ServiceOrdersCompanion.insert(
            orderNumber: 'SO-LINK',
            userId: 1,
            intakeTime: now,
          ),
        );

        var order = await db.serviceOrderDao.findById(id);
        expect(order!.receiptNo, isNull);
        expect(order.posId, isNull);

        await db.serviceOrderDao.linkToSale(id, 500, 42);

        order = await db.serviceOrderDao.findById(id);
        expect(order!.receiptNo, equals(500));
        expect(order.posId, equals(42));
      },
    );

    test(
      'generateOrderNumber should return unique SO-YYYYMMDD-NNN format',
      () async {
        final orderNumber1 = await db.serviceOrderDao.generateOrderNumber();

        expect(orderNumber1, matches(RegExp(r'^SO-\d{8}-\d{3}$')));

        await db.serviceOrderDao.insert(
          ServiceOrdersCompanion.insert(
            orderNumber: orderNumber1,
            userId: 1,
            intakeTime: now,
          ),
        );

        final orderNumber2 = await db.serviceOrderDao.generateOrderNumber();
        expect(orderNumber2, matches(RegExp(r'^SO-\d{8}-\d{3}$')));
        expect(orderNumber2, isNot(equals(orderNumber1)));

        final seq1 = int.parse(orderNumber1.split('-').last);
        final seq2 = int.parse(orderNumber2.split('-').last);
        expect(seq2, equals(seq1 + 1));
      },
    );
  });

  group('ServiceMarkDao', () {
    late int serviceOrderId;

    setUp(() async {
      serviceOrderId = await db.serviceOrderDao.insert(
        ServiceOrdersCompanion.insert(
          orderNumber: 'SO-MARKS-TEST',
          userId: 1,
          intakeTime: now,
        ),
      );
    });

    test('insert should create a service mark and return its id', () async {
      final id = await db.serviceMarkDao.insert(
        ServiceMarksCompanion.insert(
          serviceOrderId: serviceOrderId,
          description: 'Diagnostics',
          userId: 1,
          createdAt: now,
        ),
      );

      expect(id, isPositive);
    });

    test('getByOrder should return marks ordered by createdAt', () async {
      await db.serviceMarkDao.insert(
        ServiceMarksCompanion.insert(
          serviceOrderId: serviceOrderId,
          description: 'Third step',
          userId: 1,
          createdAt: now + 200,
        ),
      );
      await db.serviceMarkDao.insert(
        ServiceMarksCompanion.insert(
          serviceOrderId: serviceOrderId,
          description: 'First step',
          userId: 1,
          createdAt: now,
        ),
      );
      await db.serviceMarkDao.insert(
        ServiceMarksCompanion.insert(
          serviceOrderId: serviceOrderId,
          description: 'Second step',
          userId: 1,
          createdAt: now + 100,
        ),
      );

      final marks = await db.serviceMarkDao.getByOrder(serviceOrderId);
      expect(marks.length, equals(3));
      expect(marks[0].description, equals('First step'));
      expect(marks[1].description, equals('Second step'));
      expect(marks[2].description, equals('Third step'));
    });

    test('sumCostByOrder should return total cost as Decimal', () async {
      await db.serviceMarkDao.insert(
        ServiceMarksCompanion.insert(
          serviceOrderId: serviceOrderId,
          description: 'Part replacement',
          userId: 1,
          createdAt: now,
          cost: Value(Decimal.parse('100.500')),
        ),
      );
      await db.serviceMarkDao.insert(
        ServiceMarksCompanion.insert(
          serviceOrderId: serviceOrderId,
          description: 'Labor',
          userId: 1,
          createdAt: now + 100,
          cost: Value(Decimal.parse('50.250')),
        ),
      );
      await db.serviceMarkDao.insert(
        ServiceMarksCompanion.insert(
          serviceOrderId: serviceOrderId,
          description: 'Visual inspection',
          userId: 1,
          createdAt: now + 200,
        ),
      );

      final sum = await db.serviceMarkDao.sumCostByOrder(serviceOrderId);
      expect(sum, equals(Decimal.parse('150.75')));
    });

    test('sumCostByOrder should return zero when no marks exist', () async {
      final emptyOrderId = await db.serviceOrderDao.insert(
        ServiceOrdersCompanion.insert(
          orderNumber: 'SO-EMPTY',
          userId: 1,
          intakeTime: now,
        ),
      );

      final sum = await db.serviceMarkDao.sumCostByOrder(emptyOrderId);
      expect(sum, equals(Decimal.zero));
    });

    test('deleteById should remove a single mark', () async {
      final markId1 = await db.serviceMarkDao.insert(
        ServiceMarksCompanion.insert(
          serviceOrderId: serviceOrderId,
          description: 'To keep',
          userId: 1,
          createdAt: now,
        ),
      );
      final markId2 = await db.serviceMarkDao.insert(
        ServiceMarksCompanion.insert(
          serviceOrderId: serviceOrderId,
          description: 'To delete',
          userId: 1,
          createdAt: now + 100,
        ),
      );

      final deletedCount = await db.serviceMarkDao.deleteById(markId2);
      expect(deletedCount, equals(1));

      final remaining = await db.serviceMarkDao.getByOrder(serviceOrderId);
      expect(remaining.length, equals(1));
      expect(remaining.first.id, equals(markId1));
      expect(remaining.first.description, equals('To keep'));
    });
  });

  group('ServiceTypeDao', () {
    test('insert should create a service type and return its id', () async {
      final id = await db.serviceTypeDao.insert(
        ServiceTypesCompanion.insert(productUcode: 12345),
      );

      expect(id, isPositive);

      final serviceType = await db.serviceTypeDao.findById(id);
      expect(serviceType, isNotNull);
      expect(serviceType!.productUcode, equals(12345));
      expect(serviceType.isActive, isTrue);
    });

    test('getActive should return only active service types', () async {
      await db.serviceTypeDao.insert(
        ServiceTypesCompanion.insert(productUcode: 100),
      );
      await db.serviceTypeDao.insert(
        ServiceTypesCompanion.insert(productUcode: 200),
      );
      final inactiveId = await db.serviceTypeDao.insert(
        ServiceTypesCompanion.insert(productUcode: 300),
      );
      await db.serviceTypeDao.deactivate(inactiveId);

      final active = await db.serviceTypeDao.getActive();
      expect(active.length, equals(2));
      final ucodes = active.map((t) => t.productUcode).toSet();
      expect(ucodes, containsAll([100, 200]));
      expect(ucodes, isNot(contains(300)));
    });

    test(
      'findByProductUcode should return service type by product code',
      () async {
        await db.serviceTypeDao.insert(
          ServiceTypesCompanion.insert(productUcode: 12345),
        );

        final found = await db.serviceTypeDao.findByProductUcode(12345);
        expect(found, isNotNull);
        expect(found!.productUcode, equals(12345));

        final notFound = await db.serviceTypeDao.findByProductUcode(99999);
        expect(notFound, isNull);
      },
    );

    test('deactivate should set isActive to false', () async {
      final id = await db.serviceTypeDao.insert(
        ServiceTypesCompanion.insert(productUcode: 555),
      );

      var serviceType = await db.serviceTypeDao.findById(id);
      expect(serviceType!.isActive, isTrue);

      await db.serviceTypeDao.deactivate(id);

      serviceType = await db.serviceTypeDao.findById(id);
      expect(serviceType!.isActive, isFalse);
    });

    test('findById should return service type or null', () async {
      final id = await db.serviceTypeDao.insert(
        ServiceTypesCompanion.insert(
          productUcode: 777,
          estimatedDurationMinutes: const Value(60),
          warrantyDays: const Value(30),
          requiresDevice: const Value(true),
        ),
      );

      final found = await db.serviceTypeDao.findById(id);
      expect(found, isNotNull);
      expect(found!.productUcode, equals(777));
      expect(found.estimatedDurationMinutes, equals(60));
      expect(found.warrantyDays, equals(30));
      expect(found.requiresDevice, isTrue);
      expect(found.isActive, isTrue);

      final notFound = await db.serviceTypeDao.findById(999);
      expect(notFound, isNull);
    });
  });

  group('Cross-DAO integration', () {
    test(
      'restaurant order lifecycle: create table, open order, split guests, close',
      () async {
        final tableId = await db.restaurantTableDao.insert(
          RestaurantTablesCompanion.insert(
            name: 'Table 7',
            capacity: const Value(6),
            zone: const Value('Main'),
          ),
        );
        await db.restaurantTableDao.updateStatus(tableId, 1);

        final orderId = await db.restaurantOrderDao.insert(
          RestaurantOrdersCompanion.insert(
            openTime: now,
            tableId: Value(tableId),
            partySize: const Value(3),
          ),
        );

        await db.guestSplitDao.insert(
          GuestSplitsCompanion.insert(
            orderId: orderId,
            guestNumber: 1,
            saleProductId: 101,
            shareQuantity: Decimal.parse('1.0'),
          ),
        );
        await db.guestSplitDao.insert(
          GuestSplitsCompanion.insert(
            orderId: orderId,
            guestNumber: 2,
            saleProductId: 101,
            shareQuantity: Decimal.parse('0.5'),
          ),
        );
        await db.guestSplitDao.insert(
          GuestSplitsCompanion.insert(
            orderId: orderId,
            guestNumber: 3,
            saleProductId: 102,
            shareQuantity: Decimal.parse('1.0'),
          ),
        );

        final guestCount = await db.guestSplitDao.countGuests(orderId);
        expect(guestCount, equals(3));

        await db.restaurantOrderDao.updateTips(orderId, Decimal.parse('10.00'));
        await db.restaurantOrderDao.closeOrder(orderId, now + 5400);

        await db.restaurantTableDao.updateStatus(tableId, 0);

        final closedOrder = await db.restaurantOrderDao.findById(orderId);
        expect(closedOrder!.closeTime, isNotNull);
        expect(closedOrder.tips!.toDouble(), closeTo(10.0, 0.001));

        final table = await db.restaurantTableDao.findById(tableId);
        expect(table!.status, equals(0));

        final open = await db.restaurantOrderDao.findOpenByTable(tableId);
        expect(open, isNull);
      },
    );

    test('service order lifecycle: create, add marks, link to sale', () async {
      final orderId = await db.serviceOrderDao.insert(
        ServiceOrdersCompanion.insert(
          orderNumber: 'SO-LIFECYCLE-001',
          userId: 1,
          intakeTime: now,
          clientName: const Value('Alice'),
          clientPhone: const Value('+7001234567'),
          deviceDescription: const Value('iPhone 14 Pro'),
          complaint: const Value('Screen cracked'),
        ),
      );

      await db.serviceOrderDao.updateStatus(orderId, 1);

      await db.serviceMarkDao.insert(
        ServiceMarksCompanion.insert(
          serviceOrderId: orderId,
          description: 'Diagnostics performed',
          userId: 1,
          createdAt: now + 100,
          cost: Value(Decimal.parse('500.000')),
        ),
      );
      await db.serviceMarkDao.insert(
        ServiceMarksCompanion.insert(
          serviceOrderId: orderId,
          description: 'Screen replaced',
          userId: 1,
          createdAt: now + 200,
          cost: Value(Decimal.parse('15000.000')),
        ),
      );

      final totalCost = await db.serviceMarkDao.sumCostByOrder(orderId);
      expect(totalCost, equals(Decimal.parse('15500.0')));

      await db.serviceOrderDao.updateStatus(orderId, 2);
      await db.serviceOrderDao.linkToSale(orderId, 1001, 42);

      await db.serviceOrderDao.updateStatus(orderId, 3);

      final order = await db.serviceOrderDao.findById(orderId);
      expect(order!.status, equals(3));
      expect(order.receiptNo, equals(1001));
      expect(order.posId, equals(42));

      final active = await db.serviceOrderDao.getActive();
      expect(active.where((o) => o.id == orderId), isEmpty);
    });

    test('guest split shareQuantity preserves Decimal precision', () async {
      final tableId = await db.restaurantTableDao.insert(
        RestaurantTablesCompanion.insert(name: 'Precision Table'),
      );
      final orderId = await db.restaurantOrderDao.insert(
        RestaurantOrdersCompanion.insert(
          openTime: now,
          tableId: Value(tableId),
        ),
      );

      await db.guestSplitDao.insert(
        GuestSplitsCompanion.insert(
          orderId: orderId,
          guestNumber: 1,
          saleProductId: 1,
          shareQuantity: Decimal.parse('0.333'),
        ),
      );
      await db.guestSplitDao.insert(
        GuestSplitsCompanion.insert(
          orderId: orderId,
          guestNumber: 2,
          saleProductId: 1,
          shareQuantity: Decimal.parse('0.667'),
        ),
      );

      final splits = await db.guestSplitDao.getByOrder(orderId);
      expect(splits.length, equals(2));
      expect(splits[0].shareQuantity.toDouble(), closeTo(0.333, 0.001));
      expect(splits[1].shareQuantity.toDouble(), closeTo(0.667, 0.001));
    });

    test('multiple open orders on different tables', () async {
      final table1 = await db.restaurantTableDao.insert(
        RestaurantTablesCompanion.insert(name: 'T1'),
      );
      final table2 = await db.restaurantTableDao.insert(
        RestaurantTablesCompanion.insert(name: 'T2'),
      );

      final order1 = await db.restaurantOrderDao.insert(
        RestaurantOrdersCompanion.insert(openTime: now, tableId: Value(table1)),
      );
      final order2 = await db.restaurantOrderDao.insert(
        RestaurantOrdersCompanion.insert(
          openTime: now + 60,
          tableId: Value(table2),
        ),
      );

      final open1 = await db.restaurantOrderDao.findOpenByTable(table1);
      final open2 = await db.restaurantOrderDao.findOpenByTable(table2);
      expect(open1!.id, equals(order1));
      expect(open2!.id, equals(order2));

      final allOpen = await db.restaurantOrderDao.getOpenOrders();
      expect(allOpen.length, equals(2));
    });

    test('service order search with special characters in query', () async {
      await db.serviceOrderDao.insert(
        ServiceOrdersCompanion.insert(
          orderNumber: 'SO-ESC-1',
          userId: 1,
          intakeTime: now,
          clientName: const Value('100% Repair'),
        ),
      );
      await db.serviceOrderDao.insert(
        ServiceOrdersCompanion.insert(
          orderNumber: 'SO-ESC-2',
          userId: 1,
          intakeTime: now + 100,
          clientName: const Value('Test User'),
        ),
      );
      await db.serviceOrderDao.insert(
        ServiceOrdersCompanion.insert(
          orderNumber: 'SO-ESC-3',
          userId: 1,
          intakeTime: now + 200,
          clientName: const Value('Another Repair'),
        ),
      );

      final repairResults = await db.serviceOrderDao.searchByClientNameOrPhone(
        'Repair',
      );
      expect(repairResults.length, equals(2));

      final testResults = await db.serviceOrderDao.searchByClientNameOrPhone(
        'Test User',
      );
      expect(testResults.length, equals(1));
      expect(testResults.first.clientName, equals('Test User'));

      final partialResults = await db.serviceOrderDao.searchByClientNameOrPhone(
        '100',
      );
      expect(partialResults.length, equals(1));
      expect(partialResults.first.clientName, equals('100% Repair'));
    });

    test('restaurant table getZones returns distinct active zones', () async {
      await db.restaurantTableDao.insert(
        RestaurantTablesCompanion.insert(
          name: 'Z1-T1',
          zone: const Value('Hall'),
        ),
      );
      await db.restaurantTableDao.insert(
        RestaurantTablesCompanion.insert(
          name: 'Z1-T2',
          zone: const Value('Hall'),
        ),
      );
      await db.restaurantTableDao.insert(
        RestaurantTablesCompanion.insert(
          name: 'Z2-T1',
          zone: const Value('Terrace'),
        ),
      );
      await db.restaurantTableDao.insert(
        RestaurantTablesCompanion.insert(
          name: 'Z3-T1',
          zone: const Value('VIP'),
          isActive: const Value(false),
        ),
      );

      final zones = await db.restaurantTableDao.getZones();
      expect(zones.length, equals(2));
      expect(zones, containsAll(['Hall', 'Terrace']));
      expect(zones, isNot(contains('VIP')));
    });

    test('service type with marks: full service workflow', () async {
      final typeId = await db.serviceTypeDao.insert(
        ServiceTypesCompanion.insert(
          productUcode: 50001,
          estimatedDurationMinutes: const Value(120),
          warrantyDays: const Value(90),
          requiresDevice: const Value(true),
        ),
      );

      final orderId = await db.serviceOrderDao.insert(
        ServiceOrdersCompanion.insert(
          orderNumber: 'SO-FULL-001',
          userId: 1,
          intakeTime: now,
          deviceDescription: const Value('Samsung Galaxy S24'),
          serialNumber: const Value('SN-123456789'),
        ),
      );

      await db.serviceMarkDao.insert(
        ServiceMarksCompanion.insert(
          serviceOrderId: orderId,
          description: 'Battery replacement',
          userId: 1,
          createdAt: now + 60,
          cost: Value(Decimal.parse('3500.000')),
        ),
      );
      await db.serviceMarkDao.insert(
        ServiceMarksCompanion.insert(
          serviceOrderId: orderId,
          description: 'Software update',
          userId: 1,
          createdAt: now + 120,
          cost: Value(Decimal.parse('1000.000')),
        ),
      );

      final marks = await db.serviceMarkDao.getByOrder(orderId);
      expect(marks.length, equals(2));

      final total = await db.serviceMarkDao.sumCostByOrder(orderId);
      expect(total, equals(Decimal.parse('4500.0')));

      final serviceType = await db.serviceTypeDao.findById(typeId);
      expect(serviceType!.requiresDevice, isTrue);
      expect(serviceType.warrantyDays, equals(90));
    });
  });
}
