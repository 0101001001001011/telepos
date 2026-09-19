import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/core/constants/enums/user_role.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/discount/local_discount_policy.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/screens/settings/discount_limits_screen.dart';

/// Половина задачи 12, которую не доказывает ни одна проба кассы: **где
/// владелец назначает предел**.
///
/// Предел, который негде увидеть и изменить, отличим от несуществующего
/// только чтением исходника — и ровно так в `ThisPosEntries` появились три
/// колонки без единого читателя. Поэтому здесь проверяется не отрисовка, а
/// то, что щелчок по «Сохранить» доходит **до того самого читателя**,
/// которого спрашивает касса (`LocalDiscountPolicy.capFor`), а не до
/// какой-нибудь своей копии правила.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db
        .into(db.thisPosEntries)
        .insert(const ThisPosEntriesCompanion(id: Value(1)));
    GetIt.I.registerSingleton<AppDatabase>(db);
  });

  tearDown(() async {
    await GetIt.I.reset();
    await db.close();
  });

  /// Экран пределов — пять карточек в столбце, и в поле зрения 600×800 они
  /// не помещаются. Увеличенный холст, а не прокрутка в каждой пробе: предмет
  /// проверки — куда доезжает щелчок, а не умеет ли ListView прокручиваться.
  Future<void> wide(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  Widget host() => const ProviderScope(
    child: MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [Locale('ru')],
      home: DiscountLimitsScreen(),
    ),
  );

  /// Дождаться, пока экран прочитает базу, — **по состоянию, а не по часам**.
  ///
  /// `pumpAndSettle` крутит поддельное время; чтение базы — настоящая
  /// асинхронность, и под нагрузкой (полный набор в одиночку) оно приходит
  /// после того, как поддельное время успокоилось. На экране в этот момент
  /// индикатор, а не карточки, и проба падала «виджета нет» — три из трёх
  /// в полном прогоне и ни разу в одиночном. Тот же класс мерцания, который
  /// уже чинили в `waitForSearch` (`test/integration/`), и то же лечение:
  /// ждать появления того, чего ждём, а не отмеренной паузы.
  Future<void> untilLoaded(WidgetTester tester) async {
    for (var i = 0; i < 300; i++) {
      await tester.pumpAndSettle(const Duration(milliseconds: 10));
      final loaded = find
          .byKey(const ValueKey('discount-limits-row--1'))
          .evaluate()
          .isNotEmpty;
      if (loaded) return;
    }
  }

  Finder maxFieldOf(int role) => find.descendant(
    of: find.byKey(ValueKey('discount-limits-row-$role')),
    matching: find.byKey(const ValueKey('discount-limits-max')),
  );

  Finder saveOf(int role) => find.descendant(
    of: find.byKey(ValueKey('discount-limits-row-$role')),
    matching: find.byKey(const ValueKey('discount-limits-save')),
  );

  testWidgets('предел, назначенный на экране, читает та же касса', (
    tester,
  ) async {
    await wide(tester);
    await tester.pumpWidget(host());
    await untilLoaded(tester);

    // До правки предел кассира — умолчание миграции.
    final policy = LocalDiscountPolicy(db);
    expect(
      (await policy.capFor(UserRole.cashier.index)).maxPercent,
      Decimal.fromInt(100),
    );

    await tester.enterText(maxFieldOf(UserRole.cashier.index), '20');
    await tester.tap(saveOf(UserRole.cashier.index));
    await tester.pumpAndSettle();

    final cap = await policy.capFor(UserRole.cashier.index);
    expect(
      cap.maxPercent,
      Decimal.fromInt(20),
      reason: 'щелчок никуда не доехал — предел назначить негде',
    );
    expect(
      cap.source,
      contains('Кассир'),
      reason: 'отказ обязан назвать, чей это предел',
    );
  });

  testWidgets('пустой предел роли снимает строку, а не пишет ноль', (
    tester,
  ) async {
    // Разница существенна: ноль запрещает скидку насовсем, отсутствие строки
    // отдаёт решение умолчанию. Экран, не различающий их, отнял бы у
    // владельца возможность вернуть роль к общему правилу.
    await db
        .into(db.discountLimits)
        .insert(
          DiscountLimitsCompanion.insert(
            role: Value(UserRole.cashier.index),
            maxPercentPerLine: Value(Decimal.fromInt(20)),
          ),
        );

    await wide(tester);
    await tester.pumpWidget(host());
    await untilLoaded(tester);

    await tester.enterText(maxFieldOf(UserRole.cashier.index), '');
    await tester.tap(saveOf(UserRole.cashier.index));
    await tester.pumpAndSettle();

    final cap = await LocalDiscountPolicy(db).capFor(UserRole.cashier.index);
    expect(cap.maxPercent, Decimal.fromInt(100));
    expect(cap.source, contains('умолчанию'));
  });

  testWidgets('заслонка на двух дверях названа словами, а не оставлена '
      'выводом владельца', (tester) async {
    // При выключенном запрете снижения цены ловушки нет — и строки быть не
    // должно: предупреждение, висящее всегда, перестают читать.
    await wide(tester);
    await tester.pumpWidget(host());
    await untilLoaded(tester);
    expect(
      find.byKey(const ValueKey('discount-limits-two-doors')),
      findsNothing,
    );
  });

  testWidgets('при включённом запрете снижения цены экран называет ловушку', (
    tester,
  ) async {
    await (db.update(db.thisPosEntries)..where((t) => t.id.equals(1))).write(
      const ThisPosEntriesCompanion(isKassaPriceDecreasingBlocked: Value(true)),
    );

    await wide(tester);
    await tester.pumpWidget(host());
    await untilLoaded(tester);

    expect(
      find.byKey(const ValueKey('discount-limits-two-doors')),
      findsOneWidget,
      reason:
          'владелец, включивший запрет снижения цены, уверен, что закрыл и '
          'скидку; при пределе 100 % она открыта настежь, и сказать ему об '
          'этом должен экран',
    );
  });
}
