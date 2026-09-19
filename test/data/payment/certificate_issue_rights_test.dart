/// Выпуск сертификата спрашивает право **у себя**, а не у маршрута и не у
/// экрана — ревизия второго фронта 2026-09-19.
///
/// # Что было измерено на `aa120271`
///
/// `op.issueCertificate` проверяли ровно три места, и ни одно из них не было
/// самой операцией:
///
/// - сторож провода (`PayOps.certificateIssue` → `SessionAccess.needs`) —
///   только для браузерного терминала;
/// - карта маршрутов (`PermissionKeys.routeToPermissionKey`,
///   `/certificate-issue`) — только для `redirect`;
/// - экран (`certificate_issue_screen._issue`, `hasPermissionProvider`) —
///   только для нажатой кнопки.
///
/// В `LocalCertificateIssuer.issue` проверок права было **ноль**. То есть
/// любой, кто добрался до `GetIt.I<CertificateIssuer>()` — соседний экран,
/// диалог, будущий юзкейс, — выписывал обязательство магазина на любую
/// сумму. Это I162 дословно: спрятанная кнопка правом не является.
///
/// # Приём — тот же, что у корзины (задача 28)
///
/// Полномочия приходят **обязательным доводом** `DiscountAuthority`, и
/// читает их сам выпуск. Забыть довод нельзя по сборке; проверка стоит там,
/// куда сходятся все фронты, а не там, где рисуется интерфейс.
///
/// # Почему пробы утверждают про обязательство, а не только про отказ
///
/// «Бросило `forbidden`» — половина правды: выпуск это **две** записи
/// (бумажка и движение по счёту обязательств), и отказ, случившийся между
/// ними, оставил бы кассу с бумажкой без долга или с долгом без бумажки.
/// Поэтому каждый отказ здесь проверяется ещё и тем, что счёта обязательств
/// не появилось вовсе.
///
/// # Чего эти пробы НЕ доказывают
///
/// Что сертификат нельзя погасить без права: гашение (`CertificateDao
/// .redeem`) живёт внутри транзакции продажи и своего права не имеет — его
/// закрывает право на продажу. И что нельзя **отозвать** бумажку:
/// `CertificateIssuer.cancel` довода не принимает, его по-прежнему держат
/// маршрут и экран. Названо намеренно — следующая ревизия начинает отсюда.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/payment/local_certificate_issuer.dart';
import 'package:telepos/domain/account/account_type.dart';
import 'package:telepos/domain/discount/discount_policy.dart';
import 'package:telepos/domain/payment/certificate_issuer.dart';
import 'package:telepos/domain/wire/wire_guard.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

import '../../helpers/discount_authority.dart';

void main() {
  late AppDatabase db;
  late CertificateIssuer issuer;

  Decimal d(String v) => Decimal.parse(v);

  /// Кассир **с** правом на всё, кроме выпуска.
  ///
  /// Не пустой набор: пустой прошёл бы и у сторожа, подменяющего право на
  /// «есть ли вообще сеанс». Соседние права здесь нарочно — они доказывают,
  /// что дверь открывает именно `op.issueCertificate`, а не любой ключ.
  const noIssue = DiscountAuthority(
    roleIndex: 3,
    permissions: {
      PermissionKeys.opSellDiscount,
      PermissionKeys.opEditPrice,
      PermissionKeys.opDeferSale,
    },
  );

  /// Отказ по праву — **и код, и ключ в тексте**.
  ///
  /// Код один на оба фронта (`WireDenied.forbidden`), и по нему одному проба
  /// не отличила бы отказ выпуска от отказа любой соседней команды. Имя
  /// ключа в тексте — то, что кассир покажет владельцу, а владелец найдёт на
  /// экране пользователей.
  final forbidden = throwsA(
    isA<WireRefusal>()
        .having((r) => r.code, 'code', WireDenied.forbidden)
        .having(
          (r) => r.message,
          'message',
          contains(PermissionKeys.opIssueCertificate),
        ),
  );

  Future<int> liabilityAccounts() async =>
      (await db.accountDao.findByType(AccountType.certificateLiability)).length;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    issuer = LocalCertificateIssuer(db: db, logger: Talker());
  });

  tearDown(() => db.close());

  group('право спрашивает сама операция', () {
    test('кассир без op.issueCertificate — отказ forbidden', () async {
      await expectLater(
        issuer.issue(by: noIssue, number: 'C-1', nominal: d('5000')),
        forbidden,
      );
    });

    test('отказ доходит до денег: ни бумажки, ни обязательства', () async {
      // **Главная проба группы.** Отказ сам по себе не доказывает, что касса
      // не взяла на себя долг: выпуск это две записи, и беда между ними
      // всплыла бы у другого кассира в другую смену.
      await expectLater(
        issuer.issue(by: noIssue, number: 'C-1', nominal: d('5000')),
        forbidden,
      );

      expect(await db.certificateDao.byNumber('C-1'), isNull);
      expect(
        await liabilityAccounts(),
        0,
        reason: 'счёт обязательств не заводится ленивым выпуском отказанного',
      );
    });

    test('сеанса нет вовсе — тот же отказ', () async {
      // `DiscountAuthority.none` — честный ответ фронта без сеанса. Отдельная
      // проба потому, что «прав ноль» и «прав много, но не этого» — разные
      // состояния, и сторож, читающий `permissions.isNotEmpty`, прошёл бы
      // одну из них.
      await expectLater(
        issuer.issue(
          by: DiscountAuthority.none,
          number: 'C-1',
          nominal: d('5000'),
        ),
        forbidden,
      );
    });

    test('право проверяется РАНЬШЕ номера и номинала', () async {
      // Порядок — тот же, что у корзины («кому → что → сколько»), и он не
      // украшение: кассир без права, получивший `certificate_number_taken`,
      // узнал бы, какие номера уже выпущены, перебором. Номинал здесь
      // заведомо негодный, номер — заведомо занятый.
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-1',
        nominal: d('5000'),
      );

      await expectLater(
        issuer.issue(by: noIssue, number: 'C-1', nominal: d('-1')),
        forbidden,
      );
    });
  });

  group('управляющие пробы: починка не заперла всех подряд', () {
    test('кассир с правом выпускает как раньше', () async {
      final issued = await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-1',
        nominal: d('5000'),
      );

      expect(issued.number, 'C-1');
      expect(issued.balance, d('5000'));
      expect(await liabilityAccounts(), 1);
    });

    test('соседние двери не тронуты: lookup без права работает', () async {
      // Диверсия второго рода: «требовать право везде» прошло бы каждую
      // пробу выше и сломало бы оплату сертификатом — `lookup` зовёт
      // раскладка платежа, у которой этого права нет и быть не должно.
      await issuer.issue(
        by: fullDiscountAuthority,
        number: 'C-1',
        nominal: d('5000'),
      );

      final found = await issuer.lookup(number: 'C-1');
      expect(found.balance, d('5000'));
    });
  });
}
