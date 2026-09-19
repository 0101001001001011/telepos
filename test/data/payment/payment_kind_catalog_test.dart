/// Справочник видов оплаты: семь правил связности и то, чего у него нет.
///
/// # Главное утверждение здесь — «настройкой кассу не уронить»
///
/// Не «таблица пишется». Справочник, принимающий что угодно, — это
/// способ уронить кассу настройкой: вид без счёта-получателя выбирается
/// на экране и падает при первой оплате сырым отказом базы, а тендер,
/// объявленный «не платежом», молча завышает базу налога. Каждое из семи
/// правил проверяется **своим** отказом, и каждое — тем случаем, который
/// достижим с экрана настроек.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/payment/payment_kind_catalog_impl.dart';
import 'package:telepos/domain/account/account_type.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/payment/payment_kind_catalog.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

PaymentKind _userKind({
  int id = SystemPaymentKindIds.firstUserId,
  String code = 'gift',
  PaymentSettlement settlement = PaymentSettlement.tender,
  FiscalTreatment fiscal = FiscalTreatment.cash,
  int? payeeAccountType = AccountType.pos,
  bool requiresCounterparty = false,
  bool requiresProvider = false,
  bool givesChange = false,
  bool isActive = true,
  bool isSystem = false,
}) => PaymentKind(
  id: id,
  code: code,
  name: 'Пользовательский',
  settlement: settlement,
  fiscalTreatment: fiscal,
  payeeAccountType: payeeAccountType,
  requiresCounterparty: requiresCounterparty,
  requiresProvider: requiresProvider,
  givesChange: givesChange,
  isActive: isActive,
  isSystem: isSystem,
);

Future<String?> _refusalOf(
  PaymentKindCatalog catalog,
  PaymentKind kind,
) async {
  try {
    await catalog.upsert(kind);
    return null;
  } on WireRefusal catch (r) {
    return r.code;
  }
}

void main() {
  late AppDatabase db;
  late PaymentKindCatalog catalog;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    catalog = PaymentKindCatalogImpl(db);
  });

  tearDown(() => db.close());

  group('посев', () {
    test('девять системных видов, и все девять связны', () async {
      final kinds = await catalog.all();
      expect(kinds.map((k) => k.id).toList(), SystemPaymentKindIds.all);
      for (final kind in kinds) {
        expect(
          PaymentKindRules.validate(kind, existing: kind),
          isNull,
          reason: 'системный вид ${kind.code} обязан проходить те же правила, '
              'которые касса требует от пользовательских',
        );
      }
    });

    test('в селектор попадают включённые и невспомогательные', () async {
      final selectable = await catalog.selectable();
      final codes = selectable.map((k) => k.code).toSet();

      expect(codes, {'cash', 'card', 'bonus', 'debt'});
      expect(
        codes.contains('agent_settlement'),
        isFalse,
        reason: 'расчёт с контрагентом — не тендер продажи, выбрать его '
            'кассиру нельзя',
      );
      expect(
        codes.contains('certificate'),
        isFalse,
        reason: 'виды 5–8 заведены выключенными',
      );
    });

    test('mixed в справочнике НЕТ', () async {
      // Смешанная оплата перестаёт быть видом и становится тем, чем
      // всегда была, — двумя строками.
      expect(await catalog.byCode('mixed'), isNull);
    });
  });

  group('семь правил связности', () {
    test('тендер нельзя объявить «не платежом»', () async {
      expect(
        await _refusalOf(
          catalog,
          _userKind(fiscal: FiscalTreatment.notAPayment),
        ),
        kindTenderCannotDiscountCode,
      );
    });

    test('включённому виду нужен счёт-получатель', () async {
      expect(
        await _refusalOf(catalog, _userKind(payeeAccountType: null)),
        kindAccountMissingCode,
      );
    });

    test('выключенному виду счёт ещё не нужен', () async {
      // Спрашивать счёт у выключенного вида значило бы требовать решения
      // до того, как оператор им занялся. Спрашивается он ровно при
      // включении.
      expect(
        await _refusalOf(
          catalog,
          _userKind(payeeAccountType: null, isActive: false),
        ),
        isNull,
      );
    });

    test('обязательство требует обязанного', () async {
      expect(
        await _refusalOf(
          catalog,
          _userKind(
            settlement: PaymentSettlement.deferred,
            fiscal: FiscalTreatment.credit,
            payeeAccountType: AccountType.agentMain,
          ),
        ),
        kindCounterpartyRequiredCode,
      );
    });

    test('внешний провайдер обязан быть назван', () async {
      expect(
        await _refusalOf(
          catalog,
          _userKind(
            fiscal: FiscalTreatment.mobile,
            payeeAccountType: AccountType.customBank,
          ),
        ),
        kindProviderRequiredCode,
      );
    });

    test('фискальная трактовка, приехавшая незнакомым словом, — отказ', () {
      // Достижимо ровно с экрана настроек и из выгрузки: там трактовка
      // едет строкой, и `FiscalTreatment.byCode` на незнакомом слове
      // отдаёт `null`. Проверяется на разборе, а не на upsert: тип
      // `PaymentKind` не даёт собрать вид без трактовки, и это правильно
      // — правило стоит на входе в тип.
      expect(FiscalTreatment.byCode('sberbank'), isNull);
      expect(FiscalTreatment.byCode('notAPayment'), FiscalTreatment.notAPayment);
    });

    test('сдачу даёт только тендер', () async {
      expect(
        await _refusalOf(
          catalog,
          _userKind(
            settlement: PaymentSettlement.offset,
            givesChange: true,
            payeeAccountType: AccountType.pos,
          ),
        ),
        kindChangeNotATenderCode,
        reason: 'сертификат со сдачей — это способ его обналичить',
      );
    });

    test('системный ид занять нельзя', () async {
      expect(
        await _refusalOf(
          catalog,
          _userKind(id: SystemPaymentKindIds.certificate, code: 'my_cert'),
        ),
        kindSystemImmutableCode,
      );
    });

    test('код системного вида менять нельзя', () async {
      final cash = (await catalog.byId(SystemPaymentKindIds.cash))!;
      expect(
        await _refusalOf(catalog, cash.copyWith(code: 'nal')),
        kindSystemImmutableCode,
      );
    });

    test('род расчёта системного вида менять нельзя', () async {
      final debt = (await catalog.byId(SystemPaymentKindIds.debt))!;
      expect(
        await _refusalOf(
          catalog,
          debt.copyWith(settlement: PaymentSettlement.tender),
        ),
        kindSystemImmutableCode,
        reason: 'долг, объявленный тендером, вернул бы его в выручку смены',
      );
    });

    test('чужой код занять нельзя — отказом, а не SqliteException', () async {
      expect(
        await _refusalOf(catalog, _userKind(code: 'cash')),
        kindSystemImmutableCode,
      );
    });

    test('у каждого правила свой код, и кодов ровно семь', () {
      expect(PaymentKindRules.codes.toSet(), hasLength(7));
    });
  });

  group('что у справочника настраивается', () {
    test('имя, счёт, фискальная трактовка и возврат — у системного тоже',
        () async {
      final card = (await catalog.byId(SystemPaymentKindIds.card))!;
      await catalog.upsert(
        card.copyWith(
          name: 'Банковская карта',
          payeeAccountType: AccountType.customCash,
          fiscalTreatment: FiscalTreatment.mobile,
          requiresProvider: true,
          refundAllowed: false,
        ),
      );

      final again = (await catalog.byId(SystemPaymentKindIds.card))!;
      expect(again.name, 'Банковская карта');
      expect(again.payeeAccountType, AccountType.customCash);
      expect(again.fiscalTreatment, FiscalTreatment.mobile);
      expect(again.refundAllowed, isFalse);
    });

    test('выключенный вид остаётся в справочнике, а не исчезает', () async {
      // `Payments.kindId` ссылается на строку навсегда: чек трёхлетней
      // давности обязан читаться. Метода `delete` у контракта нет.
      final cash = (await catalog.byId(SystemPaymentKindIds.cash))!;
      await catalog.upsert(cash.copyWith(isActive: false));

      expect(await catalog.byId(SystemPaymentKindIds.cash), isNotNull);
      expect(
        (await catalog.selectable()).map((k) => k.code),
        isNot(contains('cash')),
      );
    });
  });

  group('фискальная трактовка', () {
    test('бонус оператору платежом не идёт', () async {
      final bonus = (await catalog.byId(SystemPaymentKindIds.bonus))!;
      expect(bonus.fiscalTreatment, FiscalTreatment.notAPayment);
      expect(
        bonus.fiscalTreatment.toFiscalKind(),
        isNull,
        reason: 'бонус фискально — скидка: он списывается со счёта '
            'покупателя, счёт кассы не двигается, и объявить его платежом '
            'значит завысить базу налога',
      );
    });

    test('каждый остальной член переводится в вид оператора', () {
      for (final treatment in FiscalTreatment.values) {
        if (treatment == FiscalTreatment.notAPayment ||
            treatment == FiscalTreatment.offsetNotFiscal) {
          continue;
        }
        expect(treatment.toFiscalKind(), isNotNull, reason: treatment.name);
      }
    });
  });
}
