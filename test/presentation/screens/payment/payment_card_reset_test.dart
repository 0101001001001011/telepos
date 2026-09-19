/// Две правки круга 4 задачи 14, обе — путём экрана, а не контракта.
///
/// 1. **Правка карточной суммы после проведения снимает реквизиты.** Память
///    кассы о проведении ключуется суммой; экран, оставивший старый код
///    одобрения при новой сумме, посылал бы в чек реквизиты чужого
///    платежа, а устройство списывало бы второй раз.
/// 2. **Пустой выбор счёта остаётся пустым.** `AccountSelector` сам
///    подставлял счёт с признаком умолчания — кассовый — и в том же кадре
///    отменял сброс, который делает контроллер; смешанная оплата и долг с
///    наличной частью на кассе без видимых банковских счетов не проходили
///    вовсе.
///
/// Обе прежние пробы этого не видели: они дёргали контроллер напрямую и
/// экран не монтировали.
library;

import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';
import 'package:telepos/core/logging/app_talker.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/payment/gift_certificate.dart';
import 'package:telepos/domain/sale/payment_service.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/payment/payment_controller.dart';
import 'package:telepos/presentation/controllers/sale/sale_controller.dart';
import 'package:telepos/presentation/screens/payment/payment_screen.dart';
import 'package:telepos/presentation/screens/payment/widgets/account_selector.dart';

import 'package:telepos/presentation/controllers/app/app_state_controller.dart';

import '../../../helpers/mock_providers.dart';

void main() {
  Decimal d(String v) => Decimal.parse(v);

  late _FakePayments payments;

  ProviderContainer boot({List<PaymentAccount> accounts = const []}) {
    // Журнал ставит точка входа; под виджет-пробой её нет, а контроллер
    // пишет в него по пути завершения оплаты.
    if (!isLoggerReady) installLogger(Talker());
    payments = _FakePayments(accounts);
    if (GetIt.I.isRegistered<PaymentService>()) {
      GetIt.I.unregister<PaymentService>();
    }
    GetIt.I.registerSingleton<PaymentService>(payments);
    final container = ProviderContainer(
      overrides: [
        saleControllerProvider.overrideWith(MockSaleNotifier.new),
        paymentAccountsProvider.overrideWith((ref) async => accounts),
        // Задача 16: селектор видов оплаты читает право `op.sellDebt` из
        // сеанса (`hasPermissionProvider`). Настоящий `AppStateNotifier`
        // заводит в `build` часы и сторож места — периодические таймеры,
        // которые переживают дерево и роняют пробу «A Timer is still
        // pending». Подделка их не заводит; прав у неё нет, и это верно
        // для этого файла: он про кнопку «Оплатить», а не про долг.
        appStateProvider.overrideWith(MockAppStateNotifier.new),
      ],
    );
    addTearDown(() {
      // Проба про закрытый экран закрывает контейнер сама — второй раз
      // закрывать нечего, и Riverpod это позволяет.
      container.dispose();
      if (GetIt.I.isRegistered<PaymentService>()) {
        GetIt.I.unregister<PaymentService>();
      }
    });
    return container;
  }

  group('реквизиты карты не переживают правку суммы', () {
    /// Провести карту **настоящим путём экрана** и убедиться, что
    /// реквизиты легли: иначе снимать было бы нечего и проба вырождена.
    Future<void> charge(
      ProviderContainer container,
      String amount, {
      required PaymentType type,
    }) async {
      final notifier = container.read(paymentControllerProvider.notifier);
      notifier.initialize(d('1000'));
      notifier.setPaymentType(type);
      if (type != PaymentType.card) notifier.setCardAmount(d(amount));

      await notifier.chargeCardViaTerminal(d(amount));

      final state = container.read(paymentControllerProvider);
      expect(state.terminalApprovalCode, '123456');
      expect(state.terminalChargedAmount, d(amount));
    }

    testWidgets('правка карточной суммы снимает реквизиты и говорит об этом', (
      tester,
    ) async {
      final container = boot();
      await charge(container, '650', type: PaymentType.mixed);

      container
          .read(paymentControllerProvider.notifier)
          .setCardAmount(d('500'));

      final state = container.read(paymentControllerProvider);
      expect(state.terminalApprovalCode, isNull);
      expect(state.terminalChargedAmount, isNull);
      expect(
        state.error,
        'error.card_charge_unsettled:650',
        reason: 'кассир обязан узнать сумму, которая осталась непогашенной',
      );
    });

    testWidgets('та же сумма реквизиты не трогает', (tester) async {
      // Страховка от вырождения: сброс держится на **изменении** суммы, а
      // не на самом факте правки поля — иначе повторный ввод того же
      // числа заставлял бы проводить карту заново.
      final container = boot();
      await charge(container, '650', type: PaymentType.mixed);

      container
          .read(paymentControllerProvider.notifier)
          .setCardAmount(d('650'));

      final state = container.read(paymentControllerProvider);
      expect(state.terminalApprovalCode, '123456');
      expect(state.error, isNull);
    });

    testWidgets('цифра в наличное поле реквизиты не трогает', (tester) async {
      // Вторая страховка: снимается то, что меняет **безналичную** часть,
      // а не любое нажатие.
      final container = boot();
      await charge(container, '650', type: PaymentType.mixed);

      final notifier = container.read(paymentControllerProvider.notifier);
      notifier.setActiveInput(PaymentInputField.cash);
      notifier.numpadKey('1');

      expect(
        container.read(paymentControllerProvider).terminalApprovalCode,
        '123456',
      );
    });

    testWidgets('бонус снимает реквизиты чистой карты', (tester) async {
      // Тот же механизм с другой стороны, и он существовал **до** задачи
      // 14: безналичная часть чистой карты — это сумма к оплате, а бонус
      // её меняет.
      final container = boot();
      await charge(container, '1000', type: PaymentType.card);

      final notifier = container.read(paymentControllerProvider.notifier);
      await notifier.searchLoyaltyCustomer('77015550000');
      await notifier.setBonusToUse(d('150'));

      final state = container.read(paymentControllerProvider);
      expect(state.bonusToUse, d('150'));
      expect(state.terminalApprovalCode, isNull);
      expect(state.error, 'error.card_charge_unsettled:1000');
    });
  });

  group('непогашенное проведение не теряется молча', () {
    // Круг правки 5: смена вида оплаты (**одно нажатие «Наличные»**) и
    // повторный вход на экран стирали память о проведении вместе с
    // реквизитами — сторож, выведенный из данных, до неё не доезжал, а
    // кассиру не говорилось ничего. Причина устранимая: после успешного
    // завершения реквизиты не снимались, и «погашено» было неотличимо от
    // «непогашено».
    Future<void> charge(ProviderContainer container) async {
      final notifier = container.read(paymentControllerProvider.notifier);
      notifier.initialize(d('1000'));
      notifier.setPaymentType(PaymentType.mixed);
      notifier.setCardAmount(d('650'));
      await notifier.chargeCardViaTerminal(d('650'));
      expect(
        container.read(paymentControllerProvider).terminalChargedAmount,
        d('650'),
      );
    }

    testWidgets('нажатие «Наличные» после проведения называет сумму', (
      tester,
    ) async {
      final container = boot();
      await charge(container);

      container
          .read(paymentControllerProvider.notifier)
          .setPaymentType(PaymentType.cash);

      final state = container.read(paymentControllerProvider);
      expect(state.error, 'error.card_charge_unsettled:650');
      expect(state.terminalChargedAmount, isNull);
    });

    testWidgets('повторный вход на экран называет сумму', (tester) async {
      final container = boot();
      await charge(container);

      container.read(paymentControllerProvider.notifier).initialize(d('1000'));

      expect(
        container.read(paymentControllerProvider).error,
        'error.card_charge_unsettled:650',
      );
    });

    testWidgets('смена вида оплаты после погашенного проведения молчит', (
      tester,
    ) async {
      // Страховка от вырождения: сообщение обязано означать
      // «непогашено», а не «карту вообще проводили». Без снятия реквизитов
      // по успеху оно приходило бы после каждой честной оплаты картой.
      final container = boot();
      await charge(container);
      final notifier = container.read(paymentControllerProvider.notifier);
      notifier.setCashReceived(d('350'));

      expect(await notifier.processPayment(), isTrue);
      expect(
        container.read(paymentControllerProvider).terminalChargedAmount,
        isNull,
        reason: 'успех обязан гасить память о проведении',
      );

      notifier.setPaymentType(PaymentType.cash);

      expect(container.read(paymentControllerProvider).error, isNull);
    });
  });

  group('экран закрылся, а деньги взяты', () {
    testWidgets('оплата, дошедшая до кассы, возвращает успех', (tester) async {
      // **Круг правки 5 сломал то, что закрывал круг 4.**
      // `_forgetCardCharge(settled: true)` встал строкой **выше** ветви
      // `if (_disposed) return true`, которую круг 4 добавил ровно затем,
      // чтобы вызывающий не узнал «не получилось» о том, что получилось.
      // `_forgetCardCharge` читает геттер `state`, тот после закрытия
      // бросает, собственный `catch` глотает — и `processPayment`
      // возвращал `false` о **взятых деньгах**.
      //
      // Дефект был недостижим в продукте (контейнер один на приложение,
      // `lib/web/main_web.dart`, никем не сбрасывается) — поэтому проба
      // закрывает контейнер **сама**, посреди обмена с кассой.
      final container = boot();
      final notifier = container.read(paymentControllerProvider.notifier);
      notifier.initialize(d('1000'));
      notifier.setPaymentType(PaymentType.cash);
      notifier.setCashReceived(d('1000'));

      final hold = Completer<void>();
      payments.holdComplete = hold;
      final inFlight = notifier.processPayment();

      // Экран закрыт **посреди** оплаты: касса уже спрошена, ответа ещё
      // нет. Ждать входа в кассу — про **эту** пробу, а не обход чужой
      // дыры: она про то, что дошедшая до кассы оплата возвращает успех.
      // Закрытие **до** входа проверяется отдельно, соседней пробой —
      // прежде оно выпускало исключение наружу, и это чинилось вместе с
      // входом в оплату.
      await payments.entered.future;
      container.dispose();
      hold.complete();

      expect(
        await inFlight,
        isTrue,
        reason: 'деньги взяты — вызывающий не должен узнать «не получилось»',
      );
    });
  });

  group('кассир видит текст, а не ключ', () {
    testWidgets('сообщение о непогашенном проведении переведено и с суммой', (
      tester,
    ) async {
      // **Проба, которой не было.** Прежние проверяли `state.error ==
      // 'error.card_charge_unsettled:650'` — то есть половину
      // контроллера. Что кассир видит **переведённую строку с суммой**, а
      // не голый ключ, не доказывал никто: снятие перевода целиком
      // оставляло набор зелёным.
      // Переполнение по вёрстке на тестовом холсте — не предмет этой
      // пробы; тот же приём, что в `payment_screen_test.dart`.
      final original = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        original?.call(details);
      };
      addTearDown(() => FlutterError.onError = original);
      tester.view.physicalSize = const Size(1600, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = boot();
      final notifier = container.read(paymentControllerProvider.notifier);
      notifier.initialize(d('1000'));
      notifier.setPaymentType(PaymentType.mixed);
      notifier.setCardAmount(d('650'));
      await notifier.chargeCardViaTerminal(d('650'));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en'), Locale('ru')],
            locale: const Locale('ru'),
            home: const PaymentScreen(),
          ),
        ),
      );
      await tester.pump();

      // Кассир правит карточную часть — прежнее проведение осталось
      // непогашенным.
      notifier.setCardAmount(d('500'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.textContaining('650'),
        findsWidgets,
        reason: 'кассиру не названа сумма, которую сняли с покупателя',
      );
      expect(
        find.textContaining('error.card_charge_unsettled'),
        findsNothing,
        reason: 'кассиру показан ключ вместо текста',
      );
      expect(
        find.textContaining('Отмените операцию на платёжном терминале'),
        findsOneWidget,
      );
    });
  });

  group('закрытие до входа в кассу не выпускает исключение наружу', () {
    testWidgets('оплата отказывает значением, а не броском', (tester) async {
      // **Правка, приехавшая «заодно», и потому без пробы.** Резолв
      // рабочего места и первая запись состояния стояли **вне**
      // перехвата: экран, закрытый в этот момент, ронял `processPayment`
      // броском наружу вместо отказа значением (I144). Починено вместе с
      // входом в оплату; здесь это закреплено, иначе строка уедет обратно
      // и набор не заметит.
      //
      // Закрытие происходит **до** входа в кассу — тем и отличается от
      // соседней пробы: там касса уже спрошена и деньги взяты, здесь до
      // них дело не дошло.
      final container = boot();
      final notifier = container.read(paymentControllerProvider.notifier);
      notifier.initialize(d('1000'));
      notifier.setPaymentType(PaymentType.cash);
      notifier.setCashReceived(d('1000'));

      final inFlight = notifier.processPayment();
      container.dispose();

      expect(await inFlight, isFalse);
      expect(
        payments.completed,
        0,
        reason: 'до кассы дело не дошло — и не должно было',
      );
    });
  });

  group('пустой выбор счёта остаётся пустым', () {
    Widget build(ProviderContainer container) => UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('ru')],
        locale: const Locale('ru'),
        home: const Scaffold(body: AccountSelector()),
      ),
    );

    testWidgets('селектор не подставляет счёт за кассира', (tester) async {
      // Касса без видимых банковских счетов: предлагается только кассовый,
      // и он же помечен умолчанием.
      final container = boot(
        accounts: const [PaymentAccount(id: 2, name: 'Касса', isDefault: true)],
      );

      final notifier = container.read(paymentControllerProvider.notifier);
      notifier.initialize(d('1000'));
      notifier.setPaymentType(PaymentType.cash);
      await tester.pumpAndSettle();
      expect(
        container.read(paymentControllerProvider).selectedAccountId,
        2,
        reason: 'наличные выбирают счёт кассы — иначе проба вырождена',
      );

      notifier.setPaymentType(PaymentType.mixed);
      await tester.pumpWidget(build(container));
      await tester.pumpAndSettle();

      expect(
        container.read(paymentControllerProvider).selectedAccountId,
        isNull,
        reason: 'селектор вернул счёт, который контроллер только что снял',
      );
    });

    testWidgets('нажатие кассира выбор ставит', (tester) async {
      // Страховка от вырождения: снят **автоподбор**, а не сам выбор.
      final container = boot(
        accounts: const [
          PaymentAccount(id: 2, name: 'Касса', isDefault: true),
          PaymentAccount(id: 1, name: 'Банк'),
        ],
      );

      final notifier = container.read(paymentControllerProvider.notifier);
      notifier.initialize(d('1000'));
      notifier.setPaymentType(PaymentType.card);

      await tester.pumpWidget(build(container));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Банк'));
      await tester.pump();

      expect(container.read(paymentControllerProvider).selectedAccountId, 1);
    });
  });
}

/// Касса, которая всегда одобряет карту и знает одного клиента.
class _FakePayments implements PaymentService {
  @override
  Future<String?> qrUnavailableReason() async => null;

  @override
  Future<Decimal> prepaymentBalance(int customerId) async => Decimal.zero;

  @override
  Future<GiftCertificate> findCertificate(String number, {String? pin}) =>
      throw UnimplementedError('проба про карту, а не про сертификат');

  @override
  Future<QrTender> startQr(int t, Decimal a, CartCommandMeta m) =>
      throw UnimplementedError('проба про карту, а не про QR');

  @override
  Future<QrTender> pollQr(int t, String k) =>
      throw UnimplementedError('проба про карту, а не про QR');

  @override
  Future<QrTender> cancelQr(int t, String k) =>
      throw UnimplementedError('проба про карту, а не про QR');

  _FakePayments(this.offered);

  final List<PaymentAccount> offered;
  final chargedAmounts = <Decimal>[];

  /// Пока не исполнен, завершение оплаты висит: даёт пробе закрыть экран
  /// **посреди** обмена, а не до него.
  Completer<void>? holdComplete;

  /// Исполняется, когда касса **вошла** в завершение оплаты.
  final entered = Completer<void>();

  /// Сколько раз касса завершала оплату.
  int completed = 0;

  @override
  Future<List<PaymentAccount>> accounts() async => offered;

  @override
  Future<bool> sellsInDebt() async => true;

  @override
  Future<LoyaltyCustomer?> findLoyalty(String phone) async => LoyaltyCustomer(
    id: 5,
    phone: phone,
    name: 'Айгуль',
    bonusBalance: Decimal.fromInt(500),
  );

  @override
  Future<Decimal> reserveBonus(int customerId, Decimal amount) async => amount;

  @override
  Future<CardCharge> chargeCard(
    int terminalId,
    Decimal amount,
    CartCommandMeta meta,
  ) async {
    chargedAmounts.add(amount);
    return CardCharge(
      outcome: CardChargeOutcome.approved,
      amount: amount,
      approvalCode: '123456',
      cardMask: '**** 4242',
      transactionId: 'tx-1',
    );
  }

  @override
  Future<SaleOutcome> complete(
    int terminalId,
    PaymentRequest request,
    CartCommandMeta meta,
  ) async {
    completed++;
    if (!entered.isCompleted) entered.complete();
    await holdComplete?.future;
    return SaleOutcome(
      receiptNo: 1,
      posId: 1,
      amount: Decimal.fromInt(1000),
      change: Decimal.zero,
      paid: Decimal.fromInt(1000),
      debt: Decimal.zero,
    );
  }

  @override
  Future<List<CompletionTrouble>> hardwareTroubles(
    int terminalId,
    int receiptNo,
  ) async => const [];
}
