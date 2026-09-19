import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/domain/discount/discount_policy.dart';
import 'package:telepos/domain/sale/sale_edit_terms.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/dialogs/discount_dialog.dart';
import 'package:telepos/presentation/common/widgets/keyboards/num_pad.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';
import 'package:telepos/presentation/controllers/sale/sale_controller.dart';
import 'package:telepos/presentation/screens/sale/sale_screen.dart';

import '../../../fixtures/test_states.dart';
import '../../../helpers/mock_providers.dart';

Decimal d(String s) => Decimal.parse(s);

/// Записывает, каким входом ушла скидка.
///
/// Это и есть предмет проверки: до задачи 18 `setDiscountPercent`
/// существовал со своим правом и своими пробами и **ни одного вызывающего
/// из интерфейса не имел** — процентную скидку кассир задать не мог вовсе.
class _RecordingSaleNotifier extends MockSaleNotifier {
  _RecordingSaleNotifier(super.state, {required this.cap});

  final DiscountCap cap;

  Decimal? percentAsked;
  Decimal? amountAsked;
  Decimal? priceAsked;

  /// Символ валюты едет условиями кассы, а не службой экрана: проба ниже
  /// ищет «150.00 ₸» — значит, символ дошёл до диалога этим путём.
  @override
  Future<SaleEditTerms?> editTerms() async => SaleEditTerms(
    policy: const SalePolicy(editPrice: true, sellInDiscount: true),
    cap: cap,
    currencySymbol: '₸',
  );

  @override
  Future<void> setDiscountPercent(Decimal percent) async {
    percentAsked = percent;
  }

  @override
  Future<void> setDiscountAmount(Decimal amount) async {
    amountAsked = amount;
  }

  @override
  Future<void> updatePrice(Decimal price) async {
    priceAsked = price;
  }
}

void main() {
  late SharedPreferences prefs;
  late _RecordingSaleNotifier notifier;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  setUp(() {
    notifier = _RecordingSaleNotifier(
      TestSaleStates.withItems,
      cap: DiscountCap(
        maxPercent: d('15'),
        approvalAbove: null,
        source: 'предел роли «Кассир»',
      ),
    );
  });

  tearDown(GetIt.I.reset);

  Widget host({
    Set<String> permissions = const {PermissionKeys.opSellDiscount},
  }) => ProviderScope(
    overrides: [
      saleControllerProvider.overrideWith(() => notifier),
      sharedPreferencesProvider.overrideWithValue(prefs),
      // Поле скидки читает право `op.sellDiscount` из сеанса. Подделка, а
      // не настоящий `AppStateNotifier`: тот заводит часы и сторож места —
      // таймеры, переживающие дерево.
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
      supportedLocales: const [Locale('ru'), Locale('en')],
      locale: const Locale('ru'),
      home: const Scaffold(body: SaleScreen(shiftClose: ShiftCloseAtTill())),
    ),
  );

  void suppressOverflow() {
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed by')) return;
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);
  }

  Future<void> openEdit(
    WidgetTester tester, {
    Set<String> permissions = const {PermissionKeys.opSellDiscount},
  }) async {
    suppressOverflow();
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(permissions: permissions));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Редактировать'));
    await tester.pumpAndSettle();
  }

  Future<void> openDiscount(WidgetTester tester) async {
    await openEdit(tester);
    await tester.tap(find.byKey(const Key('edit_item_discount')));
    await tester.pumpAndSettle();
  }

  Finder numKey(String label) =>
      find.descendant(of: find.byType(NumPad), matching: find.text(label));

  /// Ищем внутри самого диалога скидки: и «Сумма», и текст предела есть
  /// теперь в двух местах — в диалоге и в строке правки, которая тот же
  /// предел показывает не открывая numpad.
  Finder inDialog(Finder matching) =>
      find.descendant(of: find.byType(DiscountDialog), matching: matching);

  testWidgets('правка строки ведёт в DiscountDialog, а не в безымянное поле', (
    tester,
  ) async {
    await openEdit(tester);

    // Безымянного поля «Скидка» с вольным текстом больше нет: у скидки
    // свой вход, и он назван.
    expect(find.byKey(const Key('edit_item_discount')), findsOneWidget);

    await tester.tap(find.byKey(const Key('edit_item_discount')));
    await tester.pumpAndSettle();

    expect(find.byType(DiscountDialog), findsOneWidget);
  });

  testWidgets('кассиру без права на скидку поле заперто, предел не обещан', (
    tester,
  ) async {
    // Приёмка 2026-09-17 (стенд 3, «Кассир Второй»): окно открывалось и
    // писало «Доступно до 100 %», а запрет кассир узнавал после «Сохранить».
    await openEdit(tester, permissions: const {});

    expect(
      find.textContaining('Скидку назначать вам не разрешено'),
      findsOneWidget,
      reason: 'причина названа словарём на месте поля, до нажатия',
    );
    expect(
      find.textContaining('Доступно до'),
      findsNothing,
      reason: 'предел, которым нельзя воспользоваться, — обещание',
    );

    await tester.tap(find.byKey(const Key('edit_item_discount')));
    await tester.pumpAndSettle();
    expect(find.byType(DiscountDialog), findsNothing);

    // Цену такой кассир править может: окно целиком не заперто.
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(notifier.percentAsked, isNull);
    expect(notifier.amountAsked, isNull);
  });

  testWidgets('предел роли виден кассиру ДО того, как он что-то набрал', (
    tester,
  ) async {
    await openDiscount(tester);

    expect(
      inDialog(find.byKey(const Key('discount_limit_hint'))),
      findsOneWidget,
    );
    expect(inDialog(find.textContaining('Доступно до 15 %')), findsOneWidget);
    expect(
      inDialog(find.textContaining('предел роли «Кассир»')),
      findsOneWidget,
    );

    // И тот же предел назван строкой правки — до открытия numpad.
    expect(find.textContaining('Доступно до 15 %'), findsNWidgets(2));
  });

  testWidgets('процентная скидка доходит до setDiscountPercent', (
    tester,
  ) async {
    await openDiscount(tester);

    // 10 % — в пределе.
    await tester.tap(numKey('1'));
    await tester.pumpAndSettle();
    await tester.tap(numKey('0'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(inDialog(find.text('Применить')));
    await tester.pumpAndSettle();
    await tester.tap(inDialog(find.text('Применить')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(
      notifier.percentAsked,
      d('10'),
      reason:
          'до задачи 18 у setDiscountPercent не было ни одного '
          'вызывающего из интерфейса',
    );
    expect(notifier.amountAsked, isNull);
  });

  testWidgets('скидка суммой по-прежнему доходит до setDiscountAmount', (
    tester,
  ) async {
    await openDiscount(tester);

    await tester.tap(inDialog(find.text('Сумма')));
    await tester.pumpAndSettle();

    // Строка — 500 × 2 = 1000; предел 15 % это 150. Берём 50.
    await tester.tap(numKey('5'));
    await tester.pumpAndSettle();
    await tester.tap(numKey('0'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(inDialog(find.text('Применить')));
    await tester.pumpAndSettle();
    await tester.tap(inDialog(find.text('Применить')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(notifier.amountAsked, d('50'));
    expect(notifier.percentAsked, isNull);
  });

  testWidgets('предел меряется стоимостью выбранной строки, а не всего чека', (
    tester,
  ) async {
    await openDiscount(tester);
    await tester.tap(inDialog(find.text('Сумма')));
    await tester.pumpAndSettle();

    // 15 % от 500 × 2 = 150 ₸. Не от итога чека (1000 + 150 + 1200).
    expect(find.textContaining('150.00 ₸'), findsOneWidget);
  });
}
