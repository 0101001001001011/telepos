import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/app_tokens.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/widgets/wizard/wizard_progress_rail.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

/// Цвет, которым сегмент **нарисован** прямо сейчас.
///
/// Читать `AnimatedContainer.decoration` нельзя: это цель анимации, а не её
/// текущее значение, — по нему любая проверка середины перехода пройдёт, даже
/// если анимации нет вовсе. Настоящее значение лежит в [DecoratedBox], который
/// AnimatedContainer строит каждый кадр.
Color _segmentColor(WidgetTester tester, int index) {
  final boxes = tester
      .widgetList<DecoratedBox>(
        find.descendant(
          of: find.byType(AnimatedContainer),
          matching: find.byType(DecoratedBox),
        ),
      )
      .toList();
  return (boxes[index].decoration as BoxDecoration).color!;
}

void main() {
  testWidgets('сегментов ровно столько, сколько шагов', (tester) async {
    await _pump(
      tester,
      const WizardProgressRail(totalSteps: 11, currentStep: 3),
    );
    expect(find.byType(AnimatedContainer), findsNWidgets(11));
  });

  testWidgets('пройденные и текущий залиты акцентом, остальные — нет', (
    tester,
  ) async {
    await _pump(
      tester,
      const WizardProgressRail(totalSteps: 5, currentStep: 3),
    );

    final context = tester.element(find.byType(WizardProgressRail));
    final theme = Theme.of(context);

    for (var i = 0; i < 3; i++) {
      expect(
        _segmentColor(tester, i),
        theme.colorScheme.primary,
        reason: 'сегмент ${i + 1} должен быть залит',
      );
    }
    for (var i = 3; i < 5; i++) {
      expect(
        _segmentColor(tester, i),
        theme.colorScheme.outlineVariant,
        reason: 'сегмент ${i + 1} ещё не пройден',
      );
    }
  });

  testWidgets('на нулевом шаге рельса нет', (tester) async {
    await _pump(
      tester,
      const WizardProgressRail(totalSteps: 11, currentStep: 0),
    );
    expect(find.byType(AnimatedContainer), findsNothing);
  });

  testWidgets('сегменты равной ширины и заданной высоты', (tester) async {
    await _pump(
      tester,
      const Center(
        child: SizedBox(
          width: 400,
          child: WizardProgressRail(totalSteps: 4, currentStep: 2),
        ),
      ),
    );

    expect(find.byType(AnimatedContainer), findsNWidgets(4));
    final first = tester.getSize(find.byType(AnimatedContainer).first);
    final last = tester.getSize(find.byType(AnimatedContainer).last);
    expect(first.height, AppTokens.railHeight);
    expect(last.height, AppTokens.railHeight);
    expect(first.width, closeTo(last.width, 0.5));
  });

  testWidgets('рельс занимает всю отданную ему ширину', (tester) async {
    // Сегменты + зазоры обязаны сложиться ровно в ширину контейнера: рельс,
    // не дотягивающий до края, читается как незавершённая вёрстка.
    await _pump(
      tester,
      const Center(
        child: SizedBox(
          width: 400,
          child: WizardProgressRail(totalSteps: 4, currentStep: 2),
        ),
      ),
    );

    final left = tester.getRect(find.byType(AnimatedContainer).first).left;
    final right = tester.getRect(find.byType(AnimatedContainer).last).right;
    expect(right - left, closeTo(400, 0.5));
  });

  testWidgets('заполнение переезжает без скачка', (tester) async {
    await _pump(
      tester,
      const WizardProgressRail(totalSteps: 4, currentStep: 1),
    );
    final context = tester.element(find.byType(WizardProgressRail));
    final accent = Theme.of(context).colorScheme.primary;

    await _pump(
      tester,
      const WizardProgressRail(totalSteps: 4, currentStep: 2),
    );
    // Середина анимации: второй сегмент уже не серый, но ещё не акцент.
    await tester.pump(AppTokens.durationFast ~/ 2);
    expect(_segmentColor(tester, 1), isNot(accent));

    await tester.pumpAndSettle();
    expect(_segmentColor(tester, 1), accent);
  });

  testWidgets('рельс проговаривается вслух номером шага', (tester) async {
    // Полоса без подписи «шаг 3 из 11» ничего не сообщает программе чтения
    // с экрана: цвет сегмента ей недоступен.
    final handle = tester.ensureSemantics();

    await _pump(
      tester,
      const WizardProgressRail(totalSteps: 11, currentStep: 3),
    );

    expect(find.bySemanticsLabel('Шаг 3 из 11'), findsOneWidget);
    // Дескриптор освобождается здесь, а не в addTearDown: проверка «все
    // дескрипторы закрыты» выполняется до тела tearDown и иначе падает.
    handle.dispose();
  });
}
