import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/fiscal/ofd_policy.dart';
import 'package:telepos/domain/account/account_type.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/usecases/fiscal/fiscal_service.dart';
import 'package:telepos/domain/usecases/sale/sale_use_case.dart';

/// **«Безналичный чек» для выборочной фискализации — не только карта.**
///
/// # Дефект, который эта проба нашла, и как он выглядел
///
/// `ofdSyncType == 2` означает «в ОФД уезжают только безналичные чеки».
/// Вопрос задавался так: `kind.fiscalTreatment != FiscalTreatment.card →
/// не уезжает`. До задачи 22 это было верно по построению: единственным
/// безналичным видом была карта.
///
/// QR/СБП — второй, и его трактовка [FiscalTreatment.mobile]. Значит чек,
/// оплаченный телефоном, на кассе с выборочной фискализацией **не уезжал
/// бы оператору вовсе** — молча, без отказа, с исходом `notRequired`.
/// Кассир увидел бы обычную успешную продажу.
///
/// Это ровно та цена, которую назвал сосед по авансу: вид оплаты, не
/// доехавший до фискального решения, даёт оператору не то. У аванса —
/// «безнал уедет наличными», здесь — «безнал не уедет никак».
///
/// # Почему ответ переехал на само перечисление
///
/// Список «карта или мобильный» на месте вопроса пришлось бы повторять
/// у каждого следующего читателя, и первый же забытый повтор дал бы ту
/// же беду под другим именем. [FiscalTreatment.isCashless] — одно
/// выражение, и таблица ниже проходит по **всем** членам, а не по трём
/// вспомнившимся: новый член красит сторожа в день добавления.
void main() {
  late AppDatabase db;

  const posAccountId = 11;
  const bankAccountId = 12;
  const certificateAccountId = 13;
  const bonusAccountId = 14;
  const agentAccountId = 15;

  Decimal d(String v) => Decimal.parse(v);

  Future<void> seedAccount(int id, int type) async {
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: Value(id),
            type: type,
            name: Value('Счёт $id'),
            value: Value(Decimal.zero),
            visibleToPos: const Value(true),
          ),
        );
  }

  /// Касса, фискализующая **только безналичные чеки**.
  Future<void> cashlessOnly() async {
    await (db.update(db.thisPosEntries)..where((t) => t.id.equals(1))).write(
      const ThisPosEntriesCompanion(ofdSyncType: Value(2)),
    );
  }

  PaymentEntry entry(int kindId, int accountId, String amount) => PaymentEntry(
    payeeAccountId: accountId,
    amount: d(amount),
    kindId: kindId,
  );

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db
        .into(db.thisPosEntries)
        .insert(
          const ThisPosEntriesCompanion(
            id: Value(1),
            accountId: Value(posAccountId),
          ),
        );
    await seedAccount(posAccountId, 1);
    await seedAccount(bankAccountId, 6);
    await seedAccount(certificateAccountId, AccountType.certificateLiability);
    await seedAccount(bonusAccountId, AccountType.cashback);
    await seedAccount(agentAccountId, AccountType.agentMain);
  });

  tearDown(() async {
    await db.close();
  });

  group('выборочная фискализация по безналичности', () {
    test('чек, оплаченный по QR, уезжает оператору', () async {
      await cashlessOnly();

      final needed = await isOfdSale(
        db: db,
        fiscal: const _EnabledFiscal(),
        payments: [entry(SystemPaymentKindIds.qr, bankAccountId, '1000')],
        selectiveOfd: false,
      );

      expect(
        needed,
        isTrue,
        reason:
            'QR — безналичная оплата. Чек, не уехавший оператору, выглядит '
            'для кассира обычной успешной продажей: ни отказа, ни следа',
      );
    });

    test('карта уезжает по-прежнему', () async {
      await cashlessOnly();
      expect(
        await isOfdSale(
          db: db,
          fiscal: const _EnabledFiscal(),
          payments: [entry(SystemPaymentKindIds.card, bankAccountId, '1000')],
          selectiveOfd: false,
        ),
        isTrue,
      );
    });

    test('наличный чек НЕ уезжает — иначе выборочность ничего не значит',
        () async {
      await cashlessOnly();
      expect(
        await isOfdSale(
          db: db,
          fiscal: const _EnabledFiscal(),
          payments: [entry(SystemPaymentKindIds.cash, posAccountId, '1000')],
          selectiveOfd: false,
        ),
        isFalse,
        reason:
            'слом в обе стороны: сторож, пропускающий всё, зелен и при '
            'полностью снятой выборочности',
      );
    });

    test('смешанный чек «QR плюс наличные» НЕ уезжает целиком', () async {
      await cashlessOnly();
      expect(
        await isOfdSale(
          db: db,
          fiscal: const _EnabledFiscal(),
          payments: [
            entry(SystemPaymentKindIds.qr, bankAccountId, '400'),
            entry(SystemPaymentKindIds.cash, posAccountId, '600'),
          ],
          selectiveOfd: false,
        ),
        isFalse,
        reason:
            'достаточно одной наличной строки: «безналичный чек» — про весь '
            'чек, а не про большинство его строк',
      );
    });
  });

  /// **Состав чека, а не каждая его строка по отдельности** — ревизия
  /// 2026-09-19, дыра 1.
  ///
  /// # Дефект, измеренный до этих проб
  ///
  /// Вопрос стоял так: «**каждая** строка чека безналична?» — и всякая
  /// строка, которой ответить «да» было нечем, уводила чек мимо
  /// оператора. С задачи 22 таких строк стало три, и ни одна из них не
  /// про наличные деньги:
  ///
  /// * гашение сертификата — [FiscalTreatment.offsetNotFiscal], решение
  ///   заказчика 2026-09-14: не фискальная оплата вовсе;
  /// * бонус — [FiscalTreatment.notAPayment]: не платёж вовсе;
  /// * долг — [FiscalTreatment.credit]: обязательство вместо денег.
  ///
  /// Чек «карта 4000 + сертификат 1000» на кассе с `ofdSyncType == 2`
  /// **не уезжал оператору вовсе**: деньги картой взяты, фискального
  /// документа нет, и кассир видел обычную успешную продажу — ни отказа,
  /// ни полосы. Это ровно та беда, которую задача 22 чинила для QR, и
  /// она вернулась под другим именем, потому что ответ был про **вид**,
  /// а вопрос — про **чек**.
  ///
  /// # Правило, которое эти пробы закрепляют
  ///
  /// Уезжает чек, в котором **есть безналичная строка и нет наличной**.
  /// Вето принадлежит только наличным: выборочность «только безнал» про
  /// то и заведена, чтобы наличный чек остался вне оператора. Строка,
  /// которая сегодняшними деньгами не является (зачёт, бонус, долг),
  /// чек ни к оператору не ведёт, ни от него не уводит.
  ///
  /// # Чего эти пробы НЕ доказывают
  ///
  /// Ничего про содержимое конверта: сойдутся ли позиции с оплатами у
  /// такого чека — вопрос `fiscal_envelope_balance_test`, и он там
  /// спрошен отдельно. Здесь проверяется **только** решение «уезжает ли
  /// вообще».
  group('выборочная фискализация смотрит на состав чека', () {
    test('«карта плюс сертификат» уезжает оператору целиком', () async {
      await cashlessOnly();

      final needed = await isOfdSale(
        db: db,
        fiscal: const _EnabledFiscal(),
        payments: [
          entry(SystemPaymentKindIds.card, bankAccountId, '4000'),
          entry(SystemPaymentKindIds.certificate, certificateAccountId, '1000'),
        ],
        selectiveOfd: false,
      );

      expect(
        needed,
        isTrue,
        reason:
            'картой взяты настоящие деньги. Гашение сертификата не оплата — '
            'но и не довод против документа: без него чек «деньги взяты, '
            'документа нет», и кассиру об этом не сказано ничего',
      );
    });

    test('«карта плюс бонус» уезжает оператору целиком', () async {
      await cashlessOnly();

      expect(
        await isOfdSale(
          db: db,
          fiscal: const _EnabledFiscal(),
          payments: [
            entry(SystemPaymentKindIds.card, bankAccountId, '900'),
            entry(SystemPaymentKindIds.bonus, bonusAccountId, '100'),
          ],
          selectiveOfd: false,
        ),
        isTrue,
        reason:
            'бонус не платёж вовсе (`notAPayment`) — и потому не может '
            'отменить документ по картовой части чека',
      );
    });

    test('«QR плюс долг» уезжает оператору целиком', () async {
      await cashlessOnly();

      expect(
        await isOfdSale(
          db: db,
          fiscal: const _EnabledFiscal(),
          payments: [
            entry(SystemPaymentKindIds.qr, bankAccountId, '700'),
            entry(SystemPaymentKindIds.debt, agentAccountId, '300'),
          ],
          selectiveOfd: false,
        ),
        isTrue,
        reason:
            'долг — обязательство вместо денег, но телефоном заплачено '
            'по-настоящему',
      );
    });

    test('чек, закрытый одним сертификатом, НЕ уезжает', () async {
      await cashlessOnly();

      expect(
        await isOfdSale(
          db: db,
          fiscal: const _EnabledFiscal(),
          payments: [
            entry(
              SystemPaymentKindIds.certificate,
              certificateAccountId,
              '1000',
            ),
          ],
          selectiveOfd: false,
        ),
        isFalse,
        reason:
            'сегодняшнего расчёта нет вовсе: деньги за бумажку пришли '
            'раньше. Слом в обратную сторону — «пропускаем всё, где нет '
            'наличных» зелен и здесь',
      );
    });

    test('«наличные плюс сертификат» НЕ уезжает', () async {
      await cashlessOnly();

      expect(
        await isOfdSale(
          db: db,
          fiscal: const _EnabledFiscal(),
          payments: [
            entry(SystemPaymentKindIds.cash, posAccountId, '600'),
            entry(
              SystemPaymentKindIds.certificate,
              certificateAccountId,
              '400',
            ),
          ],
          selectiveOfd: false,
        ),
        isFalse,
        reason:
            'вето наличной строки осталось: выборочность «только безнал» '
            'ради этого и заведена',
      );
    });

    test('чек из одних бонусов НЕ уезжает', () async {
      await cashlessOnly();

      expect(
        await isOfdSale(
          db: db,
          fiscal: const _EnabledFiscal(),
          payments: [entry(SystemPaymentKindIds.bonus, bonusAccountId, '500')],
          selectiveOfd: false,
        ),
        isFalse,
        reason: 'безналичных денег в чеке нет ни одной строкой',
      );
    });
  });

  group('роль строки в составе чека названа у каждого члена', () {
    /// Та же таблица, что у [FiscalTreatment.isCashless], и с тем же
    /// доводом: перечисляется `values` целиком, новый член без строки
    /// красит сторожа в день добавления.
    ///
    /// Ролей три, и они не сводятся к одному признаку: **ведёт** к
    /// оператору (безналичные деньги), **уводит** (наличные), **молчит**
    /// (не сегодняшние деньги).
    test('у каждого члена FiscalTreatment роль названа явно', () {
      const vetoes = <FiscalTreatment, bool>{
        FiscalTreatment.cash: true,
        FiscalTreatment.card: false,
        FiscalTreatment.credit: false,
        FiscalTreatment.mobile: false,
        FiscalTreatment.tare: false,
        FiscalTreatment.notAPayment: false,
        FiscalTreatment.offsetNotFiscal: false,
      };

      expect(
        vetoes.keys.toSet(),
        FiscalTreatment.values.toSet(),
        reason:
            'член перечисления без роли в составе чека — это чек, о судьбе '
            'которого никто не решал',
      );

      for (final e in vetoes.entries) {
        expect(e.key.isCash, e.value, reason: e.key.name);
        // Ни один член не может одновременно вести и уводить.
        expect(
          e.key.isCash && e.key.isCashless,
          isFalse,
          reason: '${e.key.name}: наличные и безналичные разом',
        );
        // Строка сама по себе: ведёт — уезжает, иначе нет.
        expect(
          FiscalTreatment.receiptIsCashless([e.key]),
          e.key.isCashless,
          reason: '${e.key.name}: чек из одной такой строки',
        );
        // Рядом с картой: уводит только наличная.
        expect(
          FiscalTreatment.receiptIsCashless([FiscalTreatment.card, e.key]),
          !e.key.isCash,
          reason: '${e.key.name}: рядом с картой',
        );
      }
    });

    test('чек без строк оплаты оператору не уезжает', () {
      expect(
        FiscalTreatment.receiptIsCashless(const []),
        isFalse,
        reason:
            'пустой состав — не «безналичный чек», а отсутствие денег; '
            'иначе выборочность пропускала бы всё, что не разобрано',
      );
    });
  });

  group('таблица безналичности покрывает перечисление целиком', () {
    /// Не покрытие, а **таблица**: `values` перечисляется весь, и новый
    /// член, которому здесь не назначили ответа, красит сторожа в день
    /// добавления — а не через полгода на чужой кассе.
    test('у каждого члена FiscalTreatment ответ назван явно', () {
      const expected = <FiscalTreatment, bool>{
        FiscalTreatment.cash: false,
        FiscalTreatment.card: true,
        // Долг и рассрочка — обязательство, а не безналичные деньги.
        FiscalTreatment.credit: false,
        FiscalTreatment.mobile: true,
        // Тара — возврат залога, деньгами оператора не считается.
        FiscalTreatment.tare: false,
        // Бонус не платёж вовсе.
        FiscalTreatment.notAPayment: false,
        // Зачёт ранее внесённых денег — сегодняшнего расчёта нет.
        FiscalTreatment.offsetNotFiscal: false,
      };

      expect(
        expected.keys.toSet(),
        FiscalTreatment.values.toSet(),
        reason:
            'член перечисления без строки в этой таблице — беда, о которой '
            'узнают на кассе клиента',
      );
      for (final entry in expected.entries) {
        expect(
          entry.key.isCashless,
          entry.value,
          reason: entry.key.name,
        );
      }
    });
  });
}

/// Оператор включён — и всё. Здесь проверяется **политика**, а не разговор
/// с оператором: разговор проверяется эмулятором WebKassa, у которого есть
/// адрес и восемнадцать вызываемых отказов.
class _EnabledFiscal implements FiscalService {
  const _EnabledFiscal();

  @override
  Future<bool> isEnabled() async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} здесь не нужен');
}
