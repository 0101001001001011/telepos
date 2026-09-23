/// Экран оплаты показывает фразу, а не ключ — круг правки 2, П4.
///
/// # Почему это отдельная проба, хотя словарь уже сторожится
///
/// Сторож словаря доказывает, что у ключа есть перевод. Он ничего не знает
/// о том, **зовёт ли экран локализатор**. Экран оплаты не звал:
/// `payment_screen.dart` печатал `PaymentState.error` сырьём, а
/// `ErrorLocalizer` во всём каталоге оплаты не встречался ни разу.
///
/// До задачи 23 это было почти безвредно — в состоянии лежала русская фраза
/// (`error.save_failed:<текст>` разбирался бы, но и сырьём читался). После
/// задачи 23 `PaymentNotifier.processPayment` кладёт туда **ключ отказа
/// кассы**, и кассир на экране оплаты читал бы `error.shift_not_open`
/// буквально — во всех пяти локалях сразу. Заголовок задачи «на его языке»
/// на этом пути не выполнялся.
///
/// Экран оплаты — тот самый путь, который отчёт задачи называет
/// единственным, которым отказ доезжал до человека до правки. Поэтому проба
/// смотрит на текст в дереве виджетов, а не на вызов локализатора.
library;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker/talker.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/logging/app_talker.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/utils/error_localizer.dart';
import 'package:telepos/presentation/controllers/payment/payment_controller.dart';
import 'package:telepos/presentation/screens/payment/payment_screen.dart';

import '../../../helpers/mock_providers.dart';

/// Оплата, которой отказ приходит уже после того, как экран собран:
/// слушатель `ref.listen` на начальное значение не срабатывает.
class _PushablePaymentNotifier extends MockPaymentNotifier {
  _PushablePaymentNotifier() : super(PaymentState(totalAmount: Decimal.zero));

  void refuse(String errorKey) => state = state.copyWith(error: errorKey);
}

void main() {
  setUpAll(() {
    // Экран оплаты логирует в `talker`, а тот назначается точкой входа.
    if (!isLoggerReady) installLogger(Talker());
  });

  Future<({_PushablePaymentNotifier payment, BuildContext ctx})> pumpPayment(
    WidgetTester tester,
    String locale,
  ) async {
    final notifier = _PushablePaymentNotifier();
    late BuildContext ctx;
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          paymentControllerProvider.overrideWith(() => notifier),
          paymentAccountsProvider.overrideWith(
            (ref) async => <PaymentAccount>[],
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale(locale),
          home: Scaffold(
            body: Builder(
              builder: (c) {
                ctx = c;
                return const PaymentScreen();
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (payment: notifier, ctx: ctx);
  }

  void suppressOverflowErrors() {
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.exceptionAsString();
      if (text.contains('overflowed') || text.contains('A RenderFlex')) return;
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);
  }

  testWidgets('ключ отказа кассы показан фразой, а не ключом (ru)', (
    tester,
  ) async {
    suppressOverflowErrors();
    final stand = await pumpPayment(tester, 'ru');
    final expected = ErrorLocalizer.localize(stand.ctx, 'error.shift_not_open');

    stand.payment.refuse('error.shift_not_open');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(
      find.text('error.shift_not_open'),
      findsNothing,
      reason:
          'Экран оплаты печатает `PaymentState.error` сырьём — кассир читает '
          'ключ. `PaymentNotifier.processPayment` кладёт сюда '
          '`saleController.error`, то есть с задачи 23 именно ключ.',
    );
    expect(find.text(expected), findsOneWidget);
  });

  testWidgets('кассир с казахским интерфейсом и здесь читает казахскую фразу', (
    tester,
  ) async {
    suppressOverflowErrors();
    final ru = (await AppLocalizations.delegate.load(
      const Locale('ru'),
    )).errorShiftNotOpen;

    final stand = await pumpPayment(tester, 'kk');
    final kk = ErrorLocalizer.localize(stand.ctx, 'error.shift_not_open');
    expect(kk, isNot(equals(ru)));

    stand.payment.refuse('error.shift_not_open');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text(kk), findsOneWidget);
    expect(
      find.text(ru),
      findsNothing,
      reason: 'кассиру с казахским интерфейсом показали русскую фразу',
    );
  });

  testWidgets('просроченная смена на экране оплаты — фраза, а не ключ', (
    tester,
  ) async {
    // Путь измерен, а не предположен: `completeSale` на просроченной смене
    // кладёт `kShiftOverAgeError` в состояние продажи
    // (`sale_controller.dart:620`), а `PaymentNotifier.processPayment`
    // копирует его оттуда в своё (`payment_controller.dart:728`). Смена,
    // перевалившая за сутки, пока чек набирался, — обычный случай.
    //
    // На экране продажи этот ключ — часовой: слушатель ловит его раньше
    // показа и открывает диалог. На экране оплаты часового нет, и до круга
    // правки 3 кассир читал здесь «error.shift_over_age» буквально.
    suppressOverflowErrors();
    final ru = (await AppLocalizations.delegate.load(
      const Locale('ru'),
    )).shiftOverAgeMessage;

    final stand = await pumpPayment(tester, 'kk');
    final kk = ErrorLocalizer.localize(stand.ctx, 'error.shift_over_age');
    expect(
      kk,
      isNot(equals(ru)),
      reason: 'казахского перевода нет — словарь отдаёт русскую строку',
    );

    stand.payment.refuse('error.shift_over_age');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(
      find.text('error.shift_over_age'),
      findsNothing,
      reason: 'кассир читает ключ вместо фразы',
    );
    expect(find.text(kk), findsOneWidget);
    expect(
      find.text(ru),
      findsNothing,
      reason: 'кассиру с казахским интерфейсом показали русскую фразу',
    );
  });

  group('отказы продажи в долг доезжают до кассира фразой (задача 16)', () {
    // Требование 3 задачи: молча брать «никого» нельзя — это деньги,
    // отданные в никуда. Касса и не берёт: `_plan` отвечает
    // `debt_customer_required`, если ни экран продажи
    // (`Sales.customerLocalId`), ни экран оплаты
    // (`PaymentState.loyaltyCustomer`) покупателя не назвали. Здесь
    // проверено, что этот отказ **виден кассиру словами**, а не остаётся
    // строкой в журнале: сторож `sale_refusal_codes_localized_test`
    // доказывает наличие перевода, но ничего не знает о том, показывает
    // ли его экран.
    for (final key in const [
      'error.debt_customer_required',
      'error.debt_not_sold_here',
    ]) {
      testWidgets('$key — фраза, а не ключ', (tester) async {
        suppressOverflowErrors();
        final stand = await pumpPayment(tester, 'ru');
        final expected = ErrorLocalizer.localize(stand.ctx, key);
        expect(
          expected,
          isNot(equals(key)),
          reason: 'страховка от вырождения: локализатор ключа не знает',
        );

        stand.payment.refuse(key);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));

        expect(find.text(key), findsNothing);
        expect(find.text(expected), findsOneWidget);
      });
    }
  });
}
