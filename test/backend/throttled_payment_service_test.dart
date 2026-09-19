/// Замок перебора сертификатов на кассе мимо провода — пункт 5 A7.
///
/// Три утверждения, и каждое закрывает свою половину:
///
/// 1. С самой кассы (`ThrottledPaymentService`) N+1-я неудачная проверка
///    отказана и до проверки не доходит — раньше касса не ограничивала
///    перебор вовсе.
/// 2. Счёт номера у кассы и у провода **один**: три неудачи с планшета и две
///    с кассы запирают номер для обоих.
/// 3. Провод поверх той же обёртки не считает попытку дважды — `main.dart`
///    отдаёт `ApiServer` именно зарегистрированный `PaymentService`, то есть
///    обёртку, и без защиты от вложенного допуска предел номера на проводе
///    сжался бы до трёх.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/backend/certificate_throttle.dart';
import 'package:telepos/backend/pairing_invites.dart';
import 'package:telepos/backend/security_journal.dart';
import 'package:telepos/backend/throttled_payment_service.dart';
import 'package:telepos/backend/till_operations.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/auth/auth_outcome.dart';
import 'package:telepos/domain/auth/cashier_on_duty.dart';
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
import 'package:telepos/domain/wire/wire_refusal.dart';

import 'support/noop_auth.dart';
import 'package:telepos/domain/shift/shift_status.dart';

const _perNumber = 5;

Matcher _refused(String code) =>
    throwsA(isA<WireRefusal>().having((r) => r.code, 'code', code));

AuthSession _session() => AuthSession(
  token: 'токен',
  userId: 7,
  name: 'Кассир',
  role: 'cashier',
  permissions: const {},
  operatingMode: 0,
  pointMode: 'cashier',
  shift: ShiftStatus.open,
  issuedAt: DateTime(2026, 9, 15),
  expiresAt: DateTime(2026, 9, 16),
  terminalId: 101,
);

const _cashierA = 7;
const _cashierB = 8;
const _perCashier = 10;

void main() {
  late AppDatabase db;
  late _Paper inner;
  late CertificateThrottle throttle;
  late CashierOnDutyHolder cashier;
  late List<CertificateLock> locks;
  late ThrottledPaymentService desk;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    inner = _Paper();
    locks = [];
    throttle = CertificateThrottle(onLocked: locks.add);
    cashier = CashierOnDutyHolder()..signIn(_cashierA);
    desk = ThrottledPaymentService(
      inner,
      throttle: throttle,
      cashier: cashier,
    );
  });
  tearDown(() => db.close());

  TillOperations wire(PaymentService payments) => TillOperations(
    db: db,
    bootstrap: _Bootstrap(),
    setup: _Setup(),
    terminals: _SelfTerminal(),
    deviceBindings: _Bindings(),
    auth: NoopAuth(),
    invites: PairingInvites(),
    payments: payments,
    certificateThrottle: throttle,
  );

  Future<Map<String, Object?>> ask(TillOperations ops, String pin) =>
      ops.askHandlers[PayOps.certificate.name]!(
        {'number': 'C-1', 'pin': pin},
        11,
        _session(),
      );

  test('с самой кассы N+1-я неудача отказана и до проверки не доходит',
      () async {
    for (var i = 0; i < _perNumber; i++) {
      await expectLater(
        desk.findCertificate('C-1', pin: '0000'),
        _refused(certificatePinWrongCode),
      );
    }
    await expectLater(
      desk.findCertificate('C-1', pin: '1234'),
      _refused(certificateRateLimitedCode),
    );
    expect(inner.lookups, _perNumber);
  });

  test('оплата с кассы с сертификатом — под тем же замком', () async {
    for (var i = 0; i < _perNumber; i++) {
      await expectLater(
        desk.complete(3, _pay('0000'), _meta),
        _refused(certificatePinWrongCode),
      );
    }
    await expectLater(
      desk.findCertificate('C-1', pin: '1234'),
      _refused(certificateRateLimitedCode),
    );
  });

  test('счёт номера у кассы и у провода один', () async {
    final ops = wire(inner);
    for (var i = 0; i < 3; i++) {
      await expectLater(ask(ops, '0000'), _refused(certificatePinWrongCode));
    }
    for (var i = 0; i < 2; i++) {
      await expectLater(
        desk.findCertificate('C-1', pin: '0000'),
        _refused(certificatePinWrongCode),
      );
    }
    await expectLater(ask(ops, '1234'), _refused(certificateRateLimitedCode));
    await expectLater(
      desk.findCertificate('C-1', pin: '1234'),
      _refused(certificateRateLimitedCode),
    );
  });

  test('провод поверх обёртки не считает попытку дважды', () async {
    final ops = wire(desk);
    for (var i = 0; i < _perNumber; i++) {
      await expectLater(
        ask(ops, '0000'),
        _refused(certificatePinWrongCode),
        reason: 'попытка ${i + 1}: двойной счёт запер бы номер на третьей',
      );
    }
    await expectLater(ask(ops, '1234'), _refused(certificateRateLimitedCode));
    expect(inner.lookups, _perNumber);
  });

  // Решение заказчика 2026-09-15: «кассы — это разные кассиры, и каждый
  // всегда работает в своей смене, а не в общей». Замок на кассе считал
  // всех одним счётом места (`desktopSeatKey` и терминал самой кассы).
  group('по кассиру, а не по месту за кассой', () {
    Future<void> exhaust() async {
      for (var i = 0; i < _perCashier; i++) {
        await expectLater(
          desk.findCertificate('N-$i', pin: '0000'),
          _refused(certificatePinWrongCode),
          reason: 'попытка ${i + 1}',
        );
      }
    }

    test('кассир A исчерпал окно на разных номерах — кассир B не заперт',
        () async {
      await exhaust();
      await expectLater(
        desk.findCertificate('C-2', pin: '1234'),
        _refused(certificateRateLimitedCode),
        reason: 'подготовка: A упёрся в свой счёт',
      );

      // A закрыл смену, B вошёл и работает в своей.
      cashier
        ..signOut()
        ..signIn(_cashierB);
      expect(
        (await desk.findCertificate('C-2', pin: '1234')).number,
        'C-2',
        reason: 'у B свой счёт: общий счёт места запер бы его чужими неудачами',
      );
    });

    test('кассир A после повторного входа в той же смене по-прежнему заперт',
        () async {
      await exhaust();
      cashier
        ..signOut()
        ..signIn(_cashierA);
      await expectLater(
        desk.findCertificate('C-2', pin: '1234'),
        _refused(certificateRateLimitedCode),
        reason: 'повторный вход — не новое окно',
      );
    });

    test('номер по-прежнему общий: B не добирает чужие неудачи по номеру',
        () async {
      for (var i = 0; i < _perNumber; i++) {
        await expectLater(
          desk.findCertificate('C-1', pin: '0000'),
          _refused(certificatePinWrongCode),
        );
      }
      cashier
        ..signOut()
        ..signIn(_cashierB);
      await expectLater(
        desk.findCertificate('C-1', pin: '1234'),
        _refused(certificateRateLimitedCode),
      );
    });

    test('на кассе никто не вошёл — названный отказ, до проверки не доходит',
        () async {
      cashier.signOut();
      await expectLater(
        desk.findCertificate('C-1', pin: '1234'),
        _refused('unauthorized'),
      );
      await expectLater(
        desk.complete(3, _pay('1234'), _meta),
        _refused('unauthorized'),
      );
      expect(inner.lookups, 0, reason: 'общего счёта-запасного выхода нет');
    });

    test('журнал безопасности кассы: строка о запирании — с кассиром', () async {
      final journaled = ThrottledPaymentService(
        inner,
        throttle: CertificateThrottle(
          onLocked: certificateLockJournalHandler(
            SecurityJournal(db.securityEventDao),
          ),
        ),
        cashier: cashier,
      );
      for (var i = 0; i < _perCashier; i++) {
        await expectLater(
          journaled.findCertificate('N-$i', pin: '0000'),
          _refused(certificatePinWrongCode),
        );
      }
      await expectLater(
        journaled.findCertificate('SECRET-NO', pin: '1234'),
        _refused(certificateRateLimitedCode),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final rows = [
        for (final e in await db.securityEventDao.findAll())
          if (e.eventType == SecurityEventType.certificateRateLimited) e,
      ];
      expect(rows, hasLength(1));
      expect(rows.single.userId, _cashierA);
      expect(rows.single.outcome, isNot(contains('SECRET-NO')));
      expect(rows.single.outcome, isNot(contains('N-')));
    });

    test('запись о запирании называет кассира, номера в ней нет', () async {
      await exhaust();
      await expectLater(
        desk.findCertificate('C-2', pin: '1234'),
        _refused(certificateRateLimitedCode),
      );
      expect(locks, hasLength(1));
      expect(locks.single.userId, _cashierA);
      expect(locks.single.axes, {'cashier'});
    });
  });
}

final _meta = const CartCommandMeta(key: 'k', baseVersion: 1, receiptNo: 9);

PaymentRequest _pay(String pin) => PaymentRequest(
  type: PaymentType.cash,
  cashReceived: Decimal.parse('1000'),
  certificates: [CertificateTender(number: 'C-1', pin: pin)],
);

class _Paper implements PaymentService {
  int lookups = 0;

  Future<GiftCertificate> _lookup(String number, String? pin) async {
    lookups++;
    await Future<void>.delayed(Duration.zero);
    if (pin != '1234') {
      throw WireRefusal(certificatePinWrongCode, 'не тот', subject: number);
    }
    return GiftCertificate(
      id: 1,
      number: number,
      nominal: Decimal.parse('5000'),
      balance: Decimal.parse('5000'),
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
    for (final c in request.certificates) {
      await _lookup(c.number, c.pin);
    }
    throw StateError('до денег проба не доходит');
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
  Future<domain.Terminal> self() async => const domain.Terminal(
    id: 3,
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
