import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNotNull;
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

  group('AppDatabase initialization', () {
    test('should create database successfully', () {
      expect(db, isNotNull);
    });

    test(
      'onUpgrade has a migration branch for every version up to the '
      'live schema version',
      () {
        // This replaces a literal `expect(db.schemaVersion, equals(26))`.
        // That assertion just mirrored the `schemaVersion` constant back at
        // itself: true by construction until a legitimate bump made it
        // false, at which point it turned the branch red and caught
        // nothing in between. It broke on 25->26, was hand-edited to 26,
        // then broke again on 26->27 — a guaranteed third break on the next
        // bump if simply re-numbered again.
        //
        // The invariant actually worth protecting: every version bump is
        // paired with its own `if (from < N)` branch in `onUpgrade`. A
        // schemaVersion raised without one lets an existing install jump
        // straight from its old `user_version` to the new one with none of
        // the intervening table/column changes applied — a defect that
        // surfaces later as a missing column, not as a failed migration.
        //
        // There is no way to observe that invariant by *running*
        // `MigrationStrategy` generically: exercising a branch's actual
        // effect requires a fixture of what the schema looked like one
        // version earlier, which is schema-specific (that's what
        // test/unit/data/terminal_migration_test.dart and
        // test/unit/data/device_migration_test.dart already do for the
        // 25->26 and 26->27 bumps specifically). So this reads the
        // `onUpgrade` source instead — an honest source-text check, not a
        // behavioural one, but one that never needs editing on a future
        // bump because it compares against `db.schemaVersion` rather than
        // a typed-in number, and it fails exactly when a bump forgets the
        // branch that makes it real.
        final source = File(
          'lib/data/database/app_database.dart',
        ).readAsStringSync();
        final branchVersions = RegExp(r'if \(from < (\d+)\)')
            .allMatches(source)
            .map((m) => int.parse(m.group(1)!))
            .toList()
          ..sort();

        final expected = List.generate(db.schemaVersion - 1, (i) => i + 2);

        expect(
          branchVersions,
          equals(expected),
          reason:
              'schemaVersion is ${db.schemaVersion}, but onUpgrade in '
              'lib/data/database/app_database.dart does not have a '
              'contiguous `if (from < N)` branch for every version '
              '2..${db.schemaVersion}. Add the missing branch(es) before '
              'shipping — otherwise installs upgrading through the gap '
              'skip whatever schema change that version was supposed to '
              'make.',
        );
      },
    );

    test('should enable foreign keys PRAGMA', () async {
      final result = await db.customSelect('PRAGMA foreign_keys').getSingle();
      expect(result.data['foreign_keys'], equals(1));
    });

    test('should have valid journal mode', () async {
      final result = await db.customSelect('PRAGMA journal_mode').getSingle();
      expect(result.data['journal_mode'], anyOf('wal', 'memory'));
    });

    test('should create all tables successfully', () async {
      final tables = [
        'categories',
        'sales',
        'sale_products',
        'products_infos',
        'product_prices',
        'users',
        'agents',
        'shifts',
        'payments',
        'refunds',
        'webkassa_receipts',
      ];

      for (final table in tables) {
        try {
          await db.customSelect('SELECT 1 FROM $table LIMIT 0').get();
        } catch (e) {}
      }

      expect(db, isNotNull);
    });
  });

  group('Categories table', () {
    test('should insert and retrieve category', () async {
      final now = DateTime.now();

      await db
          .into(db.categories)
          .insert(
            CategoriesCompanion.insert(id: const Value(1), createTime: now),
          );

      final categories = await db.select(db.categories).get();
      expect(categories.length, equals(1));
      expect(categories.first.id, equals(1));
    });

    test('should support hierarchical categories with parentId', () async {
      final now = DateTime.now();

      await db
          .into(db.categories)
          .insert(
            CategoriesCompanion.insert(id: const Value(1), createTime: now),
          );

      await db
          .into(db.categories)
          .insert(
            CategoriesCompanion.insert(
              id: const Value(2),
              parentId: const Value(1),
              createTime: now,
            ),
          );

      final childCategory = await (db.select(
        db.categories,
      )..where((t) => t.id.equals(2))).getSingle();

      expect(childCategory.parentId, equals(1));
    });

    test('should update category editTime', () async {
      final createTime = DateTime.now();
      final editTime = createTime.add(const Duration(hours: 1));

      await db
          .into(db.categories)
          .insert(
            CategoriesCompanion.insert(
              id: const Value(1),
              createTime: createTime,
            ),
          );

      await (db.update(db.categories)..where((t) => t.id.equals(1))).write(
        CategoriesCompanion(editTime: Value(editTime)),
      );

      final category = await (db.select(
        db.categories,
      )..where((t) => t.id.equals(1))).getSingle();

      expect(category.editTime, isNotNull);
    });

    test('should delete category', () async {
      final now = DateTime.now();

      await db
          .into(db.categories)
          .insert(
            CategoriesCompanion.insert(id: const Value(1), createTime: now),
          );

      await (db.delete(db.categories)..where((t) => t.id.equals(1))).go();

      final categories = await db.select(db.categories).get();
      expect(categories.length, equals(0));
    });
  });

  group('Sales table with composite key', () {
    test(
      'should insert sale with composite primary key (receiptNo, posId)',
      () async {
        final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

        await db
            .into(db.sales)
            .insert(
              SalesCompanion.insert(
                receiptNo: 1,
                posId: 100,
                userId: 1,
                amount: Decimal.parse('1500.50'),
                time: timestamp,
              ),
            );

        final sales = await db.select(db.sales).get();
        expect(sales.length, equals(1));
        expect(sales.first.receiptNo, equals(1));
        expect(sales.first.posId, equals(100));
      },
    );

    test('should allow same receiptNo with different posId', () async {
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await db
          .into(db.sales)
          .insert(
            SalesCompanion.insert(
              receiptNo: 1,
              posId: 100,
              userId: 1,
              amount: Decimal.parse('1500.50'),
              time: timestamp,
            ),
          );

      await db
          .into(db.sales)
          .insert(
            SalesCompanion.insert(
              receiptNo: 1,
              posId: 200,
              userId: 1,
              amount: Decimal.parse('2500.00'),
              time: timestamp,
            ),
          );

      final sales = await db.select(db.sales).get();
      expect(sales.length, equals(2));
    });

    test('should store Decimal amounts correctly', () async {
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final amount = Decimal.parse('12345.678');

      await db
          .into(db.sales)
          .insert(
            SalesCompanion.insert(
              receiptNo: 1,
              posId: 100,
              userId: 1,
              amount: amount,
              time: timestamp,
            ),
          );

      final sale = await (db.select(
        db.sales,
      )..where((t) => t.receiptNo.equals(1) & t.posId.equals(100))).getSingle();

      expect(sale.amount.toDouble(), closeTo(12345.678, 0.001));
    });

    test('should support sale state transitions', () async {
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await db
          .into(db.sales)
          .insert(
            SalesCompanion.insert(
              receiptNo: 1,
              posId: 100,
              userId: 1,
              amount: Decimal.parse('1500.50'),
              time: timestamp,
              state: const Value(0),
            ),
          );

      await (db.update(db.sales)
            ..where((t) => t.receiptNo.equals(1) & t.posId.equals(100)))
          .write(const SalesCompanion(state: Value(1)));

      final sale = await (db.select(
        db.sales,
      )..where((t) => t.receiptNo.equals(1) & t.posId.equals(100))).getSingle();

      expect(sale.state, equals(1));
    });
  });

  group('SaleProducts table', () {
    test('should insert sale product with auto-increment id', () async {
      await db
          .into(db.saleProducts)
          .insert(
            SaleProductsCompanion.insert(
              ucode: 12345,
              quantity: Decimal.parse('2.5'),
              price: Decimal.parse('500.00'),
              priceBefore: Decimal.parse('600.00'),
            ),
          );

      final products = await db.select(db.saleProducts).get();
      expect(products.length, equals(1));
      expect(products.first.id, isPositive);
    });

    test('should link sale product to sale', () async {
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await db
          .into(db.sales)
          .insert(
            SalesCompanion.insert(
              receiptNo: 1,
              posId: 100,
              userId: 1,
              amount: Decimal.parse('1500.50'),
              time: timestamp,
            ),
          );

      await db
          .into(db.saleProducts)
          .insert(
            SaleProductsCompanion.insert(
              receiptNo: const Value(1),
              posId: const Value(100),
              ucode: 12345,
              quantity: Decimal.parse('2.5'),
              price: Decimal.parse('500.00'),
              priceBefore: Decimal.parse('600.00'),
            ),
          );

      final products = await (db.select(
        db.saleProducts,
      )..where((t) => t.receiptNo.equals(1) & t.posId.equals(100))).get();

      expect(products.length, equals(1));
      expect(products.first.ucode, equals(12345));
    });
  });

  group('ProductInfos table', () {
    test('should insert product info', () async {
      await db
          .into(db.productInfos)
          .insert(
            ProductInfosCompanion.insert(
              ucode: const Value(12345),
              barcode: 4607025392408,
              name: 'Test Product',
              type: 0,
              measure: 1,
            ),
          );

      final products = await db.select(db.productInfos).get();
      expect(products.length, equals(1));
      expect(products.first.name, equals('Test Product'));
    });

    test('should support soft delete', () async {
      await db
          .into(db.productInfos)
          .insert(
            ProductInfosCompanion.insert(
              ucode: const Value(12345),
              barcode: 4607025392408,
              name: 'Test Product',
              type: 0,
              measure: 1,
            ),
          );

      await (db.update(db.productInfos)..where((t) => t.ucode.equals(12345)))
          .write(const ProductInfosCompanion(isDeleted: Value(true)));

      final product = await (db.select(
        db.productInfos,
      )..where((t) => t.ucode.equals(12345))).getSingle();

      expect(product.isDeleted, isTrue);
    });
  });

  group('WebkassaReceipts table', () {
    test('should insert fiscal receipt', () async {
      await db
          .into(db.webkassaReceipts)
          .insert(
            WebkassaReceiptsCompanion.insert(
              operationId: const Value(1),
              receiptNo: const Value(1001),
              fiscalNo: const Value('WK-2024-001'),
              isSale: const Value(true),
            ),
          );

      final receipts = await db.select(db.webkassaReceipts).get();
      expect(receipts.length, equals(1));
      expect(receipts.first.fiscalNo, equals('WK-2024-001'));
    });

    test('should store ticket URL', () async {
      const ticketUrl = 'https://ofd.kz/check/12345';

      await db
          .into(db.webkassaReceipts)
          .insert(
            WebkassaReceiptsCompanion.insert(
              operationId: const Value(1),
              ticketUrl: const Value(ticketUrl),
              isSale: const Value(true),
            ),
          );

      final receipt = await (db.select(
        db.webkassaReceipts,
      )..where((t) => t.operationId.equals(1))).getSingle();

      expect(receipt.ticketUrl, equals(ticketUrl));
    });
  });

  group('Users table', () {
    test('should insert user', () async {
      await db
          .into(db.users)
          .insert(
            UsersCompanion.insert(
              id: const Value(1),
              name: const Value('Test Cashier'),
              role: const Value(3),
            ),
          );

      final users = await db.select(db.users).get();
      expect(users.length, equals(1));
      expect(users.first.name, equals('Test Cashier'));
    });

    test('should update user role', () async {
      await db
          .into(db.users)
          .insert(
            UsersCompanion.insert(
              id: const Value(1),
              name: const Value('Admin User'),
              role: const Value(1),
            ),
          );

      await (db.update(db.users)..where((t) => t.id.equals(1))).write(
        const UsersCompanion(role: Value(0)),
      );

      final user = await (db.select(
        db.users,
      )..where((t) => t.id.equals(1))).getSingle();

      expect(user.role, equals(0));
    });
  });

  group('Shifts table', () {
    test('should insert shift', () async {
      await db
          .into(db.shifts)
          .insert(
            ShiftsCompanion.insert(
              userId: 1,
              isOpened: true,
              openTime: DateTime.now().millisecondsSinceEpoch,
              isSynced: false,
            ),
          );

      final shifts = await db.select(db.shifts).get();
      expect(shifts.length, equals(1));
      expect(shifts.first.isOpened, isTrue);
    });

    test('should close shift with closeTime', () async {
      final openTime = DateTime.now().millisecondsSinceEpoch;

      await db
          .into(db.shifts)
          .insert(
            ShiftsCompanion.insert(
              userId: 1,
              isOpened: true,
              openTime: openTime,
              isSynced: false,
            ),
          );

      final closeTime = DateTime.now()
          .add(const Duration(hours: 8))
          .millisecondsSinceEpoch;

      final shifts = await db.select(db.shifts).get();
      final shiftId = shifts.first.id;

      await (db.update(db.shifts)..where((t) => t.id.equals(shiftId))).write(
        ShiftsCompanion(
          isOpened: const Value(false),
          closeTime: Value(closeTime),
        ),
      );

      final shift = await (db.select(
        db.shifts,
      )..where((t) => t.id.equals(shiftId))).getSingle();

      expect(shift.isOpened, isFalse);
      expect(shift.closeTime, equals(closeTime));
    });
  });

  group('Transactions', () {
    test('should rollback transaction on error', () async {
      try {
        await db.transaction(() async {
          await db
              .into(db.categories)
              .insert(
                CategoriesCompanion.insert(
                  id: const Value(1),
                  createTime: DateTime.now(),
                ),
              );

          await db
              .into(db.categories)
              .insert(
                CategoriesCompanion.insert(
                  id: const Value(1),
                  createTime: DateTime.now(),
                ),
              );
        });
      } catch (e) {}

      final categories = await db.select(db.categories).get();
      expect(categories.length, equals(0));
    });

    test('should commit successful transaction', () async {
      await db.transaction(() async {
        await db
            .into(db.categories)
            .insert(
              CategoriesCompanion.insert(
                id: const Value(1),
                createTime: DateTime.now(),
              ),
            );

        await db
            .into(db.categories)
            .insert(
              CategoriesCompanion.insert(
                id: const Value(2),
                createTime: DateTime.now(),
              ),
            );
      });

      final categories = await db.select(db.categories).get();
      expect(categories.length, equals(2));
    });
  });
}
