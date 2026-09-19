import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/services/receipt_print_service_impl.dart';
import 'package:telepos/domain/entities/receipt/receipt_options.dart';
import 'package:telepos/domain/print/print_queue.dart';
import 'package:telepos/domain/services/receipt_print_service.dart';

import 'support/receipt_wire_stand.dart';

/// Слип подарочного сертификата на бумаге — решение заказчика 2026-09-16:
/// «без печати схема у прилавка не работает: покупатель уходит с пустыми
/// руками».
///
/// Мерится **байтами**, разобранными эмулятором ESC/POS, а не вызовом
/// принтера: ширина ленты берётся из привязки (58 и 80 мм), кириллица едет
/// CP866, шапка и подвал шаблона стоят на своих местах.
///
/// # Чего эта проба НЕ доказывает
///
/// Что настоящий XPrinter напечатает то же самое: эмулятор разбирает поток
/// **нашим** пониманием ESC/POS (докстринг `emulator.dart`). Она доказывает
/// состав документа и ширину, а не физическую бумагу.
void main() {
  CertificateSlipData slip({
    bool duplicate = false,
    bool hasPin = false,
    DateTime? expiresAt,
    int? refundLocalId,
    String? sourceNumber,
  }) => CertificateSlipData(
    number: 'C-77-0001',
    amount: Decimal.parse('5000.00'),
    dateTime: DateTime(2026, 9, 16, 12, 30),
    posId: 1,
    posName: 'Касса 1',
    storeName: 'ТОО ТестПОС',
    cashierName: 'Иванова А.',
    expiresAt: expiresAt,
    hasPin: hasPin,
    refundLocalId: refundLocalId,
    sourceNumber: sourceNumber,
    isDuplicate: duplicate,
    seller: const ReceiptSellerInfo(
      binIin: '123456789012',
      address: 'г. Алматы, ул. Абая 10',
    ),
  );

  Future<void> useTemplate(ReceiptOptions options) async {
    final dao = GetIt.I<AppDatabase>().receiptTemplateDao;
    await dao.seedDefaults();
    final selected = await dao.getSelected();
    await dao.updateTemplate(
      selected!.id,
      ReceiptTemplatesCompanion(optionsJson: Value(options.encode())),
    );
  }

  List<String> textsOf(List<PaperEntry> paper) => [
    for (final e in paper)
      if (e.isLine) e.text,
  ];

  for (final mm in const [58, 80]) {
    final columns = ReceiptPaperWidth.fromMm(mm).charWidth;

    group('лента $mm мм ($columns колонок)', () {
      late ReceiptWireStand stand;
      late ReceiptPrintServiceImpl service;

      setUp(() async {
        stand = await ReceiptWireStand.boot(paperWidthMm: mm);
        service = ReceiptPrintServiceImpl();
      });

      test('слип выпуска: номер, сумма, пометка «не фискальный»', () async {
        final job = await stand.nextJob(
          () => service.printCertificateSlip(slip()),
        );
        final all = textsOf(paperOf(job)).join('\n');

        expect(
          all,
          contains('ПОДАРОЧНЫЙ СЕРТИФИКАТ'),
          reason: 'покупатель обязан понять, что у него в руках',
        );
        expect(all, contains('C-77-0001'), reason: 'номер — вся ценность слипа');
        expect(all, contains('5000.00'), reason: 'сумма, на которую он годен');
        expect(
          all,
          contains('НЕ ФИСКАЛЬНЫЙ ДОКУМЕНТ'),
          reason:
              'слип не чек: без этой строки его предъявят налоговой как чек',
        );
      });

      test('ширина — из привязки принтера, а не из шаблона', () async {
        final job = await stand.nextJob(
          () => service.printCertificateSlip(slip()),
        );
        expect(
          printedColumns(job),
          columns,
          reason:
              'на ленте $mm мм слип собран в ${printedColumns(job)} колонок '
              'вместо $columns',
        );
      });

      test('ПИН на бумагу не выходит — только «ПИН задан»', () async {
        final job = await stand.nextJob(
          () => service.printCertificateSlip(slip(hasPin: true)),
        );
        final all = textsOf(paperOf(job)).join('\n');

        expect(
          all,
          contains('ПИН задан'),
          reason: 'кассир и покупатель должны знать, что ПИН понадобится',
        );
        // Сам ПИН сюда не передаётся вовсе — у документа нет такого поля.
        // Утверждение стоит затем, чтобы поле нельзя было завести молча.
        expect(
          all,
          isNot(contains('4821')),
          reason: 'ПИН на бумажке рядом с номером обнуляет весь тираж',
        );
      });

      test('срок: названный и «без срока» — разными словами', () async {
        final dated = textsOf(
          paperOf(
            await stand.nextJob(
              () => service.printCertificateSlip(
                slip(expiresAt: DateTime(2027, 12, 31, 23, 59)),
              ),
            ),
          ),
        ).join('\n');
        expect(dated, contains('31.12.2027'));

        final endless = textsOf(
          paperOf(
            await stand.nextJob(
              () => service.printCertificateSlip(slip(duplicate: true)),
            ),
          ),
        ).join('\n');
        expect(
          endless,
          contains('без срока'),
          reason:
              'пустой срок обязан быть **словом**: молчание читается как '
              '«срок забыли напечатать»',
        );
      });

      test('слип возвратной бумажки называет возврат и исходную', () async {
        final all = textsOf(
          paperOf(
            await stand.nextJob(
              () => service.printCertificateSlip(
                slip(refundLocalId: 12, sourceNumber: 'C-77-0001'),
              ),
            ),
          ),
        ).join('\n');

        expect(all, contains('12'), reason: 'номер возврата');
        expect(
          all,
          contains('Взамен сертификата'),
          reason:
              'покупатель обязан увидеть, почему у него новая бумажка вместо '
              'старой — иначе он придёт со старой',
        );
      });

      test('шапка и подвал шаблона — на слипе тоже', () async {
        await useTemplate(
          const ReceiptOptions(
            header: ReceiptTextBlock(text: 'МЕТКА-ШАПКИ'),
            footer: ReceiptTextBlock(text: 'МЕТКА-ПОДВАЛА'),
          ),
        );
        service.invalidateReceiptOptionsCache();

        final paper = paperOf(
          await stand.nextJob(() => service.printCertificateSlip(slip())),
        );
        final texts = textsOf(paper);

        expect(texts, containsAll(['МЕТКА-ШАПКИ', 'МЕТКА-ПОДВАЛА']));
        expect(
          texts.indexOf('МЕТКА-ШАПКИ'),
          lessThan(texts.indexOf('ПОДАРОЧНЫЙ СЕРТИФИКАТ')),
          reason: 'шапка — выше обязательной части',
        );
        expect(
          texts.indexOf('МЕТКА-ПОДВАЛА'),
          greaterThan(texts.indexOf('НЕ ФИСКАЛЬНЫЙ ДОКУМЕНТ')),
          reason: 'подвал — ниже обязательной части',
        );
        expect(paper.last.kind, 'cut', reason: 'рез — последним');
      });

      test('предпросмотр — те же строки, что вышли на бумагу', () async {
        const options = ReceiptOptions(
          header: ReceiptTextBlock(text: 'МЕТКА-ШАПКИ'),
          footer: ReceiptTextBlock(text: 'МЕТКА-ПОДВАЛА'),
        );
        await useTemplate(options);
        service.invalidateReceiptOptionsCache();

        // `№` (0xFC в CP866) разборщик **эмулятора** не знает и показывает
        // точкой (`render.dart`, `_cp866`: «прочая псевдографика — точкой, а
        // не тишиной»), а разборщик продукта знает. Расхождение — свойство
        // измерительного прибора, а не документа, и соседняя проба шаблона
        // (`receipt_template_wire_test.dart`) сводит его ровно так же.
        String normalise(String line) => line.trim().replaceAll('№', '·');

        final printed = [
          for (final e in paperOf(
            await stand.nextJob(() => service.printCertificateSlip(slip())),
          ))
            if (e.isLine) normalise(e.text),
        ];
        final preview = [
          for (final l in service
              .renderCertificateSlipPreviewText(
                slip(),
                options,
                paperWidth: ReceiptPaperWidth.fromMm(mm),
              )
              .split('\n'))
            normalise(l),
        ];

        // Второй раскладки нет: предпросмотр разбирает **те же байты**.
        for (final line in printed) {
          if (line.isEmpty) continue;
          expect(preview, contains(line));
        }
      });
    });
  }

  test('повтор того же слипа не выдаёт второй бумажки', () async {
    final stand = await ReceiptWireStand.boot(paperWidthMm: 80);
    final service = ReceiptPrintServiceImpl();

    final first = await service.printCertificateSlip(slip());
    final again = await service.printCertificateSlip(slip());
    final copy = await service.printCertificateSlip(slip(duplicate: true));

    expect(first.isAccepted, isTrue);
    expect(
      again.status,
      PrintSubmitStatus.duplicate,
      reason: 'та же бумажка — то же задание, а не вторая распечатка',
    );
    expect(
      copy.isAccepted,
      isTrue,
      reason: 'дубликат — сознательно другая копия, он обязан напечататься',
    );
    expect(stand.emulator, isNotNull);
  });
}
