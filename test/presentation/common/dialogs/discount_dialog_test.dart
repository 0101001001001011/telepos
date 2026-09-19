import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/constants/app_constants.dart';
import 'package:telepos/domain/discount/discount_policy.dart';
import 'package:telepos/domain/services/currency_service.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/dialogs/discount_dialog.dart';
import 'package:telepos/presentation/common/widgets/keyboards/num_pad.dart';

Decimal d(String s) => Decimal.parse(s);

void main() {
  group('DiscountResult.calculate — деньги, а не рациональное число', () {
    // # Почему пример из плана (шаг 1 задачи 18) заменён
    //
    // План просил пробу «33 % от 100 не даёт периода». Она **зелена и до
    // правки**: 100 × 33 / 100 = 33 ровно. Больше того, периода здесь не
    // бывает в принципе — делитель сто раскладывается на 2²·5², и любое
    // десятичное, делённое на сто, остаётся конечным. То есть проба,
    // написанная по плану буквально, сторожила бы то, что сломать нельзя.
    //
    // Настоящий дефект — **разрядность**: 99.99 × 33.33 / 100 = 33.3266667,
    // шесть знаков после запятой при денежных трёх (P18,S3). Включённый
    // диалог отдал бы это число в `setDiscountAmount`, оттуда в
    // `_writeLine` → `price` → чек → ОФД.
    test('процент от нецелой суммы округляется до денежных знаков', () {
      final r = DiscountResult(
        type: DiscountType.percent,
        value: d('33.33'),
      ).calculate(d('99.99'));

      expect(r.scale, lessThanOrEqualTo(AppConstants.moneyScale));
      expect(r, d('33.327'));
    });

    test('процент от целой суммы не портится округлением', () {
      final r = DiscountResult(
        type: DiscountType.percent,
        value: d('33'),
      ).calculate(d('100'));
      expect(r, d('33'));
      expect(r.scale, lessThanOrEqualTo(AppConstants.moneyScale));
    });

    test('скидка суммой остаётся собой', () {
      final r = DiscountResult(
        type: DiscountType.fixed,
        value: d('12.5'),
      ).calculate(d('100'));
      expect(r, d('12.5'));
    });
  });

  group('Денежный потолок выводится из предела роли, а не задаётся вторым', () {
    test('до скольки денег = subtotal × maxPercent / 100', () {
      const dialog = DiscountDialog(cap: null, currencySymbol: '₸');
      expect(dialog.maxAmount, isNull, reason: 'предела нет — потолка нет');

      final withCap = DiscountDialog(
        currencySymbol: '₸',
        cap: DiscountCap(
          maxPercent: d('15'),
          approvalAbove: null,
          source: 'предел роли «Кассир»',
        ),
        subtotal: d('1000'),
      );
      expect(withCap.maxAmount, d('150'));
      expect(withCap.maxPercent, d('15'));
    });

    test('потолок округляется ВНИЗ — диалог не обещает больше, чем касса', () {
      // 15 % от 33.335 = 5.00025. `round(scale: 3)` дал бы 5.000 — здесь
      // совпало бы; берём случай, где round ушёл бы вверх: 15 % от 33.34 =
      // 5.001, а 15 % от 33.337 = 5.00055 → round 5.001, floor 5.000.
      // Касса меряет долей: 5.001 от 33.337 — это 15.0016 %, то есть
      // больше предела, и она откажет. Диалог обязан не предлагать.
      final dialog = DiscountDialog(
        currencySymbol: '₸',
        cap: DiscountCap(
          maxPercent: d('15'),
          approvalAbove: null,
          source: 'предел кассы по умолчанию',
        ),
        subtotal: d('33.337'),
      );
      expect(dialog.maxAmount, d('5'));
    });

    test('нулевая строка не даёт потолка (делить не на что)', () {
      final dialog = DiscountDialog(
        currencySymbol: '₸',
        cap: DiscountCap(maxPercent: d('15'), approvalAbove: null, source: 'x'),
        subtotal: Decimal.zero,
      );
      expect(dialog.maxAmount, isNull);
    });
  });

  group('Предел виден ДО ввода', () {

    Widget host(DiscountCap? cap, {Decimal? subtotal}) => MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ru'), Locale('en')],
      locale: const Locale('ru'),
      home: Scaffold(
        body: DiscountDialog(
          cap: cap,
          subtotal: subtotal ?? d('1000'),
          currencySymbol: '₸',
        ),
      ),
    );

    testWidgets('процент и чей это предел названы без единого нажатия', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          DiscountCap(
            maxPercent: d('15'),
            approvalAbove: null,
            source: 'предел роли «Кассир»',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ни одного ввода не сделано — а предел уже на экране.
      expect(find.byKey(const Key('discount_limit_hint')), findsOneWidget);
      expect(
        find.textContaining('Доступно до 15 %'),
        findsOneWidget,
        reason:
            'до правки предел жил только в тексте ошибки, то есть узнать '
            'его можно было единственным способом — нарушив',
      );
      expect(find.textContaining('предел роли «Кассир»'), findsOneWidget);
    });

    testWidgets('порог подтверждения старшего назван тоже', (tester) async {
      await tester.pumpWidget(
        host(
          DiscountCap(
            maxPercent: d('30'),
            approvalAbove: d('10'),
            source: 'предел кассы по умолчанию',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Выше 10 %'), findsOneWidget);
    });

    testWidgets('в режиме суммы предел назван деньгами, а не процентом', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          DiscountCap(
            maxPercent: d('15'),
            approvalAbove: null,
            source: 'предел роли «Кассир»',
          ),
          subtotal: d('1000'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Сумма'));
      await tester.pumpAndSettle();

      expect(find.textContaining('150.00 ₸'), findsOneWidget);
    });

    testWidgets('предела нет — строки нет, а не «до 100 %»', (tester) async {
      await tester.pumpWidget(host(null));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('discount_limit_hint')), findsNothing);
      expect(find.textContaining('Доступно до'), findsNothing);
    });

    testWidgets('ввод выше предела не даёт результата и называет причину', (
      tester,
    ) async {
      DiscountResult? applied;
      var applyPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ru'), Locale('en')],
          locale: const Locale('ru'),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  applyPressed = true;
                  applied = await DiscountDialog.show(
                    context: context,
                    currencySymbol: '₸',
                    cap: DiscountCap(
                      maxPercent: d('15'),
                      approvalAbove: null,
                      source: 'предел роли «Кассир»',
                    ),
                    subtotal: d('1000'),
                  );
                },
                child: const Text('открыть'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('открыть'));
      await tester.pumpAndSettle();

      // 33 % при пределе 15 % — набирается пальцем по numpad, как на кассе.
      // Ищем клавишу внутри NumPad, а не по всему экрану: то же «3»
      // печатается и в самом поле ввода.
      Finder key(String label) =>
          find.descendant(of: find.byType(NumPad), matching: find.text(label));

      await tester.tap(key('3'));
      await tester.pumpAndSettle();
      await tester.tap(key('3'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Максимум 15%'), findsOneWidget);

      await tester.ensureVisible(find.text('Применить'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Применить'));
      await tester.pumpAndSettle();

      expect(applyPressed, isTrue);
      expect(
        applied,
        isNull,
        reason:
            'диалог не закрылся и ничего не отдал — но это удобство, '
            'а не защита: предел проверяет касса (I44)',
      );
    });
  });
}
