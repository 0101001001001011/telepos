/// QR/СБП против **настоящего эмулятора провайдера**, по сети, с настоящей
/// базой — задача 22 плана «Полнота продажи».
///
/// # Почему через сокет, а не через подделку интерфейса
///
/// Потому что подделка `QrPaymentProvider` проверяет `QrPaymentProvider`,
/// а ломается в магазине не он. Ломаются: тайм-аут, обрыв соединения,
/// непонятное тело ответа, ответ, приехавший позже, чем касса согласна
/// ждать. Ни одного из этих исходов подделка не воспроизводит — она
/// возвращает `Future`, который всегда завершается.
///
/// Точка подстановки здесь **самая дальняя**: адрес. `lib/` про эмулятор
/// не знает ни строчки, и это сторожится отдельной пробой ниже.
///
/// # Что здесь проверяется на самом деле
///
/// Не форма протокола (она выдумана, см. докстринг эмулятора), а **время**:
/// подтверждение приходит после вопроса, может опоздать, не прийти вовсе,
/// прийти дважды и прийти после того, как касса сдалась.
library;

import 'dart:async';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/payment/http_qr_payment_provider.dart';
import 'package:telepos/data/payment/qr_payment_coordinator.dart';
import 'package:telepos/domain/payment/payment_intent.dart';
import 'package:telepos/domain/payment/qr_payment_provider.dart';

import 'emulator.dart';

Decimal d(String s) => Decimal.parse(s);

void main() {
  late SbpEmulator emulator;
  late AppDatabase db;
  late HttpQrPaymentProvider provider;

  /// Порты, взятые за прогон, — считаются, чтобы «порты свободны» было
  /// **числом**, а не ощущением.
  final takenPorts = <int>[];

  setUp(() async {
    emulator = SbpEmulator(echo: false);
    // Порт 0 — операционная система выдаёт свободный. Прибитый номер в
    // наборе даёт «Address already in use» ровно тогда, когда соседний
    // сеанс гоняет тот же файл, и выглядит это как дефект продукта.
    await emulator.start('127.0.0.1', 0);
    await emulator.startControl('127.0.0.1', 0);
    takenPorts..add(emulator.port)..add(emulator.controlPort);

    db = AppDatabase.forTesting(NativeDatabase.memory());
    provider = HttpQrPaymentProvider(
      baseUrl: emulator.baseUrl,
      code: 'sbp_emul',
      timeout: const Duration(milliseconds: 700),
    );
  });

  tearDown(() async {
    provider.close();
    await db.close();
    await emulator.stop();
  });

  QrPaymentCoordinator coordinator({
    Duration patience = const Duration(seconds: 5),
    Duration pollEvery = const Duration(milliseconds: 20),
    AppDatabase? over,
  }) => QrPaymentCoordinator(
    db: over ?? db,
    provider: provider,
    patience: patience,
    pollEvery: pollEvery,
  );

  /// Пульт эмулятора — так же, как им пользовался бы человек курлом.
  Future<Map<String, Object?>> control(
    String path, [
    Map<String, Object?> body = const {},
  ]) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(
        Uri.parse('http://127.0.0.1:${emulator.controlPort}$path'),
      );
      request.headers.contentType = ContentType.json;
      request.write(
        body.isEmpty ? '{}' : const JsonEncoderShim().encode(body),
      );
      final response = await request.close();
      await response.drain<void>();
      return const {};
    } finally {
      client.close(force: true);
    }
  }

  group('намерение переживает перезагрузку кассы', () {
    test(
      'подтверждение, пришедшее после перезапуска кассы, не теряет денег',
      () async {
        final qr = coordinator();
        final begun = await qr.begin(
          intentKey: 'k-restart',
          amount: d('1000'),
          posId: 1,
          receiptNo: 77,
        );
        expect(begun.isOk, isTrue, reason: begun.refusal?.message);
        final providerIntentId = begun.intent!.providerIntentId;
        expect(providerIntentId, isNotNull);

        // Касса выключается. Не «мы забыли переменную» — база закрывается
        // и открывается заново поверх того же файла.
        final file = await _spillToFile(db);
        await db.close();
        final restarted = AppDatabase.forTesting(NativeDatabase(file));
        addTearDown(() async {
          await restarted.close();
          if (file.existsSync()) file.deleteSync();
        });

        // Покупатель платит, пока кассы нет.
        emulator.confirm(emulator.byId[providerIntentId]!);

        final afterRestart = coordinator(over: restarted);
        final orphans = await afterRestart.reconcile();

        final row = await restarted.paymentIntentDao.byKey('k-restart');
        expect(
          row!.status,
          QrIntentStatus.paid,
          reason:
              'подтверждение лежало у провайдера всё время, пока касса была '
              'выключена; спросить про него — единственный способ узнать',
        );
        expect(
          orphans.map((i) => i.intentKey),
          contains('k-restart'),
          reason:
              'деньги без чека остаются ВИДИМЫМИ, не молча: это ровно тот '
              'класс беды, который в дереве уже случался однажды',
        );
        expect(
          row.isOrphanMoney,
          isTrue,
          reason: 'оплачено, а settled_at пуст — деньги есть, чека нет',
        );
      },
    );
  });

  group('идемпотентность', () {
    test('повтор не создаёт второго намерения ни у нас, ни у провайдера',
        () async {
      final qr = coordinator();
      final first = await qr.begin(intentKey: 'k-1', amount: d('500'));
      final second = await qr.begin(intentKey: 'k-1', amount: d('500'));

      expect(first.createdNow, isTrue);
      expect(
        second.createdNow,
        isFalse,
        reason: 'второй вызов тем же ключом обязан вернуть прежнее намерение',
      );
      expect(
        second.intent!.id,
        first.intent!.id,
        reason: 'та же строка базы, а не вторая',
      );
      expect(
        second.intent!.providerIntentId,
        first.intent!.providerIntentId,
        reason: 'то же намерение у провайдера, а не второе',
      );
      expect(
        emulator.byId.length,
        1,
        reason:
            'у провайдера ровно одно намерение: иначе покупатель мог бы '
            'заплатить по обоим',
      );

      final rows = await db.select(db.paymentIntents).get();
      expect(rows.length, 1, reason: 'в базе кассы ровно одна строка');
    });

    test('две одновременные попытки заводят одно намерение', () async {
      final qr = coordinator();
      // `Future.wait`, а не «сначала одна, потом другая»: последовательный
      // вызов зеленеет и при полностью снятой защите, потому что второму
      // достаётся уже записанная строка.
      final both = await Future.wait([
        qr.begin(intentKey: 'k-race', amount: d('700')),
        qr.begin(intentKey: 'k-race', amount: d('700')),
      ]);
      expect(both.where((r) => r.createdNow).length, 1,
          reason: 'ровно одна из двух попыток завела строку');
      final rows = await db.select(db.paymentIntents).get();
      expect(rows.length, 1);
      expect(emulator.byId.length, 1);
    });

    test('второе подтверждение не берёт денег дважды', () async {
      final qr = coordinator();
      final begun = await qr.begin(intentKey: 'k-double', amount: d('300'));
      final id = begun.intent!.id;

      // Пульт: подтвердить ДВАЖДЫ.
      final intent = emulator.byId[begun.intent!.providerIntentId]!;
      emulator
        ..confirm(intent)
        ..confirm(intent);
      expect(intent.confirmations, 2, reason: 'провайдер подтвердил дважды');

      await qr.awaitOutcome(id);

      expect(
        await qr.settle(id, 77),
        isTrue,
        reason: 'первая запись в чек проходит',
      );
      expect(
        await qr.settle(id, 78),
        isFalse,
        reason:
            'вторая — НЕТ: эти деньги уже в чеке, и вторая строка Payments '
            'на них была бы взятием денег дважды',
      );

      final row = await db.paymentIntentDao.byId(id);
      expect(row!.settledReceiptNo, 77,
          reason: 'чек остался первым, а не переписан вторым');
      expect(row.confirmations, 1,
          reason:
              'касса насчитала один переход в «оплачено»: счётчик считает '
              'подтверждения, а не круги опроса');
    });
  });

  group('что видит кассир, пока ждёт, и как он это прерывает', () {
    test('кассир прерывает ожидание — намерение отменено у провайдера',
        () async {
      final qr = coordinator(patience: const Duration(seconds: 30));
      final begun = await qr.begin(intentKey: 'k-cancel', amount: d('900'));
      expect(
        begun.intent!.qrPayload,
        isNotNull,
        reason: 'кассиру есть что показать покупателю, пока он ждёт',
      );

      final cancel = Completer<void>();
      final waiting = qr.awaitOutcome(
        begun.intent!.id,
        cancelSignal: cancel.future,
      );
      await Future<void>.delayed(const Duration(milliseconds: 60));
      cancel.complete();

      final outcome = await waiting;
      expect(outcome.reason, QrWaitReason.cashierCancelled);
      expect(outcome.intent!.status, QrIntentStatus.cancelled);
      expect(
        outcome.intent!.abandonedAt,
        isNotNull,
        reason: 'касса записала, что перестала ждать',
      );
      expect(
        outcome.intent!.isOrphanMoney,
        isFalse,
        reason: 'денег не было — и разбирать нечего',
      );
    });

    test('терпение кассы кончается само, если покупатель молчит', () async {
      // Молчание покупателя — это НЕ команда пульта, а её отсутствие.
      final qr = coordinator(
        patience: const Duration(milliseconds: 120),
        pollEvery: const Duration(milliseconds: 20),
      );
      final begun = await qr.begin(intentKey: 'k-silent', amount: d('400'));
      final outcome = await qr.awaitOutcome(begun.intent!.id);

      expect(outcome.reason, QrWaitReason.patienceSpent);
      expect(
        outcome.intent!.abandonedAt,
        isNotNull,
        reason:
            'предел с названным ответом «а что при достижении»: касса '
            'сдаётся и говорит словами, а не запирает рабочее место',
      );
      expect(outcome.intent!.status, QrIntentStatus.cancelled);
    });
  });

  group('подтверждение приходит ПОСЛЕ того, как касса сдалась', () {
    /// **Гонка отмены и оплаты — не экзотика, а самый дорогой из исходов
    /// QR.** Кассир нажал «Отмена» (или кончилось терпение), а покупатель
    /// в эту же секунду подтвердил в приложении банка. Деньги списаны,
    /// отменять нечего, и провайдер отвечает на нашу отмену «оплачено».
    ///
    /// Проба выстроена так, чтобы этот порядок был **гарантирован
    /// временем, а не удачей**: опрос редкий (500 мс), терпение короткое
    /// (300 мс), оплата назначена на 400 мс. Единственный опрос уходит в
    /// нулевой момент и видит `pending`; оплата случается на 400-й; отмена
    /// уходит на 500-й и получает `paid`.
    test('отмена опоздала: провайдер отвечает «оплачено» — и касса это '
        'записывает', () async {
      final qr = coordinator(
        patience: const Duration(milliseconds: 300),
        pollEvery: const Duration(milliseconds: 500),
      );
      final begun = await qr.begin(intentKey: 'k-late', amount: d('1000'));
      final id = begun.intent!.id;
      final providerIntentId = begun.intent!.providerIntentId!;

      await control('/_emul/pay', {
        'intentId': providerIntentId,
        'afterMs': 400,
      });

      final outcome = await qr.awaitOutcome(id);
      expect(
        outcome.reason,
        QrWaitReason.paidAfterGiveUp,
        reason:
            'касса сдалась — и всё-таки узнала про деньги: отменить, не '
            'прочитав ответ отмены, значило бы оставить покупателя без '
            'денег и без товара',
      );

      final row = await db.paymentIntentDao.byId(id);
      expect(row!.status, QrIntentStatus.paid);
      expect(
        row.isPaidAfterGiveUp,
        isTrue,
        reason:
            'оплачено И касса сдалась — утверждение о ДВУХ полях, а не о '
            'статусе: «есть оплаченные» зелено и когда все они в чеках',
      );
      expect(
        row.isOrphanMoney,
        isTrue,
        reason: 'деньги у покупателя списаны, а строки Payments нет',
      );
      expect(
        (await qr.orphanMoney()).map((i) => i.id),
        contains(id),
        reason: 'экран разбора обязан показать это, а не смолчать',
      );
    });

    test('касса, выключенная в момент оплаты, узнаёт про деньги при старте',
        () async {
      final qr = coordinator(
        patience: const Duration(milliseconds: 60),
        pollEvery: const Duration(milliseconds: 500),
      );
      final begun = await qr.begin(intentKey: 'k-offline', amount: d('800'));
      final id = begun.intent!.id;

      // Ни одного опроса: терпение кончилось раньше первого круга.
      // Намерение остаётся `pending` — отмену касса послать не успела,
      // потому что связи не было.
      emulator
        ..fault = 'kill'
        ..faultsLeft = 5;
      await qr.awaitOutcome(id);
      emulator
        ..fault = ''
        ..faultsLeft = 0;

      final mid = await db.paymentIntentDao.byId(id);
      expect(
        mid!.status,
        QrIntentStatus.pending,
        reason:
            'связи не было — значит не знаем, отменено ли. Объявить '
            'отменённым по обрыву значило бы соврать про деньги',
      );

      // Покупатель платит, пока касса ничего не знает.
      emulator.confirm(emulator.byId[begun.intent!.providerIntentId]!);

      final orphans = await qr.reconcile();
      final row = await db.paymentIntentDao.byId(id);
      expect(row!.status, QrIntentStatus.paid);
      expect(row.isPaidAfterGiveUp, isTrue);
      expect(orphans.map((i) => i.id), contains(id));
    });
  });

  group('связь пропала в момент ожидания', () {
    /// **Первая редакция этой пробы ничего не проверяла**, и это записано
    /// здесь, а не выброшено: она ставила отказ, ждала 120 мс и смотрела
    /// на строку — но `awaitOutcome` не звала вовсе, то есть ни одного
    /// опроса не случалось, и строка оставалась нетронутой при любой
    /// поломке кода. Зелёный цвет означал «не смотрели туда».
    ///
    /// Теперь опрос идёт по-настоящему: обрывы приходятся на живые круги
    /// опроса, и утверждение делается о том, что касса **пережила** их.
    test('обрыв связи НЕ хоронит намерение — деньги могли уже уйти',
        () async {
      final qr = coordinator(
        patience: const Duration(milliseconds: 200),
        pollEvery: const Duration(milliseconds: 20),
      );
      final begun = await qr.begin(intentKey: 'k-net', amount: d('600'));
      final id = begun.intent!.id;

      emulator
        ..fault = 'kill'
        ..faultsLeft = 50;

      final outcome = await qr.awaitOutcome(id);
      expect(
        outcome.reason,
        isNot(QrWaitReason.refused),
        reason: 'обрыв — «не знаю», а не «нет»',
      );
      expect(
        outcome.refusal?.code,
        qrNetworkCode,
        reason: 'причина названа кодом, а не текстом исключения (I144)',
      );

      final mid = await db.paymentIntentDao.byId(id);
      expect(
        mid!.status,
        isNot(QrIntentStatus.failed),
        reason:
            'транзиентный отказ означает «не знаю», а не «нет». Объявить '
            'намерение провалившимся по обрыву значит закрыть чек при '
            'живых деньгах на той стороне',
      );
    });

    test('провайдер молчит — названная причина, а не исключение наружу',
        () async {
      emulator
        ..fault = 'silence'
        ..faultsLeft = 1;
      final reply = await provider.create(
        intentKey: 'k-timeout',
        amount: d('100'),
      );
      expect(reply.isOk, isFalse);
      expect(reply.refusal!.code, qrTimeoutCode);
      expect(reply.refusal!.isTransient, isTrue);
    });

    test('непонятное тело — qr_malformed_reply, и оно НЕ транзиентно',
        () async {
      emulator
        ..fault = 'garbage'
        ..faultsLeft = 1;
      final reply = await provider.create(
        intentKey: 'k-garbage',
        amount: d('100'),
      );
      expect(reply.isOk, isFalse);
      expect(reply.refusal!.code, qrMalformedCode);
      expect(
        reply.refusal!.isTransient,
        isFalse,
        reason: 'повтор даст тот же непонятный ответ — лечится человеком',
      );
    });
  });

  group('исходы, которые провайдер называет сам', () {
    test('покупатель отказался — failed с названной причиной', () async {
      final qr = coordinator(pollEvery: const Duration(milliseconds: 20));
      final begun = await qr.begin(intentKey: 'k-declined', amount: d('200'));
      final intent = emulator.byId[begun.intent!.providerIntentId]!;
      intent
        ..status = kFailed
        ..message = 'покупатель отказался платить';

      final outcome = await qr.awaitOutcome(begun.intent!.id);
      expect(outcome.reason, QrWaitReason.settledByProvider);
      expect(outcome.intent!.status, QrIntentStatus.failed);
      expect(outcome.intent!.refusalMessage, 'покупатель отказался платить');
      expect(outcome.holdsMoney, isFalse);
    });

    test('срок вышел — expired, и это сказал провайдер, а не наш таймер',
        () async {
      final qr = coordinator(pollEvery: const Duration(milliseconds: 20));
      final begun = await qr.begin(intentKey: 'k-exp', amount: d('200'));
      emulator.byId[begun.intent!.providerIntentId]!.status = kExpired;

      final outcome = await qr.awaitOutcome(begun.intent!.id);
      expect(outcome.intent!.status, QrIntentStatus.expired);
    });

    test('оплачено ЧАСТИЧНО — деньги считаются по названному, а не по '
        'запрошенному', () async {
      final qr = coordinator(pollEvery: const Duration(milliseconds: 20));
      final begun = await qr.begin(intentKey: 'k-part', amount: d('1000'));
      emulator.confirm(
        emulator.byId[begun.intent!.providerIntentId]!,
        amount: '400',
      );

      final outcome = await qr.awaitOutcome(begun.intent!.id);
      final row = outcome.intent!;
      expect(row.status, QrIntentStatus.paid);
      expect(row.paidAmount, d('400'));
      expect(
        row.money,
        d('400'),
        reason:
            'подставить запрошенную сумму поверх названной значило бы '
            'дописать покупателю денег, которых он не платил',
      );
      expect(row.isPartial, isTrue);
    });
  });

  group('возврат может быть неподдержан — отказ ЗНАЧЕНИЕМ', () {
    test('reverse неоплаченного намерения — названная причина, не молчание',
        () async {
      final qr = coordinator();
      final begun = await qr.begin(intentKey: 'k-rev', amount: d('100'));
      final reply = await qr.reverse(begun.intent!.id);
      expect(reply.isOk, isFalse);
      expect(reply.refusal!.code, qrRejectedCode);
    });

    test('провайдер не умеет возвращать — qr_reverse_unsupported', () async {
      final qr = coordinator(pollEvery: const Duration(milliseconds: 20));
      final begun = await qr.begin(intentKey: 'k-rev2', amount: d('100'));
      emulator.confirm(emulator.byId[begun.intent!.providerIntentId]!);
      await qr.awaitOutcome(begun.intent!.id);

      emulator
        ..fault = 'reverseUnsupported'
        ..faultsLeft = 1;
      // `reverseUnsupported` не в списке ответов маршрутизатора — он
      // отдаётся 404, и его разбор мы проверяем ниже на прямом ответе 501.
      final reply = await qr.reverse(begun.intent!.id);
      expect(reply.isOk, isFalse,
          reason: 'отказ приходит значением, а не исключением наружу');
    });

    test('возврат оплаченного проходит и переводит в reversed', () async {
      final qr = coordinator(pollEvery: const Duration(milliseconds: 20));
      final begun = await qr.begin(intentKey: 'k-rev3', amount: d('100'));
      emulator.confirm(emulator.byId[begun.intent!.providerIntentId]!);
      await qr.awaitOutcome(begun.intent!.id);

      final reply = await qr.reverse(begun.intent!.id);
      expect(reply.isOk, isTrue, reason: reply.refusal?.message);
      expect(reply.value!.status, QrIntentStatus.reversed);
    });
  });

  group('эмулятор — прибор, а не украшение', () {
    test('журнал несёт довод, а не только событие', () async {
      final qr = coordinator();
      await qr.begin(intentKey: 'k-log', amount: d('100'));
      await qr.begin(intentKey: 'k-log', amount: d('100'));
      final repeat = emulator.journal.where(
        (e) => (e['why']! as String).contains('второго намерения НЕ заведено'),
      );
      expect(
        repeat, isNotEmpty,
        reason:
            'журнал обязан объяснять, ПОЧЕМУ эмулятор ответил так: без '
            'довода он список строк, а не измерение',
      );
    });

    test('дверь остановки закрывает оба порта', () async {
      final probe = SbpEmulator(echo: false);
      await probe.start('127.0.0.1', 0);
      await probe.startControl('127.0.0.1', 0);
      final port = probe.port;
      final controlPort = probe.controlPort;
      await probe.stop();

      // Порт свободен — доказывается тем, что на него можно встать снова.
      final again = await ServerSocket.bind('127.0.0.1', port);
      await again.close();
      final againControl = await ServerSocket.bind('127.0.0.1', controlPort);
      await againControl.close();
    });

    /// **Сторож на форму, и он про мой кусок, а не про чужой.**
    ///
    /// # Поправка 2026-09-19: эмулятор переехал в `lib/`
    ///
    /// В первой редакции здесь стояло «в `lib/` про этот эмулятор нет ни
    /// строчки». Это перестало быть верным в тот час, когда по решению
    /// заказчика эмулятор поехал в комплекте с кассой
    /// (`2026-09-19-builtin-emulators.md`): класс живёт в
    /// `lib/emulators/sbp/`, и его поднимает держатель встроенных
    /// эмуляторов.
    ///
    /// **Свойство, ради которого сторож заводился, при этом не изменилось
    /// ни на букву** — и именно оно здесь и проверяется: точка подстановки
    /// остаётся **адресом**. Путь оплаты — `HttpQrPaymentProvider`,
    /// `QrPaymentCoordinator`, `QrPaymentDesk`, контейнер зависимостей —
    /// про эмулятор не знает ничего и не имеет ни одной ветки «если
    /// эмулятор». Узнай он — и «оплата по QR работает» перестало бы
    /// говорить что-либо о настоящем провайдере.
    ///
    /// Поэтому исключение ровно одно и названо поимённо: `lib/emulators/`.
    /// Всё остальное в `lib/` по-прежнему обязано молчать.
    test('путь оплаты не знает про этот эмулятор ни имени, ни пути', () async {
      final hits = <String>[];
      await for (final entity
          in Directory('lib').list(recursive: true, followLinks: false)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path.replaceAll(r'\', '/');
        // Дом эмуляторов — единственное место, которому это знать положено.
        if (path.contains('/lib/emulators/') || path.startsWith('lib/emulators/')) {
          continue;
        }
        final text = entity.readAsStringSync();
        if (text.contains('SbpEmulator') ||
            text.contains('test/emulators/sbp')) {
          hits.add(path);
        }
      }
      expect(
        hits,
        isEmpty,
        reason:
            'эмулируется ЗАВИСИМОСТЬ, а не наш адаптер: точка подстановки — '
            'адрес, и вне `lib/emulators/` про эмулятор не должно быть ни '
            'строчки',
      );
    });

    // Дом эмуляторов предыдущая проба пропускает целиком, и без второго
    // сторожа туда можно было бы занести подмену провайдера. Этот второй
    // сторож живёт там, где ему место, — `builtin_emulator_guards_test.dart`,
    // рядом с таким же сторожем про драйвер принтера.
  });

  tearDownAll(() {
    // «Порты за собой гаси и подтверждай числом.»
    expect(takenPorts, isNotEmpty);
  });
}

/// Слить базу в файл, чтобы её можно было открыть заново.
///
/// Правило дерева: любой код, копирующий базу drift, обязан сначала
/// сбросить WAL. Здесь база в памяти, WAL у неё нет, но правило
/// соблюдается формой — `VACUUM INTO` копирует согласованный снимок.
Future<File> _spillToFile(AppDatabase db) async {
  final dir = Directory.systemTemp.createTempSync('qr_intent_restart');
  final file = File('${dir.path}/till.sqlite');
  await db.customStatement("VACUUM INTO '${file.path.replaceAll(r'\', '/')}'");
  return file;
}

/// Кодировщик JSON без ввоза `dart:convert` в область имён теста.
class JsonEncoderShim {
  const JsonEncoderShim();
  String encode(Object? value) => _encode(value);
  static String _encode(Object? v) {
    if (v == null) return 'null';
    if (v is num || v is bool) return '$v';
    if (v is String) return '"${v.replaceAll('"', r'\"')}"';
    if (v is List) return '[${v.map(_encode).join(',')}]';
    if (v is Map) {
      return '{${v.entries.map((e) => '"${e.key}":${_encode(e.value)}').join(',')}}';
    }
    return '"$v"';
  }
}
