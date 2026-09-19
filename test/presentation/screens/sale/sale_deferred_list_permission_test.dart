import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/constants/permission_keys.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';
import 'package:telepos/presentation/controllers/sale/sale_controller.dart';
import 'package:telepos/presentation/screens/sale/widgets/sale_action_buttons.dart';

import '../../../fixtures/test_states.dart';
import '../../../helpers/mock_providers.dart';

/// Кнопка «Отложенные» знает право `op.deferSale` вошедшего — задача 29.
///
/// Подписка на пул отложенных закрыта этим правом на кассе намеренно (пул
/// отдаёт имена кассиров), и отказ внутри диалога назван (задача 13). Но
/// кнопка стояла открытой всегда: кассир без права нажимал её, видел диалог и
/// только в нём — отказ, то есть узнавал о закрытой двери, уже войдя в неё.
///
/// **Образец — кнопка «В долг» экрана оплаты** (`payment_type_selector.dart`,
/// тот же путь продажи): кнопка на месте, заперта, и нажатие называет причину
/// (`payment_debt_denied_reason`). Не прятанье, как у плиток главного экрана
/// терминала: там это переход, а здесь — действие в сетке, где пропавшая
/// кнопка сдвигает соседей под палец («Удалить» стоит рядом с «Отложить»).
///
/// Защита остаётся на кассе: диалог по-прежнему называет отказ подписки,
/// если до него дойдут иначе.
void main() {
  Future<int Function()> pump(
    WidgetTester tester, {
    required Set<String> permissions,
  }) async {
    var opened = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          saleControllerProvider.overrideWith(
            () => MockSaleNotifier(TestSaleStates.empty),
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
              child: SaleActionButtons(onDeferredList: () => opened++),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return () => opened;
  }

  const reasonKey = Key('sale_deferred_list_denied_reason');

  testWidgets('без права кнопка на месте, но пул не открывает и называет причину', (
    tester,
  ) async {
    final opened = await pump(tester, permissions: {PermissionKeys.navSale});

    expect(
      find.text('Отложенные'),
      findsOneWidget,
      reason: 'кнопка не прячется: пропавшая сдвинула бы соседей под палец',
    );

    await tester.tap(find.text('Отложенные'));
    await tester.pumpAndSettle();

    expect(
      opened(),
      0,
      reason:
          'пул закрыт правом op.deferSale на кассе; открывать диалог, чтобы '
          'в нём же отказать, — узнавать о закрытой двери, уже войдя в неё',
    );
    expect(find.byKey(reasonKey), findsOneWidget, reason: 'причина названа');
  });

  testWidgets('с правом кнопка открывает пул и молчит', (tester) async {
    final opened = await pump(
      tester,
      permissions: {PermissionKeys.navSale, PermissionKeys.opDeferSale},
    );

    await tester.tap(find.text('Отложенные'));
    await tester.pumpAndSettle();

    expect(opened(), 1);
    expect(find.byKey(reasonKey), findsNothing);
  });
}
