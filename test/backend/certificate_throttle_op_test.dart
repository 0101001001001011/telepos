/// Замок перебора сертификатов на проводе — `pay.certificate` и
/// `pay.complete` с сертификатами.
///
/// Пробы идут через **обработчики** `TillOperations`, а не через класс замка
/// напрямую: дыра была в том, что обработчик звал проверку без всякого
/// замка, и проба класса осталась бы зелёной, сними кто-нибудь вызов из
/// обработчика.
///
/// Подделка `PaymentService` здесь правильная: вопрос не «сколько на
/// бумажке», а «дошла ли N+1-я попытка до проверки». Сколько раз проверку
/// позвали, подделка считает сама.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/backend/certificate_throttle.dart';
import 'package:telepos/backend/pairing_invites.dart';
import 'package:telepos/backend/security_journal.dart';
import 'package:telepos/backend/till_operations.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/auth/auth_outcome.dart';
import 'package:telepos/domain/payment/gift_certificate.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/setup/setup_draft.dart';
import 'package:telepos/domain/setup/setup_repository.dart';
import 'package:telepos/domain/startup/app_bootstrap.dart';
import 'package:telepos/domain/terminal/device_binding.dart';
import 'package:telepos/domain/terminal/device_binding_repository.dart';
import 'package:telepos/domain/terminal/terminal.dart' as domain;
import 'package:telepos/domain/terminal/terminal_repository.dart';
import 'package:telepos/domain/wire/pay_ops.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

import 'support/noop_auth.dart';
import 'package:telepos/domain/shift/shift_status.dart';

const _selfTerminalId = 3;

/// Настоящие величины замка: пробы мерят то, что стоит на кассе.
const _perNumber = 5;
const _perCashier = 10;
const _window = Duration(minutes: 15);

AuthSession _session({required int userId, required int terminalId}) =>
    AuthSession(
      token: 'токен-$userId',
      userId: userId,
      name: 'Кассир $userId',
      role: 'cashier',
      permissions: const {},
      operatingMode: 0,
      pointMode: 'cashier',
      shift: ShiftStatus.open,
      issuedAt: DateTime(2026, 9, 13),
      expiresAt: DateTime(2026, 9, 14),
      terminalId: terminalId,
    );

Matcher _refused(String code) =>
    throwsA(isA<WireRefusal>().having((r) => r.code, 'code', code));

void main() {
  late AppDatabase db;
  late _Certificates payments;
  late PairingInvites invites;
  late DateTime now;

  TillOperations build() => TillOperations(
    db: db,
    bootstrap: _Bootstrap(),
    setup: _Setup(),
    terminals: _SelfTerminal(),
    deviceBindings: _Bindings(),
    auth: NoopAuth(),
    invites: invites,
    payments: payments,
    certificateThrottle: CertificateThrottle(clock: () => now),
  );

  final a = _session(userId: 1, terminalId: 101);
  final b = _session(userId: 2, terminalId: 102);
  const aKey = 11;
  const bKey = 12;

  Future<Map<String, Object?>> check(
    TillOperations ops,
    AuthSession session,
    int sessionKey,
    String number,
    String pin,
  ) => ops.askHandlers[PayOps.certificate.name]!(
    {'number': number, 'pin': pin},
    sessionKey,
    session,
  );

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    payments = _Certificates({'C-1': '1234', 'C-2': '5678'});
    invites = PairingInvites();
    now = DateTime(2026, 9, 13, 12);
  });
  tearDown(() => db.close());

  test('величины по умолчанию — те, что названы в докстринге замка', () {
    final t = CertificateThrottle();
    expect(
      (t.perNumber, t.perCashier, t.perTerminal, t.window),
      (_perNumber, _perCashier, _perCashier, _window),
    );
  });

  group('pay.certificate', () {
    test('N+1-я попытка отказана названной причиной и до проверки не доходит',
        () async {
      final ops = build();
      for (var i = 0; i < _perNumber; i++) {
        await expectLater(
          check(ops, a, aKey, 'C-1', '0000'),
          _refused(certificatePinWrongCode),
          reason: 'попытка ${i + 1}',
        );
      }
      expect(payments.lookups, _perNumber);

      // Верный ПИН — и всё равно отказ: пропусти касса верный ПИН сквозь
      // замок, быстрый успех и был бы ответом перебора.
      await expectLater(
        check(ops, a, aKey, 'C-1', '1234'),
        _refused(certificateRateLimitedCode),
      );
      expect(payments.lookups, _perNumber, reason: 'касса не спрошена');
    });

    test('перебор ПИНа одного номера с двух сеансов упирается в номер',
        () async {
      final ops = build();
      for (var i = 0; i < 3; i++) {
        await expectLater(
          check(ops, a, aKey, 'C-1', '0000'),
          _refused(certificatePinWrongCode),
        );
      }
      for (var i = 0; i < 2; i++) {
        await expectLater(
          check(ops, b, bKey, 'C-1', '1111'),
          _refused(certificatePinWrongCode),
        );
      }

      // У каждого сеанса порознь неудач меньше предела номера (3 и 2), и
      // меньше предела кассира (10) — запирает только общий счёт номера.
      await expectLater(
        check(ops, b, bKey, 'C-1', '1234'),
        _refused(certificateRateLimitedCode),
      );
      await expectLater(
        check(ops, a, aKey, 'C-1', '1234'),
        _refused(certificateRateLimitedCode),
      );

      // Соседний номер тем же сеансам открыт: замок номера — не замок
      // кассира.
      final other = await check(ops, a, aKey, 'C-2', '5678');
      expect(other['number'], 'C-2');
    });

    test('успех другого сеанса не сбрасывает неудачи номера', () async {
      final ops = build();
      for (var i = 0; i < _perNumber - 1; i++) {
        await expectLater(
          check(ops, a, aKey, 'C-1', '0000'),
          _refused(certificatePinWrongCode),
        );
      }

      // Настоящая бумажка у сеанса B: успех возвращает **свою** единицу.
      await check(ops, b, bKey, 'C-1', '1234');

      await expectLater(
        check(ops, a, aKey, 'C-1', '0001'),
        _refused(certificatePinWrongCode),
      );
      await expectLater(
        check(ops, b, bKey, 'C-1', '1234'),
        _refused(certificateRateLimitedCode),
        reason:
            'сбрось успех B счёт номера, A перемежал бы свои неудачи чужими '
            'успехами бесконечно',
      );
    });

    test('«нет номера» считается так же, как «не тот ПИН» — замок не оракул',
        () async {
      final ops = build();
      for (var i = 0; i < _perNumber; i++) {
        await expectLater(
          check(ops, a, aKey, 'ВЫДУМАН', '0000'),
          _refused(certificateUnknownCode),
        );
      }
      await expectLater(
        check(ops, a, aKey, 'ВЫДУМАН', '0000'),
        _refused(certificateRateLimitedCode),
      );
    });

    test('«нужен ПИН» считается подбором — пустой ПИН не бесплатная проба',
        () async {
      final ops = build();
      for (var i = 0; i < _perNumber; i++) {
        await expectLater(
          check(ops, a, aKey, 'C-1', ''),
          _refused(certificatePinRequiredCode),
          reason: 'попытка ${i + 1}',
        );
      }
      await expectLater(
        check(ops, a, aKey, 'C-1', '1234'),
        _refused(certificateRateLimitedCode),
        reason:
            'не считай замок пустой ПИН, он отличал бы настоящий номер '
            '(счёт стоит) от выдуманного (растёт)',
      );
    });

    test('перебор номеров одним кассиром упирается в кассира', () async {
      final ops = build();
      for (var i = 0; i < _perCashier; i++) {
        await expectLater(
          check(ops, a, aKey, 'N-$i', '0000'),
          _refused(certificateUnknownCode),
        );
      }
      await expectLater(
        check(ops, a, aKey, 'C-2', '5678'),
        _refused(certificateRateLimitedCode),
        reason: 'свежий номер, но кассир исчерпал окно',
      );
      // Другой кассир за другим терминалом — открыт.
      expect((await check(ops, b, bKey, 'C-2', '5678'))['number'], 'C-2');
    });

    // Два ключа ниже разведены намеренно. В пробе выше кассир сидит за одним
    // терминалом, и её же закрывал бы и ключ терминала: диверсия «снять ключ
    // кассира» оставила её зелёной (измерено 2026-09-13). Здесь каждая ось
    // остаётся одна.
    test('кассир, сменивший терминал, не получает второго окна', () async {
      final ops = build();
      final aElsewhere = _session(userId: 1, terminalId: 103);
      for (var i = 0; i < _perCashier; i++) {
        final (session, key) = i.isEven ? (a, aKey) : (aElsewhere, 13);
        await expectLater(
          check(ops, session, key, 'N-$i', '0000'),
          _refused(certificateUnknownCode),
        );
      }
      // По терминалу — по пять неудач, до предела далеко; по номеру — по
      // одной. Запирает только кассир.
      await expectLater(
        check(ops, _session(userId: 1, terminalId: 104), 14, 'C-2', '5678'),
        _refused(certificateRateLimitedCode),
      );
    });

    test('терминал, за которым меняются кассиры, не получает второго окна',
        () async {
      final ops = build();
      for (var i = 0; i < _perCashier; i++) {
        final session = _session(userId: 200 + (i % 2), terminalId: 101);
        await expectLater(
          check(ops, session, 20 + i, 'N-$i', '0000'),
          _refused(certificateUnknownCode),
        );
      }
      // У каждого кассира по пять неудач, у каждого номера — по одной.
      await expectLater(
        check(ops, _session(userId: 299, terminalId: 101), 40, 'C-2', '5678'),
        _refused(certificateRateLimitedCode),
      );
    });

    test('успешные проверки счёта не растят', () async {
      final ops = build();
      for (var i = 0; i < 3 * _perCashier; i++) {
        await check(ops, a, aKey, 'C-1', '1234');
      }
      expect(payments.lookups, 3 * _perCashier);
    });

    test('параллельный залп: до проверки доходит ровно предел номера',
        () async {
      final ops = build();
      final outcomes = await Future.wait([
        for (var i = 0; i < 40; i++)
          check(ops, _session(userId: 100 + i, terminalId: 500 + i), 900 + i,
                  'C-1', 'x$i')
              .then<String>((_) => 'ok')
              .catchError((Object e) => (e as WireRefusal).code),
      ]);
      expect(payments.lookups, _perNumber);
      expect(
        outcomes.where((c) => c == certificateRateLimitedCode).length,
        40 - _perNumber,
      );
    });

    test('замок снимается окном после последней неудачи, не раньше', () async {
      final ops = build();
      for (var i = 0; i < _perNumber; i++) {
        await expectLater(
          check(ops, a, aKey, 'C-1', '0000'),
          _refused(certificatePinWrongCode),
        );
      }
      now = now.add(_window - const Duration(seconds: 1));
      await expectLater(
        check(ops, a, aKey, 'C-1', '1234'),
        _refused(certificateRateLimitedCode),
      );
      now = now.add(const Duration(seconds: 1));
      expect((await check(ops, a, aKey, 'C-1', '1234'))['number'], 'C-1');
    });
  });

  // Пункт 4 A7 (2026-09-15): срабатывание замка не оставляло следа в журнале
  // безопасности (живая приёмка 2026-09-13). Настоящий `SecurityJournal` над
  // той же базой — улика читается тем же `SecurityEventDao.findAll`, что у
  // двери стенда `stand/security-events`.
  group('журнал безопасности', () {
    Future<List<SecurityEvent>> events() async {
      // Запись уходит `unawaited` — операция не ждёт улики.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return [
        for (final e in await db.securityEventDao.findAll())
          if (e.eventType == SecurityEventType.certificateRateLimited) e,
      ];
    }

    TillOperations journaled() => TillOperations(
      db: db,
      bootstrap: _Bootstrap(),
      setup: _Setup(),
      terminals: _SelfTerminal(),
      deviceBindings: _Bindings(),
      auth: NoopAuth(),
      invites: invites,
      payments: payments,
      certificateThrottle: CertificateThrottle(
        clock: () => now,
        onLocked: certificateLockJournalHandler(
          SecurityJournal(db.securityEventDao),
        ),
      ),
    );

    test('срабатывание пишется одной записью на запирание, а не на стук',
        () async {
      final ops = journaled();
      for (var i = 0; i < _perNumber; i++) {
        await expectLater(
          check(ops, a, aKey, 'C-1', '0000'),
          _refused(certificatePinWrongCode),
        );
      }
      expect(await events(), isEmpty, reason: 'неудачи — ещё не замок');

      for (var i = 0; i < 3; i++) {
        await expectLater(
          check(ops, a, aKey, 'C-1', '1234'),
          _refused(certificateRateLimitedCode),
        );
      }
      final written = await events();
      expect(written, hasLength(1), reason: 'стук в запертое базу не растит');
      expect(written.single.userId, a.userId);
      expect(written.single.terminalId, a.terminalId);
      expect(written.single.outcome, startsWith(certificateRateLimitedCode));
    });

    test('новое запирание после окна — новая запись', () async {
      final ops = journaled();
      for (var round = 0; round < 2; round++) {
        for (var i = 0; i < _perNumber; i++) {
          await expectLater(
            check(ops, a, aKey, 'C-1', '0000'),
            _refused(certificatePinWrongCode),
          );
        }
        await expectLater(
          check(ops, a, aKey, 'C-1', '1234'),
          _refused(certificateRateLimitedCode),
        );
        now = now.add(_window);
      }
      expect(await events(), hasLength(2));
    });
  });

  group('pay.complete', () {
    Future<void> bind(TillOperations ops, int sessionKey) async {
      await ops.askHandlers[TillOps.terminalRegister.name]!({
        'name': 'Вкладка',
        'code': invites.mint().code,
      }, sessionKey);
    }

    Map<String, Object?> payBody(String number, String pin) => {
      'type': 'cash',
      'cashReceived': '1000',
      'certificates': [
        {'number': number, 'pin': pin},
      ],
      'key': 'k1',
      'baseVersion': 1,
      'receiptNo': 9,
    };

    test('сертификат в заявке — под тем же замком, что и вопрос', () async {
      final ops = build();
      await bind(ops, aKey);
      for (var i = 0; i < _perNumber; i++) {
        await expectLater(
          ops.askHandlers[PayOps.complete.name]!(
            payBody('C-1', '0000'),
            aKey,
            a,
          ),
          _refused(certificatePinWrongCode),
        );
      }
      // Замок, накрученный оплатой, запирает и вопрос — и наоборот.
      await expectLater(
        check(ops, b, bKey, 'C-1', '1234'),
        _refused(certificateRateLimitedCode),
      );
      await expectLater(
        ops.askHandlers[PayOps.complete.name]!(payBody('C-1', '1234'), aKey, a),
        _refused(certificateRateLimitedCode),
      );
      expect(payments.completed, _perNumber, reason: 'оплата не позвана');
    });

    // Пункт 6 A7 (2026-09-15): неудача одного номера засчитывалась всем
    // номерам заявки. Кассир, у которого покупатель принёс две бумажки и
    // одна не подошла, пятью повторами запирал и честную вторую.
    test('неудача одного номера в заявке не засчитывается другим номерам',
        () async {
      final ops = build();
      await bind(ops, aKey);
      for (var i = 0; i < _perNumber; i++) {
        await expectLater(
          ops.askHandlers[PayOps.complete.name]!(
            {
              ...payBody('C-1', '1234'),
              'certificates': [
                {'number': 'C-1', 'pin': '1234'},
                {'number': 'C-2', 'pin': '0000'},
              ],
            },
            aKey,
            a,
          ),
          _refused(certificatePinWrongCode),
          reason: 'попытка ${i + 1}',
        );
      }
      // Не тот номер — заперт.
      await expectLater(
        check(ops, b, bKey, 'C-2', '5678'),
        _refused(certificateRateLimitedCode),
      );
      // Честная бумажка той же заявки — нет: другой сеанс её проверяет.
      expect((await check(ops, b, bKey, 'C-1', '1234'))['number'], 'C-1');
    });

    test('номер, до которого проверка не дошла, неудачи не получает',
        () async {
      final ops = build();
      await bind(ops, aKey);
      for (var i = 0; i < _perNumber; i++) {
        await expectLater(
          ops.askHandlers[PayOps.complete.name]!(
            {
              ...payBody('C-1', '0000'),
              'certificates': [
                {'number': 'C-1', 'pin': '0000'},
                {'number': 'C-2', 'pin': '5678'},
              ],
            },
            aKey,
            a,
          ),
          _refused(certificatePinWrongCode),
        );
      }
      expect((await check(ops, b, bKey, 'C-2', '5678'))['number'], 'C-2');
    });

    test('заявка без сертификатов замка не касается', () async {
      final ops = build();
      await bind(ops, aKey);
      for (var i = 0; i < _perCashier; i++) {
        await expectLater(
          check(ops, a, aKey, 'N-$i', '0000'),
          _refused(certificateUnknownCode),
        );
      }
      final body = await ops.askHandlers[PayOps.complete.name]!({
        'type': 'cash',
        'cashReceived': '1000',
        'key': 'k2',
        'baseVersion': 1,
        'receiptNo': 9,
      }, aKey, a);
      expect(saleOutcomeFromWireJson(body).receiptNo, 9);
    });
  });
}

/// Тираж на два номера. Проверка асинхронна по-настоящему — иначе залп
/// параллельных попыток отрабатывал бы по одной и параллельности не мерил.
class _Certificates implements PaymentService {
  _Certificates(this._pins);

  final Map<String, String> _pins;
  int lookups = 0;
  int completed = 0;

  Future<GiftCertificate> _lookup(String number, String? pin) async {
    lookups++;
    await Future<void>.delayed(Duration.zero);
    final expected = _pins[number];
    // `subject` — как у `LocalCertificateIssuer.lookup`: по нему замок знает,
    // какой номер заявки не подошёл.
    if (expected == null) {
      throw WireRefusal(certificateUnknownCode, 'нет $number', subject: number);
    }
    if (pin == null || pin.isEmpty) {
      throw WireRefusal(certificatePinRequiredCode, 'нужен ПИН', subject: number);
    }
    if (pin != expected) {
      throw WireRefusal(certificatePinWrongCode, 'не тот ПИН', subject: number);
    }
    return GiftCertificate(
      id: 1,
      number: number,
      nominal: Decimal.parse('5000'),
      balance: Decimal.parse('1200'),
      status: CertificateStatus.active,
      issuedAt: 1000,
      liabilityAccountId: 21,
    );
  }

  @override
  Future<GiftCertificate> findCertificate(String number, {String? pin}) =>
      _lookup(number, pin);

  @override
  Future<SaleOutcome> complete(
    int terminalId,
    PaymentRequest request,
    CartCommandMeta meta,
  ) async {
    completed++;
    for (final c in request.certificates) {
      await _lookup(c.number, c.pin);
    }
    return SaleOutcome(
      receiptNo: meta.receiptNo ?? 0,
      posId: 1,
      amount: Decimal.parse('1990'),
      change: Decimal.zero,
      paid: Decimal.parse('1990'),
      debt: Decimal.zero,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
  Future<TerminalEnrollment> register({
    required String name,
    String code = '',
  }) async => (terminal: await self(), secret: 'секрет');

  @override
  Future<domain.Terminal> self() async => const domain.Terminal(
    id: _selfTerminalId,
    name: 'Касса',
    pointMode: domain.PointMode.cashier,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Bindings implements DeviceBindingRepository {
  @override
  Future<List<DeviceBinding>> forTerminal(int terminalId) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
