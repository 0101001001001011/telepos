/// Кнопка «Отложить» и сообщение об успехе — задача 10 ревизии 2026-09-19.
///
/// # Что было измерено на `6237809d`
///
/// `sale_screen._handleDefer` звал `deferSale()` **не дожидаясь ответа** и
/// показывал «Чек отложен» всегда. Право `op.deferSale` касса проверяет с
/// задачи 28 (`LocalCartService.defer`), то есть чек кассира без права
/// оставался в работе — а сказано ему было, что он отложен. Отказ при этом
/// лежал в `state.error` названным и перекрывался ложным сообщением об
/// успехе. Сама кнопка права не спрашивала вовсе — в отличие от соседней
/// «Отложенные» (задача 29).
///
/// # Что здесь доказывается — и чего это НЕ доказывает
///
/// Две разные вещи, и обе экранные:
///
/// 1. кнопка заперта тем же правом и называет **свою** причину;
/// 2. сообщение «Чек отложен» зависит от ответа кассы.
///
/// Ни одна из них не является защитой и не выдаётся за неё. Защиту несёт
/// касса (`LocalCartService.defer`, пробы —
/// `test/data/sale/cart_rights_desktop_test.dart`); спрятанная или запертая
/// кнопка правом не является (I162). Здесь мерится честность экрана: не
/// обещать того, чего не произошло, и не отправлять кассира жать кнопку,
/// которая всё равно откажет.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';
import 'package:telepos/presentation/controllers/sale/sale_controller.dart';
import 'package:telepos/presentation/screens/sale/sale_screen.dart';
import 'package:telepos/presentation/screens/sale/widgets/sale_action_buttons.dart';

import '../../../fixtures/test_states.dart';
import '../../../helpers/mock_providers.dart';

/// Кассир, у которого откладывание либо проходит, либо кассой отказано.
///
/// `deferSale` возвращает исход — ровно то, что с этой задачи обещает
/// контроллер.
///
/// # Отказ здесь **не** кладётся в `state.error` — и это измерение, а не
/// упрощение
///
/// Первая редакция двойника писала туда ключ, как это делает
/// `SaleController._emitError`, и проба «касса отказала — «Чек отложен» не
/// показывается» оказалась **зелёной при диверсии**: `ScaffoldMessenger`
/// показывает сообщения по очереди, отказ встаёт первым (слушатель
/// `ref.listen` срабатывает синхронно, внутри `await`), а ложное «Чек
/// отложен» ждёт в очереди и в дерево виджетов не попадает вовсе. То есть
/// проба краснела бы не от дефекта, а от порядка очереди — ровно тот случай,
/// когда «зелёный» означает «не смотрели туда».
///
/// Поэтому двойник отвечает **только исходом**: тогда единственный источник
/// сообщения на экране — сам [_handleDefer], и проба меряет его, а не
/// очередь. Что названный отказ доезжает до кассира, доказано отдельно и
/// другим путём — `sale_refusal_reaches_screen_test.dart`.
class _DeferNotifier extends MockSaleNotifier {
  _DeferNotifier(super.initial, {required this.allowed});

  final bool allowed;
  int calls = 0;

  @override
  Future<bool> deferSale() async {
    calls++;
    return allowed;
  }
}

void main() {
  late SharedPreferences prefs;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  const deniedKey = Key('sale_defer_denied_reason');

  group('кнопка знает право — как соседняя «Отложенные»', () {
    Future<int Function()> pumpButtons(
      WidgetTester tester, {
      required Set<String> permissions,
    }) async {
      var deferred = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Чек **не пуст**: пустой запирает кнопку раньше права, и проба
            // про право прошла бы, ничего про право не сказав.
            saleControllerProvider.overrideWith(
              () => MockSaleNotifier(TestSaleStates.withItems),
            ),
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
            supportedLocales: const [Locale('ru')],
            locale: const Locale('ru'),
            home: Scaffold(
              body: SizedBox(
                width: 600,
                child: SaleActionButtons(onDefer: () => deferred++),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return () => deferred;
    }

    testWidgets('без права кнопка на месте, но не откладывает и называет '
        'причину', (tester) async {
      final deferred = await pumpButtons(
        tester,
        permissions: {PermissionKeys.navSale},
      );

      expect(
        find.text('Отложить'),
        findsOneWidget,
        reason: 'кнопка не прячется: пропавшая сдвинула бы соседей под палец',
      );

      await tester.tap(find.text('Отложить'));
      await tester.pumpAndSettle();

      expect(deferred(), 0);
      expect(find.byKey(deniedKey), findsOneWidget, reason: 'причина названа');
    });

    testWidgets('причина у «Отложить» своя, а не текст соседней кнопки', (
      tester,
    ) async {
      // Без этой пробы переиспользованный текст «Отложенные чеки вам не
      // открыты» в ответ на «Отложить» прошёл бы предыдущую: ключ там был бы
      // другой, а фраза — не про то действие, которое кассир выполнял.
      await pumpButtons(tester, permissions: {PermissionKeys.navSale});
      await tester.tap(find.text('Отложить'));
      await tester.pumpAndSettle();

      final shown = tester.widget<Text>(find.byKey(deniedKey)).data!;
      expect(shown, contains('Отложить чек вам нельзя'));
      expect(
        find.byKey(const Key('sale_deferred_list_denied_reason')),
        findsNothing,
      );
    });

    testWidgets('с правом кнопка откладывает и молчит', (tester) async {
      final deferred = await pumpButtons(
        tester,
        permissions: {PermissionKeys.navSale, PermissionKeys.opDeferSale},
      );

      await tester.tap(find.text('Отложить'));
      await tester.pumpAndSettle();

      expect(deferred(), 1);
      expect(find.byKey(deniedKey), findsNothing);
    });

    testWidgets('пустой чек запирает кнопку раньше права', (tester) async {
      // Порядок условий: «нечего откладывать» — состояние работы, и
      // объяснять кассиру его право в ответ на пустой чек значило бы
      // отвечать не на то, что он сделал.
      var deferred = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            saleControllerProvider.overrideWith(
              () => MockSaleNotifier(TestSaleStates.empty),
            ),
            appStateProvider.overrideWith(
              () => MockAppStateNotifier(
                const AppState(permissions: {PermissionKeys.navSale}),
              ),
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
            supportedLocales: const [Locale('ru')],
            locale: const Locale('ru'),
            home: Scaffold(
              body: SizedBox(
                width: 600,
                child: SaleActionButtons(onDefer: () => deferred++),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Отложить'));
      await tester.pumpAndSettle();

      expect(deferred, 0);
      expect(
        find.byKey(deniedKey),
        findsNothing,
        reason: 'про право говорят тому, кому есть что откладывать',
      );
    });
  });

  group('экран не обещает того, чего не произошло', () {
    Future<_DeferNotifier> pumpSale(
      WidgetTester tester, {
      required bool allowed,
    }) async {
      final notifier = _DeferNotifier(
        TestSaleStates.withItems,
        allowed: allowed,
      );
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final original = FlutterError.onError;
      FlutterError.onError = (details) {
        // Переполнение раскладки на стенде — не предмет этой пробы.
        if (details.exceptionAsString().contains('overflowed by')) return;
        original?.call(details);
      };
      addTearDown(() => FlutterError.onError = original);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            saleControllerProvider.overrideWith(() => notifier),
            sharedPreferencesProvider.overrideWithValue(prefs),
            // Право есть: предмет этой группы — **ответ кассы**, а не
            // запертая кнопка. Без права кнопка не дошла бы до обработчика
            // вовсе, и проба мерила бы соседнюю половину.
            appStateProvider.overrideWith(
              () => MockAppStateNotifier(
                const AppState(
                  permissions: {
                    PermissionKeys.navSale,
                    PermissionKeys.opDeferSale,
                  },
                ),
              ),
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
            locale: const Locale('ru'),
            home: const Scaffold(
              body: SaleScreen(shiftClose: ShiftCloseAtTill()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return notifier;
    }

    testWidgets('касса отказала — «Чек отложен» не показывается', (
      tester,
    ) async {
      final notifier = await pumpSale(tester, allowed: false);

      await tester.tap(find.text('Отложить'));
      await tester.pumpAndSettle();

      expect(notifier.calls, 1, reason: 'команда ушла кассе');
      expect(
        find.text('Чек отложен'),
        findsNothing,
        reason: 'два сообщения об одном событии, из которых верхнее врёт',
      );
    });

    testWidgets('касса согласилась — «Чек отложен» показывается', (
      tester,
    ) async {
      // Управляющая проба: «никогда не показывать» прошло бы предыдущую.
      final notifier = await pumpSale(tester, allowed: true);

      await tester.tap(find.text('Отложить'));
      await tester.pumpAndSettle();

      expect(notifier.calls, 1);
      expect(find.text('Чек отложен'), findsOneWidget);
    });
  });
}
