import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/app/theme/app_tokens.dart';
import 'package:telepos/app/theme/input_mode.dart';
import 'package:telepos/app/theme/wizard_metrics.dart';
import 'package:telepos/presentation/common/adaptive/breakpoints.dart';

void main() {
  group('Режим ввода выводится из платформы', () {
    test('телефон и планшет — пальцем', () {
      expect(
        inputModeForPlatform(platform: TargetPlatform.android),
        InputMode.touch,
      );
      expect(
        inputModeForPlatform(platform: TargetPlatform.iOS),
        InputMode.touch,
      );
    });

    test('десктоп — указателем', () {
      for (final p in [
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.macOS,
      ]) {
        expect(inputModeForPlatform(platform: p), InputMode.pointer);
      }
    });
  });

  group('Метрики раскладки', () {
    test('на телефоне колонка не ограничена, поля 16', () {
      final m = WizardMetrics.resolve(
        layout: LayoutType.mobile,
        input: InputMode.touch,
      );
      expect(m.columnMaxWidth, isNull);
      expect(m.pageMargin, AppTokens.pageMarginMobile);
      expect(m.heroHeight, AppTokens.heroHeightMobile);
    });

    test('на планшете колонка 560, на десктопе 640', () {
      expect(
        WizardMetrics.resolve(
          layout: LayoutType.tablet,
          input: InputMode.touch,
        ).columnMaxWidth,
        AppTokens.columnMaxWidthTablet,
      );
      expect(
        WizardMetrics.resolve(
          layout: LayoutType.desktop,
          input: InputMode.pointer,
        ).columnMaxWidth,
        AppTokens.columnMaxWidthDesktop,
      );
    });

    test('широкая касса с сенсорным монитором сохраняет пальцевую строку', () {
      final m = WizardMetrics.resolve(
        layout: LayoutType.desktop,
        input: InputMode.touch,
      );
      expect(m.rowHeight, AppTokens.rowHeightTouch);
      expect(m.columnMaxWidth, AppTokens.columnMaxWidthDesktop);
    });

    test('наведение и фокус только под указателем', () {
      final pointer = WizardMetrics.resolve(
        layout: LayoutType.desktop,
        input: InputMode.pointer,
      );
      expect(pointer.showHover, isTrue);
      expect(pointer.showFocusRing, isTrue);
      expect(pointer.actionsAlignedRight, isTrue);

      final touch = WizardMetrics.resolve(
        layout: LayoutType.mobile,
        input: InputMode.touch,
      );
      expect(touch.showHover, isFalse);
      expect(touch.showFocusRing, isFalse);
      expect(touch.actionsAlignedRight, isFalse);
    });

    test(
      'кнопки прижимаются вправо только на широком экране под указателем',
      () {
        expect(
          WizardMetrics.resolve(
            layout: LayoutType.tablet,
            input: InputMode.pointer,
          ).actionsAlignedRight,
          isFalse,
          reason: 'на планшете кнопка остаётся во всю ширину колонки',
        );
      },
    );

    test('высота строки под пальцем не ниже пола доступности', () {
      // Пол доступности — 48. Пальцевая строка обязана быть не ниже него,
      // иначе цель нажатия меньше, чем палец способен уверенно поразить.
      final touch = WizardMetrics.resolve(
        layout: LayoutType.mobile,
        input: InputMode.touch,
      );
      expect(touch.rowHeight, greaterThanOrEqualTo(48.0));
    });
  });

  group('Режим ввода без поднятого графа зависимостей', () {
    testWidgets('провайдер отдаёт платформенное значение, а не бросает', (
      tester,
    ) async {
      // LocalProperties здесь не зарегистрирован — как на любом экране,
      // построенном до подъёма DI. Настройка размера строки не имеет права
      // оставить человека перед пустым экраном.
      late InputMode seen;
      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              seen = ref.watch(inputModeProvider);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(seen, inputModeForPlatform(platform: defaultTargetPlatform));
    });

    testWidgets('запись без хранилища признаётся неудачной, а не молчит', (
      tester,
    ) async {
      late InputModeNotifier notifier;
      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              notifier = ref.read(inputModeProvider.notifier);
              return const SizedBox();
            },
          ),
        ),
      );

      final saved = await notifier.set(InputMode.touch);
      expect(saved, isFalse, reason: 'сохранять было некуда');
      expect(notifier.state, InputMode.touch, reason: 'на экране — уже новый');
    });
  });
}
