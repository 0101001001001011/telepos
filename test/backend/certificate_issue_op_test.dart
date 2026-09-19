/// `pay.certificateIssue` — выпуск сертификата **из продукта**, а не из
/// пробы: задача 21.
///
/// # Зачем эта проба отдельно от `certificate_ledger_test`
///
/// Та зовёт `CertificateIssuer` напрямую и доказывает, что выпуск верен.
/// Она **не доказывает, что до выпуска можно дойти**. Ровно этот класс
/// дефекта дерево уже ловило дважды: код привязки терминала был написан,
/// охранял корень и не вызывался ниоткуда; `PaymentKindCatalog` появился
/// без единого читателя в продукте. Здесь проверяется путь: кадр провода
/// → обработчик кассы → строка в базе.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/backend/till_operations.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/payment/local_certificate_issuer.dart';
import 'package:telepos/domain/account/account_type.dart';
import 'package:telepos/domain/auth/auth_outcome.dart';
import 'package:telepos/domain/auth/auth_session.dart';
import 'package:telepos/domain/payment/certificate_issuer.dart';
import 'package:telepos/domain/payment/gift_certificate.dart';
import 'package:telepos/domain/shift/shift_status.dart';
import 'package:telepos/domain/wire/pay_ops.dart';
import 'package:telepos/domain/wire/wire_guard.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

import 'support/bare_till_deps.dart';
import 'support/noop_auth.dart';

void main() {
  late AppDatabase db;
  late CertificateIssuer issuer;
  late TillOperations ops;

  Decimal d(String v) => Decimal.parse(v);

  /// Сеанс кассира — **тот самый довод**, из которого обработчик обязан
  /// взять имя выпускающего. Тело его не называет и назвать не может.
  ///
  /// Право выпуска здесь есть, и это не украшение: предмет этих проб —
  /// **имя**, а не замок. Пустой набор прав после сведения с дорожкой
  /// «право едет из сеанса» давал бы отказ до записи бумажки, и проба про
  /// имя краснела бы по чужой причине. Замок мерят своими сеансами — в
  /// группе «право едет из сеанса, а не из тела кадра» ниже.
  AuthSession session(int userId) => AuthSession(
    token: 'токен-$userId',
    userId: userId,
    name: 'Кассир $userId',
    role: 'cashier',
    permissions: const {
      PermissionKeys.navSale,
      PermissionKeys.opIssueCertificate,
    },
    operatingMode: 0,
    pointMode: 'cashier',
    shift: ShiftStatus.open,
    issuedAt: DateTime(2026, 9, 19),
    expiresAt: DateTime(2026, 9, 20),
    terminalId: 7,
  );
  /// Сеанс, с которым кадр доходит до обработчика.
  ///
  /// **Ревизия второго фронта 2026-09-19:** выпуск читает право
  /// `op.issueCertificate` из довода, построенного по сеансу
  /// (`TillOperations._authorityOf`). До неё [issue] звал обработчик вовсе
  /// без сеанса — и это работало только потому, что выпуск прав не читал. В
  /// рабочей кассе такого кадра не бывает: сторож провода не пропускает
  /// операцию без сеанса. Поэтому по умолчанию сеанс есть и несёт право
  /// выпуска; пробы, которым предмет — само право, строят свой.
  AuthSession allowed() => AuthSession(
    token: 't-issuer',
    userId: 4,
    name: 'Айгуль',
    role: 'owner',
    permissions: const {
      PermissionKeys.navSale,
      PermissionKeys.opIssueCertificate,
    },
    operatingMode: 0,
    pointMode: 'cashier',
    shift: ShiftStatus.open,
    issuedAt: DateTime(2026, 9, 18),
    expiresAt: DateTime(2026, 9, 20),
    terminalId: 1,
  );

  Future<Map<String, Object?>> issueAs(
    AuthSession? session,
    Map<String, Object?> body,
  ) async {
    final result = await ops.askHandlers[PayOps.certificateIssue.name]!(
      body,
      null,
      session,
    );
    return result! as Map<String, Object?>;
  }

  /// Кадр от кассира с правом.
  ///
  /// `session` задаётся там, где проба мерит **имя выпускающего**: обе правки
  /// 2026-09-19 — право обязательным доводом и кассир из сеанса — приехали
  /// параллельными дорожками, и при сведении помощник у них стал один.
  Future<Map<String, Object?>> issue(
    Map<String, Object?> body, {
    AuthSession? session,
  }) => issueAs(session ?? allowed(), body);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    issuer = LocalCertificateIssuer(db: db, logger: Talker());
    ops = TillOperations(
      db: db,
      bootstrap: BareBootstrap(),
      setup: BareSetup(),
      terminals: BareTerminals(),
      deviceBindings: BareBindings(),
      auth: NoopAuth(),
      certificates: issuer,
    );
  });

  tearDown(() => db.close());

  test('кадр провода доводит выпуск до строки в базе', () async {
    final answer = await issue({
      'number': 'C-1',
      // Деньги по проводу — **строкой** (I159).
      'nominal': '5000',
      'pin': '4821',
      'expiresAt': 1893456000,
    });

    // Ответ — тот, который увидит вкладка.
    expect(answer['number'], 'C-1');
    expect(answer['balance'], '5000');
    expect(answer['status'], 'active');
    expect(
      answer.containsKey('pinHash'),
      isFalse,
      reason: 'хэш ПИНа не едет во вкладку ни одной веткой',
    );
    expect(
      answer.values.whereType<String>().contains('4821'),
      isFalse,
      reason: 'и сам ПИН тоже',
    );

    // Строка в базе — то, ради чего всё.
    final row = (await db.certificateDao.byNumber('C-1'))!;
    expect(row.nominal, d('5000'));
    expect(row.balance, d('5000'));
    expect(row.expiresAt, 1893456000);
    expect(row.pinHash, startsWith('pbkdf2\$sha256\$'));

    // И обязательство кассы — тоже.
    final liability = await db.accountDao.findByType(
      AccountType.certificateLiability,
    );
    expect(liability, hasLength(1));
    expect(liability.single.value, d('5000'));
    expect(
      liability.single.visibleToPos,
      isFalse,
      reason: 'обязательство не должно предлагаться кассиру счётом оплаты',
    );
  });

  test('ответ разбирается тем же кодеком, что его и пишет', () async {
    final answer = await issue({'number': 'C-1', 'nominal': '1200.500'});
    final parsed = certificateFromWireJson(answer);

    expect(parsed.number, 'C-1');
    expect(parsed.nominal, d('1200.5'));
    expect(parsed.balance, d('1200.5'));
    expect(parsed.status, CertificateStatus.active);
  });

  test('повторный номер — названный отказ, а не нутро sqlite', () async {
    await issue({'number': 'C-1', 'nominal': '5000'});

    await expectLater(
      issue({'number': 'C-1', 'nominal': '100'}),
      throwsA(
        isA<WireRefusal>().having(
          (r) => r.code,
          'code',
          certificateDuplicateNumberCode,
        ),
      ),
    );
    expect((await db.certificateDao.byNumber('C-1'))!.nominal, d('5000'));
  });

  test('неположительный номинал — отказ до записи', () async {
    await expectLater(
      issue({'number': 'C-1', 'nominal': '0'}),
      throwsA(
        isA<WireRefusal>().having(
          (r) => r.code,
          'code',
          certificateNominalInvalidCode,
        ),
      ),
    );
    expect(await db.certificateDao.byNumber('C-1'), isNull);
    expect(
      await db.accountDao.findByType(AccountType.certificateLiability),
      isEmpty,
      reason: 'счёт обязательства не заводится ради отказа',
    );
  });

  // ── кассир в бумажке: хвост 2026-09-19 ────────────────────────────────
  //
  // До правки обработчик не передавал `userId` вовсе, и поле оставалось
  // пустым у **каждой** бумажки, выпущенной с планшета. Дефект был
  // денежным, а не учётным: на пустом поле блок «СЕРТИФИКАТЫ (НЕ
  // ВЫРУЧКА)» X/Z-отчёта отбирает мягко, и выпуск чужой смены попадал в
  // строку этой (`CertificateDao.issuedNominalBetween`, сторож отбора —
  // `test/data/shift/assemble_shift_certificates_test.dart`).
  //
  // Проба живёт **здесь**, а не у выпускающего: `certificate_ledger_test`
  // зовёт `issue(userId: …)` напрямую и потому доказывает только то, что
  // аргумент записывается. Он записывался и до правки — не передавал его
  // именно провод.
  test('выпуск проводом называет кассира из сеанса', () async {
    await issue({'number': 'C-1', 'nominal': '5000'}, session: session(42));

    final row = (await db.certificateDao.byNumber('C-1'))!;
    expect(
      row.issuedByUserId,
      42,
      reason: 'бумажка без кассира отбирается мягко и считается чужой смене',
    );
  });

  test('имя выпускающего берётся из сеанса, а не из тела', () async {
    // Тело называет **чужого** кассира — и обязано быть не услышанным:
    // иначе вкладка выписывала бы бумажки за чужой подписью, а замок
    // `op.issueCertificate` проверялся бы у одного, писался бы другой.
    await issue({
      'number': 'C-1',
      'nominal': '5000',
      'userId': 99,
    }, session: session(42));

    expect((await db.certificateDao.byNumber('C-1'))!.issuedByUserId, 42);
  });

  // Проба «без сеанса поле кассира остаётся пустым» жила здесь до
  // 2026-09-19 и **снята при сведении**: она утверждала, что кадр без
  // сеанса доходит до записи бумажки. Соседняя дорожка того же дня сделала
  // выпуск без сеанса отказом, и утверждение стало ложным — не устаревшим,
  // а именно ложным. Смысл его («выдуманный кассир хуже пустого») уехал
  // туда, где он теперь достижим: «сеанса нет вовсе — тот же отказ» ниже.

  test('касса без выпускающего отказывает названной причиной', () async {
    final bare = TillOperations(
      db: db,
      bootstrap: BareBootstrap(),
      setup: BareSetup(),
      terminals: BareTerminals(),
      deviceBindings: BareBindings(),
      auth: NoopAuth(),
    );
    await expectLater(
      bare.askHandlers[PayOps.certificateIssue.name]!({
        'number': 'C-1',
        'nominal': '100',
      }, null, allowed()),
      throwsA(
        isA<WireRefusal>().having(
          (r) => r.code,
          'code',
          'certificates_unavailable',
        ),
      ),
    );
  });

  group('право едет из сеанса, а не из тела кадра', () {
    /// Сеанс **без** права выпуска, но с соседними: пустой набор прошёл бы и
    /// у проверки «есть ли вообще сеанс», а этот — нет.
    AuthSession without() => AuthSession(
      token: 't-cashier',
      userId: 9,
      name: 'Ержан',
      role: 'cashier',
      permissions: const {
        PermissionKeys.navSale,
        PermissionKeys.opSellDiscount,
      },
      operatingMode: 0,
      pointMode: 'cashier',
      shift: ShiftStatus.open,
      issuedAt: DateTime(2026, 9, 18),
      expiresAt: DateTime(2026, 9, 20),
      terminalId: 1,
    );

    test('сеанс без op.issueCertificate — forbidden, бумажки нет', () async {
      // Не дубль сторожа: тот проверяет ту же пару ключей раньше и до
      // обработчика не пускает вовсе. Здесь мерится то, что останется
      // верным, если до выпуска дойдут мимо сторожа, — а мимо него ходит
      // весь кассовый фронт, у которого провода нет.
      await expectLater(
        issueAs(without(), {'number': 'C-1', 'nominal': '5000'}),
        throwsA(
          isA<WireRefusal>().having((r) => r.code, 'code', WireDenied.forbidden),
        ),
      );

      expect(await db.certificateDao.byNumber('C-1'), isNull);
      expect(
        await db.accountDao.findByType(AccountType.certificateLiability),
        isEmpty,
        reason: 'обязательство не берётся на кассу отказанным выпуском',
      );
    });

    test('сеанса нет вовсе — тот же отказ, и ни одной бумажки', () async {
      await expectLater(
        issueAs(null, {'number': 'C-1', 'nominal': '5000'}),
        throwsA(
          isA<WireRefusal>().having((r) => r.code, 'code', WireDenied.forbidden),
        ),
      );

      // Наследство снятой пробы про имя кассира: молчаливая бумажка
      // страшнее отказа. Пустое поле кассира отбирается мягко и попадает в
      // чужую смену блоком «СЕРТИФИКАТЫ (НЕ ВЫРУЧКА)» X/Z-отчёта — значит
      // бумажки не должно быть вовсе, а не «быть, но без имени».
      expect(await db.certificateDao.byNumber('C-1'), isNull);
    });

    test('право, названное ТЕЛОМ кадра, права не даёт', () async {
      // Диверсия под «а вдруг обработчик читает права откуда-нибудь ещё»:
      // вкладка называет себя вправе — касса не верит, потому что строит
      // довод из сеанса и только из него.
      await expectLater(
        issueAs(without(), {
          'number': 'C-1',
          'nominal': '5000',
          'permissions': [PermissionKeys.opIssueCertificate],
        }),
        throwsA(
          isA<WireRefusal>().having((r) => r.code, 'code', WireDenied.forbidden),
        ),
      );
    });
  });
}


