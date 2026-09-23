/// Отказ по часам продажи доходит до кассира — на всех пяти языках.
///
/// # Почему отдельной пробой
///
/// Общий сторож отказов (`sale_refusal_codes_localized_test`) подставляет
/// ОДИН образец во все места шаблона. У этого отказа доводов два — товар и
/// окно, — и сторож проверяет только ветку «окна не приехало». Настоящий
/// путь остался бы непроверенным: среда добрее продукта.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:telepos/core/locale/app_locale.dart';
import 'package:telepos/domain/sale/cart_service.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/utils/error_localizer.dart';
import 'package:telepos/presentation/controllers/sale/sale_refusal_keys.dart';

void main() {
  Future<BuildContext> pump(WidgetTester tester, String locale) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(locale),
        supportedLocales: AppLocale.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (ctx) {
            captured = ctx;
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pump();
    return captured;
  }

  String shown(BuildContext ctx, String message) => ErrorLocalizer.localize(
    ctx,
    saleRefusalErrorKeyOf(WireRefusal(cartSellingHoursBannedCode, message)),
  );

  testWidgets('кассир видит И товар, И до какого часа нельзя', (tester) async {
    for (final locale in ['ru', 'en', 'kk', 'ky', 'uz']) {
      final ctx = await pump(tester, locale);
      final text = shown(ctx, 'Craft beer|23:00–08:00');

      expect(
        text,
        contains('Craft beer'),
        reason: '$locale: кассир не узнает, какой товар нельзя',
      );
      expect(
        text,
        contains('23:00–08:00'),
        reason: '$locale: без часа кассир будет пробовать снова каждую минуту',
      );
      expect(
        text,
        isNot(contains('|')),
        reason: '$locale: разделитель провода уехал на экран',
      );
    }
  });

  testWidgets('окна нет — фраза целая, без дыры на его месте', (tester) async {
    // Обрывок «запрет .» читается как поломка продукта, а не как отказ.
    for (final locale in ['ru', 'en', 'kk', 'ky', 'uz']) {
      final ctx = await pump(tester, locale);
      final text = shown(ctx, 'Craft beer');

      expect(text, contains('Craft beer'));
      expect(text.trim(), isNot(endsWith(' .')));
      expect(text, isNot(contains('  ')));
    }
  });

  testWidgets('на английском ни слова по-русски', (tester) async {
    final ctx = await pump(tester, 'en');
    final text = shown(ctx, 'Craft beer|23:00–08:00');
    expect(text, isNot(matches(RegExp(r'[А-Яа-яЁё]'))));
  });

  testWidgets('фраза каждого языка своя, а не общая русская', (tester) async {
    final seen = <String>{};
    for (final locale in ['ru', 'en', 'kk', 'ky', 'uz']) {
      final ctx = await pump(tester, locale);
      seen.add(shown(ctx, 'Craft beer|23:00–08:00'));
    }
    expect(
      seen,
      hasLength(5),
      reason: 'два языка показали одно и то же — перевод не заведён',
    );
  });
}
