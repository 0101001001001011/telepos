/// Экран налогов: выбор дробится, пресет применяется, ставка выводится.
///
/// # Что здесь главное
///
/// Не то, что поля нарисовались. Главное — три утверждения, каждое из
/// которых в жизни стоило бы денег:
///
/// 1. выбор **дробится**: штат и город становятся доступны при выборе
///    страны, и у страны без штатов второго уровня нет;
/// 2. применение пресета доезжает до базы и **обратно** — экран показывает
///    ту ставку, которую посчитает чек;
/// 3. второй пресет **заменяет** первый, а не доливается.
///
/// Экран ходит в настоящую базу и настоящие файлы пресетов: подменить их
/// значило бы проверить, что виджет умеет показывать выдуманное.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/tax/tax_preset_catalog.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/settings/tax_settings_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await GetIt.I.reset();
    GetIt.I.registerSingleton<AppDatabase>(db);

    // Память каталога и кэш пакета — чистятся перед каждой пробой.
    //
    // Не гигиена, а необходимость: `testWidgets` гоняет тело в поддельных
    // часах, и future, созданный в зоне прошлой пробы, колбэк в этой зоне
    // не доставляет. Экран остался бы со спиннером навсегда, и выглядело бы
    // это как дефект продукта, которого нет.
    TaxPresetCatalog.resetCache();
    rootBundle.clear();

    // Промах мимо виджета — красный, а не строчка в выводе. Без этого
    // нажатие по кнопке за краем экрана оставляет пробу зелёной на
    // действии, которого не было.
    WidgetController.hitTestWarningShouldBeFatal = true;
  });

  tearDown(() async {
    await GetIt.I.reset();
    await db.close();
  });

  /// Язык закреплён: иначе проба зависит от языка машины, на которой её
  /// запустили.
  const locale = Locale('en');

  Widget host() => ProviderScope(
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const TaxSettingsScreen(),
    ),
  );

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
  }

  /// Выбирает значение в выпадающем списке, ПРОКРУЧИВАЯ до него.
  ///
  /// Прокрутка не вежливость. 2026-09-22 наборов стало девятнадцать вместо
  /// двух, список стран перестал помещаться на экран, и `find.text(...).last`
  /// падал «Bad state: No element» — позиции просто не было в дереве.
  /// Выглядело это как поломка экрана, которой нет.
  Future<void> choose(
    WidgetTester tester,
    String dropdownKey,
    String option,
  ) async {
    await tester.tap(find.byKey(ValueKey(dropdownKey)));
    await tester.pumpAndSettle();

    // Проверяем БЕЗ `.last`: у пустого `.last` сам `evaluate()` бросает
    // «Bad state: No element», и прокрутка не успевает случиться.
    if (find.text(option).evaluate().isEmpty) {
      // Без `.last`: `scrollUntilVisible` зовёт `isEmpty` на переданном
      // искателе, а у пустого `.last` это бросает.
      await tester.scrollUntilVisible(
        find.text(option),
        120,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text(option).last);
    await tester.pumpAndSettle();
  }

  /// Жмёт «применить», предварительно доведя кнопку до видимой части.
  ///
  /// `ensureVisible` не вежливость: при настроенном Денвере разбивка из
  /// четырёх долей уводит кнопку за нижний край, нажатие уходит в пустоту, а
  /// `tap` всего лишь печатает предупреждение. Проба зеленела бы на
  /// действии, которого не было, — поэтому предупреждение сделано
  /// смертельным в `setUp`.
  Future<void> apply(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const ValueKey('tax-preset-apply')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tax-preset-apply')));
    await tester.pumpAndSettle();
    // Назад к выведенной ставке: список строит только видимое, и карточка
    // наверху после прокрутки к кнопке в дереве уже не существует.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('tax-settings-resolved')),
      -120,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('ненастроенная касса говорит, что считает ноль', (tester) async {
    await open(tester);

    expect(
      find.byKey(const ValueKey('tax-settings-not-configured')),
      findsOneWidget,
      reason:
          'молчание на этом экране неотличимо от настроенного нуля, и '
          'владелец узнал бы о недоборе налога от проверяющего',
    );
    expect(find.byKey(const ValueKey('tax-settings-resolved')), findsNothing);
  });

  testWidgets('выбор дробится: штат и город появляются после страны', (
    tester,
  ) async {
    await open(tester);

    expect(
      find.byKey(const ValueKey('tax-preset-region')),
      findsNothing,
      reason: 'до выбора страны спрашивать штат не о чем',
    );

    await choose(tester, 'tax-preset-country', 'US');

    expect(
      find.byKey(const ValueKey('tax-preset-region')),
      findsOneWidget,
      reason: 'решение заказчика: при выборе становятся доступны штат и город',
    );
  });

  testWidgets('у страны с одной ставкой второго уровня нет', (tester) async {
    await open(tester);
    await choose(tester, 'tax-preset-country', 'KZ');

    expect(
      find.byKey(const ValueKey('tax-preset-region')),
      findsNothing,
      reason:
          'в Казахстане ставка одна на страну; пустое поле «штат» там — '
          'вопрос без ответа',
    );
    expect(
      find.byKey(const ValueKey('tax-preset-preset')),
      findsOneWidget,
      reason: 'сам набор при этом доступен сразу',
    );
  });

  testWidgets('применённый пресет даёт на экране ту же ставку, что и чек', (
    tester,
  ) async {
    await open(tester);
    await choose(tester, 'tax-preset-country', 'US');
    await choose(tester, 'tax-preset-region', 'CO');
    await choose(tester, 'tax-preset-city', 'Denver');
    await choose(tester, 'tax-preset-preset', 'Denver, Colorado');

    // Источник и дата — на виду до применения, а не в файле: человек,
    // который решает, применять ли, обязан видеть, чем набор подтверждён.
    expect(find.textContaining('Colorado DR 1002'), findsOneWidget);
    expect(find.textContaining('2026-01-01'), findsOneWidget);

    await apply(tester);

    expect(
      find.textContaining('9.15'),
      findsWidgets,
      reason:
          'экран считает тем же движком, что и чек; расхождение здесь '
          'значит, что владелец настроил не то, что напечатается',
    );
    // Разбивка целиком: по ней бухгалтер отчитывается за каждую долю.
    for (final name in ['CO State', 'Denver', 'RTD', 'SCFD']) {
      expect(find.text(name), findsWidgets, reason: 'доля «$name» потеряна');
    }
  });

  testWidgets('второй пресет заменяет первый, а не доливается', (tester) async {
    await open(tester);
    await choose(tester, 'tax-preset-country', 'US');
    await choose(tester, 'tax-preset-region', 'CO');
    await choose(tester, 'tax-preset-city', 'Denver');
    await choose(tester, 'tax-preset-preset', 'Denver, Colorado');
    await apply(tester);

    await choose(tester, 'tax-preset-country', 'KZ');
    await choose(tester, 'tax-preset-preset', 'Казахстан');
    await apply(tester);

    expect(
      find.text('CO State'),
      findsNothing,
      reason:
          'доли двух стран, сложенные вместе, дали бы двойной налог, и '
          'узнал бы об этом покупатель',
    );
    expect(find.textContaining('16'), findsWidgets);
  });

  testWidgets('смена страны сбрасывает нижние уровни', (tester) async {
    await open(tester);
    await choose(tester, 'tax-preset-country', 'US');
    await choose(tester, 'tax-preset-region', 'CO');

    await choose(tester, 'tax-preset-country', 'KZ');

    expect(
      find.text('CO'),
      findsNothing,
      reason:
          'оставшийся штат Колорадо под Казахстаном показывал бы одно, а '
          'применился бы другой набор',
    );
  });
}
