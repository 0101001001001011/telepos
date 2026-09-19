/// Диалоги оплаты говорят на языке кассира — пункт 3 группы F (2026-09-15).
///
/// Обход презентационного слоя нашёл литералы кириллицы мимо словаря в двух
/// диалогах денег: срок и схема рассрочки (`installment_terms_dialog.dart`)
/// и приём оплаты / погашение долга покупателя
/// (`record_customer_payment_dialog.dart`). Кассир с английским
/// интерфейсом читал их по-русски.
///
/// Исключения названы: имя схемы рассрочки берётся у домена
/// (`InstallmentScheme.label`) — тем же словом его печатает договор, и два
/// списка названий разошлись бы; имя покупателя — данные, а не фраза.
library;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/domain/payment/installment_scheduler.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/dialogs/record_customer_payment_dialog.dart';
import 'package:telepos/presentation/screens/payment/widgets/installment_terms_dialog.dart';

final _cyrillic = RegExp('[А-Яа-яЁё]');

Future<BuildContext> _app(WidgetTester tester) async {
  late BuildContext ctx;
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light,
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
            return const Scaffold();
          },
        ),
      ),
    ),
  );
  return ctx;
}

List<String> _shown(WidgetTester tester) => [
  for (final w in tester.widgetList<Text>(find.byType(Text))) w.data ?? '',
  for (final w in tester.widgetList<InputDecorator>(find.byType(InputDecorator)))
    w.decoration.labelText ?? '',
];

void main() {
  testWidgets('рассрочка: срок, схема и кнопки — фразами словаря', (
    tester,
  ) async {
    final ctx = await _app(tester);
    showInstallmentTermsDialog(ctx);
    await tester.pumpAndSettle();

    final schemeLabels = {for (final s in InstallmentScheme.values) s.label};
    expect(
      _shown(tester)
          .where((t) => !schemeLabels.contains(t))
          .where(_cyrillic.hasMatch),
      isEmpty,
    );
  });

  testWidgets('приём оплаты покупателя: заголовок, долг, поле, кнопки', (
    tester,
  ) async {
    final ctx = await _app(tester);
    showDialog<void>(
      context: ctx,
      builder: (_) => RecordCustomerPaymentDialog(
        agentId: 1,
        agentName: 'Покупатель',
        currentBalance: Decimal.parse('-300'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      _shown(tester)
          .where((t) => t != 'Покупатель')
          .where(_cyrillic.hasMatch),
      isEmpty,
    );

    // Пустая сумма — отказ формы, тоже словами словаря.
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
    expect(
      _shown(tester)
          .where((t) => t != 'Покупатель')
          .where(_cyrillic.hasMatch),
      isEmpty,
    );
  });
}
