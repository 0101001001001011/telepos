/// Экран оплаты зовёт эквайринг при **любой** безналичной части — задача
/// 14, круг правки 3.
///
/// **Проба идёт путём экрана, а не через контракт.** Расхождение было
/// именно между ними: экран звал платёжный терминал только при чистой
/// карте (`paymentType == card`), а касса требовала доказательства
/// проведения при любой безналичной части (`LocalPaymentService
/// ._requireCardProof`). На кассе с привязанным Kaspi смешанная оплата и
/// долг с картой отвергались `card_charge_unproven` — то есть не работали
/// вовсе. Четыре пробы круга правки 2 этого не увидели, потому что все
/// звали контракт напрямую и ни одна не шла по смешанной оплате.
library;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/payment/payment_controller.dart';
import 'package:telepos/presentation/screens/payment/payment_screen.dart';

import '../../../helpers/mock_providers.dart';

void main() {
  Decimal d(String v) => Decimal.parse(v);

  late MockPaymentNotifier notifier;

  Widget build(PaymentState state) {
    notifier = MockPaymentNotifier(state)..completes = false;
    return ProviderScope(
      overrides: [
        paymentControllerProvider.overrideWith(() => notifier),
        paymentAccountsProvider.overrideWith((ref) async => <PaymentAccount>[]),
      ],
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
        home: PaymentScreen(amount: state.totalAmount),
      ),
    );
  }

  Future<void> pressPay(
    WidgetTester tester,
    PaymentState state, {
    int taps = 1,
  }) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    // Переполнение по ширине — свойство вёрстки экрана на тестовом
    // холсте, а не предмет этой пробы; тот же приём, что и в
    // `payment_screen_test.dart`.
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);

    await tester.pumpWidget(build(state));
    await tester.pump();
    final button = find.byKey(const Key('payment_complete'));
    expect(button, findsOneWidget, reason: 'кнопку оплаты надо чем-то нажать');

    // Обработчик зовётся **напрямую и синхронно**, а не через
    // `tester.tap`, и вот что про это измерено (поправка после
    // переразбора: прежнее объяснение здесь было выведено, а не
    // измерено, и оказалось неверным).
    //
    // `tester.tap` внутри себя прогоняет очередь микрозадач, поэтому два
    // подряд идущих «нажатия» выполняются **по очереди**: первый ход
    // успевает дойти до `finally` и сам гасит признак обработки — тем
    // более что подделка заводится с `completes = false`. Второе нажатие
    // становится **законной повторной попыткой**, а не гонкой, и
    // эквайринг зовётся дважды **и на исправленном коде тоже**: проба на
    // `tester.tap` красная одинаково с диверсией и без неё, то есть не
    // различает их вовсе.
    //
    // Прямой синхронный зов и есть то, что делает кассир: два нажатия в
    // **одном кадре**, до всякой перерисовки и до того, как первый ход
    // дошёл до своего `finally`.
    final onPressed = tester.widget<ElevatedButton>(button).onPressed;
    expect(onPressed, isNotNull, reason: 'кнопка обязана быть живой');
    for (var i = 0; i < taps; i++) {
      onPressed!();
    }
    await tester.pump();
    await tester.pump();
  }

  testWidgets('смешанная оплата зовёт эквайринг на безналичную часть', (
    tester,
  ) async {
    await pressPay(
      tester,
      PaymentState(
        totalAmount: d('1150'),
        paymentType: PaymentType.mixed,
        cashReceived: d('500'),
        cardAmount: d('650'),
      ),
    );

    expect(notifier.chargedAmounts, [d('650')]);
  });

  testWidgets('долг с картой зовёт эквайринг на карточную часть', (
    tester,
  ) async {
    await pressPay(
      tester,
      PaymentState(
        totalAmount: d('1150'),
        paymentType: PaymentType.debt,
        cashReceived: d('100'),
        cardAmount: d('400'),
      ),
    );

    expect(notifier.chargedAmounts, [d('400')]);
  });

  testWidgets('чистая карта — вся сумма к оплате', (tester) async {
    // Прежнее поведение обязано остаться прежним: правка расширяет
    // условие, а не подменяет число.
    await pressPay(
      tester,
      PaymentState(totalAmount: d('1150'), paymentType: PaymentType.card),
    );

    expect(notifier.chargedAmounts, [d('1150')]);
  });

  testWidgets('карта после бонуса — за вычетом бонуса', (tester) async {
    // Страховка от подмены суммы: безналичная часть считается от суммы к
    // оплате, а не от итога чека.
    await pressPay(
      tester,
      PaymentState(
        totalAmount: d('1150'),
        paymentType: PaymentType.card,
        bonusToUse: d('150'),
        loyaltyCustomer: LoyaltyCustomer(
          id: 1,
          phone: '77015550000',
          name: 'Айгуль',
          bonusBalance: d('150'),
        ),
      ),
    );

    expect(notifier.chargedAmounts, [d('1000')]);
  });

  testWidgets('двойное нажатие «Оплатить» зовёт эквайринг один раз', (
    tester,
  ) async {
    // **Одновременность, а не последовательность.** Признак обработки
    // ставился только перед завершением оплаты, поэтому кнопка жила весь
    // обмен с устройством, а сторож в начале обработчика читал тот же
    // ложный признак: два нажатия давали **два настоящих списания**.
    // Круг 3 поднял цену — эквайринг зовётся и в смешанной, и в долге.
    await pressPay(
      tester,
      PaymentState(
        totalAmount: d('1150'),
        paymentType: PaymentType.mixed,
        cashReceived: d('500'),
        cardAmount: d('650'),
      ),
      taps: 2,
    );

    expect(notifier.chargedAmounts, [d('650')]);
  });

  testWidgets('наличная оплата эквайринг не зовёт', (tester) async {
    // Страховка от вырождения: условие «любая безналичная часть» не
    // должно превратиться в «всегда» — иначе касса без карты звала бы
    // терминал на каждую продажу.
    await pressPay(
      tester,
      PaymentState(
        totalAmount: d('1150'),
        paymentType: PaymentType.cash,
        cashReceived: d('1150'),
      ),
    );

    expect(notifier.chargedAmounts, isEmpty);
  });

  testWidgets('смешанная без карточной части эквайринг не зовёт', (
    tester,
  ) async {
    // Кассир выбрал «смешанную», но всю сумму даёт наличными: проводить
    // нечего, и обращаться к устройству не за чем.
    await pressPay(
      tester,
      PaymentState(
        totalAmount: d('1150'),
        paymentType: PaymentType.mixed,
        cashReceived: d('1150'),
      ),
    );

    expect(notifier.chargedAmounts, isEmpty);
  });
}
