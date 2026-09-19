/// Обработчики пяти денежных операций оплаты — задача 14.
///
/// Здесь проверяется **шов**, а не деньги: деньги проверены на настоящей
/// базе (`test/data/sale/local_payment_service_test.dart`), а шов
/// отвечает на три вопроса, которых там нет вовсе:
///
/// - откуда касса берёт имя рабочего места (из сеанса — и только из
///   него);
/// - что происходит, когда принимать деньги нечем;
/// - что происходит, когда деньги в кадре пришли не строкой.
///
/// Подделка [PaymentService] здесь **правильная**: вопрос не «сколько
/// сдачи», а «с каким рабочим местом её позвали». Настоящая реализация
/// доказывала бы то же самое дороже и заодно уводила бы разбор в сторону.
library;

import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:telepos/domain/payment/gift_certificate.dart';
import 'package:telepos/domain/payment/prepayment_intake.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/backend/till_operations.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/setup/setup_draft.dart';
import 'package:telepos/domain/setup/setup_repository.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';
import 'package:telepos/domain/terminal/device_binding.dart';
import 'package:telepos/domain/terminal/device_binding_repository.dart';
import 'package:telepos/domain/terminal/terminal.dart' as domain;
import 'package:telepos/backend/pairing_invites.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/wire/pay_ops.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

import 'support/noop_auth.dart';

const _sessionKey = 42;
const _selfTerminalId = 3;

void main() {
  late AppDatabase db;
  late _RecordingPayments payments;
  late PairingInvites invites;

  TillOperations build({bool withPayments = true}) => TillOperations(
    db: db,
    bootstrap: _Bootstrap(),
    setup: _Setup(),
    terminals: _SelfTerminal(),
    deviceBindings: _Bindings(),
    auth: NoopAuth(),
    invites: invites,
    payments: withPayments ? payments : null,
  );

  /// Привязать сеанс к терминалу тем же путём, каким это делает браузер:
  /// `terminals.register` с одноразовым кодом привязки. Это **единственный**
  /// обработчик, наполняющий `_sessionTerminals`, вместе с
  /// `terminals.resume`; `terminals.selfEnsure` им быть перестал (задача 19,
  /// круг правки 4 — разбор у самого обработчика).
  Future<void> bindSession(TillOperations ops) async {
    await ops.askHandlers[TillOps.terminalRegister.name]!({
      'name': 'Вкладка',
      'code': invites.mint().code,
    }, _sessionKey);
  }

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    payments = _RecordingPayments();
    invites = PairingInvites();
  });
  tearDown(() => db.close());

  group('имя рабочего места берётся из сеанса', () {
    test('pay.complete зовёт сервис с терминалом сеанса', () async {
      final ops = build();
      await bindSession(ops);

      final body = await ops.askHandlers[PayOps.complete.name]!({
        'type': 'cash',
        'cashReceived': '1000',
        'key': 'k9',
        'baseVersion': 3,
        'receiptNo': 9,
      }, _sessionKey);

      expect(payments.completedFor, _selfTerminalId);
      expect(payments.completedMeta?.key, 'k9');
      expect(payments.completedMeta?.receiptNo, 9);
      expect(payments.completedRequest?.cashReceived, Decimal.parse('1000'));
      expect(saleOutcomeFromWireJson(body).change, Decimal.parse('3010'));
    });

    /// **Восьмой случай правки, закрытой кодом без пробы** — и он был
    /// мой (круг правки 2). Владение `pay.troubles` проверялось только на
    /// стороне сервиса: замена `_payTerminal(sessionId, body)` в
    /// обработчике на чтение `terminalId` из тела — ровно та подмена,
    /// ради которой правка делалась, — оставляла `test/backend/
    /// test/web/ test/domain/wire/` зелёными (+486).
    ///
    /// Беда чека отдаётся **владельцу**, и разрушающим чтением
    /// (докстринг `PaymentService.hardwareTroubles`): чужой сеанс с
    /// `nav.sale` иначе не просто прочитал бы чужую беду, а съел бы её,
    /// а номера чеков последовательны по кассе.
    test('pay.troubles зовёт сервис с терминалом сеанса', () async {
      final ops = build();
      await bindSession(ops);
      payments.troubles = const [
        CompletionTrouble(
          kind: CompletionTroubleKind.print,
          receiptNo: 9,
          message: 'бумаги нет',
        ),
      ];

      final body = await ops.askHandlers[PayOps.troubles.name]!({
        'receiptNo': 9,
      }, _sessionKey);

      expect(payments.troublesFor, _selfTerminalId);
      final back = troublesFromWireJson(body);
      expect(back.single.kind, CompletionTroubleKind.print);
      expect(back.single.message, 'бумаги нет');
    });

    test('pay.card зовёт сервис с терминалом сеанса', () async {
      final ops = build();
      await bindSession(ops);

      await ops.askHandlers[PayOps.card.name]!({
        'amount': '500',
        'key': 'k9',
        'baseVersion': 3,
        'receiptNo': 9,
      }, _sessionKey);

      expect(payments.chargedFor, _selfTerminalId);
    });

    test(
      'названное в теле имя — отказ, а не молчаливое игнорирование',
      () async {
        // Решение заказчика (круг правки 5 задачи 7, докстринг
        // `CartService`): кадр с названным именем рабочего места — либо
        // ошибка клиента, либо попытка, и молчаливое игнорирование прячет
        // обе. Первая всплыла бы как необъяснимое «команды уходят не туда»,
        // вторая не всплыла бы вовсе.
        //
        // **Код отказа сменился при слиянии, и правило от этого только
        // строже.** Задача 14 сторожила запрет собственным `_payTerminal`:
        // он сверял ключ строкой `terminalId` и отвечал `bad_request`.
        // Задача 10 к тому времени уже измерила, что такой сверки мало —
        // `terminal_id`, `TerminalId`, `terminalID` и имя во вложенном
        // объекте проходили молча, — и завела общий запрет на всю карту
        // продажи (`_refusingTerminalInBody`) с кодом `terminal_in_body`,
        // у которого есть перевод для кассира. Две проверки одного правила
        // под разными именами оставлять нельзя; пять денежных операций
        // теперь под общим запретом, и проба утверждает про него.
        final ops = build();
        await bindSession(ops);

        // **Каталог разбивается целиком, а не перечисляется наполовину**
        // (круг правки 4).
        //
        // Круг правки 3 завёл здесь `PayOps.all.where(...)` по множеству
        // из трёх имён и счёл это «по каталогу». Померено разбором: это
        // по-прежнему список руками, и он ловит **сжатие** каталога
        // (имя пропало — `hasLength(3)` краснеет), а дефект, его
        // породивший, был **ростом**: седьмая операция с чтением места
        // из тела оставляла `pay_operations_test` и `pay_ops_access_test`
        // зелёными (+22).
        //
        // Поэтому здесь названы **обе** половины, и их объединение
        // сверяется с каталогом. Новому имени спрятаться негде: пока его
        // не отнесли к одной из половин, красным будет [_partitionCovers],
        // а отнесённое к владеющим сразу попадает под цикл ниже.
        // `pay.qrStart`, `pay.qrPoll`, `pay.qrCancel` — во владеющих:
        // намерение принадлежит рабочему месту, которое показало код, и
        // чужая вкладка не опросит, не отменит и не закроет им свой чек.
        const owningNames = {
          'pay.complete',
          'pay.card',
          'pay.troubles',
          'pay.qrStart',
          'pay.qrPoll',
          'pay.qrCancel',
        };
        // `pay.sellsInDebt` (задача 16 плана «Полнота продажи») — в
        // невладеющих: тумблер «продажа в кредит» принадлежит **кассе**,
        // а не рабочему месту, и довода у операции нет вовсе. Отнести её
        // к владеющим значило бы утверждать, что кредит бывает разный на
        // соседних терминалах одной кассы, — такого свойства нет.
        // `pay.certificateIssue` (задача 21) — в невладеющих: выпуск
        // берёт обязательство на **кассу**, а не на рабочее место, и
        // довода `terminalId` у операции нет вовсе. Отнести её к
        // владеющим значило бы утверждать, что обязательства магазина
        // бывают разные на соседних терминалах одной кассы.
        // `pay.prepayment` и `pay.certificate` (вход в аванс и сертификат)
        // — в невладеющих: сальдо покупателя и тираж бумажек **одни на
        // кассу**, и довода `terminalId` у операций нет вовсе. Отнести их к
        // владеющим значило бы утверждать, что аванс покупателя разный на
        // соседних терминалах одной кассы.
        // `pay.qrReadiness` (2026-09-15) — в невладеющих: вид оплаты и
        // провайдер QR — настройка **кассы**, довода `terminalId` у
        // операции нет вовсе.
        const notOwningNames = {
          'pay.qrReadiness',
          'pay.accounts',
          'pay.sellsInDebt',
          'pay.loyalty',
          'pay.bonus',
          'pay.prepayment',
          'pay.certificate',
          'pay.certificateIssue',
          // Приём аванса — требование заказчика 2026-09-18. Рабочего места
          // не читает и не называет по той же причине, что соседняя
          // `pay.prepayment`: сальдо покупателя одно на кассу, и взнос не
          // принадлежит ни одной вкладке.
          'pay.prepaymentIntake',
          // Выдача аванса (2026-09-18) — там же и по тому же доводу: это
          // зеркало приёма, и счёт у него тот же самый. Отнести её к
          // владеющим значило бы утверждать, что аванс покупателя разный на
          // соседних терминалах одной кассы.
          'pay.prepaymentRefund',
          // Повтор печати слипа (2026-09-18) — в невладеющих: тираж бумажек
          // один на кассу, как у соседней `pay.certificate`, а печатает та
          // касса, к которой подключён принтер. Довода `terminalId` у
          // операции нет вовсе.
          'pay.certificateSlip',
        };
        _partitionCovers(owningNames, notOwningNames);

        final owning = PayOps.all.where((op) => owningNames.contains(op.name));

        for (final op in owning) {
          await expectLater(
            ops.askHandlers[op.name]!({
              'terminalId': 99,
              'type': 'cash',
              'amount': '500',
              'key': 'k9',
              'baseVersion': 3,
              'receiptNo': 9,
            }, _sessionKey),
            throwsA(
              isA<WireRefusal>().having(
                (r) => r.code,
                'code',
                'terminal_in_body',
              ),
            ),
            reason: op.name,
          );
        }

        // Написание, которое прежний `_payTerminal` пропускал молча:
        // общий запрет ищет имя по написанию и на любой глубине.
        for (final body in const [
          {'terminal_id': 99, 'type': 'cash', 'amount': '500'},
          {'TerminalID': 99, 'type': 'cash', 'amount': '500'},
          {
            'meta': {'terminalId': 99},
            'type': 'cash',
            'amount': '500',
          },
        ]) {
          await expectLater(
            ops.askHandlers[PayOps.complete.name]!(body, _sessionKey),
            throwsA(
              isA<WireRefusal>().having(
                (r) => r.code,
                'code',
                'terminal_in_body',
              ),
            ),
            reason: '$body',
          );
        }
        expect(payments.completedFor, isNull);
        expect(payments.chargedFor, isNull);
        expect(payments.troublesFor, isNull);
      },
    );

    test('сеанс без терминала — названный отказ, а не подстановка', () async {
      // Ноль или «терминал самой кассы» здесь были бы худшим исходом: оба
      // — настоящие номера, запрос с ними не падает, а находит чужой чек.
      final ops = build();

      await expectLater(
        ops.askHandlers[PayOps.complete.name]!({
          'type': 'cash',
          'key': 'k9',
          'baseVersion': 3,
          'receiptNo': 9,
        }, _sessionKey),
        throwsA(
          isA<WireRefusal>().having((r) => r.code, 'code', 'unknown_terminal'),
        ),
      );
      expect(payments.completedFor, isNull);
    });
  });

  group('вход в аванс и сертификат', () {
    test('pay.prepayment спрашивает кассу о названном покупателе', () async {
      final ops = build();
      await bindSession(ops);

      final body = await ops.askHandlers[PayOps.prepayment.name]!({
        'customerId': 5,
      }, _sessionKey);

      expect(payments.prepaymentFor, 5);
      expect(body['amount'], '700');
    });

    test('pay.certificate отдаёт остаток и не отдаёт хэш ПИНа', () async {
      final ops = build();
      await bindSession(ops);

      final body = await ops.askHandlers[PayOps.certificate.name]!({
        'number': 'C-1',
        'pin': '1234',
      }, _sessionKey);

      expect(payments.certificateAsked, (number: 'C-1', pin: '1234'));
      expect(body['balance'], '1200');
      expect(body.values, isNot(contains('pbkdf2:секрет-кассы')));
    });

    test('pay.prepayment без покупателя — bad_request, касса не спрошена',
        () async {
      final ops = build();
      await bindSession(ops);

      await expectLater(
        ops.askHandlers[PayOps.prepayment.name]!(const {}, _sessionKey),
        throwsA(
          isA<WireRefusal>().having((r) => r.code, 'code', 'bad_request'),
        ),
      );
      expect(payments.prepaymentFor, isNull);
    });
  });

  group('касса, которая не умеет принимать деньги', () {
    test('все операции каталога отказывают названной причиной', () async {
      // Голый процесс `bin/telepos_backend.dart` не строит ни подготовку
      // чека, ни `SaleUseCase`. Пустой ответ, похожий на успех, был бы
      // здесь худшим из возможного.
      final ops = build(withPayments: false);
      await bindSession(ops);

      // Задача 21: у выпуска сертификата **своя** зависимость и своя
      // причина. Слить их в одно слово было бы подлогом того же рода, что
      // «чек уже оплачен» о чеке без строк оплаты: касса, умеющая брать
      // деньги и не умеющая выпускать обязательства, — законная сборка, и
      // сказать о ней «принять деньги нечем» значит отправить владельца
      // чинить не то. Карта ведётся **поимённо**, а не умолчанием: новая
      // операция без записи здесь красит сторожа в день добавления.
      const causeOf = <String, String>{
        'pay.certificateIssue': 'certificates_unavailable',
        // Приём аванса живёт не на `PaymentService`, а на своём контракте
        // (`PrepaymentIntakeService`, под которым на кассе стоит тот же
        // `CustomerPaymentUseCase`, что и под кассовым диалогом), — значит
        // и отказывает своим словом. Общее `payments_unavailable` здесь
        // соврало бы про то, чего кассе не хватает.
        'pay.prepaymentIntake': prepaymentIntakeUnavailableCode,
        // Выдача аванса — на своём контракте (`PrepaymentRefundService`, под
        // которым на кассе стоит тот же `CustomerPaymentUseCase`), и потому
        // своё слово. Сказать «принять деньги нечем» о кассе, которой нечем
        // их **выдать**, значит отправить владельца чинить не то.
        'pay.prepaymentRefund': prepaymentRefundUnavailableCode,
        // Повтор печати слипа зависит от очереди печати и от узла
        // сертификатов, а не от раскладки оплаты. Код — существующий
        // `certificates_unavailable`: беда та же, что у выпуска («в этой
        // сборке сертификатов нет вовсе»), и второе слово на неё дало бы
        // кассиру два разных текста об одном.
        'pay.certificateSlip': 'certificates_unavailable',
      };

      for (final op in PayOps.all) {
        await expectLater(
          ops.askHandlers[op.name]!({
            'phone': '77015550000',
            'customerId': 5,
            'amount': '100',
            'nominal': '100',
            'number': 'C-1',
            'type': 'cash',
            'key': 'k9',
            'baseVersion': 3,
            'receiptNo': 9,
          }, _sessionKey),
          throwsA(
            isA<WireRefusal>().having(
              (r) => r.code,
              'code',
              causeOf[op.name] ?? 'payments_unavailable',
            ),
          ),
          reason: op.name,
        );
      }
    });
  });

  group('деньги в кадре — строкой', () {
    test('число вместо строки — названный отказ', () async {
      // I159 действует на входе, а не только на выходе: `Decimal.parse`
      // упал бы здесь чужим исключением, и до терминала доехало бы одно
      // имя типа (`safeErrorText`).
      final ops = build();
      await bindSession(ops);

      for (final body in const [
        {'customerId': 5, 'amount': 100},
        {'customerId': 5, 'amount': 'сто'},
        {'customerId': 5},
      ]) {
        await expectLater(
          ops.askHandlers[PayOps.bonus.name]!(body, _sessionKey),
          throwsA(
            isA<WireRefusal>().having((r) => r.code, 'code', 'bad_request'),
          ),
          reason: '$body',
        );
      }
    });

    test('строка проходит и доезжает до сервиса без потери разрядов', () async {
      final ops = build();
      await bindSession(ops);

      final body = await ops.askHandlers[PayOps.bonus.name]!({
        'customerId': 5,
        'amount': '120.125',
      }, _sessionKey);

      expect(payments.reservedAmount, Decimal.parse('120.125'));
      expect(body['amount'], '120.125');
    });
  });

  group('счета и лояльность', () {
    test('счета доезжают тем же составом', () async {
      final ops = build();
      final body = await ops.askHandlers[PayOps.accounts.name]!(const {});

      final decoded = accountsFromWireJson(body);
      expect(decoded.map((a) => a.id), [11, 12]);
      expect(decoded.first.isDefault, isTrue);
    });

    test('клиента нет — ответ, а не отказ', () async {
      final ops = build();
      payments.loyalty = null;

      final body = await ops.askHandlers[PayOps.loyalty.name]!(const {
        'phone': '77019999999',
      });

      expect(loyaltyFromWireJson(body), isNull);
    });
  });
}

class _RecordingPayments implements PaymentService {
  @override
  Future<String?> qrUnavailableReason() async => null;

  /// Кого спросили об авансе и о какой бумажке — вход в зачёты.
  int? prepaymentFor;
  ({String number, String? pin})? certificateAsked;

  @override
  Future<Decimal> prepaymentBalance(int customerId) async {
    prepaymentFor = customerId;
    return Decimal.parse('700');
  }

  @override
  Future<GiftCertificate> findCertificate(String number, {String? pin}) async {
    certificateAsked = (number: number, pin: pin);
    return GiftCertificate(
      id: 3,
      number: number,
      nominal: Decimal.parse('5000'),
      balance: Decimal.parse('1200'),
      status: CertificateStatus.active,
      issuedAt: 1000,
      pinHash: 'pbkdf2:секрет-кассы',
      liabilityAccountId: 21,
    );
  }

  /// Кто и о чём спрашивал QR — вход в оплату по QR.
  int? qrFor;
  String? qrKeyAsked;

  QrTender _tender(String key, QrTenderPhase phase) => QrTender(
    intentKey: key,
    phase: phase,
    amount: Decimal.parse('500'),
    qrPayload: phase == QrTenderPhase.waiting ? 'https://pay/q' : null,
  );

  @override
  Future<QrTender> startQr(
    int terminalId,
    Decimal amount,
    CartCommandMeta meta,
  ) async {
    qrFor = terminalId;
    return _tender('qr-${meta.key}', QrTenderPhase.waiting);
  }

  @override
  Future<QrTender> pollQr(int terminalId, String intentKey) async {
    qrFor = terminalId;
    qrKeyAsked = intentKey;
    return _tender(intentKey, QrTenderPhase.paid);
  }

  @override
  Future<QrTender> cancelQr(int terminalId, String intentKey) async {
    qrFor = terminalId;
    qrKeyAsked = intentKey;
    return _tender(intentKey, QrTenderPhase.cashierCancelled);
  }

  int? completedFor;
  int? chargedFor;

  /// Кого спросили про беды железа — задача 16, круг правки 3.
  int? troublesFor;
  List<CompletionTrouble> troubles = const [];
  Decimal? reservedAmount;
  PaymentRequest? completedRequest;
  CartCommandMeta? completedMeta;

  LoyaltyCustomer? loyalty = LoyaltyCustomer(
    id: 5,
    phone: '77015550000',
    name: 'Айгуль',
    bonusBalance: Decimal.parse('340'),
  );

  @override
  Future<List<PaymentAccount>> accounts() async => const [
    PaymentAccount(id: 11, name: 'Касса', isDefault: true),
    PaymentAccount(id: 12, name: 'Банк'),
  ];

  /// Тумблер кассы «продажа в кредит» — задача 16. Здесь включён: пробы
  /// этого файла про кадр и его разбор, а не про настройку кассы.
  @override
  Future<bool> sellsInDebt() async => true;

  @override
  Future<LoyaltyCustomer?> findLoyalty(String phone) async => loyalty;

  @override
  Future<Decimal> reserveBonus(int customerId, Decimal amount) async {
    reservedAmount = amount;
    return amount;
  }

  @override
  Future<CardCharge> chargeCard(
    int terminalId,
    Decimal amount,
    CartCommandMeta meta,
  ) async {
    chargedFor = terminalId;
    return CardCharge(outcome: CardChargeOutcome.approved, amount: amount);
  }

  @override
  Future<SaleOutcome> complete(
    int terminalId,
    PaymentRequest request,
    CartCommandMeta meta,
  ) async {
    completedFor = terminalId;
    completedRequest = request;
    completedMeta = meta;
    return SaleOutcome(
      receiptNo: meta.receiptNo ?? 0,
      posId: 1,
      amount: Decimal.parse('1990'),
      change: Decimal.parse('3010'),
      paid: Decimal.parse('1990'),
      debt: Decimal.zero,
    );
  }

  @override
  Future<List<CompletionTrouble>> hardwareTroubles(
    int terminalId,
    int receiptNo,
  ) async {
    troublesFor = terminalId;
    return troubles;
  }
}

class _Bootstrap implements AppBootstrap {
  @override
  Future<AppInitStatus> start({required BootProgress onProgress}) async =>
      AppInitStatus.success;
}

class _Setup implements SetupRepository {
  @override
  Future<void> completeSetup(SetupDraft draft) async {}
}

class _SelfTerminal implements TerminalRepository {
  @override
  Future<List<domain.Terminal>> list() async => const [];

  @override
  Stream<List<domain.Terminal>> watchAll() async* {
    yield const [];
    await Completer<void>().future;
  }

  @override
  Stream<domain.Terminal?> watchSelf() async* {
    yield null;
    await Completer<void>().future;
  }

  /// Регистрация заведена при слиянии: задача 19 вырезала запись в
  /// `_sessionTerminals` из `terminals.selfEnsure` (она открывала строку
  /// самой кассы любой сессии), и настоящий путь вкладки браузера —
  /// `terminals.register` с одноразовым кодом.
  @override
  Future<TerminalEnrollment> register({
    required String name,
    String code = '',
  }) async => (terminal: await self(), secret: 'секрет');

  @override
  Future<domain.Terminal> resume({
    required int terminalId,
    required String secret,
  }) => throw UnimplementedError();

  @override
  Future<void> rename(int terminalId, String name) async {}

  @override
  Future<void> setAllowedPaymentTypes(
    int terminalId,
    Set<PaymentType> types,
  ) async {}

  @override
  Future<void> delete(int terminalId) async {}

  @override
  Future<domain.Terminal> self() async => const domain.Terminal(
    id: _selfTerminalId,
    name: 'Касса',
    pointMode: domain.PointMode.cashier,
  );
}

class _Bindings implements DeviceBindingRepository {
  @override
  Future<List<DeviceBinding>> forTerminal(int terminalId) async => const [];

  @override
  Stream<List<DeviceBinding>> watchForTerminal(int terminalId) async* {
    yield const [];
    await Completer<void>().future;
  }

  @override
  Future<void> save(int terminalId, DeviceBinding binding) async {}
}

/// Обе половины каталога вместе — это **весь** каталог.
///
/// Заведено кругом правки 4 задачи 16: сторож, перечисляющий только
/// интересную половину, ловит исчезновение имени и не ловит появление
/// нового. Разбор это и померил — седьмая операция с чтением рабочего
/// места из тела прошла мимо обеих проб.
void _partitionCovers(Set<String> owning, Set<String> notOwning) {
  final catalogue = PayOps.all.map((op) => op.name).toSet();
  final classified = {...owning, ...notOwning};

  expect(
    owning.intersection(notOwning),
    isEmpty,
    reason: 'операция не может и владеть, и не владеть',
  );
  expect(
    catalogue.difference(classified),
    isEmpty,
    reason:
        'новая операция оплаты не отнесена ни к владеющим рабочим местом, '
        'ни к невладеющим — пока это не сделано, сторож её не проверяет',
  );
  expect(
    classified.difference(catalogue),
    isEmpty,
    reason:
        'имя из списка каталогу неизвестно — операция ушла или переименована',
  );
}
