/// Экран договоров рассрочки — **погашение достижимо из продукта**.
///
/// # Что здесь доказывается, и почему это не косметика
///
/// Служба `CreditService` может быть безупречной и при этом мёртвой:
/// таблица пишется продажей, а читается ниоткуда. Ровно так в
/// `ThisPosEntries` третий год лежат три колонки без единого читателя.
/// Проба ниже ходит **настоящим экраном** поверх **настоящей базы** —
/// нажимает те кнопки, которые нажмёт кассир, — и утверждает, что после
/// нажатия сдвинулись **оба счёта** и строка графика.
///
/// Заглушки над службой здесь нет намеренно: подменённая служба доказала
/// бы, что экран умеет звать метод, а не что деньги двигаются.
library;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';

import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/account_dao.dart';
import 'package:telepos/data/database/daos/credit_dao.dart';
import 'package:telepos/data/payment/local_credit_service.dart';
import 'package:telepos/domain/payment/credit_contract.dart';
import 'package:telepos/domain/payment/credit_service.dart';
import 'package:telepos/domain/payment/installment_scheduler.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/credit/credit_contracts_screen.dart';

void main() {
  late AppDatabase db;

  const posAccountId = 11;
  const agentMainAccountId = 14;
  const customerId = 5;

  Decimal d(String v) => Decimal.parse(v);

  Future<Decimal> balanceOf(int id) async =>
      (await db.accountDao.findById(id))?.value ?? Decimal.zero;

  Future<void> seedAccount(int id, int type, {String value = '0'}) async {
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: Value(id),
            type: type,
            name: Value('Счёт $id'),
            value: Value(d(value)),
            visibleToPos: const Value(true),
          ),
        );
  }

  Future<void> openContract() async {
    await db.creditDao.insertContract(
      number: 'РС-1-1',
      agentLocalId: customerId,
      receivableAccountId: agentMainAccountId,
      receiptNo: 1,
      posId: 1,
      principal: d('900'),
      feeTotal: Decimal.zero,
      downPayment: Decimal.zero,
      termMonths: 3,
      scheme: InstallmentScheme.equalInstalments,
      signedAt: 1000,
      schedule: InstallmentScheduler.build(
        principal: d('900'),
        feeTotal: Decimal.zero,
        termMonths: 3,
        firstDueDate: DateTime(2026, 10, 1),
        scheme: InstallmentScheme.equalInstalments,
      ),
    );
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db
        .into(db.thisPosEntries)
        .insert(
          const ThisPosEntriesCompanion(
            id: Value(1),
            accountId: Value(posAccountId),
            companyName: Value('ТОО Ромашка'),
          ),
        );
    await db
        .into(db.users)
        .insert(const UsersCompanion(id: Value(4), name: Value('Айгуль')));
    await db
        .into(db.shifts)
        .insert(
          const ShiftsCompanion(
            userId: Value(4),
            openTime: Value(1000),
            isOpened: Value(true),
            isSynced: Value(false),
          ),
        );
    await seedAccount(posAccountId, AccountType.pos);
    await seedAccount(agentMainAccountId, AccountType.agentMain, value: '-900');

    GetIt.I.allowReassignment = true;
    GetIt.I.registerSingleton<AppDatabase>(db);
    GetIt.I.registerSingleton<CreditService>(
      LocalCreditService(db: db, logger: Talker()),
    );
  });

  tearDown(() async {
    await GetIt.I.reset();
    await db.close();
  });

  Widget host() => MaterialApp(
    theme: AppTheme.light,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('ru'), Locale('en')],
    locale: const Locale('ru'),
    home: const CreditContractsScreen(
      agentLocalId: customerId,
      agentName: 'Айгуль',
    ),
  );

  testWidgets('живой договор показан, и по нему видно ближайший платёж', (
    tester,
  ) async {
    await openContract();
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('credit_contract_РС-1-1')), findsOneWidget);
    expect(find.textContaining('Осталось: 900'), findsOneWidget);
    expect(find.textContaining('Ближайший платёж'), findsOneWidget);
  });

  testWidgets('без договоров экран говорит словами, а не пустотой', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('credit_contracts_empty')), findsOneWidget);
  });

  testWidgets('«Погасить целиком» двигает ОБА счёта и закрывает договор', (
    tester,
  ) async {
    await openContract();
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('credit_repay_РС-1-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('credit_repay_dialog')), findsOneWidget);
    // Остаток показан числом: досрочное погашение целиком — это ровно он.
    expect(find.textContaining('Осталось по договору: 900'), findsOneWidget);

    await tester.tap(find.byKey(const Key('credit_repay_whole')));
    await tester.pumpAndSettle();

    // Числа, а не «нажалось»: долг ушёл в ноль, деньги легли в ящик,
    // график закрыт, договор больше не живой.
    expect(await balanceOf(agentMainAccountId), Decimal.zero);
    expect(await balanceOf(posAccountId), d('900'));

    final row = (await db.creditDao.rowByNumber('РС-1-1'))!;
    expect(CreditDao.toDomain(row)!.status, CreditContractStatus.closed);
    expect(
      (await db.creditDao.scheduleRows(row.id)).map((e) => e.paidMillis),
      [300000, 300000, 300000],
    );

    // Закрытый договор исчез из списка живых.
    expect(find.byKey(const Key('credit_contracts_empty')), findsOneWidget);
  });

  testWidgets('переплата отвергается СЛОВАМИ, и ни один счёт не двинулся', (
    tester,
  ) async {
    await openContract();
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('credit_repay_РС-1-1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('credit_repay_amount')),
      '1000',
    );
    await tester.tap(find.byKey(const Key('credit_repay_confirm')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('credit_contracts_error')), findsOneWidget);
    // Причина названа числом остатка — тем самым, которое кассир наберёт
    // следующим.
    expect(find.textContaining('900'), findsWidgets);

    expect(await balanceOf(agentMainAccountId), d('-900'));
    expect(await balanceOf(posAccountId), Decimal.zero);
  });

  testWidgets('поиск по номеру находит договор с бумажки', (tester) async {
    await openContract();
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('credit_search_number')),
      'РС-1-1',
    );
    await tester.tap(find.byKey(const Key('credit_search_button')));
    await tester.pumpAndSettle();

    // Найденный показан отдельно, поверх списка: тот же договор виден
    // дважды — и это не дефект, а два разных ответа («что у покупателя» и
    // «что на бумажке»).
    expect(find.byKey(const Key('credit_contract_РС-1-1')), findsNWidgets(2));
  });

  testWidgets('КОНТРОЛЬНЫЙ МАРКЕР: чужого номера нет — и сказано словами', (
    tester,
  ) async {
    // Без него зелёный поиск выше означал бы «показывает что угодно».
    await openContract();
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('credit_search_number')),
      'РС-9-9',
    );
    await tester.tap(find.byKey(const Key('credit_search_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('credit_contracts_error')), findsOneWidget);
    expect(find.textContaining('РС-9-9'), findsWidgets);
    expect(find.byKey(const Key('credit_contract_РС-1-1')), findsOneWidget);
  });

  testWidgets('печатная форма показывает график, а не «печатается…»', (
    tester,
  ) async {
    await openContract();
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('credit_print_РС-1-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('credit_contract_preview')), findsOneWidget);
    expect(find.textContaining('ДОГОВОР РАССРОЧКИ'), findsOneWidget);
    expect(find.textContaining('ИТОГО К ОПЛАТЕ'), findsOneWidget);
  });
}
