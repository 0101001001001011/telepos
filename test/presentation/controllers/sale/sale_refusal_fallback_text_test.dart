/// Запасной выход карты отказов продажи не несёт текст кассы — пункт 3
/// группы F (2026-09-15).
///
/// `saleRefusalErrorKeyOf` для кода, которого нет в карте, отдавал
/// `error.save_failed:<WireRefusal.message>` — русский текст, написанный
/// кассой для журнала, буквами в любом интерфейсе. Сторож
/// `named_refusal_reaches_cashier_test` держит карту полной для кодов
/// `lib/`, но касса новее терминала пришлёт код, которого этот терминал не
/// знает, — и тогда кассир обязан увидеть «неизвестная причина (код …)», а
/// не русскую фразу.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/utils/error_localizer.dart';
import 'package:telepos/presentation/controllers/sale/sale_refusal_keys.dart';

void main() {
  testWidgets('неизвестный код — код, а не текст кассы', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) {
            ctx = context;
            return const SizedBox();
          },
        ),
      ),
    );

    const refusal = WireRefusal('brand_new_code', 'касса знает новую причину');
    final key = saleRefusalErrorKeyOf(refusal);
    final shown = ErrorLocalizer.localize(ctx, key);

    expect(shown, contains('brand_new_code'));
    expect(shown, isNot(contains('касса знает')));
    expect(RegExp('[А-Яа-яЁё]').hasMatch(shown), isFalse, reason: shown);
  });
}
