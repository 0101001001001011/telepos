/// Живой проход по эмуляторам железа: **настоящие классы продукта** против
/// эмуляторов, поднятых на настоящих сокетах.
///
/// Отличие от обычных проб этого дерева ровно одно и оно решающее: здесь
/// нет ни одного подставленного `PrinterSocket`, ни одного двойника
/// транспорта. `WifiPrinterManager` открывает `Socket.connect`,
/// `KaspiPosService` открывает свой, `LabelPrinterService` — свой. Значит
/// проверяется сборка кадров, разбор ответов и ветки отказа, а не наша
/// вера в них.
///
/// # Чего этот набор НЕ доказывает
///
/// * **Что чек напечатан, ящик открылся, деньги списаны.** Ни бумаги, ни
///   соленоида, ни банка здесь нет.
/// * **Что настоящие приборы ведут себя так же.** Каждое число в эмуляторах
///   снято с нашего же кода.
/// * **Что петля COM-порта работает.** Пары виртуальных портов на машине
///   набора нет, поэтому весы проверяются на уровне строки протокола, а не
///   порта; это названо в самой пробе.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/hardware/kaspi_pos/kaspi_pos_config.dart';
import 'package:telepos/hardware/kaspi_pos/kaspi_pos_service.dart';
import 'package:telepos/hardware/kaspi_pos/payment_terminal_journal.dart';
import 'package:telepos/hardware/label_printer/label_printer_service.dart';
import 'package:telepos/hardware/printer/printer_manager.dart';
import 'package:telepos/hardware/printer/wifi_printer.dart';
import 'package:telepos/emulators/emulated_spooler_printer.dart';
import 'package:telepos/hardware/scales/scales_service.dart';

import 'escpos/emulator.dart';
import 'escpos/faults.dart';
import 'escpos/render.dart';
import 'kaspi/emulator.dart';
import 'labels/zpl.dart';
import 'serial/emulator.dart';

void main() {
  group('Эмулятор ESC/POS ↔ настоящий WifiPrinterManager', () {
    late EscPosEmulator emulator;
    late WifiPrinterManager printer;

    setUp(() async {
      emulator = EscPosEmulator(faults: EmulatorFaults(), echo: false);
      await emulator.start('127.0.0.1', 0);
      printer = WifiPrinterManager(
        host: '127.0.0.1',
        port: emulator.port,
        statusReplyTimeout: const Duration(milliseconds: 300),
      );
    });

    tearDown(() async {
      await printer.disconnect();
      await emulator.stop();
    });

    test('чек с русским текстом доезжает и рисуется читаемым', () async {
      expect((await printer.connect()).success, isTrue);

      final job = <int>[
        ...EscPosCommands.init,
        ...EscPosCommands.alignCenter,
        ..._cp866('ЧЕК ПРОДАЖИ'),
        ...EscPosCommands.newLine,
        ...EscPosCommands.alignLeft,
        ..._cp866('Молоко 3,2%   1 x 450,00'),
        ...EscPosCommands.newLine,
        ...EscPosCommands.cutPaperPartialEscI,
      ];
      final result = await printer.printReceipt(Uint8List.fromList(job));
      expect(result.success, isTrue, reason: result.errorMessage);

      await _until(() => emulator.jobs.isNotEmpty);
      final rendered = renderReceipt(emulator.jobs.single);

      // Сильная проверка — о САМИХ полях, а не о балансе: разборщик,
      // читающий CP866 как latin1, показал бы крокозябры и был бы зелен по
      // любой проверке «строка не пуста».
      expect(rendered, contains('ЧЕК ПРОДАЖИ'));
      expect(rendered, contains('Молоко 3,2%'));
      expect(rendered, contains('[cut]'));
      expect(rendered, contains('[codepage] ESC t 17 → CP866'));
    });

    test('открытие ящика видно эмулятору отдельной командой', () async {
      expect((await printer.connect()).success, isTrue);
      await printer.openCashDrawer();
      await _until(() => emulator.drawerKicks > 0);
      expect(emulator.drawerKicks, 1);
      expect(
        renderReceipt(emulator.jobs.single),
        contains('ЯЩИК ОТКРЫТ'),
        reason: 'ящик у чекового принтера — это команда ESC p, а не прибор',
      );
    });

    test('исправный принтер отвечает на опрос состояния «готов»', () async {
      expect((await printer.connect()).success, isTrue);
      final status = await printer.getStatus();
      expect(status.isReady, isTrue, reason: status.errorMessage);
    });

    test('ОТКАЗ «бумага кончилась» доходит до продукта отдельной причиной',
        () async {
      expect((await printer.connect()).success, isTrue);
      emulator.faults.outOfPaper = true;
      final status = await printer.getStatus();
      expect(status.isOnline, isTrue);
      expect(status.isPaperPresent, isFalse);
      expect(status.errorMessage, contains('бумага'));
    });

    test('ОТКАЗ «крышка/не в сети» отличается от «нет бумаги»', () async {
      expect((await printer.connect()).success, isTrue);
      emulator.faults.coverOpen = true;
      final status = await printer.getStatus();
      expect(status.isOnline, isFalse);
      expect(status.isCoverClosed, isFalse);
    });

    test('ОТКАЗ «мусор вместо ответа» не принимается за состояние', () async {
      expect((await printer.connect()).success, isTrue);
      emulator.faults.garbageLeft = 4;
      final status = await printer.getStatus();
      expect(status.isReady, isFalse);
      expect(status.errorCode, WifiPrinterManager.statusUnknownErrorCode);
      expect(status.errorMessage, contains('неизвестно'));
    });

    test('ОТКАЗ «молчание» отличим от «мусора» по тексту причины', () async {
      expect((await printer.connect()).success, isTrue);
      emulator.faults.silencesLeft = 4;
      final status = await printer.getStatus();
      expect(status.isReady, isFalse);
      expect(status.errorMessage, contains('не ответил'));
      expect(
        status.errorMessage,
        isNot(contains('ни один из них')),
        reason:
            '«молчал» и «сказал непонятное» — разные диагнозы, и продукт их '
            'уже различает; эмулятор обязан уметь вызвать оба',
      );
    });

    test('ОТКАЗ «обрыв» замечен, а не проглочен', () async {
      expect((await printer.connect()).success, isTrue);
      emulator.faults.killsLeft = 1;
      // Первая запись роняет сокет с той стороны.
      await printer.writeRaw(Uint8List.fromList(_cp866('раз')));
      await _until(() => !printer.isConnected, timeout: const Duration(seconds: 3));
      final status = await printer.getStatus();
      expect(status.isOnline, isFalse);
    });

    test('связь с погашенным эмулятором не устанавливается', () async {
      await emulator.stop();
      final result = await printer.connect();
      expect(result.success, isFalse);
      expect(result.errorMessage, isNotNull);
    });
  });

  group('Эмулятор ZPL ↔ настоящий LabelPrinterService', () {
    late EscPosEmulator emulator;
    late LabelPrinterService labels;

    setUp(() async {
      emulator = EscPosEmulator(faults: EmulatorFaults(), echo: false, labels: true);
      await emulator.start('127.0.0.1', 0);
      labels = LabelPrinterService(host: '127.0.0.1', port: emulator.port);
    });

    tearDown(() async {
      await labels.disconnect();
      await emulator.stop();
    });

    test('ценник доезжает, и в нём видны цена и штрихкод', () async {
      final result = await labels.printPriceLabel(
        productName: 'Moloko 3,2%',
        price: Decimal.parse('450.00'),
        barcode: '4870204370014',
      );
      expect(result.success, isTrue, reason: result.errorMessage);

      await _until(() => emulator.jobs.isNotEmpty);
      final rendered = renderLabels(emulator.jobs.single);

      // Поля, а не длина: этикетка «не пустая» бывает и у той, где вместо
      // цены пусто.
      expect(rendered, contains('Moloko 3,2%'));
      expect(rendered, contains('450.00'));
      expect(rendered, contains('[barcode]'));
      expect(rendered, contains('4870204370014'));
      expect(rendered, contains('[end]'));
    });

    // # Кириллица на этикетке — было и стало
    //
    // Было: `LabelPrinterService._send` писал `Uint8List.fromList(page
    // .codeUnits)` — коды UTF-16 обрезались до байта, «Молоко» уходило
    // управляющими символами [0x1C, 0x3E, …]. Штрихкод из цифр доезжал
    // целым, и дефект был незаметен: сканер читает, имя товара — мусор.
    // Проба закрепляла дефект как ожидание («сходится, пока дефект жив») —
    // переписана на верное поведение.
    //
    // Стало: кодовая страница — по языку принтера, и **объявлена в потоке**:
    // разборщик эмулятора декодирует только то, что поток объявил
    // (`decodeLabelStream`), так что UTF-8 без `^CI28` здесь тоже мусор.
    Future<String> printRussian(LabelLanguage language) async {
      final service = LabelPrinterService(
        host: '127.0.0.1',
        port: emulator.port,
        language: language,
      );
      try {
        final result = await service.printPriceLabel(
          productName: 'Молоко 3,2%',
          price: Decimal.parse('450.00'),
          barcode: '4870204370014',
        );
        expect(result.success, isTrue, reason: result.errorMessage);
        await _until(() => emulator.jobs.isNotEmpty);
        return renderLabels(emulator.jobs.single);
      } finally {
        await service.disconnect();
      }
    }

    test('ZPL: ^CI28 и UTF-8 — русское название доезжает', () async {
      final rendered = await printRussian(LabelLanguage.zpl);
      expect(rendered, contains('Молоко 3,2%'));
      expect(rendered, contains('^CI28'));
      expect(rendered, contains('4870204370014'));
    });

    test('TSPL: CODEPAGE UTF-8 — русское название доезжает', () async {
      final rendered = await printRussian(LabelLanguage.tspl);
      expect(rendered, contains('Молоко 3,2%'));
      expect(rendered, contains('CODEPAGE UTF-8'));
      expect(rendered, contains('4870204370014'));
    });

    test('EPL: I8,C (Windows-1251) — русское название доезжает', () async {
      final rendered = await printRussian(LabelLanguage.epl);
      expect(rendered, contains('Молоко 3,2%'));
      expect(rendered, contains('I8,C,'));
      expect(rendered, contains('4870204370014'));
    });

    /// Казахское название и знак тенге на этикетке EPL.
    ///
    /// До правки 2026-09-19 `LabelPrinterService._windows1251` знал только
    /// А-я, Ё/ё и №: `ә ғ қ ң ө ұ ү һ` и `₸` уходили `0x3F`, и ценник был
    /// нечитаем. Windows-1251 из казахских букв содержит **только** `і`
    /// (0xB3) — она и должна доехать целой, остальное выходит русской
    /// основой, `₸` — сокращением `тг` (`hardware/paper_charset.dart`).
    ///
    /// Диверсия: верни `_encode` прежнее `page.codeUnits.map(_windows1251)`
    /// — падает на «ни одного знака вопроса».
    ///
    /// Чего НЕ доказывает: железа не было. Проверено, какие байты ушли и как
    /// их читает разборщик, объявивший ту же страницу.
    test('EPL: казахское название и ₸ — читаемы, без знаков вопроса', () async {
      final service = LabelPrinterService(
        host: '127.0.0.1',
        port: emulator.port,
        language: LabelLanguage.epl,
      );
      try {
        final result = await service.printPriceLabel(
          productName: 'Сүт Айналайын 1 л',
          price: Decimal.parse('480.00'),
          barcode: '4870204370014',
        );
        expect(result.success, isTrue, reason: result.errorMessage);
        await _until(() => emulator.jobs.isNotEmpty);
        final rendered = renderLabels(emulator.jobs.single);

        expect(rendered, contains('I8,C,'), reason: 'страница объявлена');
        expect(
          rendered,
          contains('Сут Айналайын 1 л'),
          reason: 'ү печатается русской «у», а не «?»',
        );
        expect(
          rendered,
          contains('тг 480.00'),
          reason: '₸ печатается сокращением «тг»',
        );
        expect(
          rendered,
          isNot(contains('?')),
          reason: 'ни одного знака вопроса на этикетке',
        );
        expect(rendered, contains('4870204370014'));
      } finally {
        await service.disconnect();
      }
    });

    /// `і` (U+0456) и «ёлочки» в Windows-1251 **есть** — заменять их нечем и
    /// незачем, и таблица это знает: замена вступает только там, где страница
    /// знак не берёт. Старая таблица службы читала « как `?`, то есть портила
    /// то, что принтер напечатал бы верно.
    test('EPL: «ёлочки» и «і» страница держит сама, они не вырождаются',
        () async {
      final service = LabelPrinterService(
        host: '127.0.0.1',
        port: emulator.port,
        language: LabelLanguage.epl,
      );
      try {
        await service.printPriceLabel(
          productName: 'Қант «Қызылорда» 1 кг',
          price: Decimal.parse('390.00'),
          barcode: '4870204370021',
        );
        await _until(() => emulator.jobs.isNotEmpty);
        final rendered = renderLabels(emulator.jobs.single);
        expect(rendered, contains('Кант «Кызылорда» 1 кг'));
        expect(rendered, isNot(contains('?')));
      } finally {
        await service.disconnect();
      }
    });

    test('разборщик не снисходительнее принтера: UTF-8 без ^CI28 — мусор', () {
      final undeclared = renderLabels(
        utf8.encode('^XA\n^FO20,20^FDМолоко^FS\n^XZ\n'),
      );
      expect(undeclared, isNot(contains('Молоко')));
      final declared = renderLabels(
        utf8.encode('^XA\n^CI28\n^FO20,20^FDМолоко^FS\n^XZ\n'),
      );
      expect(declared, contains('Молоко'));
    });
  });

  group('Эмулятор Kaspi ↔ настоящий KaspiPosService', () {
    late KaspiEmulator emulator;
    late KaspiPosService kaspi;

    setUp(() async {
      emulator = KaspiEmulator(echo: false);
      await emulator.start('127.0.0.1', 0);
      kaspi = KaspiPosService(
        config: KaspiPosConfig(
          enabled: true,
          host: '127.0.0.1',
          port: emulator.port,
          timeoutMs: 2000,
        ),
      );
    });

    tearDown(() async {
      // ДЕФЕКТ ПРОДУКТА, найденный этим эмулятором и закреплённый пробой
      // «disconnect после удачной оплаты падает» ниже: после любого
      // успешного ответа `disconnect()` выбрасывает `Bad state: Future
      // already completed`. Здесь он ловится, чтобы не красить чужие
      // случаи; сама проба его требует.
      try {
        await kaspi.disconnect();
      } catch (_) {}
      await emulator.stop();
    });

    test('disconnect после удачной оплаты закрывает терминал без исключения',
        () async {
      // До задачи 26 здесь стояла проба «ДЕФЕКТ: … выбрасывает исключение»:
      // `_onDataReceived` завершал `_pendingResponse` и не обнулял его, а
      // `disconnect` безусловно звал `completeError` на уже завершённом
      // Completer. Проба была заведена сходиться, пока дефект жив, и
      // покраснела ровно в день починки — починила его живая проба возврата
      // на карту (`kaspi/refund_live_test.dart`): возврат закрывает
      // терминал в `finally` и падал **после** того, как деньги вернулись.
      final result = await kaspi.requestPayment(
        amountKopeiki: 45000,
        receiptNo: '41',
      );
      expect(result.success, isTrue);
      await kaspi.disconnect();
      expect(kaspi.isConnected, isFalse);
    });

    test('покупка проходит, и разбор достаёт все три поля ответа', () async {
      final result = await kaspi.requestPayment(
        amountKopeiki: 45000,
        receiptNo: '42',
      );
      expect(result.success, isTrue, reason: result.errorMessage);
      // Сильная проверка — о самих полях: «успех» без номера операции это
      // «деньги взяты, следа нет», и такой дефект в этом дереве уже был.
      expect(result.transactionId, isNotEmpty);
      expect(result.approvalCode, isNotEmpty);
      expect(result.cardMask, '440043******1234');
      expect(emulator.approved['000042'], 45000);
    });

    /// # Журнал обменов с терминалом — то, чего у кассы не было вовсе
    ///
    /// Проверяется **через настоящий сокет и настоящий разбор**: запись
    /// сделана внутри `_sendAndReceive`, то есть в единственном месте, через
    /// которое проходит каждый кадр. Проба, заполнявшая бы журнал вручную,
    /// доказывала бы, что список умеет хранить список.
    test('удачный обмен попадает в журнал с кодом одобрения', () async {
      PaymentTerminalJournal.shared.clear();
      final result = await kaspi.requestPayment(
        amountKopeiki: 45000,
        receiptNo: '46',
      );
      expect(result.success, isTrue, reason: result.errorMessage);

      final exchanges = PaymentTerminalJournal.shared.recent();
      expect(
        exchanges,
        hasLength(1),
        reason: 'один кадр туда — одна запись, а не ноль и не две',
      );
      final exchange = exchanges.single;
      expect(exchange.operation, PaymentTerminalOperation.purchase);
      expect(
        exchange.request,
        contains('000045000'),
        reason: 'в журнале — тот самый кадр, который ушёл в сокет',
      );
      expect(exchange.request, contains('000046'));
      expect(exchange.approved, isTrue);
      expect(
        exchange.approvalCode,
        result.approvalCode,
        reason:
            'код одобрения снят ТЕМ ЖЕ разбором, которым продукт принимает '
            'решение о деньгах: второй разборщик однажды разойдётся с первым '
            'молча',
      );
      expect(exchange.transactionId, result.transactionId);
      expect(exchange.refusal, isNull);
      expect(exchange.response, isNotNull);
    });

    test('отказ терминала попадает в журнал дословной причиной', () async {
      PaymentTerminalJournal.shared.clear();
      emulator.refuse = 'cyrillic';
      emulator.refusesLeft = 1;
      await kaspi.requestPayment(amountKopeiki: 45000, receiptNo: '47');

      final exchange = PaymentTerminalJournal.shared.recent().single;
      expect(exchange.approved, isFalse);
      expect(
        exchange.refusal,
        'ОТКАЗ',
        reason:
            'причина приводится дословно и в той же кодировке, в какой её '
            'читает кассир: приглаженная формулировка врёт там, где её '
            'сверяют с экраном терминала',
      );
      expect(exchange.approvalCode, isNull);
    });

    test('молчание терминала — запись «ответа не было», а не пустота', () async {
      PaymentTerminalJournal.shared.clear();
      emulator.refuse = 'silence';
      emulator.refusesLeft = 1;
      // Терпение своё, короткое: ждать боевые 60 с в наборе незачем, а
      // проверяется не число, а то, что молчание оставляет след.
      final result = await kaspi.requestRefund(
        amountKopeiki: 100,
        transactionId: 'KP0000000001',
        refundKey: 'silence-1',
      );
      expect(result.success, isFalse);

      final exchange = PaymentTerminalJournal.shared.recent().single;
      expect(exchange.operation, PaymentTerminalOperation.refund);
      expect(
        exchange.response,
        isNull,
        reason: 'ответа не было — и это видно, а не додумывается по пустоте',
      );
      expect(exchange.refusal, isNotNull);
    }, timeout: const Timeout(Duration(seconds: 90)));

    test('сумма собрана ровно так, как ждёт протокол', () async {
      await kaspi.requestPayment(amountKopeiki: 45000, receiptNo: '42');
      // Эмулятор разобрал 12 цифр суммы и 6 цифр чека — если бы продукт
      // сдвинул поля, суммы бы не совпали, а не «что-то бы не сработало».
      expect(emulator.approved.keys.single, '000042');
      expect(emulator.approved.values.single, 45000);
    });

    test('ОТКАЗ «declined» приходит значением с текстом, а не исключением',
        () async {
      emulator.refuse = 'declined';
      emulator.refusesLeft = 1;
      final result = await kaspi.requestPayment(
        amountKopeiki: 45000,
        receiptNo: '43',
      );
      expect(result.success, isFalse);
      expect(result.errorMessage, contains('OTKAZ BANKA'));
      expect(result.errorCode, '${kInventedRefusalCodes['declined']}');
    });

    test('ОТКАЗ «insufficientFunds» отличим по коду и тексту', () async {
      emulator.refuse = 'insufficientFunds';
      emulator.refusesLeft = 1;
      final result = await kaspi.requestPayment(
        amountKopeiki: 45000,
        receiptNo: '44',
      );
      expect(result.success, isFalse);
      expect(result.errorMessage, contains('NEDOSTATOCHNO SREDSTV'));
      expect(
        result.errorCode,
        isNot('${kInventedRefusalCodes['declined']}'),
        reason: 'два отказа, слипшиеся в один код, — это отказ без диагноза',
      );
    });

    test('кириллица в ответе терминала доезжает до кассира', () async {
      // Было: `_parsePurchaseResponse` разбирал хвост через
      // `String.fromCharCodes` — побайтно, как latin1, и русский отказ
      // приходил крокозябрами. Проба закрепляла это как «предел» —
      // переписана на верное поведение: хвост — UTF-8.
      //
      // Кодировку настоящего терминала Kaspi мы не знаем (протокол этого
      // эмулятора снят с нашего клиента, а не с документации) — это вопрос
      // наружу, названный в отчёте дорожки D. UTF-8 выбран потому, что
      // ASCII-поля ответа он читает без изменений.
      emulator.refuse = 'cyrillic';
      emulator.refusesLeft = 1;
      final result = await kaspi.requestPayment(
        amountKopeiki: 45000,
        receiptNo: '45',
      );
      expect(result.success, isFalse);
      expect(result.errorMessage, 'ОТКАЗ');
    });

    test('НЕДОСТИЖИМО ПО TCP: ветка «Пустой ответ от терминала»', () {
      // Записано, а не проверено, и это честнее молчания. Сокет не приносит
      // пустых пакетов: `_onDataReceived` вызывается только с непустыми
      // данными, поэтому `response.isEmpty` в `_parsePurchaseResponse`
      // (`kaspi_pos_service.dart:227`) не достижим ни одним поведением
      // терминала. Эмулятор вызвать эту ветку НЕ МОЖЕТ — и заявлять, что
      // может, значило бы врать зелёным цветом.
      //
      // Ближайшее достижимое — пустая НАГРУЗКА внутри кадра, и это соседняя
      // проба «только кадр, нагрузки нет».
      expect(true, isTrue, skip: false);
    }, skip: 'ветка недостижима по TCP — см. довод в теле пробы');

    test('ОТКАЗ «только кадр, нагрузки нет» — вторая ветка того же разбора',
        () async {
      emulator.refuse = 'framesOnly';
      emulator.refusesLeft = 1;
      final result = await kaspi.requestPayment(
        amountKopeiki: 45000,
        receiptNo: '46',
      );
      expect(result.success, isFalse);
      expect(result.errorMessage, contains('Некорректный ответ'));
    });

    test('ОТКАЗ «обрыв связи» приходит значением, а не падением', () async {
      emulator.refuse = 'kill';
      emulator.refusesLeft = 1;
      final result = await kaspi.requestPayment(
        amountKopeiki: 45000,
        receiptNo: '47',
      );
      expect(result.success, isFalse);
      expect(result.errorMessage, isNotNull);
    });

    test('ОТКАЗ возникает сам: сумма ноль не проводится', () async {
      final result = await kaspi.requestPayment(
        amountKopeiki: 0,
        receiptNo: '48',
      );
      expect(result.success, isFalse);
      expect(result.errorMessage, contains('BOLSHE NULYA'));
      expect(emulator.approved, isEmpty);
    });

    test('ОТКАЗ возникает сам: сторнировать нечего', () async {
      expect(await kaspi.connect(), isTrue);
      expect(await kaspi.cancelTransaction(), isFalse);
    });

    test('сторно снимает проведённую операцию', () async {
      expect(
        (await kaspi.requestPayment(amountKopeiki: 45000, receiptNo: '49'))
            .success,
        isTrue,
      );
      expect(await kaspi.cancelTransaction(), isTrue);
      expect(emulator.approved, isEmpty);
    });

    test('соединение с отвергающим терминалом не устанавливается', () async {
      emulator.refuseConnect = true;
      final result = await kaspi.testConnection();
      // testConnection только открывает и закрывает сокет: отказ приёма
      // виден в журнале эмулятора, даже когда TCP-рукопожатие успело
      // состояться. Проверяется именно это, а не удобное «не удалось».
      await _until(
        () => emulator.journal.any((e) => e['kind'] == 'refuseConnect'),
      );
      expect(
        emulator.journal.where((e) => e['kind'] == 'refuseConnect'),
        isNotEmpty,
      );
      expect(result, isNotNull);
    });
  });

  group('Эмулятор весов ↔ настоящий ScalesService.parseLine', () {
    // Пары виртуальных портов на машине набора нет, поэтому проверяется
    // граница, до которой можно дотянуться: **строка протокола**. Что порт
    // открывается и что через com0com байты доходят, эта проба НЕ
    // доказывает — это делает живая проверка на стенде.
    test('исправная строка CAS читается тем весом, который назвали', () {
      final service = ScalesService(protocol: ScalesProtocol.cas);
      final reading = service.parseLine(
        scaleLine(dialect: 'cas', weight: '1.250', stable: true).trim(),
      );
      expect(reading, isNotNull);
      expect(reading!.weight, Decimal.parse('1.250'));
      expect(reading.status, ScalesStatus.stable);
    });

    test('отрицательный вес не теряет знак', () {
      final service = ScalesService(protocol: ScalesProtocol.cas);
      final reading = service.parseLine(
        scaleLine(dialect: 'cas', weight: '-0.500', stable: true).trim(),
      );
      expect(reading!.weight, Decimal.parse('-0.500'));
    });

    test('ОТКАЗ «перегрузка» доходит отдельным состоянием', () {
      final service = ScalesService(protocol: ScalesProtocol.cas);
      final reading = service.parseLine(
        scaleLine(dialect: 'cas', weight: '0', stable: false, overload: true)
            .trim(),
      );
      expect(reading!.status, ScalesStatus.overload);
    });

    test('ОТКАЗ «мусор» читается как «веса в строке нет», а не как ноль', () {
      final service = ScalesService(protocol: ScalesProtocol.cas);
      expect(service.parseLine('ЭТО НЕ ВЕС'), isNull);
    });

    test('неустоявшийся вес диалекта massaK не теряет старшую цифру', () {
      // Тот самый денежный дефект: `  12.345` читался как 2.345 кг.
      final service = ScalesService(protocol: ScalesProtocol.massaK);
      final reading = service.parseLine(
        scaleLine(dialect: 'massaK', weight: '12.345', stable: false).trim(),
      );
      expect(reading!.weight, Decimal.parse('12.345'));
      expect(reading.status, ScalesStatus.unstable);
    });

    test('эмулятор НЕ выдумывает перегрузку там, где её нет в протоколе', () {
      // Ложная «перегрузка» останавливает продажу. Диалект massaK не знает
      // такого маркера — эмулятор молчит, а не изобретает.
      expect(
        scaleLine(dialect: 'massaK', weight: '0', stable: false, overload: true),
        isEmpty,
      );
    });
  });

  group('Эмулятор дисплея покупателя', () {
    test('строки видны, а управляющие байты названы, а не проглочены', () {
      final rendered = renderDisplay([
        0x0C,
        ..._cp866('ИТОГО'),
        0x0D,
        ..._cp866('450,00'),
      ]);
      expect(rendered, contains('очистка экрана'));
      expect(rendered, contains('ИТОГО'));
      expect(rendered, contains('450,00'));
    });
  });

  group('Эмулятор спулера — виртуальный профиль', () {
    test('без подключения не пишет ни байта, как и настоящий драйвер',
        () async {
      // Заведено после диверсии: убрал проверку подключения — НИ ОДНА проба
      // не покраснела. Сторож, не умеющий сделать своё дело, здесь стоил бы
      // ровно того, ради чего эмулятор и существует: эмулятор, пишущий без
      // подключения, скрыл бы дефект продукта, который печатает мимо
      // открытого канала.
      final file =
          '${Directory.systemTemp.path}/telepos-emul-noconnect-'
          '${DateTime.now().microsecondsSinceEpoch}.bin';
      final printer = EmulatedSpoolerPrinter(file: file);

      final result = await printer.writeRaw(Uint8List.fromList([1, 2, 3]));
      expect(result.success, isFalse);
      expect(result.errorMessage, contains('без подключения'));
      expect(
        File(file).existsSync(),
        isFalse,
        reason: 'файла не должно появиться вовсе: байты никуда не ушли',
      );

      expect((await printer.connect()).success, isTrue);
      expect((await printer.writeRaw(Uint8List.fromList([1, 2, 3]))).success,
          isTrue);
      expect(File(file).lengthSync(), 3);
      File(file).deleteSync();
    });
  });

  group('Двери остановки', () {
    test('stop() рвёт связь с УЖЕ подключённым клиентом, а не только слушателя',
        () async {
      // Заведено после диверсии: убрал гашение клиентов — проба «порт
      // свободен» осталась зелёной, потому что Windows освобождает
      // слушающий порт и при живых клиентских сокетах. То есть прежний
      // сторож проверял не то, ради чего написан.
      //
      // Проверяется наблюдаемое: клиент, которому никто не сказал, что
      // прибора больше нет, будет ждать ответа до тайм-аута — и это ровно
      // тот висящий процесс, из-за которого дверь и появилась.
      final emulator = EscPosEmulator(faults: EmulatorFaults(), echo: false);
      await emulator.start('127.0.0.1', 0);
      final socket = await Socket.connect('127.0.0.1', emulator.port);
      var closed = false;
      socket.listen((_) {}, onError: (_) => closed = true,
          onDone: () => closed = true);
      // Клиент должен успеть приехать на сервер, иначе гасить нечего.
      socket.add([0x41]);
      await socket.flush();
      await _until(() => emulator.jobs.isNotEmpty || closed);

      await emulator.stop();

      await _until(
        () => closed,
        timeout: const Duration(seconds: 3),
      );
      expect(closed, isTrue, reason: 'клиента бросили висеть');
      socket.destroy();
    });

    test('после stop() порт свободен — иначе стенд не поднимется второй раз',
        () async {
      final emulator = EscPosEmulator(faults: EmulatorFaults(), echo: false);
      await emulator.start('127.0.0.1', 0);
      final port = emulator.port;
      final socket = await Socket.connect('127.0.0.1', port);
      await emulator.stop();

      socket.destroy();
      final again = await ServerSocket.bind('127.0.0.1', port);
      await again.close();
    });

    test('пульт /_emul/stop гасит эмулятор и освобождает оба порта', () async {
      final emulator = EscPosEmulator(faults: EmulatorFaults(), echo: false);
      await emulator.start('127.0.0.1', 0);
      await emulator.startControl('127.0.0.1', 0);
      final port = emulator.port;
      final control = emulator.controlPort;

      await stopRemote('127.0.0.1', control);

      final a = await ServerSocket.bind('127.0.0.1', port);
      await a.close();
      final b = await HttpServer.bind('127.0.0.1', control);
      await b.close(force: true);
    });

    test('у эмулятора Kaspi дверь тоже есть', () async {
      final emulator = KaspiEmulator(echo: false);
      await emulator.start('127.0.0.1', 0);
      final port = emulator.port;
      await emulator.stop();
      final again = await ServerSocket.bind('127.0.0.1', port);
      await again.close();
    });

    test('у эмулятора COM-порта дверь закрывает порт, а не только пульт',
        () async {
      final emulator = SerialEmulator(
        portPath: 'нет такого порта',
        role: 'scale',
        echo: false,
      );
      final refusal = await emulator.open();
      // Отказ значением: пары портов на машине набора нет, и это ожидаемо.
      expect(refusal, isNotNull);
      expect(refusal, contains('com0com'));
      await emulator.stop();
    });
  });
}

/// Байты CP866 из русской строки — то, что реально уходит принтеру.
List<int> _cp866(String s) => s.codeUnits.map((c) {
  if (c < 0x80) return c;
  if (c >= 0x0410 && c <= 0x043F) return 0x80 + (c - 0x0410);
  if (c >= 0x0440 && c <= 0x044F) return 0xE0 + (c - 0x0440);
  if (c == 0x0401) return 0xF0;
  if (c == 0x0451) return 0xF1;
  return 0x3F;
}).toList();

Future<void> _until(
  bool Function() done, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!done()) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('Не дождались условия за ${timeout.inMilliseconds} мс');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}
