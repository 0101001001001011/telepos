import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';
import 'package:telepos/presentation/controllers/payment/payment_controller.dart';
import 'package:telepos/presentation/screens/payment/widgets/payment_type_selector.dart';

import '../../../helpers/mock_providers.dart';

/// Кнопка «В долг» и первый читатель `sellInDebt` — задача 16.
///
/// # Что здесь доказывается, а что — не здесь
///
/// Здесь — **экран**: кнопка появляется тогда и только тогда, когда
/// сошлись тумблер кассы и право кассира, и в каждом из трёх отказных
/// случаев называет свою причину. Отказ **кассы** сторожат свои пробы и
/// эта задача их не снимает: `local_payment_service_debt_toggle_test.dart`
/// (тумблер, `debt_not_sold_here`), `pay_ops_access_test.dart` и
/// `wt_payment_service_test.dart` (право `op.sellDebt`). Погашенная
/// кнопка защитой не является (I44, I162), и ни одна проба ниже на неё
/// не опирается.
///
/// # Почему кнопка не исчезает ни в одном отказном случае
///
/// В презентационном слое уже 33 места, где кнопка пропадает без единого
/// слова, и два из них врут. Тридцать четвёртым это не станет: кассир,
/// которому нужен долг, обязан узнать, что вид существует и чего именно
/// не хватает, а не гадать.
class _RecordingPaymentNotifier extends MockPaymentNotifier {
  _RecordingPaymentNotifier(super.initialState);

  final chosen = <PaymentType>[];

  @override
  void setPaymentType(PaymentType type) => chosen.add(type);
}

void main() {
  Widget harness(
    _RecordingPaymentNotifier notifier, {
    required Set<String> permissions,
  }) {
    return ProviderScope(
      overrides: [
        paymentControllerProvider.overrideWith(() => notifier),
        appStateProvider.overrideWith(
          () => MockAppStateNotifier(AppState(permissions: permissions)),
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
        supportedLocales: const [Locale('en'), Locale('ru')],
        locale: const Locale('ru'),
        home: const Scaffold(body: PaymentTypeSelector()),
      ),
    );
  }

  _RecordingPaymentNotifier notifierFor(bool? sellInDebt) =>
      _RecordingPaymentNotifier(
        PaymentState(
          totalAmount: Decimal.fromInt(1000),
          sellInDebt: sellInDebt,
        ),
      );

  const withDebt = {PermissionKeys.navSale, PermissionKeys.opSellDebt};
  const withoutDebt = {PermissionKeys.navSale};

  const button = Key('payment_type_button_debt');
  const lock = Key('payment_type_locked_debt');
  const reason = Key('payment_debt_denied_reason');

  Future<String> tapAndRead(WidgetTester tester) async {
    await tester.tap(find.byKey(button));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final found = find.byKey(reason);
    expect(
      found,
      findsOneWidget,
      reason: 'погашенная кнопка обязана называть причину, а не молчать',
    );
    return tester.widget<Text>(found).data ?? '';
  }

  group('тройное условие', () {
    testWidgets('сошлось всё — кнопка живая и выбирает долг', (tester) async {
      final notifier = notifierFor(true);
      await tester.pumpWidget(harness(notifier, permissions: withDebt));
      await tester.pumpAndSettle();

      expect(find.byKey(button), findsOneWidget);
      expect(
        find.byKey(lock),
        findsNothing,
        reason: 'замка на разрешённом виде быть не должно',
      );

      await tester.tap(find.byKey(button));
      await tester.pumpAndSettle();
      expect(notifier.chosen, [PaymentType.debt]);
    });

    testWidgets('нет права — кнопка на месте, погашена, вид не меняется', (
      tester,
    ) async {
      final notifier = notifierFor(true);
      await tester.pumpWidget(harness(notifier, permissions: withoutDebt));
      await tester.pumpAndSettle();

      expect(find.byKey(button), findsOneWidget);
      expect(find.byKey(lock), findsOneWidget);

      await tapAndRead(tester);
      expect(
        notifier.chosen,
        isEmpty,
        reason: 'экран не заставляет кассира делать заведомо отвергаемое',
      );
    });

    testWidgets('тумблер кассы выключен — кнопка на месте и погашена', (
      tester,
    ) async {
      final notifier = notifierFor(false);
      await tester.pumpWidget(harness(notifier, permissions: withDebt));
      await tester.pumpAndSettle();

      expect(
        find.byKey(button),
        findsOneWidget,
        reason: 'молча исчезнувшая кнопка — тридцать четвёртое такое место',
      );
      expect(find.byKey(lock), findsOneWidget);

      await tapAndRead(tester);
      expect(notifier.chosen, isEmpty);
    });

    testWidgets('нет ни тумблера, ни права — тоже погашена', (tester) async {
      final notifier = notifierFor(false);
      await tester.pumpWidget(harness(notifier, permissions: withoutDebt));
      await tester.pumpAndSettle();

      expect(find.byKey(lock), findsOneWidget);
      await tapAndRead(tester);
      expect(notifier.chosen, isEmpty);
    });

    testWidgets('касса ещё не ответила — кнопка погашена, но не «нельзя»', (
      tester,
    ) async {
      final notifier = notifierFor(null);
      await tester.pumpWidget(harness(notifier, permissions: withDebt));
      await tester.pumpAndSettle();

      expect(find.byKey(button), findsOneWidget);
      expect(find.byKey(lock), findsOneWidget);
      await tapAndRead(tester);
      expect(notifier.chosen, isEmpty);
    });
  });

  group('причина называется своя на каждый случай', () {
    testWidgets('выключенный тумблер отправляет в настройки кассы', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(notifierFor(false), permissions: withDebt),
      );
      await tester.pumpAndSettle();

      final text = (await tapAndRead(tester)).toLowerCase();
      expect(
        text,
        contains('кредит'),
        reason: 'названо, чего именно нет на этой кассе',
      );
      expect(
        text,
        contains('настройк'),
        reason: 'названо, где это меняется',
      );
      expect(
        text,
        isNot(contains('право')),
        reason: 'права здесь ни при чём — кассир пошёл бы не туда',
      );
    });

    testWidgets('отсутствующее право отправляет к администратору', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(notifierFor(true), permissions: withoutDebt),
      );
      await tester.pumpAndSettle();

      final text = (await tapAndRead(tester)).toLowerCase();
      expect(text, contains('прав'), reason: 'названо, чего не хватает');
      expect(
        text,
        contains('администратор'),
        reason: 'названо, кто это выдаёт',
      );
    });

    testWidgets('молчание кассы называется молчанием, а не запретом', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(notifierFor(null), permissions: withDebt),
      );
      await tester.pumpAndSettle();

      final text = (await tapAndRead(tester)).toLowerCase();
      expect(text, contains('не ответила'));
      expect(
        text,
        isNot(contains('не разрешено')),
        reason: 'неотвеченный вопрос — не запрет, и врать про это нельзя',
      );
    });

    testWidgets('три случая дают три разных текста', (tester) async {
      // Один текст на три беды отправил бы кассира не туда с той же
      // уверенностью, с какой отправляет молчащая кнопка.
      final texts = <String>[];
      for (final c in [
        (sell: false, perms: withDebt),
        (sell: true, perms: withoutDebt),
        (sell: null, perms: withDebt),
      ]) {
        // Дерево сносится между случаями: без этого полоса предыдущего
        // случая доживает свои шесть секунд, и проба читает её текст
        // вместо нового — то есть краснела бы на верной реализации и
        // зеленела бы на трёх одинаковых текстах.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          harness(notifierFor(c.sell), permissions: c.perms),
        );
        await tester.pumpAndSettle();
        texts.add(await tapAndRead(tester));
      }
      expect(texts.toSet(), hasLength(3), reason: '$texts');
    });
  });

  group('долг не путается с набором видов рабочего места', () {
    testWidgets('запрет места на наличные не гасит долг', (tester) async {
      // Набор видов долг не сторожит вовсе (`paymentTypeOfferable`).
      // Гасить его по набору значило бы завести на экране запрет,
      // которого у кассы нет.
      final notifier = _RecordingPaymentNotifier(
        PaymentState(
          totalAmount: Decimal.fromInt(1000),
          allowedPaymentTypes: const {PaymentType.card},
          sellInDebt: true,
        ),
      );
      await tester.pumpWidget(harness(notifier, permissions: withDebt));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('payment_type_locked_cash')), findsOneWidget);
      expect(find.byKey(lock), findsNothing);

      await tester.tap(find.byKey(button));
      await tester.pumpAndSettle();
      expect(notifier.chosen, [PaymentType.debt]);
    });

    testWidgets('погашенный долг не попадает в подпись «место принимает»', (
      tester,
    ) async {
      // Подпись говорит о наборе рабочего места. Долг в неё не входит:
      // он этим набором не запрещён, и упоминание его там было бы
      // утверждением про запрет, которого нет.
      final notifier = _RecordingPaymentNotifier(
        PaymentState(
          totalAmount: Decimal.fromInt(1000),
          allowedPaymentTypes: const {PaymentType.cash, PaymentType.card},
          sellInDebt: false,
        ),
      );
      await tester.pumpWidget(harness(notifier, permissions: withDebt));
      await tester.pumpAndSettle();

      expect(find.byKey(lock), findsOneWidget, reason: 'долг погашен');
      expect(
        find.byKey(const Key('payment_types_limited_note')),
        findsNothing,
        reason: 'место не ограничено — подпись была бы шумом и неправдой',
      );
    });
  });
}
