/// Экран приёма аванса — требование заказчика 2026-09-18.
///
/// # Что доказывается здесь, а не пробой провода
///
/// Проба провода (`wt_prepayment_intake_test.dart`) доказывает, что взнос
/// доходит до денег. Она **не доказывает, что кассир может его сделать**, —
/// ровно этот класс дефекта дерево ловило трижды: операции отзыва сеанса
/// были готовы и недостижимы; `pay.certificateIssue` написана и не имеет ни
/// одного вызывающего; сам приём аванса был верен и недостижим из браузера.
///
/// Четыре беды, каждая своей пробой:
///
/// 1. **покупатель находится по телефону** — иначе экран бесполезен: у
///    браузера нет картотеки, и другого входа к покупателю тоже нет;
/// 2. **заявка уходит теми полями, которые набрал кассир** — покупатель,
///    сумма, вид оплаты. Экран, отправляющий не то, что показал, хуже
///    неработающего;
/// 3. **отказ кассы доезжает фразой словаря, а не русским текстом кассы** —
///    тот самый дефект, ради которого заведён `ErrorLocalizer`;
/// 4. **беда фискализации не прячется за успехом** — деньги приняты, чека
///    нет, и кассир обязан узнать об этом словом.
///
/// # Пятая беда — выдача, решение заказчика 2026-09-18
///
/// «В браузере должно работать то же, что в приложении». Выдача аванса
/// живёт на **этом же** экране переключателем направления, и у неё своя
/// ловушка, которой у приёма нет: кассир, нажавший «Принять», получивший
/// обрыв и переключившийся на «Выдать», послал бы **прежний ключ** — и
/// касса, узнав в нём повтор приёма, ответила бы «принято» на просьбу
/// выдать. Ключ на экране не рисуется, глазами это не видно, и доказать
/// можно только пробой.
///
/// # Почему подделки контрактов, а не петля провода
///
/// Потому что проверяется **экран**, и подделка позволяет назвать ответ
/// кассы, который петлёй пришлось бы подстраивать базой. Что эти же
/// контракты работают над настоящей кассой, доказано петлёй в соседнем
/// файле; повторять это здесь значило бы мерить второй раз одно и то же.
library;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';
import 'package:telepos/core/logging/app_talker.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/domain/payment/payment_kind.dart';
import 'package:telepos/domain/payment/prepayment_intake.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/prepayment/prepayment_intake_screen.dart';

void main() {
  late _FakePayments payments;
  late _FakeIntake intake;
  late _FakeRefund refund;

  Decimal d(String v) => Decimal.parse(v);

  // Журнал ставит точка входа; под пробой её нет, а экран пишет в него
  // причину отказа (она на экран не едет — едет фраза словаря).
  setUpAll(() => installLogger(Talker()));

  setUp(() {
    payments = _FakePayments();
    intake = _FakeIntake();
    refund = _FakeRefund();
    GetIt.I
      ..registerSingleton<PaymentService>(payments)
      ..registerSingleton<PrepaymentIntakeService>(intake)
      ..registerSingleton<PrepaymentRefundService>(refund);
  });

  tearDown(() => GetIt.I.reset());

  Future<AppLocalizations> pump(WidgetTester tester) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('ru'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context)!;
              return const PrepaymentIntakeScreen();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return l10n;
  }

  Future<void> lookUp(WidgetTester tester, String phone) async {
    await tester.enterText(find.byKey(const ValueKey('prepayment-phone')), phone);
    await tester.tap(find.byKey(const ValueKey('prepayment-find')));
    await tester.pumpAndSettle();
  }

  /// Переключить направление на выдачу (или обратно на приём).
  Future<void> switchTo(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester, String amount) async {
    await tester.enterText(
      find.byKey(const ValueKey('prepayment-amount')),
      amount,
    );
    await tester.tap(find.byKey(const ValueKey('prepayment-submit')));
    await tester.pumpAndSettle();
  }

  testWidgets('покупатель находится по телефону, остаток — ответ кассы', (
    tester,
  ) async {
    await pump(tester);

    // До поиска полей взноса нет вовсе: сумма без покупателя — заявка,
    // которую некуда отправить.
    expect(find.byKey(const ValueKey('prepayment-amount')), findsNothing);

    await lookUp(tester, '77015550000');

    expect(payments.searched, ['77015550000']);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('prepayment-customer'))).data,
      'Айгуль',
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('prepayment-balance'))).data,
      contains('700.00'),
      reason: 'остаток показан тот, что назвала касса',
    );
    expect(find.byKey(const ValueKey('prepayment-amount')), findsOneWidget);
  });

  testWidgets('незнакомый номер — фраза словаря, а не пустой экран', (
    tester,
  ) async {
    final l10n = await pump(tester);
    payments.customer = null;

    await lookUp(tester, '77010000000');

    expect(
      tester.widget<Text>(find.byKey(const ValueKey('prepayment-error'))).data,
      l10n.prepaymentIntakeNotFound,
    );
    expect(find.byKey(const ValueKey('prepayment-amount')), findsNothing);
  });

  testWidgets('заявка уходит теми полями, которые набрал кассир', (
    tester,
  ) async {
    final l10n = await pump(tester);
    await lookUp(tester, '77015550000');

    // Вид оплаты — карта: умолчание наличные, и проба, не трогающая
    // переключатель, зеленела бы и на экране, который его не читает.
    await tester.tap(find.text(l10n.paymentCard));
    await tester.pumpAndSettle();

    await submit(tester, '1500,50');

    expect(intake.asks, hasLength(1));
    expect(intake.asks.single.customerId, 5);
    expect(
      intake.asks.single.amount,
      d('1500.5'),
      reason: 'запятая — тот же разделитель, что и точка',
    );
    expect(intake.asks.single.tenderKindId, SystemPaymentKindIds.card);

    // И кассир видит, что приём состоялся, — сальдо из ответа кассы.
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('prepayment-done'))).data,
      contains('2200.50'),
    );
    expect(find.byKey(const ValueKey('prepayment-error')), findsNothing);
  });

  testWidgets('ноль не уезжает на кассу вовсе', (tester) async {
    final l10n = await pump(tester);
    await lookUp(tester, '77015550000');

    await submit(tester, '0');

    expect(intake.asks, isEmpty, reason: 'круг за заведомый отказ не платим');
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('prepayment-error'))).data,
      l10n.customerPaymentAmountInvalid,
    );
  });

  testWidgets('отказ кассы — фраза словаря, а не русский текст кассы', (
    tester,
  ) async {
    final l10n = await pump(tester);
    await lookUp(tester, '77015550000');

    intake.refusal = const WireRefusal(
      prepaymentTenderInvalidCode,
      'Деньги покупателя принимаются наличными, картой или по QR',
    );
    await submit(tester, '1000');

    final shown = tester
        .widget<Text>(find.byKey(const ValueKey('prepayment-error')))
        .data;
    expect(shown, l10n.errorPrepaymentTenderInvalid);
    expect(
      shown,
      isNot('Деньги покупателя принимаются наличными, картой или по QR'),
      reason: 'текст кассы написан по-русски внутри кассы и на экран не едет',
    );
  });

  testWidgets('код, которого терминал не знает, не молчит', (tester) async {
    await pump(tester);
    await lookUp(tester, '77015550000');

    intake.refusal = const WireRefusal('zz_never_named', 'что-то случилось');
    await submit(tester, '1000');

    final shown = tester
        .widget<Text>(find.byKey(const ValueKey('prepayment-error')))
        .data!;
    expect(shown, isNotEmpty);
    expect(
      shown,
      isNot(contains('что-то случилось')),
      reason: 'текст неизвестного кода на экран не едет (И144)',
    );
  });

  testWidgets('деньги приняты, чека нет — кассир узнаёт об этом словом', (
    tester,
  ) async {
    final l10n = await pump(tester);
    await lookUp(tester, '77015550000');

    intake.fiscalError = 'network';
    await submit(tester, '1000');

    // Обе строки сразу: успех приёма и беда документа — разные вещи, и
    // спрятать вторую за первой значило бы соврать про чек.
    expect(find.byKey(const ValueKey('prepayment-done')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('prepayment-error'))).data,
      l10n.prepaymentIntakeFiscalFailed,
    );
  });

  /// Ключ повтора — пятая беда экрана, дефект живой приёмки 2026-09-18.
  ///
  /// Касса опознаёт повтор ключом заявки, но опознать ей нечего, если
  /// **экран** шлёт на второе нажатие новый ключ. Иначе говоря, вся защита
  /// держится на том, что здесь и меряется, и ничем другим доказана быть не
  /// может: касса видит два кадра и не знает, из какой формы они набраны.
  group('ключ заявки', () {
    testWidgets('повтор после отказа шлёт ТОТ ЖЕ ключ', (tester) async {
      await pump(tester);
      await lookUp(tester, '77015550000');

      // Провод оборвался: ответ до вкладки не доехал, экран показал отказ.
      // Касса при этом деньги уже приняла — но экран об этом не знает и
      // знать не может.
      intake.refusal = const WireRefusal(
        'stream_failed',
        'WebTransportError: Connection lost',
      );
      await submit(tester, '1000');

      // Кассир жмёт «Принять» снова, ничего не правя.
      intake.refusal = null;
      await tester.tap(find.byKey(const ValueKey('prepayment-submit')));
      await tester.pumpAndSettle();

      expect(intake.asks, hasLength(2));
      expect(
        intake.asks[1].key,
        intake.asks[0].key,
        reason: 'форма не правлена — заявка та же, и ключ обязан быть тем же',
      );
      expect(intake.asks[0].key, isNotEmpty);
    });

    testWidgets('новая заявка после успеха получает НОВЫЙ ключ', (
      tester,
    ) async {
      await pump(tester);
      await lookUp(tester, '77015550000');

      await submit(tester, '1000');
      // Успех очищает поле суммы; кассир набирает её заново — это уже
      // другая заявка, и второй взнос той же тысячи законен.
      await submit(tester, '1000');

      expect(intake.asks, hasLength(2));
      expect(
        intake.asks[1].key,
        isNot(intake.asks[0].key),
        reason: 'ключ, переживший успех, съел бы законный второй взнос',
      );
    });

    testWidgets('правка суммы после отказа рождает новый ключ', (tester) async {
      await pump(tester);
      await lookUp(tester, '77015550000');

      intake.refusal = const WireRefusal('stream_failed', 'Connection lost');
      await submit(tester, '1000');

      // Кассир передумал: не тысяча, а сотня. Прежний ключ здесь был бы
      // хуже, чем бесполезен — касса ответила бы **прежним исходом на
      // тысячу**, и экран показал бы успех приёма отменённой суммы.
      intake.refusal = null;
      await submit(tester, '100');

      expect(intake.asks, hasLength(2));
      expect(intake.asks[1].amount, d('100'));
      expect(intake.asks[1].key, isNot(intake.asks[0].key));
    });

    testWidgets('смена НАПРАВЛЕНИЯ после отказа рождает новый ключ', (
      tester,
    ) async {
      // **Самая дорогая из правок формы**, и единственная, которой у приёма
      // не было. Прежний ключ здесь означал бы, что касса узнаёт в просьбе
      // выдать повтор приёма — и отвечает «принято», не выдав ни копейки.
      // Экран при этом показал бы успех.
      final l10n = await pump(tester);
      await lookUp(tester, '77015550000');

      intake.refusal = const WireRefusal('stream_failed', 'Connection lost');
      await submit(tester, '1000');

      intake.refusal = null;
      await switchTo(tester, l10n.prepaymentRefundTitle);
      await tester.enterText(
        find.byKey(const ValueKey('prepayment-amount')),
        '1000',
      );
      await tester.tap(find.byKey(const ValueKey('prepayment-submit')));
      await tester.pumpAndSettle();

      expect(intake.asks, hasLength(1), reason: 'вторая заявка — выдача');
      expect(refund.asks, hasLength(1));
      expect(
        refund.asks.single.key,
        isNot(intake.asks.single.key),
        reason: 'ключ, переживший смену направления, отдал бы просьбе выдать '
            'исход приёма',
      );
    });

    testWidgets('смена вида оплаты после отказа рождает новый ключ', (
      tester,
    ) async {
      final l10n = await pump(tester);
      await lookUp(tester, '77015550000');

      intake.refusal = const WireRefusal('stream_failed', 'Connection lost');
      await submit(tester, '1000');

      // У переключателя нет слушателя текста, и забыть его здесь было бы
      // легче всего: экран выглядел бы правильным, а карта принималась бы
      // как наличные того же ключа.
      intake.refusal = null;
      await tester.tap(find.text(l10n.paymentCard));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('prepayment-submit')));
      await tester.pumpAndSettle();

      expect(intake.asks, hasLength(2));
      expect(intake.asks[1].tenderKindId, SystemPaymentKindIds.card);
      expect(intake.asks[1].key, isNot(intake.asks[0].key));
    });
  });

  /// Выдача аванса — решение заказчика 2026-09-18.
  ///
  /// Проба здесь про **экран**: что кнопка есть, что она зовёт выдачу своим
  /// контрактом, и что заявка уходит теми полями, которые набрал кассир. Что
  /// выдача доходит до денег, доказывают пробы операции.
  group('выдача аванса', () {
    testWidgets('кнопка «Выдать» зовёт выдачу, а не приём', (tester) async {
      final l10n = await pump(tester);
      await lookUp(tester, '77015550000');

      await switchTo(tester, l10n.prepaymentRefundTitle);
      await submit(tester, '300.005');

      // Несущая часть: приём **не** позван. Экран, зовущий приём на кнопке
      // «Выдать», принял бы деньги там, где их просили отдать, и показал бы
      // успех.
      expect(intake.asks, isEmpty);
      expect(refund.asks, hasLength(1));
      expect(refund.asks.single.customerId, 5);
      // Третий знак: 300.005 в двойной точности не представима, и `double`
      // где-нибудь по дороге превратил бы её в 300.00499…
      expect(refund.asks.single.amount, d('300.005'));
      expect(refund.asks.single.tenderKindId, SystemPaymentKindIds.cash);
      expect(refund.asks.single.key, isNotEmpty);
      // Основание вкладка не выдумывает: списка проводок покупателя у неё
      // нет, и сослаться на чужой документ она права не имеет.
      expect(refund.asks.single.intakeOperationId, isNull);
    });

    testWidgets('остаток после выдачи — ответ кассы, а не вычитание', (
      tester,
    ) async {
      final l10n = await pump(tester);
      await lookUp(tester, '77015550000');

      await switchTo(tester, l10n.prepaymentRefundTitle);
      // Касса отвечает заведомо «неправильным» с точки зрения арифметики
      // вкладки числом. Экран обязан показать **его**: сложить у себя
      // значило бы завести второй источник правды о деньгах.
      refund.balance = d('42.500');
      await submit(tester, '300.005');

      expect(
        find.text(l10n.prepaymentRefundDone('42.50')),
        findsOneWidget,
      );
    });

    testWidgets('отказ выдачи доезжает фразой словаря, а не текстом кассы', (
      tester,
    ) async {
      final l10n = await pump(tester);
      await lookUp(tester, '77015550000');

      await switchTo(tester, l10n.prepaymentRefundTitle);
      refund.refusal = const WireRefusal(
        prepaymentRefundExceedsBalanceCode,
        'На счёте покупателя нет такой суммы аванса',
      );
      await submit(tester, '5000');

      expect(
        find.text(l10n.errorPrepaymentRefundExceedsBalance),
        findsOneWidget,
      );
      expect(
        find.text('На счёте покупателя нет такой суммы аванса'),
        findsNothing,
        reason: 'русский текст кассы на экран не едет вовсе — он в журнале',
      );
    });

    testWidgets('беда документа не прячется за успехом выдачи', (
      tester,
    ) async {
      // Деньги отданы, документа нет. Показать это отказом значило бы
      // предложить кассиру выдать их второй раз; промолчать — отправить
      // покупателя без документа.
      final l10n = await pump(tester);
      await lookUp(tester, '77015550000');

      await switchTo(tester, l10n.prepaymentRefundTitle);
      refund.fiscalError = 'network';
      await submit(tester, '300');

      expect(find.text(l10n.prepaymentRefundFiscalFailed), findsOneWidget);
      expect(
        find.text(l10n.prepaymentRefundDone('42.50')),
        findsNothing,
        reason: 'страховка от вырождения: сальдо здесь другое',
      );
    });

    testWidgets('исключение без кода даёт фразу ВЫДАЧИ, а не приёма', (
      tester,
    ) async {
      // Обрыв провода приходит сюда и при выдаче. «Аванс принять не
      // удалось» на экране выдачи отправило бы кассира искать беду не там.
      final l10n = await pump(tester);
      await lookUp(tester, '77015550000');

      await switchTo(tester, l10n.prepaymentRefundTitle);
      refund.crash = true;
      await submit(tester, '300');

      expect(find.text(l10n.errorPrepaymentRefundFailed), findsOneWidget);
      expect(find.text(l10n.errorPrepaymentIntakeFailed), findsNothing);
    });
  });
}

class _FakePayments implements PaymentService {
  final List<String> searched = [];

  LoyaltyCustomer? customer = LoyaltyCustomer(
    id: 5,
    phone: '77015550000',
    name: 'Айгуль',
    bonusBalance: Decimal.zero,
  );

  @override
  Future<LoyaltyCustomer?> findLoyalty(String phone) async {
    searched.add(phone);
    return customer;
  }

  @override
  Future<Decimal> prepaymentBalance(int customerId) async =>
      Decimal.parse('700');

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

/// Касса, выдающая аванс. Подделка по тому же доводу, что [_FakeIntake]:
/// проверяется экран, а не путь кадра до денег.
class _FakeRefund implements PrepaymentRefundService {
  final List<PrepaymentRefundRequest> asks = [];

  /// Чем касса ответит. `null` — выдала.
  WireRefusal? refusal;

  /// Исключение **без кода** — обрыв провода, падение обработчика.
  bool crash = false;

  String? fiscalError;

  /// Сальдо после выдачи — то, что скажет касса, а не то, что вычтет экран.
  Decimal balance = Decimal.parse('400');

  @override
  Future<PrepaymentRefundOutcome> payOutPrepayment(
    PrepaymentRefundRequest ask,
  ) async {
    // Заявка записывается **до** отказа, по тому же доводу, что у приёма:
    // ключ повтора имеет смысл ровно на той попытке, которая не доехала.
    asks.add(ask);
    if (crash) throw StateError('провод оборвался');
    final refused = refusal;
    if (refused != null) throw refused;
    return PrepaymentRefundOutcome(
      operationId: 2,
      balance: balance,
      fiscalError: fiscalError,
    );
  }
}

class _FakeIntake implements PrepaymentIntakeService {
  final List<PrepaymentIntakeRequest> asks = [];

  /// Чем касса ответит. `null` — приняла.
  WireRefusal? refusal;

  String? fiscalError;

  @override
  Future<PrepaymentIntakeOutcome> acceptPrepayment(
    PrepaymentIntakeRequest ask,
  ) async {
    // Заявка записывается **до** отказа, а не после: ключ повтора имеет
    // смысл ровно на той попытке, которая не доехала, и проба, не видящая
    // отказанных заявок, не увидела бы и его.
    asks.add(ask);
    final refused = refusal;
    if (refused != null) throw refused;
    return PrepaymentIntakeOutcome(
      operationId: 1,
      // Сальдо считает касса: 700 было + взнос.
      balance: Decimal.parse('700') + ask.amount,
      fiscalError: fiscalError,
    );
  }
}
