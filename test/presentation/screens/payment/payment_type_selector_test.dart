import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/payment/payment_controller.dart';
import 'package:telepos/presentation/screens/payment/widgets/payment_type_selector.dart';

import '../../../helpers/mock_providers.dart';

/// Селектор видов оплаты читает разрешения рабочего места — задача 15.
///
/// # Половина сторожа, которая живёт здесь, и половина, которая живёт не здесь
///
/// Здесь — **экран**: кассир на планшете «только безнал» не должен набирать
/// сумму наличными, чтобы узнать на «Оплатить», что этого нельзя. Отказ по
/// проводу, мимо экрана, сторожится своими пробами
/// (`test/backend/payment_types_test.dart`, группа «отказ приходит от кассы»)
/// и **не снимается** этой задачей: спрятанная кнопка защитой не является
/// (I162).
///
/// # Почему кнопка не исчезает
///
/// В презентационном слое уже 33 места, где кнопка пропадает без единого
/// слова, и два из них врут. Тридцать четвёртым это не станет: запрещённый
/// вид остаётся на экране погашенным, с замком, а нажатие на него называет
/// причину и место, где она меняется. Кассир узнаёт «нельзя, и вот почему»,
/// а не «куда делась кнопка».
class _RecordingPaymentNotifier extends MockPaymentNotifier {
  _RecordingPaymentNotifier(super.initialState);

  final chosen = <PaymentType>[];

  @override
  void setPaymentType(PaymentType type) => chosen.add(type);
}

void main() {
  Widget harness(_RecordingPaymentNotifier notifier) {
    return ProviderScope(
      overrides: [paymentControllerProvider.overrideWith(() => notifier)],
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
        home: const Scaffold(body: PaymentTypeSelector()),
      ),
    );
  }

  _RecordingPaymentNotifier notifierFor(Set<PaymentType> allowed) =>
      _RecordingPaymentNotifier(
        PaymentState(
          totalAmount: Decimal.fromInt(1000),
          allowedPaymentTypes: allowed,
        ),
      );

  group('рабочее место без ограничений', () {
    testWidgets('пустой набор означает «все» — три кнопки живые', (
      tester,
    ) async {
      final notifier = notifierFor(const {});
      await tester.pumpWidget(harness(notifier));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('payment_type_button_cash')), findsOneWidget);
      expect(find.byKey(const Key('payment_type_button_card')), findsOneWidget);
      expect(
        find.byKey(const Key('payment_type_button_mixed')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('payment_types_limited_note')),
        findsNothing,
        reason: 'ограничений нет — говорить об ограничении нечего',
      );

      await tester.tap(find.byKey(const Key('payment_type_button_cash')));
      await tester.pumpAndSettle();
      expect(notifier.chosen, [PaymentType.cash]);
    });
  });

  group('рабочее место «только безнал»', () {
    testWidgets('запрещённая кнопка остаётся на экране, а не исчезает', (
      tester,
    ) async {
      final notifier = notifierFor(const {PaymentType.card});
      await tester.pumpWidget(harness(notifier));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('payment_type_button_cash')),
        findsOneWidget,
        reason: 'молча исчезнувшая кнопка — тридцать четвёртое такое место',
      );
      expect(find.byKey(const Key('payment_type_button_card')), findsOneWidget);
      expect(
        find.byKey(const Key('payment_type_button_mixed')),
        findsOneWidget,
      );
    });

    testWidgets('запрещённая кнопка помечена замком, разрешённая — нет', (
      tester,
    ) async {
      final notifier = notifierFor(const {PaymentType.card});
      await tester.pumpWidget(harness(notifier));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('payment_type_locked_cash')), findsOneWidget);
      expect(
        find.byKey(const Key('payment_type_locked_mixed')),
        findsOneWidget,
        reason: 'смешанная — форма из двух половин, наличная запрещена',
      );
      expect(find.byKey(const Key('payment_type_locked_card')), findsNothing);
    });

    testWidgets('под кнопками названо, что рабочее место принимает', (
      tester,
    ) async {
      final notifier = notifierFor(const {PaymentType.card});
      await tester.pumpWidget(harness(notifier));
      await tester.pumpAndSettle();

      final note = find.byKey(const Key('payment_types_limited_note'));
      expect(note, findsOneWidget);
      expect(
        tester.widget<Text>(note).data,
        contains('безналичная'),
        reason: 'кассир обязан прочитать, что именно ему разрешено',
      );
      expect(
        tester.widget<Text>(note).data,
        isNot(contains('наличная,')),
        reason: 'перечислено разрешённое, а не всё подряд',
      );
    });

    testWidgets('нажатие на запрещённую не меняет вид оплаты', (tester) async {
      final notifier = notifierFor(const {PaymentType.card});
      await tester.pumpWidget(harness(notifier));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('payment_type_button_cash')));
      await tester.pumpAndSettle();

      expect(
        notifier.chosen,
        isEmpty,
        reason: 'экран не заставляет кассира делать заведомо отвергаемое',
      );
    });

    testWidgets('нажатие на запрещённую называет причину словами', (
      tester,
    ) async {
      final notifier = notifierFor(const {PaymentType.card});
      await tester.pumpWidget(harness(notifier));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('payment_type_button_cash')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final reason = find.byKey(const Key('payment_type_denied_reason'));
      expect(
        reason,
        findsOneWidget,
        reason: 'без этого кнопка гаснет молча — ровно то, чего нельзя',
      );
      final text = tester.widget<Text>(reason).data ?? '';
      expect(
        text,
        contains('Наличная'),
        reason: 'сказано, какой именно вид не разрешён',
      );
      expect(
        text.toLowerCase(),
        contains('оборудован'),
        reason: 'сказано, где это меняется',
      );
    });

    testWidgets('разрешённая кнопка работает по-прежнему', (tester) async {
      final notifier = notifierFor(const {PaymentType.card});
      await tester.pumpWidget(harness(notifier));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('payment_type_button_card')));
      await tester.pumpAndSettle();

      expect(notifier.chosen, [PaymentType.card]);
    });
  });

  group('рабочее место «только наличные»', () {
    testWidgets('карта погашена, наличные живые', (tester) async {
      final notifier = notifierFor(const {PaymentType.cash});
      await tester.pumpWidget(harness(notifier));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('payment_type_locked_card')), findsOneWidget);
      expect(find.byKey(const Key('payment_type_locked_cash')), findsNothing);

      await tester.tap(find.byKey(const Key('payment_type_button_cash')));
      await tester.pumpAndSettle();
      expect(notifier.chosen, [PaymentType.cash]);
    });
  });

  group('оба тендера разрешены явно', () {
    testWidgets('{cash, card} — ни одного замка и ни одной подписи', (
      tester,
    ) async {
      final notifier = notifierFor(const {PaymentType.cash, PaymentType.card});
      await tester.pumpWidget(harness(notifier));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('payment_type_locked_cash')), findsNothing);
      expect(find.byKey(const Key('payment_type_locked_card')), findsNothing);
      expect(find.byKey(const Key('payment_type_locked_mixed')), findsNothing);
      expect(
        find.byKey(const Key('payment_types_limited_note')),
        findsNothing,
        reason: 'запрещать нечего — подпись была бы шумом, а не честностью',
      );
    });
  });
}
