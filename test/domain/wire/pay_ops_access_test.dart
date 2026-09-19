/// Права пяти денежных операций оплаты — задача 14.
///
/// Проверяется **достижимость отказа от кассы**, а не наличие ключа в
/// таблице: спрятанная кнопка правом не является (I44, I162), и ровно так
/// «войти было нельзя» пережило 3518 зелёных тестов.
///
/// Здесь впервые в дереве читается ключ `op.sellDebt`. До этой задачи его
/// не спрашивала ни одна строка `lib/` — докстринг `PermissionKeys`
/// называл это прямо и просил не принимать объявленный ключ за работающий
/// механизм.
///
/// **`op.cancelPayment` читателя не получил и остаётся плацебо.** Круг
/// правки 1 убрал отмену уже проведённой оплаты целиком: механизм, который
/// право читает и **обходит**, хуже честно неподключённого ключа. Проба
/// «долг не открывает отмену» ниже сторожит именно это — она была красной
/// до правки и покраснеет снова, если кто-нибудь вернёт второй ключ, не
/// вернув цикл.
library;

import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/domain/auth/auth_session.dart';
import 'package:telepos/domain/auth/session_lookup.dart';
import 'package:telepos/domain/wire/pay_ops.dart';
import 'package:telepos/domain/wire/wire_access.dart';
import 'package:telepos/domain/wire/wire_guard.dart';
import 'package:telepos/domain/wire/wire_op.dart';
import 'package:telepos/domain/shift/shift_status.dart';

class _Sessions implements SessionLookup {
  _Sessions(this._byToken);
  final Map<String, AuthSession> _byToken;
  @override
  AuthSession? sessionFor(String token) => _byToken[token];
}

AuthSession _session(Set<String> permissions) => AuthSession(
  token: 'tok',
  userId: 1,
  name: 'Айгуль',
  role: 'cashier',
  permissions: permissions,
  operatingMode: 0,
  pointMode: 'cashier',
  shift: ShiftStatus.open,
  issuedAt: DateTime.utc(2026, 9, 6, 10),
  expiresAt: DateTime.utc(2026, 9, 6, 10, 30),
  terminalId: 7,
);

/// Операции со **своим постоянным** правом сверх `nav.sale`.
///
/// Не «с объявленным `alsoNeeds`» — `pay.complete` тоже его объявляет, но
/// читает тело. Здесь те, у кого второе право не зависит от заявки вовсе, и
/// потому кассир с одним `nav.sale` их проходить не должен.
///
/// Решение заказчика 2026-09-18 добавило сюда две: `pay.prepaymentRefund`
/// (выдача аванса, постоянное `op.creditRepay` — тот же ключ, что у приёма) и
/// `pay.certificateSlip` (повтор печати слипа, постоянное
/// `op.issueCertificate` — тот же ключ, что у выпуска). Обе названы здесь
/// поимённо, а не выведены по форме описания: вывод по форме сказал бы
/// «объявлен `alsoNeeds`» и записал бы сюда `pay.complete`, у которой право
/// зависит от тела.
const _ownRightOps = {
  'pay.certificateIssue',
  'pay.certificateSlip',
  'pay.prepaymentIntake',
  'pay.prepaymentRefund',
};

void main() {
  WireGuard guardFor(Set<String> permissions) => WireGuard(
    access: {for (final op in PayOps.all) op.name: op.access},
    sessions: _Sessions({'tok': _session(permissions)}),
    isTillConfigured: () async => true,
    selfTerminalId: () async => 1,
  );

  /// Кассир по умолчанию: `nav.sale` есть, ни `op.sellDebt`, ни
  /// `op.cancelPayment` нет. Это не выдумка теста — ровно такое множество
  /// раздаёт `PermissionKeys.defaultsFor(UserRole.cashier)` минус долг
  /// (долг кассиру полагается; здесь его снимают, чтобы проверить сам
  /// механизм).
  const withoutDebt = {PermissionKeys.navSale};
  const withDebt = {PermissionKeys.navSale, PermissionKeys.opSellDebt};

  group('постоянное право', () {
    test('все операции каталога требуют nav.sale', () {
      for (final op in PayOps.all) {
        final access = op.access;
        expect(access, isA<SessionAccess>(), reason: op.name);
        expect(
          (access as SessionAccess).needs,
          PermissionKeys.navSale,
          reason: op.name,
        );
      }
    });

    test('кассир без nav.sale не проходит ни одну', () async {
      final guard = guardFor(const {});
      for (final op in PayOps.all) {
        final verdict = await guard.check(op.name, const {}, 'tok');
        expect(verdict, isA<WireDenied>(), reason: op.name);
        expect(
          (verdict as WireDenied).code,
          WireDenied.forbidden,
          reason: op.name,
        );
      }
    });

    test('без сеанса вовсе — unauthorized, а не forbidden', () async {
      final verdict = await guardFor(
        withDebt,
      ).check(PayOps.complete.name, const {}, null);
      expect((verdict as WireDenied).code, WireDenied.unauthorized);
    });
  });

  group('оплата в долг требует op.sellDebt', () {
    test('без права — отказ от кассы, кодом forbidden', () async {
      final verdict = await guardFor(withoutDebt).check(PayOps.complete.name, {
        'type': 'debt',
        'key': 'k9',
        'baseVersion': 3,
      }, 'tok');

      expect(verdict, isA<WireDenied>());
      expect((verdict as WireDenied).code, WireDenied.forbidden);
      expect(verdict.reason, contains(PermissionKeys.opSellDebt));
      // Сеанс донесён до журнала: отказ по праву — событие безопасности,
      // и знать, кто его получил, обязано не гадание.
      expect(verdict.session?.userId, 1);
    });

    test('с правом — проходит', () async {
      final verdict = await guardFor(withDebt).check(PayOps.complete.name, {
        'type': 'debt',
        'key': 'k9',
        'baseVersion': 3,
      }, 'tok');

      expect(verdict, isA<WireAllowed>());
    });

    test('обычная оплата права на долг не требует', () async {
      // Страховка от вырождения: если бы `alsoNeeds` требовал долг всегда,
      // предыдущие два теста прошли бы одинаково и ничего не доказывали.
      for (final type in const ['cash', 'card', 'mixed']) {
        final verdict = await guardFor(withoutDebt).check(
          PayOps.complete.name,
          {'type': type, 'key': 'k9', 'baseVersion': 3},
          'tok',
        );
        expect(verdict, isA<WireAllowed>(), reason: type);
      }
    });

    test('чужое слово в поле вида оплаты долгом не считается', () async {
      // `PaymentType.byWireName` вернёт `null` и разбор упадёт на
      // наличные — значит и право спрашивать не за что. Обратное
      // (требовать `op.sellDebt` на любое незнакомое слово) заперло бы
      // кассу от собственного будущего вида оплаты.
      final verdict = await guardFor(
        withoutDebt,
      ).check(PayOps.complete.name, {'type': 'долг'}, 'tok');
      expect(verdict, isA<WireAllowed>());
    });
  });

  // **Предел этой группы, названный честно (круг правки 2):** настоящей
  // операции, требующей двух прав от тела, в дереве **нет** — после
  // снятия отмены `pay.complete` требует одного. Значит «сторож ходит по
  // всем правам» держится ровно на одной искусственной пробе ниже, а не
  // на продукте: заведи кто-нибудь второе право у настоящей операции и
  // напиши цикл заново неправильно — покраснеет только она.
  group('множество прав, а не одно', () {
    test('второе право не теряется за первым — проба C1', () async {
      // **Дыра, найденная разбором круга правки 1, и она была про кражу.**
      // Пока `alsoNeeds` отдавала одно право (`String?`), тело, требующее
      // двух, проверялось по **первому применимому**: кадр
      // `{'type':'debt','cancelPrevious':true}` спрашивал `op.sellDebt`
      // (он у кассира есть) и до `op.cancelPayment` (которого у кассира
      // нет) не доходил **никогда**. Сторож пропускал отмену уже
      // проведённой оплаты под видом долга.
      //
      // Сама отмена убрана целиком, но механизм остался, и он обязан
      // выдерживать множество. Проба ставит два права искусственно —
      // сторож проверяется без единственного сегодняшнего читателя,
      // потому что дыра была в **стороже**, а не в том, кто его звал.
      const both = {'op.first', 'op.second'};
      final guard = WireGuard(
        access: const {
          'probe': SessionAccess(
            needs: PermissionKeys.navSale,
            alsoNeeds: _twoRights,
          ),
        },
        sessions: _Sessions({
          'tok': _session({PermissionKeys.navSale, 'op.first'}),
        }),
        isTillConfigured: () async => true,
        selfTerminalId: () async => 1,
      );

      final verdict = await guard.check('probe', const {}, 'tok');

      expect(verdict, isA<WireDenied>());
      expect((verdict as WireDenied).code, WireDenied.forbidden);
      expect(
        verdict.reason,
        contains('op.second'),
        reason: 'названо первое НЕДОСТАЮЩЕЕ право, а не первое применимое',
      );
      expect(both, hasLength(2), reason: 'проба про два права, а не про одно');
    });

    test('оба права на месте — проходит', () async {
      // Страховка от вырождения: сторож, отвергающий всё, прошёл бы пробу
      // выше и ничего не доказывал.
      final guard = WireGuard(
        access: const {
          'probe': SessionAccess(
            needs: PermissionKeys.navSale,
            alsoNeeds: _twoRights,
          ),
        },
        sessions: _Sessions({
          'tok': _session({PermissionKeys.navSale, 'op.first', 'op.second'}),
        }),
        isTillConfigured: () async => true,
        selfTerminalId: () async => 1,
      );

      expect(await guard.check('probe', const {}, 'tok'), isA<WireAllowed>());
    });

    test('op.cancelPayment каталогом оплаты не спрашивается вовсе', () async {
      // Решение заказчика: отмена — отдельная работа со своим экраном и
      // подтверждением, а не флаг в кадре. Ключ остаётся плацебо, и это
      // записано прямо, а не спрятано механизмом, который его читает и
      // обходит.
      for (final op in PayOps.all) {
        final needed = (op.access as SessionAccess).alsoNeeds?.call(const {
          'type': 'debt',
          'cancelPrevious': true,
        });
        expect(
          needed ?? const <String>{},
          isNot(contains(PermissionKeys.opCancelPayment)),
          reason: op.name,
        );
      }
    });
  });

  group('право по телу — только у pay.complete', () {
    /// Меняет ли операция набор прав **в зависимости от тела**.
    ///
    /// # Почему не «объявлен ли `alsoNeeds`» — задача 21
    ///
    /// До неё сторож спрашивал именно это, и до неё вопросы совпадали:
    /// `alsoNeeds` была одна и читала тело. Задача 21 завела вторую —
    /// `pay.certificateIssue` требует `op.issueCertificate` **всегда**,
    /// потому что тела, при котором выпуск обязательства был бы
    /// безобиден, не существует, — и другого места под второй постоянный
    /// ключ в описании нет (`needs` — один ключ).
    ///
    /// Мерить объявление вместо поведения значило бы запретить второй
    /// постоянный ключ навсегда, ничего этим не защитив. Беда, ради
    /// которой сторож заведён, — «право зависит от заявки» расползлось по
    /// каталогу, — меряется вызовом функции **двумя разными телами**.
    bool variesWithBody(WireOp<Object?, Object?> op) {
      final also = (op.access as SessionAccess).alsoNeeds;
      if (also == null) return false;
      final asDebt = also(const {'type': 'debt'});
      final asCash = also(const {'type': 'cash'});
      return !const SetEquality<String>().equals(asDebt, asCash);
    }

    test('остальные тела не читают', () async {
      // Иначе «право зависит от заявки» расползлось бы по каталогу, и
      // каждую операцию пришлось бы читать целиком, чтобы узнать, что она
      // требует.
      final conditional = PayOps.all
          .where(variesWithBody)
          .map((op) => op.name)
          .toList();
      expect(conditional, ['pay.complete']);
    });

    test('постоянное второе право не превращается в право по телу', () async {
      // Слом в другую сторону: `pay.certificateIssue` обязана требовать
      // своё право **при любом теле**. Функция, вернувшая пустое
      // множество на каком-нибудь теле, открыла бы выпуск обязательств
      // подобранным кадром.
      final also =
          (PayOps.certificateIssue.access as SessionAccess).alsoNeeds!;
      for (final body in const <Map<String, Object?>>[
        {},
        {'type': 'cash'},
        {'type': 'debt'},
        {'number': 'C-1', 'nominal': '100'},
      ]) {
        expect(
          also(body),
          {PermissionKeys.opIssueCertificate},
          reason: 'тело $body не должно снимать право на выпуск',
        );
      }
    });

    test('кассир без op.sellDebt проходит все безусловные операции', () async {
      // **Список выводится из каталога, а не пишется рядом** (круг правки
      // 4 задачи 16). Прежний ручной перечень ловил бы исчезновение
      // операции и пропускал появление новой — ровно тем способом, каким
      // `pay.troubles` ушла из-под сторожа владения в круге правки 2.
      //
      // Задача 21: «безусловная» здесь — не «без `alsoNeeds`», а «набор
      // прав не зависит от тела». `pay.certificateIssue` из списка
      // исключена **своим правом**, а не формой описания: кассир без
      // `op.issueCertificate` её и не должен проходить. Требование
      // заказчика 2026-09-18 добавило вторую такую — `pay.prepaymentIntake`
      // (постоянное `op.creditRepay`), и потому исключение стало списком.
      final unconditional = PayOps.all
          .where((op) => !variesWithBody(op))
          .where((op) => !_ownRightOps.contains(op.name))
          .toList();
      expect(
        unconditional.map((op) => op.name),
        isNot(contains('pay.complete')),
        reason: 'страховка от вырождения: условная операция в список не входит',
      );
      // **Число закрытое, а не относительное** (2026-09-18). До этой правки
      // здесь стояло `PayOps.all.length - 2`, и план работы уже называл эту
      // форму сторожем, которого нет: новая безусловная операция сдвигала
      // обе стороны сразу и проезжала молча. Закрытое число обязывает
      // автора следующей операции назвать её вслух — здесь и в списке
      // [_ownRightOps] выше, если право у неё своё.
      //
      // **И одного закрытого числа мало — измерено этой работой.** Решение
      // заказчика 2026-09-18 завело две операции сразу, и обе со своим
      // постоянным правом: каталог вырос с 15 до 17, список [_ownRightOps] —
      // с двух до четырёх, а 12 осталось двенадцатью. То есть сторож,
      // заведённый ровно затем, чтобы новая операция не проехала молча,
      // пропустил бы **две**, не покраснев ни разу.
      //
      // Поэтому чисел теперь два, и второе закрывает дыру первого: размер
      // каталога назван прямо. Прибавить операцию, не сказав о ней вслух,
      // больше нельзя ни одним из двух способов.
      expect(
        PayOps.all.length,
        17,
        reason: 'операция добавлена в каталог, а её право не названо здесь',
      );
      // 12 = 17 операций каталога минус одна условная по телу
      // (`pay.complete`) минус четыре со своим постоянным правом.
      expect(
        unconditional.length,
        12,
        reason: 'операция добавлена, а решение о её праве не названо',
      );

      final guard = guardFor(withoutDebt);
      for (final op in unconditional) {
        expect(
          await guard.check(op.name, const {'type': 'debt'}, 'tok'),
          isA<WireAllowed>(),
          reason: '${op.name} — тело не должно менять её право',
        );
      }
    });

    test('без op.creditRepay приём аванса не проходит, с ним — проходит',
        () async {
      // Тот же сторож в обе стороны, что у выпуска сертификата ниже, и
      // заведён по той же причине: денежная операция без права — дверь, а
      // запрет, который не пропускает никого, выглядит так же зелено, как
      // запрет, который никого не останавливает.
      //
      // Тело — настоящее (покупатель, сумма, вид оплаты): проверка обязана
      // мерить право, а не разбор кадра.
      const body = <String, Object?>{
        'customerId': 5,
        'amount': '1000',
        'tenderKindId': 1,
      };
      final denied = guardFor(withoutDebt);
      expect(
        await denied.check(PayOps.prepaymentIntake.name, body, 'tok'),
        isA<WireDenied>(),
        reason: 'кассир без права двигает счёт расчётов покупателя',
      );

      final allowed = guardFor({
        ...withoutDebt,
        PermissionKeys.opCreditRepay,
      });
      expect(
        await allowed.check(PayOps.prepaymentIntake.name, body, 'tok'),
        isA<WireAllowed>(),
      );
    });

    test('право приёма аванса постоянно — тело его не снимает', () async {
      // Слом в другую сторону, тот же, что закрыт у выпуска сертификата:
      // функция, вернувшая пустое множество на каком-нибудь теле, открыла
      // бы приём чужих денег на чужой счёт подобранным кадром.
      final also = (PayOps.prepaymentIntake.access as SessionAccess).alsoNeeds!;
      for (final body in const <Map<String, Object?>>[
        {},
        {'type': 'cash'},
        {'type': 'debt'},
        {'customerId': 5, 'amount': '1000', 'tenderKindId': 1},
      ]) {
        expect(
          also(body),
          {PermissionKeys.opCreditRepay},
          reason: 'тело $body не должно снимать право на приём аванса',
        );
      }
    });

    test('без op.creditRepay выдача аванса не проходит, с ним — проходит',
        () async {
      // Решение заказчика 2026-09-18: выдача аванса деньгами с планшета.
      // Сторож в обе стороны, по тому же доводу, что у приёма выше: запрет,
      // не пропускающий никого, выглядит так же зелено, как запрет, не
      // останавливающий никого.
      //
      // Тело — настоящее (покупатель, сумма, вид оплаты, ключ повтора):
      // проверка обязана мерить право, а не разбор кадра.
      const body = <String, Object?>{
        'key': 'r-1',
        'customerId': 5,
        'amount': '1000',
        'tenderKindId': 1,
      };
      expect(
        await guardFor(withoutDebt).check(
          PayOps.prepaymentRefund.name,
          body,
          'tok',
        ),
        isA<WireDenied>(),
        reason: 'кассир без права выпускает живые деньги из ящика',
      );

      expect(
        await guardFor({
          ...withoutDebt,
          PermissionKeys.opCreditRepay,
        }).check(PayOps.prepaymentRefund.name, body, 'tok'),
        isA<WireAllowed>(),
      );
    });

    test('право выдачи аванса постоянно — тело его не снимает', () async {
      // Слом в другую сторону: функция, вернувшая пустое множество на
      // каком-нибудь теле, открыла бы выдачу чужих денег подобранным кадром.
      final also = (PayOps.prepaymentRefund.access as SessionAccess).alsoNeeds!;
      for (final body in const <Map<String, Object?>>[
        {},
        {'type': 'cash'},
        {'type': 'debt'},
        {'key': 'r-1', 'customerId': 5, 'amount': '1000', 'tenderKindId': 1},
      ]) {
        expect(
          also(body),
          {PermissionKeys.opCreditRepay},
          reason: 'тело $body не должно снимать право на выдачу аванса',
        );
      }
    });

    test('без op.issueCertificate слип не печатается, с ним — печатается',
        () async {
      // Решение заказчика 2026-09-18: повтор печати слипа с планшета. Право
      // то же, что у выпуска, и это не экономия: слип печатает обязательство
      // магазина, и кассир, которому не доверен выпуск, не должен печатать
      // его бумажку.
      const body = <String, Object?>{'number': 'C-1', 'pin': '1234'};
      expect(
        await guardFor(
          withoutDebt,
        ).check(PayOps.certificateSlip.name, body, 'tok'),
        isA<WireDenied>(),
        reason: 'кассир без права печатает обязательства магазина',
      );

      expect(
        await guardFor({
          ...withoutDebt,
          PermissionKeys.opIssueCertificate,
        }).check(PayOps.certificateSlip.name, body, 'tok'),
        isA<WireAllowed>(),
      );
    });

    test('право на слип постоянно — тело его не снимает', () async {
      final also = (PayOps.certificateSlip.access as SessionAccess).alsoNeeds!;
      for (final body in const <Map<String, Object?>>[
        {},
        {'type': 'cash'},
        {'number': 'C-1'},
        {'number': 'C-1', 'pin': '1234'},
      ]) {
        expect(
          also(body),
          {PermissionKeys.opIssueCertificate},
          reason: 'тело $body не должно снимать право на печать слипа',
        );
      }
    });

    test('без op.issueCertificate выпуск не проходит, с ним — проходит',
        () async {
      // Гейт обязан краснеть в обе стороны: запрет, который никого не
      // останавливает, и запрет, который не пропускает никого, выглядят
      // одинаково зелёными, если спрашивать только одну сторону.
      final denied = guardFor(withoutDebt);
      expect(
        await denied.check(
          PayOps.certificateIssue.name,
          const {'number': 'C-1', 'nominal': '100'},
          'tok',
        ),
        isA<WireDenied>(),
        reason: 'кассир без права печатает обязательства магазина',
      );

      final allowed = guardFor({
        ...withoutDebt,
        PermissionKeys.opIssueCertificate,
      });
      expect(
        await allowed.check(
          PayOps.certificateIssue.name,
          const {'number': 'C-1', 'nominal': '100'},
          'tok',
        ),
        isA<WireAllowed>(),
      );
    });
  });
}

/// Два права от одного тела — искусственный читатель [SessionAccess.alsoNeeds].
///
/// Объявлен на верхнем уровне, потому что ссылка кладётся в `const`
/// [SessionAccess] — то же требование, что и к настоящему
/// [payExtraPermissions].
Set<String> _twoRights(Map<String, Object?> body) => const {
  'op.first',
  'op.second',
};
