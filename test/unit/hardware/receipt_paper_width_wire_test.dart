import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/services/receipt_print_service_impl.dart';
import 'package:telepos/data/usecases/cash_operation/cash_operation_receipt_service_impl.dart';
import 'package:telepos/domain/entities/receipt/receipt_options.dart';
import 'package:telepos/domain/print/print_queue.dart';
import 'package:telepos/domain/services/receipt_print_service.dart';

import 'support/receipt_wire_stand.dart';

/// Жалоба заказчика с XPrinter: «постоянно печатался узкий чек, даже если
/// выбирали широкий».
///
/// Ширину ленты оператор выбирает на экране «Настройки принтера» — это опция
/// `paperWidthMm` привязки чекового принтера (`DeviceBinding.options`). Проба
/// сохраняет её **тем же репозиторием**, каким сохраняет экран, печатает
/// каждым путём, которым касса выпускает бумагу, и меряет ширину по байтам,
/// разобранным эмулятором принтера. Служба собрана так же, как в
/// `service_locator.dart` — без ширины в конструкторе: ширину ей обязана дать
/// привязка, а не умолчание.
void main() {
  for (final mm in const [58, 80]) {
    final columns = ReceiptPaperWidth.fromMm(mm).charWidth;

    group('выбрана лента $mm мм → чек в $columns колонок', () {
      late ReceiptWireStand stand;
      late ReceiptPrintService service;

      setUp(() async {
        stand = await ReceiptWireStand.boot(paperWidthMm: mm);
        service = ReceiptPrintServiceImpl();
      });

      Future<void> expectColumns(
        String path,
        Future<PrintSubmitOutcome> Function() print,
      ) async {
        final job = await stand.nextJob(print);
        expect(
          printedColumns(job),
          columns,
          reason:
              '$path: на ленте $mm мм чек собран в ${printedColumns(job)} '
              'колонок вместо $columns',
        );
      }

      test('продажа (касса и браузерный терминал — одна служба)', () async {
        await expectColumns('продажа', () => service.printSaleReceipt(wireSale()));
      });

      test('дубликат продажи', () async {
        await expectColumns(
          'дубликат продажи',
          () => service.printSaleDuplicate(wireSale()),
        );
      });

      test('возврат', () async {
        await expectColumns(
          'возврат',
          () => service.printRefundReceipt(wireRefund()),
        );
      });

      test('дубликат возврата', () async {
        await expectColumns(
          'дубликат возврата',
          () => service.printRefundDuplicate(wireRefund()),
        );
      });

      test('пробная печать шаблона', () async {
        await expectColumns(
          'пробная печать',
          () => service.printSampleReceipt(wireSale()),
        );
      });

      test('X-отчёт', () async {
        await expectColumns(
          'X-отчёт',
          () => service.printXReport(
            storeName: 'ТОО ТестПОС',
            posName: 'Касса 1',
            cashierName: 'Иванова А.',
            dateTime: DateTime(2026, 9, 15, 13),
            saleCount: 3,
            saleTotal: Decimal.parse('1500.00'),
            refundCount: 1,
            refundTotal: Decimal.parse('250.00'),
            cashInDrawer: Decimal.parse('1250.00'),
            // Ширину ленты меряет **заполненный** отчёт: нули спрятали бы
            // блок сертификатов, и самая длинная строка на ленте оказалась
            // бы не той, которую печатает касса с сертификатами.
            certificatesIssued: Decimal.parse('5000.00'),
            certificatesRedeemed: Decimal.parse('1000.00'),
          ),
        );
      });

      test('Z-отчёт', () async {
        await expectColumns(
          'Z-отчёт',
          () => service.printZReport(
            storeName: 'ТОО ТестПОС',
            posName: 'Касса 1',
            cashierName: 'Иванова А.',
            shiftStart: DateTime(2026, 9, 15, 9),
            shiftEnd: DateTime(2026, 9, 15, 21),
            saleCount: 3,
            saleTotal: Decimal.parse('1500.00'),
            refundCount: 1,
            refundTotal: Decimal.parse('250.00'),
            cashStart: Decimal.zero,
            cashEnd: Decimal.parse('1250.00'),
            cashIncome: Decimal.zero,
            cashDiscrepancy: Decimal.zero,
          cashExpense: Decimal.zero,
            certificatesIssued: Decimal.parse('5000.00'),
            certificatesRedeemed: Decimal.parse('1000.00'),
          ),
        );
      });

      test('пречек', () async {
        await expectColumns(
          'пречек',
          () => service.printPreCheck(
            PreCheckData(
              tableName: 'Стол 4',
              waiterName: 'Пётр',
              guestCount: 2,
              products: wireSale().products,
              totalAmount: Decimal.parse('500.00'),
              dateTime: DateTime(2026, 9, 15, 14),
              storeName: 'ТОО ТестПОС',
            ),
          ),
        );
      });

      test('квитанция кассовой операции', () async {
        final db = GetIt.I<AppDatabase>();
        final id = await db.cashOperationDao.insert(
          CashOperationsCompanion.insert(
            amount: Decimal.parse('1000.00'),
            type: 0,
            docTime: const Value(1757930400),
          ),
        );
        final cashService = CashOperationReceiptServiceImpl(
          db: db,
          logger: Talker(),
        );
        await expectColumns(
          'кассовая операция',
          () => cashService.printReceipt(id),
        );
      });
    });
  }

  test(
    'ширина, сменённая на экране принтера, действует со следующего чека — '
    'без перезапуска кассы',
    () async {
      final stand = await ReceiptWireStand.boot(paperWidthMm: 58);
      final service = ReceiptPrintServiceImpl();

      final narrow = await stand.nextJob(
        () => service.printSaleReceipt(wireSale()),
      );
      expect(printedColumns(narrow), 32);

      await stand.choosePaperWidth(80);
      final wide = await stand.nextJob(
        () => service.printSaleDuplicate(wireSale()),
      );
      expect(
        printedColumns(wide),
        48,
        reason: 'служба запомнила ширину первого чека',
      );
    },
  );
}
