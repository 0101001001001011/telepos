/// Категория товара доезжает от формы до чека.
///
/// # Зачем
///
/// Движок, схема, экран настройки и сборка чека были готовы, а пометить
/// товар категорией было нечем: в карточке стояли жёсткие «12 % / 0 %» —
/// казахстанские, в поле, которое чек больше не читает. Молоко в Денвере
/// облагалось бы полной ставкой, потому что сказать «это еда для дома»
/// было негде.
///
/// # Что здесь главное
///
/// Не наличие выпадающего поля. Главное — **сквозной путь**: выбрал
/// категорию в карточке → она записалась → чек вывел по ней ставку. Каждое
/// из трёх звеньев по отдельности уже проверено; здесь проверяется, что
/// они соединены.
library;

import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/tax/tax_preset.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/catalog/catalog_controller.dart';
import 'package:telepos/presentation/screens/catalog/dialogs/product_form_dialog.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await GetIt.I.reset();
    GetIt.I.registerSingleton<AppDatabase>(db);
    WidgetController.hitTestWarningShouldBeFatal = true;
  });

  tearDown(() async {
    await GetIt.I.reset();
    await db.close();
  });

  Future<Map<String, int>> applyDenver() => db.taxSettingsDao.applyPreset(
    TaxPreset.fromJson(
      json.decode(
            File('assets/tax_presets/us-co-denver.json').readAsStringSync(),
          )
          as Map<String, Object?>,
    ),
  );

  ProductFormResult? captured;

  Widget host({CatalogItem? item}) => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              captured = await ProductFormDialog.show(context, item: item);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );

  /// Высокое окно: карточка товара длинная, и на 800×600 поле категории
  /// уходит за нижний край вместе с кнопкой сохранения.
  ///
  /// Это проба пути данных, а не раскладки на телефоне; бороться здесь с
  /// прокруткой значило бы проверять `ensureVisible`, а не форму.
  void useTallWindow(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> openForm(WidgetTester tester, {CatalogItem? item}) async {
    useTallWindow(tester);
    captured = null;
    await tester.pumpWidget(host(item: item));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('без заведённых налогов поля категории нет', (tester) async {
    await openForm(tester);

    expect(
      find.byKey(const ValueKey('product-tax-category')),
      findsNothing,
      reason:
          'выбор из пустого списка — вопрос без ответа; для кассы с одной '
          'ставкой на страну категория ничего не решает',
    );
  });

  testWidgets('заведённые категории показываются своими названиями', (
    tester,
  ) async {
    await applyDenver();
    await openForm(tester);

    expect(find.byKey(const ValueKey('product-tax-category')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('product-tax-category')));
    await tester.pumpAndSettle();

    expect(
      find.text('Food for home consumption'),
      findsWidgets,
      reason:
          'названия берутся из заведённых категорий, а не из зашитого '
          'списка: иначе каждый новый штат означал бы правку кода',
    );
  });

  testWidgets('выбранная категория возвращается формой', (tester) async {
    final ids = await applyDenver();
    await openForm(tester);

    // Имя и цена — обязательные: без них форма не отдаёт результат, и
    // проба молча проверяла бы отказ вместо сохранения.
    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.enterText(
      find.widgetWithText(TextFormField, l10n.catalogProductName),
      'Milk, 1 gal',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, l10n.catalogPrice),
      '4.29',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('product-tax-category')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food for home consumption').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ElevatedButton).last);
    await tester.pumpAndSettle();

    expect(
      captured?.taxCategoryId,
      ids['food-home'],
      reason:
          'без этого звена молоко в Денвере облагалось бы полной ставкой: '
          'сказать «это еда для дома» было бы негде',
    );
  });

  test('записанная категория даёт в чеке ставку 6,25 %', () async {
    // Последнее звено пути: категория в базе → выведенная ставка. Здесь же
    // видно, ради чего всё: штат освободил еду, город — нет.
    final ids = await applyDenver();
    await db
        .into(db.productInfos)
        .insert(
          ProductInfosCompanion.insert(
            ucode: const Value(1),
            barcode: 4607001,
            name: 'Milk, 1 gal',
            type: 0,
            measure: 0,
            taxCategoryId: Value(ids['food-home']),
          ),
        );

    final saved = await db.productInfoDao.findByUcode(1);
    final config = await db.taxSettingsDao.load();

    expect(
      config
          .resolve(categoryId: saved!.taxCategoryId, on: DateTime.utc(2026, 3))
          .totalRatePercent,
      Decimal.parse('6.25'),
    );
  });
}
