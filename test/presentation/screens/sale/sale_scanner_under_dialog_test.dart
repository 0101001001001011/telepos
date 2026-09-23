/// Сканер экрана продажи не принимает ввод, пока поверх экрана открыт
/// маршрут — экран оплаты или диалог.
///
/// # Дефект, найденный живой приёмкой браузерного терминала
///
/// Экран продажи → «Оплатить» → поле «Номер телефона» панели лояльности →
/// `77011234567` → Enter. Покупатель нашёлся, и **одновременно** всплыла
/// полоса «Товар не найден: товар со штрихкодом 77011234567 не найден».
/// Корзина не изменилась лишь потому, что такого товара нет: с кодом
/// существующего товара он лёг бы в чек **во время оплаты**.
///
/// # Механизм (измерен, а не предположен)
///
/// `BarcodeScannerMixin` слушает `HardwareKeyboard.instance.addHandler` —
/// глобальный обработчик, которому приходит **каждое** нажатие во всём
/// приложении, где бы ни был фокус и что бы ни лежало поверх. Цифры, набранные
/// в поле диалога, копились в буфере сканера экрана под ним, а `Enter`
/// превращал их в «скан». Набор и сборка этого не видели: ни одна проба не
/// открывала что-либо поверх экрана продажи и не жала клавиши.
///
/// # Как проба гонит ввод
///
/// Двумя половинами, как уже измерено в `wt_sale_route_test.dart` («после
/// скана поле поиска пусто»): текст — через канал ввода (`enterText`), потому
/// что `TextField` получает символы оттуда, а цифры и `Enter` — событиями
/// клавиатуры, потому что сканер слушает ровно `HardwareKeyboard`. В браузере
/// одно нажатие даёт обе половины сразу.
///
/// # Почему у каждой красной пробы есть зелёный контроль
///
/// Проба «под диалогом скан не прошёл» зеленела бы и тогда, когда события
/// до сканера не доходят вовсе. Контроль — те же нажатия на открытом экране
/// продажи — обязан положить товар в чек; без него отсутствие скана ничего
/// не доказывает.
library;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker/talker.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/core/logging/app_talker.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/payment/payment_controller.dart';
import 'package:telepos/presentation/controllers/sale/sale_controller.dart';
import 'package:telepos/presentation/screens/payment/payment_screen.dart';
import 'package:telepos/presentation/screens/payment/widgets/loyalty_panel.dart';
import 'package:telepos/presentation/screens/sale/sale_screen.dart';

import '../../../helpers/mock_providers.dart';

/// Код товара, который **есть** в каталоге стенда.
const _milk = '4870001234567';

/// Номер телефона из живой приёмки: товара с таким кодом нет.
const _phone = '77011234567';

/// Корзина стенда: известный код кладёт строку, неизвестный — отказ тем же
/// ключом, каким его кладёт `SaleController` (`error.product_not_found:<код>`).
///
/// Чек начинается **не пустым** — одна строка «Кефир»: «корзина не
/// изменилась» на пустой корзине неотличимо от «экран корзину не читал».
class _CatalogSale extends MockSaleNotifier {
  _CatalogSale()
    : super(
        SaleState(
          receiptNo: 1,
          items: [
            SaleItem(
              id: 'kefir',
              productId: 200,
              name: 'Кефир',
              price: Decimal.parse('499.995'),
              quantity: Decimal.one,
              barcode: '4870007654321',
            ),
          ],
        ),
      );

  static const _catalog = {_milk: 'Молоко'};

  /// Каждый код, дошедший до корзины, — в порядке прихода.
  final scanned = <String>[];

  @override
  Future<bool> addByBarcode(String barcode) async {
    scanned.add(barcode);
    final name = _catalog[barcode];
    if (name == null) {
      state = SaleState(
        receiptNo: state.receiptNo,
        items: state.items,
        error: 'error.product_not_found:$barcode',
      );
      return false;
    }
    state = SaleState(
      receiptNo: state.receiptNo,
      items: [
        ...state.items,
        SaleItem(
          id: 'line-${state.items.length}',
          productId: 100,
          name: name,
          price: Decimal.fromInt(500),
          quantity: Decimal.one,
          barcode: barcode,
        ),
      ],
    );
    return true;
  }
}

class _Payment extends MockPaymentNotifier {
  _Payment() : super(PaymentState(totalAmount: Decimal.parse('499.995')));

  /// Что панель лояльности успела спросить — доказательство, что `Enter` и
  /// набор дошли до **поля диалога**, а не только до сканера под ним.
  final lookups = <String>[];

  @override
  Future<void> searchLoyaltyCustomer(String phone) async => lookups.add(phone);
}

const _digitKeys = <String, LogicalKeyboardKey>{
  '0': LogicalKeyboardKey.digit0,
  '1': LogicalKeyboardKey.digit1,
  '2': LogicalKeyboardKey.digit2,
  '3': LogicalKeyboardKey.digit3,
  '4': LogicalKeyboardKey.digit4,
  '5': LogicalKeyboardKey.digit5,
  '6': LogicalKeyboardKey.digit6,
  '7': LogicalKeyboardKey.digit7,
  '8': LogicalKeyboardKey.digit8,
  '9': LogicalKeyboardKey.digit9,
};

/// Набор кода и `Enter` — так, как это приходит от человека или
/// клавиатурного сканера в браузере. [field] — куда ложится текст; `null` —
/// фокуса в поле нет (скан на открытом экране продажи).
Future<void> _typeAndEnter(
  WidgetTester tester,
  String code, {
  Finder? field,
}) async {
  if (field != null) await tester.enterText(field, code);
  for (final digit in code.split('')) {
    await tester.sendKeyEvent(_digitKeys[digit]!);
  }
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  late SharedPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    if (!isLoggerReady) installLogger(Talker());
  });

  // Сканер спрашивает режим у GetIt; пустой GetIt — клавиатурный сканер, тот
  // самый путь, что и в браузере без привязки устройства.
  setUp(() async => GetIt.I.reset());
  tearDown(() async => GetIt.I.reset());

  /// Экран оплаты — настольная раскладка, как в живой приёмке.
  void desktop(WidgetTester tester) {
    tester.view.physicalSize = const Size(1920, 937);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.exceptionAsString();
      if (text.contains('overflowed') || text.contains('A RenderFlex')) return;
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);
  }

  /// Стенд с маршрутами. [shell] — десктопная таблица: продажа внутри
  /// `ShellRoute` (вложенный навигатор), оплата — в корневом. Без него —
  /// браузерная таблица: оба маршрута в корневом навигаторе.
  Future<({_CatalogSale sale, _Payment payment, GoRouter router})> pumpStand(
    WidgetTester tester, {
    required bool shell,
  }) async {
    final sale = _CatalogSale();
    final payment = _Payment();
    final rootKey = GlobalKey<NavigatorState>();
    final saleRoute = GoRoute(
      path: '/sale',
      builder: (context, state) =>
          const Scaffold(body: SaleScreen(shiftClose: ShiftCloseAtTill())),
    );
    final router = GoRouter(
      navigatorKey: rootKey,
      initialLocation: '/sale',
      routes: [
        if (shell)
          ShellRoute(
            builder: (context, state, child) => Scaffold(
              body: Row(
                children: [
                  const SizedBox(width: 72, child: Placeholder()),
                  Expanded(child: child),
                ],
              ),
            ),
            routes: [
              GoRoute(
                path: '/sale',
                builder: (context, state) =>
                    const SaleScreen(shiftClose: ShiftCloseAtTill()),
              ),
            ],
          )
        else
          saleRoute,
        GoRoute(
          path: '/payment',
          parentNavigatorKey: rootKey,
          builder: (context, state) => const PaymentScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          saleControllerProvider.overrideWith(() => sale),
          paymentControllerProvider.overrideWith(() => payment),
          paymentAccountsProvider.overrideWith(
            (ref) async => <PaymentAccount>[],
          ),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
          locale: const Locale('ru'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (sale: sale, payment: payment, router: router);
  }

  Finder phoneField() => find.descendant(
    of: find.byType(LoyaltyPanel),
    matching: find.byType(TextField),
  );

  Finder scannerRefusal() => find.descendant(
    of: find.byType(SnackBar),
    matching: find.textContaining('Товар не найден'),
  );

  for (final shell in const [false, true]) {
    final table = shell
        ? 'касса (продажа во вложенном навигаторе)'
        : 'браузер (оба маршрута в корне)';

    group(table, () {
      testWidgets('контроль: на открытом экране продажи скан кладёт товар', (
        tester,
      ) async {
        desktop(tester);
        final stand = await pumpStand(tester, shell: shell);

        await _typeAndEnter(tester, _milk);

        expect(
          stand.sale.scanned,
          [_milk],
          reason:
              'события клавиатуры обязаны доходить до сканера — иначе пробы '
              'ниже зеленеют ничего не измерив',
        );
        expect(stand.sale.state.items.map((i) => i.name), ['Кефир', 'Молоко']);
      });

      testWidgets(
        'Enter в поле телефона на экране оплаты не кладёт существующий товар '
        'в чек',
        (tester) async {
          desktop(tester);
          final stand = await pumpStand(tester, shell: shell);
          stand.router.push('/payment');
          await tester.pumpAndSettle();
          expect(phoneField(), findsOneWidget, reason: 'предпосылка: оплата');

          await _typeAndEnter(tester, _milk, field: phoneField());

          expect(
            stand.payment.lookups,
            isNotEmpty,
            reason: 'предпосылка: набор дошёл до поля телефона в диалоге',
          );
          expect(
            stand.sale.scanned,
            isEmpty,
            reason:
                'сканер экрана продажи под экраном оплаты принял набор в поле '
                'диалога за скан — товар лёг бы в чек во время оплаты',
          );
          expect(stand.sale.state.items.map((i) => i.name), [
            'Кефир',
          ], reason: 'корзина изменилась, пока открыта оплата');
          expect(scannerRefusal(), findsNothing);
        },
      );

      testWidgets(
        'номер телефона из приёмки не даёт полосы «Товар не найден»',
        (tester) async {
          desktop(tester);
          final stand = await pumpStand(tester, shell: shell);
          stand.router.push('/payment');
          await tester.pumpAndSettle();

          await _typeAndEnter(tester, _phone, field: phoneField());

          expect(stand.sale.scanned, isEmpty);
          expect(
            scannerRefusal(),
            findsNothing,
            reason:
                'живая приёмка: кассир ищет покупателя, а видит отказ '
                'сканера экрана, которого не касался',
          );
        },
      );

      testWidgets(
        'диалог поверх продажи (количество, отложенные, маркировка — все '
        '`showDialog`) тоже закрывает сканер',
        (tester) async {
          desktop(tester);
          final stand = await pumpStand(tester, shell: shell);

          // Тот же вызов, каким экран продажи открывает свои диалоги:
          // `showDialog` из контекста экрана — корневой навигатор.
          showDialog<void>(
            context: tester.element(find.byType(SaleScreen)),
            builder: (_) =>
                const AlertDialog(content: TextField(key: Key('dialog_field'))),
          );
          await tester.pumpAndSettle();

          await _typeAndEnter(
            tester,
            _milk,
            field: find.byKey(const Key('dialog_field')),
          );

          expect(stand.sale.scanned, isEmpty);
          expect(stand.sale.state.items.map((i) => i.name), ['Кефир']);
        },
      );

      testWidgets('после закрытия оплаты сканер снова работает', (
        tester,
      ) async {
        // Обратная сторона починки: закрытие по маршруту, а не выключение
        // навсегда. Сканер, переставший работать после первой оплаты, —
        // дефект хуже исходного.
        desktop(tester);
        final stand = await pumpStand(tester, shell: shell);
        stand.router.push('/payment');
        await tester.pumpAndSettle();
        await _typeAndEnter(tester, _phone, field: phoneField());

        stand.router.pop();
        await tester.pumpAndSettle();
        expect(find.byType(PaymentScreen), findsNothing);

        await _typeAndEnter(tester, _milk);

        expect(
          stand.sale.scanned,
          [_milk],
          reason:
              'цифры, набранные в диалоге, не имеют права приклеиться к '
              'следующему скану, и сам скан обязан пройти',
        );
        expect(stand.sale.state.items.map((i) => i.name), ['Кефир', 'Молоко']);
      });
    });
  }
}
