import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/app/theme/app_tokens.dart';
import 'package:telepos/app/theme/input_mode.dart';
import 'package:telepos/app/theme/wizard_metrics.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/adaptive/breakpoints.dart';
import 'package:telepos/presentation/common/widgets/wizard/wizard_actions.dart';
import 'package:telepos/presentation/common/widgets/wizard/wizard_hero.dart';
import 'package:telepos/presentation/common/widgets/wizard/wizard_progress_rail.dart';
import 'package:telepos/presentation/common/widgets/wizard/wizard_scaffold.dart';

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  required InputMode input,
  VoidCallback? onNext,
  VoidCallback? onBack,
  Widget? hero,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [inputModeProvider.overrideWith(() => _FixedInputMode(input))],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: WizardScaffold(
          totalSteps: 11,
          currentStep: 3,
          onNext: onNext,
          onBack: onBack,
          hero: hero,
          nextLabel: 'Далее',
          child: const Text('содержимое'),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FixedInputMode extends InputModeNotifier {
  _FixedInputMode(this.value);

  final InputMode value;

  @override
  InputMode build() => value;
}

void main() {
  testWidgets('рельс показывает текущий шаг', (tester) async {
    await _pump(tester, size: const Size(1440, 900), input: InputMode.pointer);
    final rail = tester.widget<WizardProgressRail>(
      find.byType(WizardProgressRail),
    );
    expect(rail.currentStep, 3);
    expect(rail.totalSteps, 11);
  });

  testWidgets('на десктопе колонка ограничена 640', (tester) async {
    await _pump(tester, size: const Size(1440, 900), input: InputMode.pointer);
    final box = tester.widget<ConstrainedBox>(
      find.byKey(WizardScaffold.columnKey),
    );
    expect(box.constraints.maxWidth, AppTokens.columnMaxWidthDesktop);
  });

  testWidgets('на телефоне колонка не ограничена', (tester) async {
    await _pump(tester, size: const Size(400, 800), input: InputMode.touch);
    final box = tester.widget<ConstrainedBox>(
      find.byKey(WizardScaffold.columnKey),
    );
    expect(box.constraints.maxWidth, double.infinity);
  });

  testWidgets('под указателем Enter ведёт дальше, Escape — назад', (
    tester,
  ) async {
    var next = 0;
    var back = 0;
    await _pump(
      tester,
      size: const Size(1440, 900),
      input: InputMode.pointer,
      onNext: () => next++,
      onBack: () => back++,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(next, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(back, 1);
  });

  testWidgets('под пальцем клавиатурные сокращения не срабатывают', (
    tester,
  ) async {
    var next = 0;
    await _pump(
      tester,
      size: const Size(400, 800),
      input: InputMode.touch,
      onNext: () => next++,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(next, 0);
  });

  testWidgets('под пальцем «Назад» — стрелка в строке рельса', (tester) async {
    // По таблице привязки к платформе: на телефоне и планшете возврат живёт
    // в шапке, а не в панели действий. Иначе две кнопки внизу конкурируют за
    // большой палец, и «Назад» нажимается по ошибке.
    await _pump(
      tester,
      size: const Size(400, 800),
      input: InputMode.touch,
      onNext: () {},
      onBack: () {},
    );

    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    final actions = tester.widget<WizardActions>(find.byType(WizardActions));
    expect(actions.onBack, isNull);
    expect(actions.metrics.actionsAlignedRight, isFalse);
  });

  testWidgets('под указателем «Назад» — текстовая кнопка в панели действий', (
    tester,
  ) async {
    await _pump(
      tester,
      size: const Size(1440, 900),
      input: InputMode.pointer,
      onNext: () {},
      onBack: () {},
    );

    expect(find.byIcon(Icons.arrow_back), findsNothing);
    expect(find.widgetWithText(TextButton, 'Назад'), findsOneWidget);
    final actions = tester.widget<WizardActions>(find.byType(WizardActions));
    expect(actions.metrics.actionsAlignedRight, isTrue);
  });

  testWidgets('под пальцем кнопка «Далее» занимает всю ширину колонки', (
    tester,
  ) async {
    await _pump(
      tester,
      size: const Size(400, 800),
      input: InputMode.touch,
      onNext: () {},
    );

    final button = tester.getSize(find.byType(ElevatedButton));
    // 400 минус поля страницы с двух сторон.
    expect(button.width, 400 - AppTokens.pageMarginMobile * 2);
  });

  testWidgets('под указателем кнопки прижаты к правому краю, а не растянуты', (
    tester,
  ) async {
    await _pump(
      tester,
      size: const Size(1440, 900),
      input: InputMode.pointer,
      onNext: () {},
    );

    final column = tester.getRect(find.byKey(WizardScaffold.columnKey));
    final button = tester.getRect(find.byType(ElevatedButton));
    expect(button.width, lessThan(column.width / 2));
    expect(
      button.right,
      closeTo(column.right - AppTokens.pageMarginDesktop, 0.5),
    );
  });

  testWidgets('пока идёт работа, «Далее» не нажимается повторно', (
    tester,
  ) async {
    // Двойное нажатие на «Далее» во время записи в базу создавало вторую
    // организацию. Занятость обязана гасить кнопку, а не только показывать
    // спиннер.
    var next = 0;
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inputModeProvider.overrideWith(
            () => _FixedInputMode(InputMode.touch),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: WizardScaffold(
            totalSteps: 11,
            currentStep: 3,
            busy: true,
            onNext: () => next++,
            child: const Text('содержимое'),
          ),
        ),
      ),
    );
    await tester.pump();

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(next, 0);
  });

  testWidgets('незаполненный шаг не пускает дальше ни кнопкой, ни Enter', (
    tester,
  ) async {
    var next = 0;
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inputModeProvider.overrideWith(
            () => _FixedInputMode(InputMode.pointer),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: WizardScaffold(
            totalSteps: 11,
            currentStep: 3,
            nextEnabled: false,
            onNext: () => next++,
            child: const Text('содержимое'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(next, 0, reason: 'Enter обошёл проверку заполненности');

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('шапка встаёт над содержимым и не заменяет его', (tester) async {
    await _pump(
      tester,
      size: const Size(400, 800),
      input: InputMode.touch,
      hero: const Text('приветствие'),
    );

    expect(find.text('приветствие'), findsOneWidget);
    expect(find.text('содержимое'), findsOneWidget);
    expect(
      tester.getRect(find.text('приветствие')).top,
      lessThan(tester.getRect(find.text('содержимое')).top),
    );
  });

  testWidgets('форма на высоком окне прижата к верху, а не центрирована', (
    tester,
  ) async {
    // Здесь стояло обратное утверждение: содержимое обязано стоять посреди
    // своей области, иначе «кнопка читается как забытая в углу». Оправдание
    // не выдержало проверки о собранный веб — заказчик посмотрел мастер
    // 2026-08-04 и сказал, что на Telegram не похоже, а центрированная
    // посреди экрана форма была одной из двух причин (вторая — плакат).
    //
    // В настройках Telegram группы начинаются сразу под шапкой, и пустота
    // внизу короткого списка — норма. Центрирование же ставило первую строку
    // каждого шага на разную высоту в зависимости от того, сколько строк
    // ниже: глаз заново искал начало на каждом следующем шаге.
    await _pump(
      tester,
      size: const Size(1440, 1600),
      input: InputMode.pointer,
      onNext: () {},
    );

    final content = tester.getRect(find.text('содержимое'));
    final rail = tester.getRect(find.byType(WizardProgressRail));
    final actions = tester.getRect(find.byType(WizardActions));
    final regionHeight = actions.top - rail.bottom;

    expect(
      content.top - rail.bottom,
      lessThan(regionHeight * 0.15),
      reason:
          'первая строка формы отстоит от рельса на ${content.top - rail.bottom} '
          'при высоте области $regionHeight — содержимое снова центрируют',
    );
  });

  testWidgets('экран с иллюстрацией остаётся центрированным', (tester) async {
    // Исключение из правила выше, и оно не произвол: там, где всё содержимое
    // — картинка с подписью (первый шаг, завершение, обрыв связи), прижатая к
    // верху композиция выглядит обрезком. Так же устроен первый запуск
    // Telegram.
    await _pump(
      tester,
      size: const Size(1440, 1600),
      input: InputMode.pointer,
      onNext: () {},
      hero: const Text('приветствие'),
    );

    final hero = tester.getRect(find.text('приветствие'));
    final rail = tester.getRect(find.byType(WizardProgressRail));
    final actions = tester.getRect(find.byType(WizardActions));
    final regionHeight = actions.top - rail.bottom;

    expect(
      hero.top - rail.bottom,
      greaterThan(regionHeight * 0.15),
      reason: 'иллюстрация прижалась к верху — правило перепутано местами',
    );
  });

  group('WizardHero', () {
    Future<void> pumpHero(WidgetTester tester, LayoutType layout) {
      return tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: WizardHero(
              title: 'Добро пожаловать',
              subtitle: 'Выберите страну',
              metrics: WizardMetrics.resolve(
                layout: layout,
                input: InputMode.touch,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('без иллюстрации картинки не появляется', (tester) async {
      // Иллюстрация есть на трёх шагах из одиннадцати. Пустой блок высотой
      // 160 px на остальных восьми оттолкнул бы форму вниз без причины.
      await pumpHero(tester, LayoutType.mobile);
      expect(find.byType(Image), findsNothing);
      expect(find.text('Добро пожаловать'), findsOneWidget);
      expect(find.text('Выберите страну'), findsOneWidget);
    });

    testWidgets('подзаголовок набран вторичным цветом, заголовок — основным', (
      tester,
    ) async {
      await pumpHero(tester, LayoutType.desktop);
      final context = tester.element(find.text('Выберите страну'));
      final scheme = Theme.of(context).colorScheme;

      final subtitle = tester.widget<Text>(find.text('Выберите страну'));
      expect(subtitle.style?.color, scheme.onSurfaceVariant);

      final title = tester.widget<Text>(find.text('Добро пожаловать'));
      expect(title.style?.color, isNot(scheme.onSurfaceVariant));
    });
  });
}
