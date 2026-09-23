/// Пустая группа с подписью рисует сообщение ВНУТРИ карточки.
///
/// # Что измерено 2026-09-21
///
/// Заказчик, глядя на мастер: «там текст вышел за пределы блока или не
/// раскрашен». На американской кассе шаги «Фискализация» и «Терминалы»
/// показывали ровно это: всё содержимое шага — голая серая строчка
/// «Fiscalization is not required for your country» посреди пустоты, без
/// карточки, не как всё остальное на экране.
///
/// Причина: `SettingsSection(children: const [], footer: '…')`. Карточка с
/// нулём строк имеет нулевую высоту, а подпись рисуется ПОД ней.
///
/// # Почему проба на виджете, а не на шаге
///
/// Пустая группа встретится снова, и следующий раз никто не вспомнит, что
/// её надо обойти. Проба держит правило там, где оно живёт.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/presentation/common/widgets/settings/settings_section.dart';
import 'package:telepos/presentation/common/widgets/settings/settings_tile.dart';
import 'package:telepos/app/theme/input_mode.dart';
import 'package:telepos/app/theme/wizard_metrics.dart';
import 'package:telepos/presentation/common/adaptive/breakpoints.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(
      body: Center(child: SizedBox(width: 600, child: child)),
    ),
  );

  testWidgets('сообщение пустой группы лежит внутри карточки', (tester) async {
    await tester.pumpWidget(
      host(
        const SettingsSection(
          header: 'Fiscalization',
          footer: 'Fiscalization is not required for your country',
          children: [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final message = find.text('Fiscalization is not required for your country');
    expect(message, findsOneWidget);

    expect(
      find.ancestor(of: message, matching: find.byType(Material)),
      findsWidgets,
      reason:
          'сообщение обязано лежать в поверхности группы. Снаружи оно '
          'выглядит забытой строкой, а не ответом шага',
    );

    // Высота карточки говорит громче родословной: пустая карточка нулевой
    // высоты и была тем, из-за чего текст висел в воздухе.
    final card = tester
        .widgetList<Material>(find.byType(Material))
        .where((m) => m.clipBehavior == Clip.antiAlias)
        .toList();
    expect(card, isNotEmpty, reason: 'поверхность группы не найдена');

    final size = tester.getSize(
      find
          .byWidgetPredicate(
            (w) => w is Material && w.clipBehavior == Clip.antiAlias,
          )
          .first,
    );
    expect(
      size.height,
      greaterThan(20),
      reason:
          'карточка пустой высоты — ровно то, что делало сообщение голой '
          'строкой в пустоте',
    );
  });

  testWidgets('сообщение не печатается дважды', (tester) async {
    await tester.pumpWidget(
      host(
        const SettingsSection(
          header: 'Terminals',
          footer: 'No payment terminals available for your region',
          children: [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('No payment terminals available for your region'),
      findsOneWidget,
      reason:
          'подпись нарисована и внутри, и под карточкой — человек читает '
          'одно и то же дважды',
    );
  });

  testWidgets('у НЕпустой группы подпись осталась под карточкой', (
    tester,
  ) async {
    // Обратная сторона: правка не имеет права утащить поясняющую подпись
    // внутрь там, где строки есть. Там её место под ними — она поясняет
    // группу, а не заменяет её.
    final metrics = WizardMetrics.resolve(
      layout: LayoutType.desktop,
      input: InputMode.pointer,
    );
    await tester.pumpWidget(
      host(
        SettingsSection(
          header: 'Company',
          footer: 'Printed on the receipt.',
          children: [SettingsTile(metrics: metrics, title: 'Company name')],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final footer = tester.getTopLeft(find.text('Printed on the receipt.'));
    final row = tester.getBottomLeft(find.text('Company name'));
    expect(
      footer.dy,
      greaterThan(row.dy),
      reason: 'подпись группы обязана стоять НИЖЕ её строк',
    );
  });
}
