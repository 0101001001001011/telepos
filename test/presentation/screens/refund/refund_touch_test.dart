import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/refund/refund_controller.dart';
import 'package:telepos/presentation/screens/refund/refund_screen.dart';
import 'package:telepos/presentation/screens/refund/widgets/refund_items_list.dart';
import 'package:telepos/presentation/screens/refund/widgets/refund_items_table.dart';
import 'package:telepos/presentation/screens/refund/widgets/refund_total_panel.dart';

import '../../../fixtures/test_states.dart';
import '../../../helpers/mock_providers.dart';

/// Возврат под палец — шаг 4 задачи 20.
///
/// # Почему это меряется, а не осматривается
///
/// «Кнопка маловата» — не наблюдение, а впечатление, и спорить о нём можно
/// бесконечно. Число спорить не даёт: **48 логических точек** — предел, ниже
/// которого палец промахивается (Material «touch target», тот же порог, что
/// у `MaterialTapTargetSize.padded`). Здесь он проверяется у каждой цели,
/// до которой кассир дотягивается пальцем на планшете, и у высоты строки
/// списка, по которой он в эту строку попадает.
///
/// # Три требования шага 4, каждое своей пробой
///
/// 1. **цели не меньше 48** — строка чека, её флажок;
/// 2. **выделение работает пальцем, а не только стилусом** — попадание по
///    строке целиком, а не по флажку в ней. Мерится **шириной области
///    нажатия**: строка, у которой нажимается только флажок, требует
///    точности стилуса;
/// 3. **итог не прячется под экранной клавиатурой** — при поднятой
///    клавиатуре (`viewInsets.bottom`) панель итога обязана остаться в
///    видимой части экрана. На планшете номер чека набирают с экранной
///    клавиатуры, и сумма к возврату — последнее, что имеет право уехать
///    под неё.
const _minTouchTarget = 48.0;

Widget _screen(RefundState state, {required Size size, double keyboard = 0}) {
  return ProviderScope(
    overrides: [
      refundControllerProvider.overrideWith(() => MockRefundNotifier(state)),
    ],
    child: MediaQuery(
      data: MediaQueryData(
        size: size,
        viewInsets: EdgeInsets.only(bottom: keyboard),
      ),
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
        home: const Scaffold(body: RefundScreen()),
      ),
    ),
  );
}

void main() {
  testWidgets('строка чека в таблице — цель не меньше 48 точек', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _screen(TestRefundStates.byReceipt, size: const Size(1600, 1000)),
    );
    await tester.pumpAndSettle();

    final rows = find.descendant(
      of: find.byType(RefundItemsTable),
      matching: find.byType(InkWell),
    );
    expect(rows, findsWidgets, reason: 'строки чека обязаны быть на экране');

    for (var i = 0; i < rows.evaluate().length; i++) {
      final size = tester.getSize(rows.at(i));
      expect(
        size.height,
        greaterThanOrEqualTo(_minTouchTarget),
        reason:
            'строка $i высотой ${size.height} — палец в неё не попадёт, '
            'нужен стилус',
      );
    }
  });

  testWidgets('флажок строки — цель не меньше 48 точек', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _screen(TestRefundStates.byReceipt, size: const Size(1600, 1000)),
    );
    await tester.pumpAndSettle();

    final boxes = find.descendant(
      of: find.byType(RefundItemsTable),
      matching: find.byType(Checkbox),
    );
    expect(boxes, findsWidgets);

    for (var i = 0; i < boxes.evaluate().length; i++) {
      final size = tester.getSize(boxes.at(i));
      expect(
        size.width,
        greaterThanOrEqualTo(_minTouchTarget),
        reason: 'флажок $i шириной ${size.width} — цель для стилуса',
      );
      expect(size.height, greaterThanOrEqualTo(_minTouchTarget));
    }
  });

  testWidgets('строка списка на планшете — цель не меньше 48 точек', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _screen(TestRefundStates.byReceipt, size: const Size(500, 900)),
    );
    await tester.pumpAndSettle();

    final rows = find.descendant(
      of: find.byType(RefundItemsList),
      matching: find.byType(InkWell),
    );
    expect(rows, findsWidgets);

    for (var i = 0; i < rows.evaluate().length; i++) {
      final size = tester.getSize(rows.at(i));
      expect(size.height, greaterThanOrEqualTo(_minTouchTarget));
    }
  });

  testWidgets('нажатие по строке ловится всей строкой, а не только флажком', (
    tester,
  ) async {
    // Стилусом попадают в флажок; пальцем — в строку. Если нажимается
    // только флажок, выделение остаётся возможностью для стилуса.
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _screen(TestRefundStates.byReceipt, size: const Size(1600, 1000)),
    );
    await tester.pumpAndSettle();

    final row = find
        .descendant(
          of: find.byType(RefundItemsTable),
          matching: find.byType(InkWell),
        )
        .first;
    final rowWidth = tester.getSize(row).width;
    final checkbox = find
        .descendant(
          of: find.byType(RefundItemsTable),
          matching: find.byType(Checkbox),
        )
        .first;
    final checkboxWidth = tester.getSize(checkbox).width;

    expect(
      rowWidth,
      greaterThan(checkboxWidth * 3),
      reason:
          'область нажатия строки ($rowWidth) обязана быть шире флажка '
          '($checkboxWidth) — иначе выделение доступно только стилусу',
    );
  });

  /// Телефонные размеры: браузерный терминал целится не только в планшет.
  ///
  /// Переполнение `RenderFlex` — не косметика: часть строки кассир **не
  /// видит вовсе**, а поверх идёт жёлто-чёрная лента. Широкую панель я
  /// починил по такой же пробе на 900×1400; компактную не трогал, и разбор
  /// круга правки перемерил её на трёх телефонах:
  /// 360×800 — **два** переполнения (98 точек и ещё 6, другой `RenderFlex`),
  /// 390×844 — 68, 412×915 — 46.
  ///
  /// Проверяется **отсутствием исключения отрисовки**, а не числом: числа
  /// зависят от шрифта и локали, а переполнение — факт.
  for (final size in const [Size(360, 800), Size(390, 844), Size(412, 915)]) {
    testWidgets('панель итога не переполняется на ${size.width.toInt()}×'
        '${size.height.toInt()}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_screen(TestRefundStates.byReceipt, size: size));
      await tester.pumpAndSettle();

      expect(
        find.byType(RefundTotalPanel),
        findsOneWidget,
        reason: 'подготовка: панель на экране',
      );
      expect(
        tester.takeException(),
        isNull,
        reason:
            'RenderFlex overflowed — часть строки кассиру не видна вовсе, '
            'а поверх панели идёт жёлто-чёрная лента',
      );
    });
  }

  testWidgets('итог не уходит под экранную клавиатуру', (tester) async {
    const screen = Size(500, 900);
    const keyboard = 320.0;

    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _screen(TestRefundStates.byReceipt, size: screen, keyboard: keyboard),
    );
    await tester.pumpAndSettle();

    final panel = find.byType(RefundTotalPanel);
    expect(panel, findsOneWidget);

    final bottom = tester.getBottomLeft(panel).dy;
    expect(
      bottom,
      lessThanOrEqualTo(screen.height - keyboard + 0.5),
      reason:
          'панель итога кончается на $bottom, клавиатура начинается на '
          '${screen.height - keyboard} — сумма к возврату под ней не видна',
    );
  });
}
