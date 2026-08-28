import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/app/theme/app_tokens.dart';

void main() {
  test('шкала отступов кратна четырём и возрастает', () {
    const scale = [
      AppTokens.space4,
      AppTokens.space8,
      AppTokens.space12,
      AppTokens.space16,
      AppTokens.space20,
      AppTokens.space24,
      AppTokens.space32,
      AppTokens.space40,
      AppTokens.space48,
    ];
    for (var i = 0; i < scale.length; i++) {
      expect(scale[i] % 4, 0, reason: '${scale[i]} не кратно четырём');
      if (i > 0) {
        expect(
          scale[i],
          greaterThan(scale[i - 1]),
          reason:
              'шкала обязана возрастать, иначе имя перестаёт '
              'соответствовать величине',
        );
      }
    }
  });

  test('радиусы соответствуют спеке', () {
    expect(AppTokens.radiusSection, 12.0);
    expect(AppTokens.radiusControl, 10.0);
    expect(AppTokens.radiusChip, 8.0);
  });

  test('строка под палец выше строки под курсор', () {
    // Плотность Telegram, принятая 2026-08-04: было 52 и 44.
    // 48 — не выбор, а порог доступности; ниже нельзя.
    expect(AppTokens.rowHeightTouch, 48.0);
    expect(AppTokens.rowHeightPointer, 40.0);
    expect(
      AppTokens.rowHeightTouch,
      greaterThan(AppTokens.rowHeightPointer),
      reason: 'касса с сенсорным монитором бывает широкой, но пальцевой',
    );
  });

  test('цель нажатия под пальцем не меньше 48 — это предел, а не вкус', () {
    // Меньше сорока восьми логических пикселей палец промахивается; и Material,
    // и Apple называют одно и то же число. Строка списка обязана его держать.
    expect(AppTokens.rowHeightTouch, greaterThanOrEqualTo(48.0));
  });

  testWidgets('hairline равен одному физическому пикселю', (tester) async {
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetDevicePixelRatio);

    late double hairline;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          hairline = AppTokens.hairlineOf(context);
          return const SizedBox();
        },
      ),
    );
    expect(hairline, 0.5);
  });

  testWidgets('на экране без масштабирования hairline остаётся единицей', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetDevicePixelRatio);

    late double hairline;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          hairline = AppTokens.hairlineOf(context);
          return const SizedBox();
        },
      ),
    );
    expect(hairline, 1.0);
  });

  test('ширина колонки на десктопе больше, чем на планшете', () {
    expect(
      AppTokens.columnMaxWidthDesktop,
      greaterThan(AppTokens.columnMaxWidthTablet),
    );
    expect(AppTokens.columnMaxWidthTablet, 560.0);
    expect(AppTokens.columnMaxWidthDesktop, 640.0);
  });

  test('иллюстрация растёт вместе с экраном', () {
    expect(AppTokens.heroHeightTablet, greaterThan(AppTokens.heroHeightMobile));
    expect(
      AppTokens.heroHeightDesktop,
      greaterThan(AppTokens.heroHeightTablet),
    );
  });

  test('быстрая длительность короче обычной и обе заметно короче секунды', () {
    expect(AppTokens.durationFast, lessThan(AppTokens.durationNormal));
    expect(
      AppTokens.durationNormal.inMilliseconds,
      lessThan(400),
      reason:
          'анимация дольше 400 мс на кассе читается как задержка, '
          'а не как движение',
    );
  });
}
