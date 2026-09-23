/// Экран часов запрета: завести, увидеть, не сохранить непригодное.
///
/// # Зачем экран вообще появился
///
/// Механизм запрета жил в продукте с самого начала — таблица, DAO, договор
/// `IsCategoryBlockedUseCase`. Заполнить его было НЕЧЕМ: ни одного экрана.
/// Настройка существовала на бумаге, и ночная продажа проходила везде.
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/core/locale/app_locale.dart';
import 'package:telepos/data/catalog/local_selling_hours.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/catalog/selling_hours_repository.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/settings/selling_hours_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    await GetIt.I.reset();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    GetIt.I.registerSingleton<AppDatabase>(db);
    GetIt.I.registerSingleton<SellingHoursRepository>(LocalSellingHours(db));
    await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            id: const Value(1),
            name: const Value('Alcohol'),
            createTime: DateTime.now(),
          ),
        );
  });

  tearDown(() async {
    await db.close();
    await GetIt.I.reset();
  });

  Future<void> open(WidgetTester tester, {String locale = 'en'}) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: Locale(locale),
          supportedLocales: AppLocale.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const SellingHoursScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('окно заводится и появляется в списке', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('selling-hours-add')));
    await tester.pumpAndSettle();

    // Умолчание — ночное окно: именно его ставят чаще всего, и предлагать
    // пустые поля значило бы заставить набирать их каждому.
    expect(find.text('23:00'), findsOneWidget);
    expect(find.text('08:00'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('selling-hours-save')));
    await tester.pumpAndSettle();

    final saved = await GetIt.I<SellingHoursRepository>().all();
    expect(saved, hasLength(1));
    expect(saved.single.beginTime, '23:00');
    expect(saved.single.endTime, '08:00');
    expect(find.text('Alcohol'), findsOneWidget);
  });

  testWidgets('непригодные часы сохранить НЕЛЬЗЯ', (tester) async {
    // Сохрани мы их — запрет молча не сработал бы, и узнал бы об этом не
    // владелец, а проверяющий.
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('selling-hours-add')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('selling-hours-from')),
      '25:00',
    );
    await tester.pumpAndSettle();

    final save = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('selling-hours-save')),
    );
    expect(save.onPressed, isNull, reason: 'кнопка сохранения осталась живой');
    // Ищем именно подсказку, а не подписи полей: «HH:MM» стоит и в них.
    expect(find.textContaining('for example'), findsOneWidget);
  });

  testWidgets('пустое окно тоже не сохраняется', (tester) async {
    // Начало равно концу не запрещает ничего — сохранить его значило бы
    // завести правило, которое не работает.
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('selling-hours-add')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('selling-hours-to')),
      '23:00',
    );
    await tester.pumpAndSettle();

    final save = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('selling-hours-save')),
    );
    expect(save.onPressed, isNull);
  });

  testWidgets('ночное окно названо словами ДО сохранения', (tester) async {
    // «С 23 до 8» выглядит опечаткой. Без этой строки владелец правил бы
    // окно, пока не сломал.
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('selling-hours-add')));
    await tester.pumpAndSettle();
    expect(find.textContaining('midnight'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('selling-hours-from')),
      '13:00',
    );
    await tester.enterText(
      find.byKey(const ValueKey('selling-hours-to')),
      '14:00',
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('midnight'), findsNothing);
    expect(find.textContaining('one day'), findsOneWidget);
  });

  testWidgets('без категорий добавить нечего, и это сказано', (tester) async {
    await db.delete(db.categories).go();
    await open(tester);

    final add = tester.widget<FloatingActionButton>(
      find.byKey(const ValueKey('selling-hours-add')),
    );
    expect(add.onPressed, isNull);
    expect(find.textContaining('Create categories'), findsOneWidget);
  });

  testWidgets('на английском ни слова по-русски', (tester) async {
    await GetIt.I<SellingHoursRepository>().save(
      const SellingHoursRule(
        categoryId: 1,
        categoryName: 'Alcohol',
        beginTime: '23:00',
        endTime: '08:00',
      ),
    );
    await open(tester);

    final cyrillic = RegExp(r'[А-Яа-яЁё]');
    final offenders = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .where(cyrillic.hasMatch)
        .toList();
    expect(offenders, isEmpty, reason: offenders.join(' · '));
  });
}
