library;

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/services/receipt_print_service_impl.dart';
import 'package:telepos/domain/entities/receipt/receipt_options.dart';

void main() {
  final service = ReceiptPrintServiceImpl();

  String zText() => service.renderZReportPreview(
    paperWidth: ReceiptPaperWidth.mm58,
    storeName: 'ТОО Новая Заря',
    posName: 'Касса №1',
    cashierName: 'Иванова А.',
    shiftStart: DateTime(2026, 6, 20, 9, 0),
    shiftEnd: DateTime(2026, 6, 20, 21, 0),
    saleCount: 12,
    saleTotal: Decimal.parse('15320.50'),
    refundCount: 1,
    refundTotal: Decimal.parse('320.00'),
    cashStart: Decimal.parse('5000.00'),
    cashEnd: Decimal.parse('19000.50'),
    cashIncome: Decimal.parse('15000.50'),
    cashExpense: Decimal.parse('1000.00'),
    certificatesIssued: Decimal.zero,
    certificatesRedeemed: Decimal.zero,
  );

  String xText() => service.renderXReportPreview(
    paperWidth: ReceiptPaperWidth.mm58,
    storeName: 'ТОО Новая Заря',
    posName: 'Касса №1',
    cashierName: 'Иванова А.',
    dateTime: DateTime(2026, 6, 20, 14, 30),
    saleCount: 8,
    saleTotal: Decimal.parse('9999.99'),
    refundCount: 0,
    refundTotal: Decimal.zero,
    cashInDrawer: Decimal.parse('14999.99'),
    certificatesIssued: Decimal.zero,
    certificatesRedeemed: Decimal.zero,
  );

  group('Z-отчёт — кириллица РК-стиль', () {
    test('заголовки и подписи на кириллице (не транслит)', () {
      final t = zText();
      expect(t, contains('Z-ОТЧЁТ'), reason: 'заголовок кириллицей');
      expect(t, contains('ЗАКРЫТИЕ СМЕНЫ'));
      expect(t, contains('Кассир:'));
      expect(t, contains('Иванова А.'));
      expect(t, contains('Начало:'));
      expect(t, contains('Окончание:'));
      expect(t, contains('ПРОДАЖИ'));
      expect(t, contains('ВОЗВРАТЫ'));
      expect(t, contains('ДЕНЕЖНЫЕ ОПЕРАЦИИ'));
      expect(t, contains('На начало:'));
      expect(t, contains('Внесения:'));
      expect(t, contains('Изъятия:'));
      expect(t, contains('ИТОГО В КАССЕ:'));
      expect(t, contains('ТОО Новая Заря'));
      expect(t, contains('Касса №1'));
    });

    test('НЕТ старого транслита (Latin)', () {
      final t = zText();
      for (final stale in [
        'Z-OTCHET',
        'ZAKRYTIE',
        'PRODAZHI',
        'VOZVRATY',
        'DENEZHNYE',
        'Kassir',
        'ITOGO V KASSE',
      ]) {
        expect(
          t,
          isNot(contains(stale)),
          reason: 'устаревший транслит: $stale',
        );
      }
    });

    test('суммы Decimal-точно (без double-дрейфа)', () {
      final t = zText();
      expect(t, contains('15320.50'), reason: 'сумма продаж');
      expect(t, contains('320.00'), reason: 'сумма возвратов');
      expect(t, contains('5000.00'), reason: 'на начало');
      expect(t, contains('19000.50'), reason: 'итого в кассе');
    });
  });

  group('X-отчёт — кириллица РК-стиль', () {
    test('заголовки и подписи на кириллице (не транслит)', () {
      final t = xText();
      expect(t, contains('X-ОТЧЁТ'), reason: 'заголовок кириллицей');
      expect(t, contains('ПРОМЕЖУТОЧНЫЙ'));
      expect(t, contains('Дата:'));
      expect(t, contains('Кассир:'));
      expect(t, contains('ПРОДАЖИ'));
      expect(t, contains('ВОЗВРАТЫ'));
      expect(t, contains('ИТОГО В КАССЕ:'));
      expect(t, contains('ТОО Новая Заря'));
    });

    test('НЕТ старого транслита (Latin)', () {
      final t = xText();
      for (final stale in [
        'X-OTCHET',
        'Data:',
        'Kassir',
        'Prodazhi',
        'Vozvraty',
        'V KASSE',
      ]) {
        expect(
          t,
          isNot(contains(stale)),
          reason: 'устаревший транслит: $stale',
        );
      }
    });

    test('суммы Decimal-точно', () {
      final t = xText();
      expect(t, contains('9999.99'), reason: 'сумма продаж');
      expect(t, contains('14999.99'), reason: 'итого в кассе');
    });
  });
}
