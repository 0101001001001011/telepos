import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/app/di/print_module.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/print/print_queue_local.dart';
import 'package:telepos/data/services/receipt_print_service_impl.dart';
import 'package:telepos/data/terminal/terminal_repository_local.dart';
import 'package:telepos/domain/print/print_job.dart';
import 'package:telepos/domain/print/print_job_store.dart';
import 'package:telepos/domain/print/print_queue.dart';
import 'package:telepos/domain/services/receipt_print_service.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/hardware/printer/receipt_builder.dart';
import 'package:telepos/hardware/printer/printer_manager.dart';
import 'package:telepos/hardware/printer/wifi_printer.dart';

/// Что уходит в принтер по проводу.
///
/// До этого файла ни один тест в репозитории не смотрел на байты. Существующие
/// проверяют либо проводку типов, либо **текстовый предпросмотр**, а его рисует
/// `_PreviewTextRenderer` (`receipt_print_service_impl.dart:998-1152`) — совсем
/// другой код, чем `ReceiptBuilder`, который формирует ESC/POS. Формат провода
/// не был защищён ничем: план 2б нашёл, что голый `ESC @` после выбора кодовой
/// страницы отменял её, пробный чек печатался кракозябрами — и весь набор был
/// зелёным.
///
/// Поэтому здесь:
///
/// * печать идёт **настоящим путём продажи**, и он стал длиннее:
///   `ReceiptPrintServiceImpl.printSaleReceipt` → `PrintDocumentId` (владелец и
///   ключ идемпотентности) → `PrintQueue.submit` → очередь → транспорт
///   `printToBoundPrinter` → `WifiPrinterManager.writeRaw` → сокет. Ни
///   предпросмотра, ни собранного руками массива байтов, и ни одного звена не
///   подделано: очередь и транспорт берутся из `print_module.dart` — того
///   самого модуля, который собирает их в приложении;
/// * приёмник — настоящий TCP-слушатель на петле, порт даёт ОС (`:0`), так что
///   параллельный прогон `-j 4` не может столкнуть два теста на одном порту;
/// * ожидание — по событию прихода байтов, не по `sleep`;
/// * кодовая страница проверяется **состоянием, а не присутствием команды**:
///   поток разбирается конечным автоматом, и для каждого текстового байта
///   известно, какая страница действовала в момент его записи. Проверка «команда
///   выбора где-то есть» тот дефект не поймала бы — она там была.
void main() {
  group('ESC/POS на проводе', () {
    test('чек продажи доходит до принтера ожидаемыми байтами', () async {
      final endpoint = await _PrinterEndpoint.bind();
      addTearDown(endpoint.close);

      final printer = _managerFor(endpoint);
      addTearDown(printer.disconnect);

      await _bootPrintPath(printer);

      final service = ReceiptPrintServiceImpl(charWidth: 32);
      final outcome = await service.printSaleReceipt(_saleReceipt());

      _expectQueued(outcome);

      final wire = await endpoint.waitFor(_cut);
      await _expectPrintedByQueue(outcome);
      final scan = _EscPosScan.of(wire);

      // ── 1. Инициализация, в том порядке, в каком она уходит ──────────────
      //
      // Сброс, потом выбор страницы. Обратный порядок — это ровно дефект плана
      // 2б: `ESC @` очищает пользовательские настройки принтера, включая
      // выбранную кодовую таблицу, поэтому выбор обязан идти **после** сброса,
      // а не до него.
      expect(
        wire.take(5).toList(),
        <int>[0x1B, 0x40, 0x1B, 0x74, 17],
        reason: 'ESC @ (сброс), затем ESC t 17 (CP866) — именно в таком порядке',
      );

      // ── 2. Кодовая страница действует в момент записи кириллицы ──────────
      //
      // Главная проверка файла. Не «команда выбора встречается в потоке», а «в
      // момент записи каждого нецифрового байта действовала страница 17».
      // Любой `ESC @`, попавший после выбора и до текста, обнуляет страницу до
      // заводской — и здесь это видно, хотя байты текста не меняются.
      final unprotected = scan.text
          .where((t) => t.byte >= 0x80 && t.codePage != _cp866)
          .toList();
      expect(
        unprotected,
        isEmpty,
        reason:
            'кириллица записана при кодовой странице '
            '${unprotected.isEmpty ? '' : unprotected.first.codePage} вместо 17 '
            '(смещение ${unprotected.isEmpty ? '' : unprotected.first.offset}); '
            'между выбором CP866 и текстом встал сброс',
      );

      // ── 3. Кириллица — это CP866, а не UTF-8 ────────────────────────────
      //
      // Слова выбраны так, что два кодирования расходятся видимо и однозначно:
      // в CP866 каждая буква — один байт из таблицы ниже, в UTF-8 — два байта
      // с ведущим 0xD0/0xD1. Ни одна из этих последовательностей не может
      // получиться случайно из другой.
      //
      //   Х=0x95 л=0xAB е=0xA5 б=0xA1   (0x80..0x9F — А..Я, 0xA0..0xAF — а..п)
      //   ш=0xE8 т=0xE2                 (0xE0..0xEF — р..я)
      //   ё=0xF1  №=0xFC                (одиночные, вне непрерывных диапазонов)
      //
      // «ё» и «№» здесь не для красоты: это два места, где CP866 ломает
      // непрерывность, и кодировщик, написанный только по диапазонам, на них
      // спотыкается.
      expect(
        _indexOf(wire, const [0x95, 0xAB, 0xA5, 0xA1]),
        greaterThanOrEqualTo(0),
        reason: '«Хлеб» в CP866',
      );
      expect(
        _indexOf(wire, const [0xE8, 0xE2]),
        greaterThanOrEqualTo(0),
        reason: '«шт» в CP866',
      );
      expect(
        _indexOf(wire, const [0x8F, 0xF1, 0xE2, 0xE0]),
        greaterThanOrEqualTo(0),
        reason: '«Пётр» в CP866: ё — это 0xF1, а не продолжение диапазона',
      );
      expect(
        _indexOf(wire, const [0xFC]),
        greaterThanOrEqualTo(0),
        reason: '«№» в CP866 — 0xFC',
      );
      expect(
        _indexOf(wire, const [0x88, 0x92, 0x8E, 0x83, 0x8E]),
        greaterThanOrEqualTo(0),
        reason: '«ИТОГО» в CP866',
      );
      expect(
        _indexOf(wire, const [0x8D, 0x80, 0x8B, 0x88, 0x97, 0x8D, 0x9B, 0x8C, 0x88]),
        greaterThanOrEqualTo(0),
        reason: '«НАЛИЧНЫМИ» в CP866',
      );

      for (final word in const ['Хлеб', 'шт', 'Пётр', '№', 'ИТОГО']) {
        expect(
          _indexOf(wire, utf8.encode(word)),
          -1,
          reason: '«$word» не должно уйти в UTF-8: принтеру отдали CP866',
        );
      }

      // ── 4. Деньги ────────────────────────────────────────────────────────
      //
      // 1.005 → «1.01». На double это «1.00»: 1.005 в двоичной плавающей точке
      // хранится как 1.00499999999999989, и `toStringAsFixed(2)` округляет вниз.
      // Строка на чеке — последнее место, где Decimal ещё может быть потерян.
      expect(
        _indexOf(wire, ascii.encode('1.01 ')),
        greaterThanOrEqualTo(0),
        reason: 'количество 1.005 печатается как 1.01 (на double было бы 1.00)',
      );
      expect(
        _indexOf(wire, ascii.encode('=3760.00')),
        greaterThanOrEqualTo(0),
        reason: 'итог 3760.00 — сумма пяти строк',
      );
      expect(
        _indexOf(wire, ascii.encode('=4000.00')),
        greaterThanOrEqualTo(0),
        reason: 'принято наличными',
      );

      // ── 5. Рез приходит, и приходит последним ────────────────────────────
      //
      // «Последним» значит: после него в потоке нет ни байта. Рез в середине
      // отрезает половину чека, а хвост печатает на следующем.
      //
      // Проверяется то, что уходит: `ESC i`. По спецификации Epson это
      // **частичный** рез (остаётся одна точка), полный — `GS V 0`. Константа
      // называлась `cutPaperFull`, то есть имя обещало не то, что делает
      // команда; переименована в `cutPaperPartialEscI`. Байты оставлены как
      // есть — см. группу «Рез бумаги» ниже, там это записано проверкой.
      expect(
        scan.commands.last.name,
        'ESC i',
        reason: 'последняя команда потока — рез бумаги',
      );
      expect(
        scan.commands.last.at + scan.commands.last.length,
        wire.length,
        reason: 'после реза в потоке не осталось ни одного байта',
      );
      expect(
        scan.commands[scan.commands.length - 2].name,
        'ESC d',
        reason:
            'перед резом — протяжка: текст обязан выйти из-под ножа, иначе '
            'отрежется по последней строке',
      );
      expect(
        scan.text.where((t) => t.offset > scan.commands.last.at),
        isEmpty,
        reason: 'после реза не печатается никакой текст',
      );
    });

    test('казахская и киргизская кириллица в CP866 не помещается', () async {
      // Это не украшение теста, а измерение. Продукт заявлен на пяти языках, а
      // на проводе одна кодовая страница — CP866, в которой есть только русский
      // алфавит. Ә, Ғ, Қ, Ң, Ө, Ұ, Ү, Һ, І и киргизские Ө, Ү отсутствуют как
      // кодовые точки: заменить их нечем, и кодировщик ставит '?' (0x3F).
      // Замена сама по себе честная — соврать байтом из другой буквы было бы
      // хуже. Проверяется здесь то, что потеря происходит **молча**: ни ошибки,
      // ни отказа печатать, ни следа в результате.
      final endpoint = await _PrinterEndpoint.bind();
      addTearDown(endpoint.close);

      final printer = _managerFor(endpoint);
      addTearDown(printer.disconnect);

      await _bootPrintPath(printer);

      final outcome = await ReceiptPrintServiceImpl(
        charWidth: 32,
      ).printSaleReceipt(_saleReceipt());
      _expectQueued(outcome);

      final wire = await endpoint.waitFor(_cut);
      await _expectPrintedByQueue(outcome);

      // «Дүкен» — казахское «магазин». Д=0x84, ү нет в CP866 → 0x3F,
      // к=0xAA, е=0xA5, н=0xAD.
      expect(
        _indexOf(wire, const [0x84, 0x3F, 0xAA, 0xA5, 0xAD]),
        greaterThanOrEqualTo(0),
        reason: 'ү теряется и заменяется на «?» — CP866 её не содержит',
      );
      // «Көл» — киргизское «озеро». К=0x8A, ө → 0x3F, л=0xAB.
      expect(
        _indexOf(wire, const [0x8A, 0x3F, 0xAB]),
        greaterThanOrEqualTo(0),
        reason: 'ө теряется так же',
      );
      // Знак тенге ₸ (U+20B8) в CP866 тоже отсутствует.
      expect(
        _indexOf(wire, ascii.encode('240.00 ?')),
        greaterThanOrEqualTo(0),
        reason: 'символ валюты ₸ на чеке печатается как «?»',
      );
      // Латиница проходит без потерь — узбекский и английский на этой странице
      // живут, а две другие кириллицы нет.
      expect(
        _indexOf(wire, ascii.encode('Non Toshkent')),
        greaterThanOrEqualTo(0),
      );
      expect(
        _indexOf(wire, ascii.encode('Coca-Cola 0.5 L')),
        greaterThanOrEqualTo(0),
      );
    });

    test('чек уходит одной записью и соединение закрывается', () async {
      // Ресурсы: слушатель принял ровно одно соединение, после disconnect оно
      // закрыто, а сокет не остался висеть до конца прогона.
      final endpoint = await _PrinterEndpoint.bind();
      addTearDown(endpoint.close);

      final printer = _managerFor(endpoint);
      await _bootPrintPath(printer);

      final outcome = await ReceiptPrintServiceImpl(
        charWidth: 32,
      ).printSaleReceipt(_saleReceipt());
      _expectQueued(outcome);

      await endpoint.waitFor(_cut);
      await _expectPrintedByQueue(outcome);
      expect(
        endpoint.connections,
        1,
        reason: 'один чек — одно соединение, а не по соединению на команду',
      );

      await printer.disconnect();
      expect(printer.isConnected, isFalse);
      await endpoint.waitUntilAllClosed();
      expect(
        endpoint.openConnections,
        0,
        reason: 'после disconnect на стороне принтера открытых сокетов нет',
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Длина чека
  // ───────────────────────────────────────────────────────────────────────────
  //
  // Группа существует из-за дефекта, который нашёл файл выше: `EscPosBuffer`
  // держал 1000 байт, `addAll` бросал `BufferOverflowException` **до того, как
  // что-либо добавил**, а `BufferedPrinterManager.printReceipt` ловил его и
  // возвращал ошибку с пустым буфером. До принтера не доходило ни одного байта —
  // это не обрезанный чек, а его отсутствие, при уже принятых деньгах. Обычный
  // фискальный чек с QR весит 1167 байт, то есть не печатался.
  //
  // Проверяется не «стало больше», а «пришло всё и в том порядке»: чек из
  // двадцати позиций с фискальным QR, каждая позиция найдена, смещения строго
  // возрастают, последняя команда — рез, и после неё ни байта.
  //
  // **Путь короче, чем у группы выше, и это выбор, а не упрощение.** Проверяемое
  // здесь живёт в `BufferedPrinterManager`, а документ ему готовит
  // `ReceiptBuilder` — обе стороны настоящие, ни одна не подделана.
  // `ReceiptPrintServiceImpl` и очередь в эту цепочку не входят намеренно:
  // проверка потолка документа, привязанная к их устройству, краснела бы от
  // правок в них, ничего не сообщая о самом потолке. Что чек доходит до
  // принтера **через очередь**, проверяет группа выше.
  group('Длина чека', () {
    test('чек из двадцати позиций с QR доходит целиком и по порядку', () async {
      final endpoint = await _PrinterEndpoint.bind();
      addTearDown(endpoint.close);

      final printer = _managerFor(endpoint);
      addTearDown(printer.disconnect);

      final document = _largeReceiptBytes();
      expect(
        document.length,
        greaterThan(1000),
        reason:
            'фикстура обязана быть длиннее прежнего потолка, иначе она ничего '
            'не проверяет (получилось ${document.length} байт)',
      );

      final result = await printer.printReceipt(document);
      expect(
        result.success,
        isTrue,
        reason:
            'на прежнем буфере здесь была бы ошибка и ноль отправленных байтов; '
            'ни одна проверка ниже без этого смысла не имеет: '
            '${result.errorMessage}',
      );

      final wire = await endpoint.waitFor(_cut);
      expect(
        wire.length,
        document.length,
        reason:
            'до принтера дошёл ровно тот документ, что был собран, — ни короче, '
            'ни склеенный из кусков',
      );
      expect(
        result.bytesSent,
        document.length,
        reason: 'отчитались ровно за то, что ушло',
      );

      // ── 1. Пришли все двадцать позиций, и в том порядке, в каком выбиты ──
      //
      // Проверяются суммы строк, а не названия: сумма — чистый ASCII, её не
      // надо перекодировать в тесте, и «=» перед числом не даёт «=450.00»
      // найтись внутри «=1450.00». Названия проверяются отдельно, ниже, и
      // байтами.
      //
      // Строгое возрастание — это и есть «целиком и по порядку»: обрыв на
      // потолке потерял бы хвост, а перемешивание кусков сбило бы порядок.
      var previous = -1;
      for (final line in _largeReceiptLineTotals) {
        final at = _indexOf(wire, ascii.encode('=$line'));
        expect(
          at,
          greaterThanOrEqualTo(0),
          reason: 'строка на сумму =$line не дошла до принтера',
        );
        expect(
          at,
          greaterThan(previous),
          reason:
              'строка =$line стоит на проводе раньше предыдущей: порядок строк '
              'чека не сохранён',
        );
        previous = at;
      }

      // ── 2. Название последней позиции дошло ─────────────────────────────
      //
      // Канарейка на обрыв: любое усечение по длине съело бы прежде всего
      // хвост. «Пакет» в CP866 — П=0x8F, а=0xA0, к=0xAA, е=0xA5, т=0xE2;
      // «№» — 0xFC.
      final firstItemAt = _indexOf(wire, const [0x95, 0xAB, 0xA5, 0xA1]);
      final lastItemAt = _indexOf(wire, const [0x8F, 0xA0, 0xAA, 0xA5, 0xE2]);
      expect(firstItemAt, greaterThanOrEqualTo(0), reason: '«Хлеб» — позиция 1');
      expect(
        lastItemAt,
        greaterThan(firstItemAt),
        reason: '«Пакет» — позиция 20, и она обязана быть после первой',
      );
      expect(
        _indexOf(wire, const [0xFC, 0x32]),
        greaterThan(firstItemAt),
        reason: '«№2» в названии последней позиции — 0xFC 0x32',
      );

      // ── 3. Итог равен сумме двадцати строк ───────────────────────────────
      //
      // Целостность документа, а не только его длины: напечатанный итог обязан
      // сойтись со строками, которые до него дошли.
      final expectedTotal = _largeReceiptLineTotals
          .map(Decimal.parse)
          .fold(Decimal.zero, (Decimal sum, Decimal line) => sum + line);
      expect(
        expectedTotal.toStringAsFixed(2),
        '31015.00',
        reason: 'фикстура: сумма двадцати строк',
      );
      expect(
        _indexOf(wire, ascii.encode('=31015.00')),
        greaterThan(lastItemAt),
        reason: 'ИТОГО печатается после последней позиции и равен их сумме',
      );
      // Весовая позиция: 1.005 кг. На double `toStringAsFixed(2)` даёт «1.00»,
      // потому что 1.005 хранится как 1.00499999999999989.
      expect(
        _indexOf(wire, ascii.encode('1.01 ')),
        greaterThanOrEqualTo(0),
        reason: 'количество 1.005 печатается как 1.01 (на double было бы 1.00)',
      );

      // ── 4. Это тот чек, а не какой-нибудь ────────────────────────────────
      expect(
        _indexOf(wire, const [0x8F, 0x90, 0x8E, 0x84, 0x80, 0x86, 0x80]),
        greaterThanOrEqualTo(0),
        reason: '«ПРОДАЖА» в CP866',
      );
      expect(
        _indexOf(wire, const [0x82, 0x8E, 0x87, 0x82, 0x90, 0x80, 0x92]),
        -1,
        reason:
            '«ВОЗВРАТ» здесь взяться неоткуда; если он нашёлся, проверки выше '
            'смотрят не на тот документ',
      );

      // ── 5. QR фискального оператора дошёл целиком ────────────────────────
      //
      // QR — самая длинная неделимая команда чека и первое, что терялось при
      // обрыве. Проверяется не «команда GS ( где-то есть», а что её объявленная
      // длина равна длине ссылки и что по этому смещению лежит именно ссылка:
      // блок хранения данных — это 8 байт заголовка (`1D 28 6B pL pH 31 50 30`)
      // и следом сами данные.
      final scan = _EscPosScan.of(wire);
      final url = ascii.encode(_largeReceiptTicketUrl);
      final store = scan.commands
          .where((c) => c.name == 'GS (' && c.length == url.length + 8)
          .toList();
      expect(
        store,
        hasLength(1),
        reason:
            'ровно один блок хранения данных QR длиной под ссылку '
            '${url.length} + 8 байт; найдено ${store.length}',
      );
      expect(
        wire.sublist(store.first.at + 8, store.first.at + 8 + url.length),
        url,
        reason: 'в QR записана ссылка проверки чека, целиком',
      );
      expect(
        store.first.at,
        greaterThan(lastItemAt),
        reason: 'QR печатается после товаров',
      );

      // ── 6. Рез — последним, и после него ни байта ────────────────────────
      expect(
        scan.commands.last.at,
        greaterThan(store.first.at),
        reason: 'рез после QR, а не посреди него',
      );
      expect(
        scan.commands.last.at + scan.commands.last.length,
        wire.length,
        reason: 'после реза в потоке не осталось ни одного байта',
      );
    });

    test('чек любого размера — ровно одна запись в транспорт', () async {
      // Число, на которое опирается не этот файл. `PrintQueueLocal` объявляет
      // свой срок как «четыре попытки × одна отправка ≤ 17 с на возможность»;
      // арифметика верна ровно до тех пор, пока задание уходит одним
      // `writeRaw`. Разбиение вернуло бы множитель, а число очереди осталось бы
      // на вид точным — то есть врало бы убедительно.
      //
      // Считается на шве драйвера, а не на приёмнике: TCP волен склеить и
      // разрезать поток как угодно, и число сегментов на петле ничего не
      // говорит о числе вызовов.
      final endpoint = await _PrinterEndpoint.bind();
      addTearDown(endpoint.close);

      final printer = _CountingPrinter(
        host: InternetAddress.loopbackIPv4.address,
        port: endpoint.port,
        timeout: const Duration(seconds: 5),
        retryBudget: const Duration(seconds: 20),
        retryBackoff: const Duration(milliseconds: 20),
      );
      addTearDown(printer.disconnect);

      final document = _largeReceiptBytes();
      expect((await printer.printReceipt(document)).success, isTrue);
      await endpoint.waitFor(_cut);

      expect(
        printer.writes,
        1,
        reason:
            'документ на ${document.length} байт ушёл за ${printer.writes} '
            'записей; всё, кроме одной, ломает срок очереди и делимость '
            'задания (И29)',
      );
    });

    test('короткий текст доходит до принтера, а не остаётся в памяти', () async {
      // До удаления буфера `printText` складывал команды в общий буфер и
      // сбрасывал их, только когда тот заполнялся на 90 % — то есть короткий
      // текст **никогда** не уходил, а вызывающий получал `PrintResult.ok` с
      // числом байтов, оставшихся в оперативной памяти. Отказ, стёртый в
      // правдоподобное значение: ровно то, что здесь запрещено.
      final endpoint = await _PrinterEndpoint.bind();
      addTearDown(endpoint.close);

      final printer = _managerFor(endpoint);
      addTearDown(printer.disconnect);

      // «Привет» в CP866: П=0x8F, р=0xE0, и=0xA8, в=0xA2, е=0xA5, т=0xE2.
      const hello = [0x8F, 0xE0, 0xA8, 0xA2, 0xA5, 0xE2];

      final result = await printer.printText('Привет, касса 1');
      expect(result.success, isTrue, reason: result.errorMessage ?? '');

      final wire = await endpoint.waitFor(hello);
      expect(
        result.bytesSent,
        wire.length,
        reason:
            'отчитались ровно за те байты, которые пришли на приёмник, а не за '
            'те, что легли в буфер',
      );
    });

    test('невозможный по размеру документ отвергается, не отправив ни байта',
        () async {
      // Потолок остался, но он выведен из бумаги, а не из вкуса: 1 МиБ — это
      // примерно целый 80-метровый рулон. Проверяется не число, а поведение на
      // нём: отказ **назван** (размер, предел, причина), соединение с принтером
      // даже не открывается, и ни один байт не уходит.
      final endpoint = await _PrinterEndpoint.bind();
      addTearDown(endpoint.close);

      final printer = _managerFor(endpoint);
      addTearDown(printer.disconnect);

      final impossible = Uint8List(BufferedPrinterManager.maxJobBytes + 1);
      final result = await printer.printReceipt(impossible);

      expect(result.success, isFalse);
      expect(
        result.errorMessage,
        allOf(
          contains('${BufferedPrinterManager.maxJobBytes + 1}'),
          contains('${BufferedPrinterManager.maxJobBytes}'),
        ),
        reason:
            'причина отказа называет и пришедший размер, и предел — иначе '
            'оператору нечего понять: «${result.errorMessage}»',
      );
      expect(
        endpoint.connections,
        0,
        reason: 'к принтеру даже не подключались: отправлять было нечего',
      );
      expect(endpoint.received, isEmpty, reason: 'ни одного байта на проводе');

      // А чек нормального размера после этого печатается: отказ не оставил
      // драйвер в нерабочем состоянии — проверка состояния **после** операции,
      // а не только её возвращаемого значения.
      final document = _largeReceiptBytes();
      final second = await printer.printReceipt(document);
      expect(second.success, isTrue, reason: second.errorMessage ?? '');
      final wire = await endpoint.waitFor(_cut);
      expect(wire.length, document.length);
      expect(
        endpoint.connections,
        1,
        reason: 'соединение открылось ровно один раз — под тот чек, что ушёл',
      );
    });

    test('неудачная команда принтера не теряется в Future<void>', () async {
      // `cutPaper`, `openCashDrawer`, `feedLines` и `initialize` возвращают
      // `Future<void>`: результата записи вернуть некуда, и раньше он просто
      // выбрасывался. Порт занимаем и сразу освобождаем — соединение на него
      // будет отвергнуто.
      final dead = await _PrinterEndpoint.bind();
      final port = dead.port;
      await dead.close();

      final printer = WifiPrinterManager(
        host: InternetAddress.loopbackIPv4.address,
        port: port,
        timeout: const Duration(milliseconds: 200),
        retryBudget: const Duration(milliseconds: 400),
        retryBackoff: const Duration(milliseconds: 10),
      );
      addTearDown(printer.disconnect);

      await expectLater(
        printer.cutPaper(),
        throwsA(isA<PrinterCommandException>()),
        reason:
            'рез, который не дошёл до принтера, обязан быть слышен; молчание '
            'здесь — это «бумага отрезана» при неотрезанной бумаге',
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Рез бумаги
  // ───────────────────────────────────────────────────────────────────────────
  //
  // Здесь записано решение по второму дефекту той же области: константа
  // называлась `cutPaperFull`, а `ESC i` по спецификации Epson — **частичный**
  // рез. Имя обещало обратное тому, что делает команда, — тот же класс дефекта,
  // что поле с числом символов под именем про миллиметры.
  //
  // Исправлено **имя, а не байты**. Проверка ниже это фиксирует: если кто-то
  // решит, что «частичный» надо всё же заменить полным, он сломает не сборку, а
  // именно эту проверку — и прочитает, почему так решили.
  group('Рез бумаги', () {
    test('обе константы реза — частичные, полного реза в наборе нет', () {
      expect(
        EscPosCommands.cutPaperPartialEscI,
        const [0x1B, 0x69],
        reason:
            'ESC i — частичный рез (остаётся одна точка). Байты оставлены: они '
            'проверены на установленных принтерах, бумага режется. Полный рез '
            'GS V 0 — это другое физическое поведение, вживую не смотренное, и '
            'менять его ради того, чтобы сойтись с неверным именем, значило бы '
            'выдать непроверенное за проверенное',
      );
      expect(
        EscPosCommands.cutPaper,
        const [0x1D, 0x56, 0x01],
        reason: 'GS V 1 — тоже частичный рез',
      );
      // Полного реза (`GS V 0`) в наборе нет, и это не пропуск: он никому не
      // нужен. Проверка держит это утверждение честным — константа с такими
      // байтами появится только вместе с причиной.
      final commands = <List<int>>[
        EscPosCommands.cutPaper,
        EscPosCommands.cutPaperPartialEscI,
      ];
      expect(
        commands.where((c) => _sameBytes(c, const [0x1D, 0x56, 0x00])),
        isEmpty,
        reason: 'GS V 0 — полный рез; в наборе команд его намеренно нет',
      );
    });
  });
}

/// Настоящий сетевой транспорт, который вдобавок считает свои записи.
///
/// Подмены здесь нет: байты идут в тот же сокет тем же кодом, счётчик только
/// смотрит. Считать надо именно на этом шве — ниже начинается TCP, который
/// волен склеить две записи в один сегмент и разрезать одну на два.
class _CountingPrinter extends WifiPrinterManager {
  _CountingPrinter({
    required super.host,
    super.port,
    super.timeout,
    super.retryBudget,
    super.retryBackoff,
  });

  int writes = 0;

  @override
  Future<PrintResult> writeRaw(Uint8List data) {
    writes++;
    return super.writeRaw(data);
  }
}

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

// ─────────────────────────────────────────────────────────────────────────────
// Данные чека
// ─────────────────────────────────────────────────────────────────────────────

/// Чек, который система действительно способна произвести: пять товаров на пяти
/// языках продукта, весовая позиция с тремя знаками, НДС, фискальный блок,
/// наличная оплата со сдачей.
///
/// Чек короткий, и это теперь выбор оформления, а не обход дефекта. Когда он
/// писался, `EscPosBuffer` держал 1000 байт и `BufferedPrinterManager
/// .printReceipt` возвращал ошибку с **пустым** буфером — до принтера не
/// доходило ни одного байта. Измерено на этом самом чеке: пять позиций без QR —
/// 964 байта (запас 36), шестая позиция — 1020, те же пять позиций с фискальным
/// QR — 1167; ни то, ни другое не печаталось. Потолок снят (задача «буфер»),
/// буфер удалён, и длина проверяется отдельно — группой «Длина чека» выше, на
/// двадцати позициях с QR. Этот же чек остаётся коротким, чтобы проверка
/// формата провода читалась целиком.
SaleReceiptData _saleReceipt() {
  return SaleReceiptData(
    receiptNo: 1042,
    posId: 1,
    posName: 'Касса 1',
    // «№» — 0xFC, «ү» — буквы, которой в CP866 нет.
    storeName: 'Дүкен №2',
    dateTime: DateTime(2026, 7, 31, 12, 5),
    // «ё» — 0xF1, отдельная кодовая точка вне непрерывного диапазона.
    cashierName: 'Пётр Семёнов',
    products: [
      ReceiptProductLine(
        name: 'Хлеб Бородинский',
        quantity: Decimal.fromInt(2),
        price: Decimal.parse('250.00'),
        total: Decimal.parse('500.00'),
      ),
      ReceiptProductLine(
        // Весовая позиция: 1.005 кг — значение, на котором double врёт.
        name: 'Боорсок Ысык-Көл',
        quantity: Decimal.parse('1.005'),
        price: Decimal.parse('2000.00'),
        total: Decimal.parse('2010.00'),
      ),
      ReceiptProductLine(
        name: 'Сүт Айналайын 1 л',
        quantity: Decimal.fromInt(1),
        price: Decimal.parse('480.00'),
        total: Decimal.parse('480.00'),
      ),
      ReceiptProductLine(
        name: 'Non Toshkent',
        quantity: Decimal.fromInt(3),
        price: Decimal.parse('150.00'),
        total: Decimal.parse('450.00'),
      ),
      ReceiptProductLine(
        name: 'Coca-Cola 0.5 L',
        quantity: Decimal.fromInt(1),
        price: Decimal.parse('320.00'),
        total: Decimal.parse('320.00'),
      ),
    ],
    payments: [
      ReceiptPaymentLine(
        name: 'Наличные',
        amount: Decimal.parse('4000.00'),
        isCash: true,
      ),
    ],
    totalAmount: Decimal.parse('3760.00'),
    change: Decimal.parse('240.00'),
    seller: const ReceiptSellerInfo(
      binIin: '180440034321',
      address: 'Алматы, Абая 150',
    ),
    fiscal: const ReceiptFiscalInfo(
      fiscalNumber: 'SWK00043030',
      fiscalSign: '123456789012',
      ofdName: 'Казахтелеком',
    ),
    isVatPayer: true,
    vatAmount: Decimal.parse('402.857'),
    vatRatePercent: 12,
  );
}

/// Ссылка проверки чека у фискального оператора — то, что уходит в QR.
const String _largeReceiptTicketUrl =
    'https://consumer.oofd.kz/ticket/7f3ab9c2202607310142';

/// Суммы двадцати строк [_largeReceiptBytes] в том порядке, в каком они выбиты.
///
/// Проверка идёт по ним, а не по названиям: сумма — чистый ASCII, её не надо
/// перекодировать в тесте, а знак «=» перед числом не даёт «=450.00» найтись
/// внутри «=1450.00». Ни одна сумма не повторяется — иначе «строки пришли по
/// порядку» доказывалось бы совпадением.
const List<String> _largeReceiptLineTotals = [
  '500.00',
  '1440.00',
  '2010.00',
  '450.00',
  '1920.00',
  '1780.00',
  '3450.00',
  '1990.00',
  '2500.00',
  '1800.00',
  '1380.00',
  '1680.00',
  '760.00',
  '690.00',
  '2900.00',
  '1170.00',
  '1150.00',
  '1080.00',
  '2340.00',
  '25.00',
];

/// Продуктовая корзина на двадцать позиций с фискальным QR, собранная тем же
/// `ReceiptBuilder`, которым её собирает касса.
///
/// Не «двадцать раз одно и то же»: настоящие названия на пяти языках продукта,
/// весовая позиция с тремя знаками, у каждой строки своя сумма. Такой чек в
/// магазине у дома выбивают каждый день, и до снятия потолка он не печатался
/// вовсе — до принтера не доходило ни байта, при уже принятых деньгах.
///
/// Порядок блоков и их состав повторяют `ReceiptPrintServiceImpl
/// ._buildSaleReceipt`: шапка продавца, реквизиты кассы, товары двумя строками,
/// итог, оплата, НДС, фискальный блок со ссылкой и QR, подвал, протяжка, рез.
Uint8List _largeReceiptBytes() {
  final names = <String>[
    'Хлеб Бородинский',
    'Сүт Айналайын 1 л',
    'Боорсок Ысык-Көл',
    'Non Toshkent',
    'Coca-Cola 0.5 L',
    'Шоколад Рахат Казахстанский',
    'Кофе Jacobs Monarch 95 г',
    'Масло сливочное Простоквашино',
    'Ірімшік Сарыарқа 200 г',
    'Қымыз Наурыз 1 л',
    'Яйцо С1 десяток',
    'Сахар Аксу 1 кг',
    'Рис Ақмарал 900 г',
    'Гречка Алтын Дән 800 г',
    'Чай Пиала Gold 250 г',
    'Вода Тұран 5 л',
    'Печенье Юбилейное',
    'Сметана Бәйтерек 20%',
    'Сосиски Беккер Молочные',
    'Пакет майка №2',
  ];

  // Количество и цена на строку. Третья — весовая: 1.005 кг, значение, на
  // котором `double.toStringAsFixed(2)` даёт «1.00» вместо «1.01».
  const quantities = <String>[
    '2', '3', '1.005', '3', '6', '2', '1', '1', '2', '1',
    '2', '4', '1', '1', '2', '3', '5', '2', '1', '1',
  ];
  const prices = <String>[
    '250.00', '480.00', '2000.00', '150.00', '320.00',
    '890.00', '3450.00', '1990.00', '1250.00', '1800.00',
    '690.00', '420.00', '760.00', '690.00', '1450.00',
    '390.00', '230.00', '540.00', '2340.00', '25.00',
  ];

  final receipt = ReceiptBuilder(charWidth: 32)
    ..init()
    ..addCentered('Магазин у дома', bold: true)
    ..addCentered('БИН 180440034321')
    ..addCentered('Алматы, Абая 150')
    ..addLine()
    ..addRow('Касса', 'Касса 1')
    ..addRow('Чек №', '1043')
    ..addRow('Кассир:', 'Пётр Семёнов')
    ..addCentered('31.07.2026 19:42')
    ..addCentered('ПРОДАЖА', bold: true)
    ..addLine();

  for (var i = 0; i < names.length; i++) {
    final quantity = Decimal.parse(quantities[i]).toStringAsFixed(2);
    receipt
      ..addLeft(names[i])
      ..addRow(
        '$quantity шт x ${Decimal.parse(prices[i]).toStringAsFixed(2)}',
        '=${_largeReceiptLineTotals[i]}',
      );
  }

  receipt
    ..addLine()
    ..addRow('ИТОГО:', '=31015.00', bold: true)
    ..addRow('НАЛИЧНЫМИ:', '=35000.00')
    ..addRow('Сдача:', '3985.00')
    ..addRow('НДС 12%:', '3323.04')
    ..addCentered('ОФД Казахтелеком')
    ..addRow('ФИСК. ПРИЗНАК:', '123456789012')
    ..addRow('ФН:', 'SWK00043030')
    ..addEmptyLine()
    ..addCentered('Для проверки чека зайдите на')
    ..addCentered(_largeReceiptTicketUrl)
    ..addCentered('ФИСКАЛЬНЫЙ ЧЕК', bold: true)
    ..addEmptyLine()
    ..qr(_largeReceiptTicketUrl)
    ..addEmptyLine()
    ..addCentered('Спасибо за покупку!')
    ..addNewLines(3)
    ..cut();

  return receipt.build();
}

// ─────────────────────────────────────────────────────────────────────────────
// Приёмник
// ─────────────────────────────────────────────────────────────────────────────

/// Кодовая страница 17 в ESC/POS — это CP866.
const int _cp866 = 17;

/// То, что `ReceiptBuilder.cut()` кладёт в конец чека: `ESC i`, частичный рез.
///
/// Имя без «Full»: полного реза здесь нет и не было — было только имя
/// константы `cutPaperFull`, которое его обещало.
const List<int> _cut = [0x1B, 0x69];

/// Поднимает **настоящую** проводку печати вокруг [printer] и убирает её за
/// собой.
///
/// Ничего не подделано и ничего не собрано отдельно «для теста»: очередь и
/// транспорт заводит `registerPrintQueue` из `lib/app/di/print_module.dart` —
/// та же функция, которой пользуется приложение. Своя очередь здесь была бы
/// вторым писателем в принтер, то есть ровно тем, что она запрещает.
///
/// База настоящая, потому что без неё документ не опознать: владелец задания по
/// И29 — терминал **и** касса, `TerminalRepository.self()` берёт их из
/// установки, и без имени кассы он отказывается выдумывать терминал.
Future<AppDatabase> _bootPrintPath(PrinterManager printer) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  await db.thisPosDao.insertInitialConfig(
    companyName: 'ТОО ТестПОС',
    iinbin: '123456789012',
    cashBoxName: 'Касса 1',
    countryCode: 0,
    currencyCode: 0,
    currencySymbol: '₸',
    currencyNameShort: 'KZT',
    paperWidth: 32,
    printerHeader: null,
    printerFooter: null,
    accountId: null,
    acquiringAccountId: null,
    rsaPublicKey: null,
  );
  await (db.update(db.thisPosEntries)..where((tp) => tp.rId.equals(true)))
      .write(const ThisPosEntriesCompanion(id: Value(1)));

  GetIt.I
    ..registerSingleton<AppDatabase>(db)
    ..registerSingleton<TerminalRepository>(LocalTerminalRepository(db))
    ..registerSingleton<PrinterManager>(printer);
  registerPrintQueue(GetIt.I);

  addTearDown(() async {
    // Порядок обязателен: сброс `GetIt` зовёт `dispose` очереди, а тот снимает
    // будильник и дожидается записи, которая прямо сейчас уходит в принтер.
    // Закрыть базу раньше значило бы дописывать исход задания в закрытую базу.
    await GetIt.I.reset();
    await db.close();
  });
  return db;
}

/// Чек принят очередью. Это **не** «напечатан» — см. [_expectPrintedByQueue].
void _expectQueued(PrintSubmitOutcome outcome) {
  expect(
    outcome.status,
    PrintSubmitStatus.accepted,
    reason:
        'чек не встал в очередь, то есть не ушёл вовсе, и ни одна проверка '
        'ниже смысла не имеет: ${outcome.message}',
  );
}

/// Задание дошло до принтера и принтер его подтвердил.
///
/// **Почему одной проверки [_expectQueued] мало.** Прежний контракт
/// `printSaleReceipt` возвращал `bool` уже после записи в принтер, и `true`
/// означал «бумага вышла». `PrintSubmitStatus.accepted` означает только
/// «принято в очередь»: задание, которое принтер отверг, принимается точно так
/// же. Заменить одно на другое значило бы тихо ослабить проверку, поэтому
/// исход спрашивается отдельно — и спрашивается **у хранилища**, которое
/// переживает вызов, а не у ответа, который живёт ровно столько, сколько он.
Future<void> _expectPrintedByQueue(PrintSubmitOutcome outcome) async {
  final queue = GetIt.I<PrintQueue>();
  if (queue is PrintQueueLocal) await queue.whenIdle();

  final job = await GetIt.I<PrintJobStore>().jobById(outcome.jobId);
  expect(
    job?.state,
    PrintJobState.printed,
    reason:
        'байты на приёмнике есть, а очередь задание ${outcome.jobId} '
        'напечатанным не считает: ${job?.failureReason ?? 'задания нет вовсе'}',
  );
}

WifiPrinterManager _managerFor(_PrinterEndpoint endpoint) {
  return WifiPrinterManager(
    host: InternetAddress.loopbackIPv4.address,
    port: endpoint.port,
    // Сроки выбраны с запасом относительно петли: на петле подключение и запись
    // укладываются в единицы миллисекунд, так что запас ничего не замедляет, но
    // и не даёт загруженной машине под `-j 4` уронить тест по таймауту.
    timeout: const Duration(seconds: 5),
    retryBudget: const Duration(seconds: 20),
    retryBackoff: const Duration(milliseconds: 20),
  );
}

/// Настоящий TCP-принтер: слушает петлю, копит всё пришедшее и умеет дождаться
/// нужной последовательности, не засыпая на фиксированный срок.
class _PrinterEndpoint {
  _PrinterEndpoint._(this._server);

  static Future<_PrinterEndpoint> bind() async {
    // Порт `0` — его выбирает ОС. Иначе два файла тестов под `-j 4` дерутся за
    // один номер, и падение выглядит как дефект принтера.
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final endpoint = _PrinterEndpoint._(server);
    endpoint._subscription = server.listen(endpoint._accept);
    return endpoint;
  }

  final ServerSocket _server;
  StreamSubscription<Socket>? _subscription;

  final List<int> _received = [];
  final List<Socket> _sockets = [];

  int _connections = 0;
  int _closed = 0;
  Completer<void>? _tick;

  int get port => _server.port;

  int get connections => _connections;

  int get openConnections => _connections - _closed;

  List<int> get received => List<int>.unmodifiable(_received);

  void _accept(Socket socket) {
    _connections++;
    _sockets.add(socket);
    socket.listen(
      (chunk) {
        _received.addAll(chunk);
        _wake();
      },
      onError: (Object _) {
        _closed++;
        _wake();
      },
      onDone: () {
        _closed++;
        _wake();
      },
      cancelOnError: false,
    );
    _wake();
  }

  void _wake() {
    final tick = _tick;
    _tick = null;
    if (tick != null && !tick.isCompleted) tick.complete();
  }

  /// Ждёт, пока в принятом потоке появится [terminator].
  ///
  /// Просыпается на приходе байтов, а не по расписанию: на быстрой машине
  /// возвращает сразу, на загруженной — терпит, и ни в одном случае не зависит
  /// от угаданной длительности `sleep`.
  Future<List<int>> waitFor(
    List<int> terminator, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    await _waitUntil(
      () => _indexOf(_received, terminator) >= 0,
      timeout,
      'принтер не получил последовательность $terminator за '
      '${timeout.inSeconds} с; принято ${_received.length} байт',
    );
    return received;
  }

  Future<void> waitUntilAllClosed({
    Duration timeout = const Duration(seconds: 10),
  }) {
    return _waitUntil(
      () => openConnections == 0,
      timeout,
      'соединение с принтером осталось открытым',
    );
  }

  Future<void> _waitUntil(
    bool Function() done,
    Duration timeout,
    String onTimeout,
  ) async {
    final deadline = DateTime.now().add(timeout);
    while (!done()) {
      final left = deadline.difference(DateTime.now());
      if (left <= Duration.zero) fail(onTimeout);
      final tick = Completer<void>();
      _tick = tick;
      try {
        await tick.future.timeout(left);
      } on TimeoutException {
        if (!done()) fail(onTimeout);
        return;
      } finally {
        _tick = null;
      }
    }
  }

  Future<void> close() async {
    for (final socket in _sockets) {
      try {
        socket.destroy();
      } catch (_) {}
    }
    _sockets.clear();
    await _subscription?.cancel();
    _subscription = null;
    await _server.close();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Разбор потока ESC/POS
// ─────────────────────────────────────────────────────────────────────────────

class _Command {
  const _Command(this.at, this.length, this.name);

  final int at;
  final int length;
  final String name;

  @override
  String toString() => '$name@$at';
}

class _TextByte {
  const _TextByte(this.offset, this.byte, this.codePage);

  final int offset;
  final int byte;

  /// Кодовая страница, действовавшая в момент записи этого байта. `-1` —
  /// «заводская, какая именно неизвестно»: столько знает принтер после `ESC @`.
  final int codePage;

  @override
  String toString() =>
      '0x${byte.toRadixString(16)}@$offset(cp=$codePage)';
}

/// Разбирает поток так, как это делает принтер: команды по длине, всё
/// остальное — печатаемые данные.
///
/// Длины команд обязательны: без них параметр вроде `0x1B` внутри QR-кода был
/// бы принят за начало новой команды, и автомат разошёлся бы с принтером. На
/// неизвестной команде разбор бросает исключение вместо того, чтобы её
/// пропустить: незамеченная команда — это ровно та дыра, которую этот файл
/// закрывает.
class _EscPosScan {
  _EscPosScan._(this.commands, this.text);

  final List<_Command> commands;
  final List<_TextByte> text;

  /// Страница после `ESC @`: сброс возвращает принтер к его собственной
  /// настройке, и утверждать, что это 17, нельзя.
  static const int unknownCodePage = -1;

  static _EscPosScan of(List<int> bytes) {
    final commands = <_Command>[];
    final text = <_TextByte>[];
    var codePage = unknownCodePage;
    var i = 0;

    int at(int offset) {
      if (i + offset >= bytes.length) {
        fail('поток обрывается посреди команды на смещении $i');
      }
      return bytes[i + offset];
    }

    while (i < bytes.length) {
      final byte = bytes[i];

      if (byte == 0x1B) {
        final code = at(1);
        final int length;
        final String name;
        switch (code) {
          case 0x40: // ESC @ — сброс. Кодовая таблица возвращается к заводской.
            codePage = unknownCodePage;
            length = 2;
            name = 'ESC @';
          case 0x74: // ESC t n — выбор кодовой таблицы.
            codePage = at(2);
            length = 3;
            name = 'ESC t';
          case 0x61: // ESC a n — выравнивание.
            length = 3;
            name = 'ESC a';
          case 0x45: // ESC E n — жирный.
            length = 3;
            name = 'ESC E';
          case 0x2D: // ESC - n — подчёркивание.
            length = 3;
            name = 'ESC -';
          case 0x64: // ESC d n — протяжка на n строк.
            length = 3;
            name = 'ESC d';
          case 0x33: // ESC 3 n — межстрочный интервал.
            length = 3;
            name = 'ESC 3';
          case 0x32: // ESC 2 — интервал по умолчанию.
            length = 2;
            name = 'ESC 2';
          case 0x69: // ESC i — рез.
            length = 2;
            name = 'ESC i';
          case 0x6D: // ESC m — рез.
            length = 2;
            name = 'ESC m';
          case 0x70: // ESC p m t1 t2 — денежный ящик.
            length = 5;
            name = 'ESC p';
          case 0x42: // ESC B n t — зуммер.
            length = 4;
            name = 'ESC B';
          default:
            fail(
              'неизвестная команда ESC 0x${code.toRadixString(16)} на смещении '
              '$i — разбор остановлен, чтобы не выдать параметры за текст',
            );
        }
        at(length - 1);
        commands.add(_Command(i, length, name));
        i += length;
        continue;
      }

      if (byte == 0x1D) {
        final code = at(1);
        final int length;
        final String name;
        switch (code) {
          case 0x21: // GS ! n — размер символа.
            length = 3;
            name = 'GS !';
          case 0x42: // GS B n — инверсия.
            length = 3;
            name = 'GS B';
          case 0x56: // GS V m — рез.
            length = 3;
            name = 'GS V';
          case 0x28: // GS ( k pL pH ... — двумерные коды, длина в параметрах.
            length = 5 + at(3) + at(4) * 256;
            name = 'GS (';
          default:
            fail(
              'неизвестная команда GS 0x${code.toRadixString(16)} на смещении $i',
            );
        }
        at(length - 1);
        commands.add(_Command(i, length, name));
        i += length;
        continue;
      }

      text.add(_TextByte(i, byte, codePage));
      i++;
    }

    return _EscPosScan._(commands, text);
  }
}

int _indexOf(List<int> haystack, List<int> needle) {
  if (needle.isEmpty || needle.length > haystack.length) return -1;
  for (var i = 0; i + needle.length <= haystack.length; i++) {
    var hit = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        hit = false;
        break;
      }
    }
    if (hit) return i;
  }
  return -1;
}
