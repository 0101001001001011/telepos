import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/services/receipt_print_service_impl.dart';
import 'package:telepos/domain/entities/receipt/receipt_options.dart';

import 'support/receipt_wire_stand.dart';

/// Шаблон чека на бумаге: жалоба заказчика «в любой POS-системе чеки
/// настраиваются — маркетинг и благодарность в шапке и в подвале».
///
/// Каждая проба сохраняет шаблон **в базу кассы** — туда, куда его пишет экран
/// «Шаблоны чеков», — печатает службой, собранной как в приложении, и читает
/// бумагу эмулятора ESC/POS: какие строки, в каком порядке, с каким
/// выравниванием, жирностью и размером они вышли.
void main() {
  const header =
      'Добро пожаловать в магазин Ромашка!\n'
      'Скидка 10% по средам на всю молочную продукцию и хлеб';
  const footer =
      'Спасибо за покупку!\n'
      'Обмен и возврат в течение 14 дней при наличии чека\n'
      'Сайт: romashka.kz Instagram: @romashka_kz';

  Future<void> useTemplate(ReceiptOptions options) async {
    final dao = GetIt.I<AppDatabase>().receiptTemplateDao;
    await dao.seedDefaults();
    final selected = await dao.getSelected();
    await dao.updateTemplate(
      selected!.id,
      ReceiptTemplatesCompanion(optionsJson: Value(options.encode())),
    );
  }

  List<String> textsOf(List<PaperEntry> paper) =>
      [for (final e in paper) if (e.isLine) e.text];

  for (final mm in const [58, 80]) {
    final columns = ReceiptPaperWidth.fromMm(mm).charWidth;
    final ticketUrl = wireSale().fiscal!.ticketUrl!;

    group('лента $mm мм ($columns колонок)', () {
      late ReceiptWireStand stand;

      setUp(() async {
        stand = await ReceiptWireStand.boot(paperWidthMm: mm);
      });

      test(
        'шапка из 2 строк и подвал из 3 — выше и ниже обязательной части, '
        'по центру, перенесены по словам, кириллица на месте',
        () async {
          await useTemplate(
            const ReceiptOptions(
              header: ReceiptTextBlock(text: header),
              footer: ReceiptTextBlock(text: footer),
            ),
          );
          final paper = paperOf(
            await stand.nextJob(
              () => ReceiptPrintServiceImpl().printSaleReceipt(wireSale()),
            ),
          );
          final lines = paper.where((e) => e.isLine).toList();

          // ── Шапка: до продавца, первой строки обязательной части.
          final storeAt = lines.indexWhere((l) => l.text == 'ТОО ТестПОС');
          expect(storeAt, greaterThan(0), reason: 'шапки нет перед продавцом');
          final headerLines = lines
              .take(storeAt)
              .where((l) => l.text.isNotEmpty)
              .toList();
          expect(
            headerLines.map((l) => l.text).join(' '),
            header.replaceAll('\n', ' '),
            reason: 'слова шапки, их порядок и кириллица',
          );
          expect(
            headerLines,
            hasLength(mm == 58 ? 4 : 3),
            reason: 'перенос по словам под $columns колонок: $headerLines',
          );
          for (final l in headerLines) {
            expect(l.text.length, lessThanOrEqualTo(columns), reason: '$l');
            expect(l.align, PaperEntry.alignCenter, reason: '$l');
          }

          // ── Подвал: после QR фискального блока, до реза.
          final qrAt = paper.indexWhere((e) => e.kind == 'qr');
          final cutAt = paper.indexWhere((e) => e.kind == 'cut');
          expect(qrAt, greaterThan(0), reason: 'QR фискального чека не вышел');
          expect(cutAt, greaterThan(qrAt));
          final footerLines = paper
              .sublist(qrAt + 1, cutAt)
              .where((e) => e.isLine && e.text.isNotEmpty)
              .toList();
          expect(
            footerLines.map((l) => l.text).join(' '),
            footer.replaceAll('\n', ' '),
          );
          expect(
            footerLines,
            hasLength(mm == 58 ? 5 : 4),
            reason: 'перенос по словам под $columns колонок: $footerLines',
          );
          for (final l in footerLines) {
            expect(l.text.length, lessThanOrEqualTo(columns), reason: '$l');
            expect(l.align, PaperEntry.alignCenter, reason: '$l');
          }

          // ── Обязательная часть на месте и целиком.
          final all = textsOf(paper).join('\n');
          for (final required in const [
            'Чек ',
            'ИТОГО:',
            'НАЛИЧНЫМИ',
            'ФИСК. ПРИЗНАК:',
            'РНМ:',
            'ФИСКАЛЬНЫЙ ЧЕК',
          ]) {
            expect(all, contains(required));
          }
          expect(paper[qrAt].text, ticketUrl, reason: 'QR несёт ссылку целиком');
          final urlFrom = lines.indexWhere(
            (l) => l.text == 'Для проверки чека зайдите на',
          );
          final fiscalAt = lines.indexWhere((l) => l.text == 'ФИСКАЛЬНЫЙ ЧЕК');
          expect(
            lines.sublist(urlFrom + 1, fiscalAt).map((l) => l.text).join(),
            ticketUrl,
            reason:
                'ссылка проверки перенесена, а не обрезана по ширине ленты — '
                'по обрезанной покупатель не проверит чек',
          );
        },
      );

      test('пустые шапка и подвал не дают ни одной пустой строки', () async {
        await useTemplate(
          const ReceiptOptions(
            header: ReceiptTextBlock(text: '  \n\n '),
            footer: ReceiptTextBlock(),
          ),
        );
        final paper = paperOf(
          await stand.nextJob(
            () => ReceiptPrintServiceImpl().printSaleReceipt(wireSale()),
          ),
        );
        expect(
          paper.firstWhere((e) => e.isLine).text,
          'ТОО ТестПОС',
          reason: 'первая строка бумаги — продавец, а не пустота шапки',
        );
        final qrAt = paper.indexWhere((e) => e.kind == 'qr');
        final cutAt = paper.indexWhere((e) => e.kind == 'cut');
        expect(
          paper.sublist(qrAt + 1, cutAt).where((e) => e.isLine),
          isEmpty,
          reason: 'после QR — только протяжка и рез',
        );
      });

      test(
        'крупная жирная шапка справа не протекает в обязательную часть',
        () async {
          const loud = 'АКЦИЯ ДНЯ: кофе в подарок к выпечке';
          await useTemplate(
            const ReceiptOptions(
              header: ReceiptTextBlock(
                text: loud,
                align: ReceiptTextAlign.right,
                bold: true,
                doubleSize: true,
              ),
              footer: ReceiptTextBlock(
                text: 'До встречи!',
                align: ReceiptTextAlign.left,
                bold: true,
              ),
            ),
          );
          final lines = paperOf(
            await stand.nextJob(
              () => ReceiptPrintServiceImpl().printSaleReceipt(wireSale()),
            ),
          ).where((e) => e.isLine).toList();

          final storeAt = lines.indexWhere((l) => l.text == 'ТОО ТестПОС');
          final headerLines = lines
              .take(storeAt)
              .where((l) => l.text.isNotEmpty)
              .toList();
          expect(headerLines.map((l) => l.text).join(' '), loud);
          for (final l in headerLines) {
            expect(l.align, PaperEntry.alignRight, reason: '$l');
            expect(l.bold, isTrue, reason: '$l');
            expect(l.size, PaperEntry.sizeDouble, reason: '$l');
            expect(
              l.text.length,
              lessThanOrEqualTo(columns ~/ 2),
              reason: 'двойной размер — вдвое меньше колонок: $l',
            );
          }

          final cashbox = lines.firstWhere((l) => l.text.startsWith('Касса'));
          expect(cashbox.align, PaperEntry.alignLeft, reason: '$cashbox');
          expect(cashbox.bold, isFalse, reason: '$cashbox');
          expect(cashbox.size, PaperEntry.sizeNormal, reason: '$cashbox');
          expect(lines[storeAt].size, PaperEntry.sizeNormal);
          expect(lines[storeAt].align, PaperEntry.alignCenter);

          final bye = lines.firstWhere((l) => l.text == 'До встречи!');
          expect(bye.align, PaperEntry.alignLeft);
          expect(bye.bold, isTrue);
          expect(bye.size, PaperEntry.sizeNormal);
        },
      );

      test('управляющие байты из текста шаблона до принтера не доходят', () async {
        await useTemplate(
          const ReceiptOptions(
            // ESC i — рез, ESC @ — сброс, GS V — рез, NUL: вставлены из
            // буфера обмена или набраны нарочно.
            header: ReceiptTextBlock(text: 'Акция\x1Bi дня\x1DV!\x00'),
            footer: ReceiptTextBlock(text: 'Спасибо\x1B@'),
          ),
        );
        final paper = paperOf(
          await stand.nextJob(
            () => ReceiptPrintServiceImpl().printSaleReceipt(wireSale()),
          ),
        );
        expect(paper.where((e) => e.kind == 'cut'), hasLength(1));
        expect(paper.where((e) => e.kind == 'init'), hasLength(1));
        expect(paper.where((e) => e.kind == 'codepage'), hasLength(1));
        expect(paper.where((e) => e.kind == 'unknown'), isEmpty);
        expect(paper.last.kind, 'cut', reason: 'рез — последним');
        final texts = textsOf(paper);
        expect(texts, contains('Акцияi дняV!'));
        expect(texts, contains('Спасибо@'));
      });

      test(
        'сторож: шаблон из базы читается путём печати — продажа и возврат — и '
        'правка действует после сброса кэша',
        () async {
          final service = ReceiptPrintServiceImpl();
          await useTemplate(
            const ReceiptOptions(
              header: ReceiptTextBlock(text: 'МЕТКА-ШАПКИ-1'),
              footer: ReceiptTextBlock(text: 'МЕТКА-ПОДВАЛА-1'),
            ),
          );

          final sale = textsOf(
            paperOf(await stand.nextJob(() => service.printSaleReceipt(wireSale()))),
          );
          expect(sale, containsAll(['МЕТКА-ШАПКИ-1', 'МЕТКА-ПОДВАЛА-1']));

          final refund = textsOf(
            paperOf(
              await stand.nextJob(() => service.printRefundReceipt(wireRefund())),
            ),
          );
          expect(refund, containsAll(['МЕТКА-ШАПКИ-1', 'МЕТКА-ПОДВАЛА-1']));

          await useTemplate(
            const ReceiptOptions(
              header: ReceiptTextBlock(text: 'МЕТКА-ШАПКИ-2'),
              footer: ReceiptTextBlock(text: 'МЕТКА-ПОДВАЛА-2'),
            ),
          );
          service.invalidateReceiptOptionsCache();
          final edited = textsOf(
            paperOf(
              await stand.nextJob(() => service.printSaleDuplicate(wireSale())),
            ),
          );
          expect(edited, containsAll(['МЕТКА-ШАПКИ-2', 'МЕТКА-ПОДВАЛА-2']));
        },
      );

      test(
        'казахская шапка: предпросмотр показывает ровно то, что выйдет на '
        'бумагу — русскую основу вместо ә, ғ, қ, ө, ү',
        () async {
          // Это и есть «явное предупреждение» о замене: отдельной надписи нет
          // и не задумано, потому что экран шаблона показывает бумагу. Если
          // предпросмотр покажет «Сәлем», а лента выбьет «Салем», заказчик
          // узнает о потере от покупателя.
          const kazakh = ReceiptOptions(
            header: ReceiptTextBlock(text: 'Сәлеметсіз бе! Дүкен «Ромашка»'),
            footer: ReceiptTextBlock(text: 'Сатып алғаныңыз үшін рақмет! 100 ₸'),
          );
          await useTemplate(kazakh);
          final service = ReceiptPrintServiceImpl();
          final printed = textsOf(
            paperOf(
              await stand.nextJob(() => service.printSaleReceipt(wireSale())),
            ),
          );

          // Сравнение по склеенному тексту, а не по строкам: на ленте 58 мм
          // подвал переносится по словам, и число строк — свойство ширины, а
          // не знаков.
          String flat(Iterable<String> lines) =>
              lines.join(' ').replaceAll(RegExp(r'\s+'), ' ');

          const expectedHeader = 'Салеметсiз бе! Дукен "Ромашка"';
          const expectedFooter = 'Сатып алганыныз ушiн ракмет! 100 тг';

          expect(
            flat(printed),
            contains(expectedHeader.replaceAll('i', 'и')),
            reason: 'бумага: казахские буквы русской основой',
          );
          expect(
            flat(printed),
            contains(expectedFooter.replaceAll('i', 'и')),
            reason: 'бумага: ₸ сокращением «тг»',
          );
          expect(
            printed.where((l) => l.contains('?')),
            isEmpty,
            reason: 'ни одного знака вопроса на ленте',
          );

          final preview = service
              .renderSalePreviewText(
                wireSale(),
                kazakh,
                paperWidth: ReceiptPaperWidth.fromMm(mm),
              )
              .split('\n');
          expect(
            flat(preview),
            contains(expectedHeader.replaceAll('i', 'и')),
            reason: 'предпросмотр показывает бумагу, а не исходный текст',
          );
          expect(flat(preview), contains(expectedFooter.replaceAll('i', 'и')));
        },
      );

      test('предпросмотр шаблона — те же строки, что вышли на бумагу', () async {
        const options = ReceiptOptions(
          header: ReceiptTextBlock(text: header),
          footer: ReceiptTextBlock(text: footer, align: ReceiptTextAlign.left),
        );
        await useTemplate(options);
        final service = ReceiptPrintServiceImpl();
        final paper = paperOf(
          await stand.nextJob(() => service.printSampleReceipt(wireSale())),
        );

        // `№` больше не выправляется: до сведения таблиц знаков продукт
        // писал его байтом 0xFC, предпросмотр читал «№», а эмулятор — «·»,
        // и сравнение приходилось ослаблять. Теперь таблица одна
        // (`hardware/paper_charset.dart`), и строки сходятся как есть.
        List<String> normalise(Iterable<String> lines) {
          final result = [
            for (final l in lines)
              if (!l.trim().startsWith('ВРЕМЯ:')) l.trim(),
          ];
          while (result.isNotEmpty && result.last.isEmpty) {
            result.removeLast();
          }
          return result;
        }

        final printed = normalise([
          for (final e in paper)
            if (e.isLine) e.text else if (e.kind == 'qr') '[ QR ]',
        ]);
        final preview = normalise(
          service
              .renderSalePreviewText(
                wireSale(),
                options,
                paperWidth: ReceiptPaperWidth.fromMm(mm),
              )
              .split('\n'),
        );
        expect(preview, printed);
      });
    });
  }
}
