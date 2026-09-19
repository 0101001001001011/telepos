/// Отказ подписки на пул отложенных чеков доезжает до кассира фразой
/// словаря, а не текстом кассы и не литералом диалога.
///
/// До правки `_deferredErrorText` показывал `WireRefusal.message` — русскую
/// фразу, написанную кассой для журнала, — а на всё прочее литерал «Список
/// отложенных чеков недоступен». Кассир с английским интерфейсом читал
/// по-русски оба.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/domain/sale/cart_service.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/sale/widgets/deferred_sales_dialog.dart';

class _RefusingPool implements CartService {
  _RefusingPool(this.error);

  final Object error;

  @override
  Stream<List<DeferredCart>> watchDeferred({required DiscountAuthority by}) =>
      Stream.error(error);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _cyrillic = RegExp('[А-Яа-яЁё]');

Future<AppLocalizations> _pump(WidgetTester tester, Object error) async {
  GetIt.I.registerSingleton<CartService>(_RefusingPool(error));
  late AppLocalizations l10n;
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
            l10n = AppLocalizations.of(context)!;
            return const Scaffold(body: DeferredSalesDialog());
          },
        ),
      ),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  return l10n;
}

List<String> _texts(WidgetTester tester) => [
  for (final w in tester.widgetList<Text>(find.byType(Text))) w.data ?? '',
];

void main() {
  tearDown(() async => GetIt.I.reset());

  testWidgets('отказ кассы с кодом — фраза словаря этого кода', (tester) async {
    final l10n = await _pump(
      tester,
      const WireRefusal('forbidden', 'нет права op.deferSale'),
    );
    expect(find.text(l10n.errorNotAllowed), findsOneWidget);
    expect(
      _texts(tester).where(_cyrillic.hasMatch),
      isEmpty,
      reason: 'текст кассы написан по-русски для журнала',
    );
  });

  testWidgets('неожиданная беда — фраза словаря, а не литерал диалога', (
    tester,
  ) async {
    final l10n = await _pump(tester, StateError('внутренность'));
    expect(find.text(l10n.errorDeferredListUnavailable), findsOneWidget);
    expect(_texts(tester).where(_cyrillic.hasMatch), isEmpty);
  });

  testWidgets('код, которого нет в словаре, — код, но не русский текст', (
    tester,
  ) async {
    await _pump(
      tester,
      const WireRefusal('brand_new_code', 'совсем новая причина'),
    );
    expect(find.textContaining('brand_new_code'), findsOneWidget);
    expect(_texts(tester).where(_cyrillic.hasMatch), isEmpty);
  });
}
