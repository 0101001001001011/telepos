/// Экран трёх настроек дорожки A: что показано — то и записано.
///
/// Хранилище подменено памятью: запись в строку `ThisPos` проверена
/// `migration_v47_offset_fiscal_test`, а решение кассы по записанному —
/// эмулятором WebKassa (`offset_fiscal_settings_live_test`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/domain/fiscal/fiscal_offset_settings.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/settings/widgets/fiscal_offset_settings_section.dart';

class _MemoryStore implements FiscalOffsetSettingsStore {
  FiscalOffsetSettings value = FiscalOffsetSettings.defaults;
  bool refuse = false;
  int saves = 0;

  @override
  Future<FiscalOffsetSettings> load() async => value;

  @override
  Future<void> save(FiscalOffsetSettings settings) async {
    saves++;
    if (refuse) throw StateError('касса не настроена');
    value = settings;
  }
}

void main() {
  late _MemoryStore store;

  setUp(() {
    store = _MemoryStore();
    GetIt.I.registerSingleton<FiscalOffsetSettingsStore>(store);
  });

  tearDown(() => GetIt.I.unregister<FiscalOffsetSettingsStore>());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          locale: Locale('ru'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(child: FiscalOffsetSettingsSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  bool switchValue(WidgetTester tester, String key) =>
      tester.widget<SwitchListTile>(find.byKey(ValueKey(key))).value;

  testWidgets('умолчания заказчика видны на экране', (tester) async {
    await pump(tester);
    expect(switchValue(tester, 'fiscal-offset-certificate-sale'), isFalse);
    expect(switchValue(tester, 'fiscal-offset-prepayment-receipt'), isTrue);
    final layout = tester.widget<SegmentedButton<OffsetFiscalLayout>>(
      find.byKey(const ValueKey('fiscal-offset-layout')),
    );
    expect(layout.selected, {OffsetFiscalLayout.discount});
  });

  testWidgets('переключатели и раскладка записываются в хранилище', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(
      find.byKey(const ValueKey('fiscal-offset-certificate-sale')),
    );
    await tester.pumpAndSettle();
    expect(store.value.fiscalizeCertificateSale, isTrue);

    await tester.tap(find.text('Чек только на доплату'));
    await tester.pumpAndSettle();
    expect(store.value.offsetLayout, OffsetFiscalLayout.surchargeOnly);

    await tester.tap(
      find.byKey(const ValueKey('fiscal-offset-prepayment-receipt')),
    );
    await tester.pumpAndSettle();
    expect(store.value.fiscalizePrepaymentReceipt, isFalse);
    expect(
      store.value,
      const FiscalOffsetSettings(
        fiscalizeCertificateSale: true,
        offsetLayout: OffsetFiscalLayout.surchargeOnly,
        fiscalizePrepaymentReceipt: false,
      ),
    );
  });

  testWidgets('несохранённое не показывается сохранённым', (tester) async {
    await pump(tester);
    store.refuse = true;

    await tester.tap(
      find.byKey(const ValueKey('fiscal-offset-certificate-sale')),
    );
    await tester.pumpAndSettle();

    expect(store.saves, 1);
    expect(store.value.fiscalizeCertificateSale, isFalse);
    expect(
      switchValue(tester, 'fiscal-offset-certificate-sale'),
      isFalse,
      reason: 'экран вернул прежнее значение — в базе ничего не поменялось',
    );
    expect(find.text('Не удалось сохранить настройку'), findsOneWidget);
  });
}
