/// Настройка налога пишется, читается и считает тем же движком.
///
/// # Что здесь главное
///
/// Не то, что строки сохранились, — это свойство drift. Главное, что
/// **прочитанная обратно настройка даёт ту же ставку, что и пресет**: между
/// файлом и кассой стоят три таблицы и два преобразования, и потеряться
/// может любая доля.
library;

import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/tax/tax_preset.dart';
import 'package:telepos/domain/tax/tax_resolution.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// Настоящий поставляемый пресет, а не выдуманный в пробе: проба на своём
  /// примере доказывала бы, что запись работает, — но не то, что доезжает
  /// именно Денвер.
  TaxPreset denver() => TaxPreset.fromJson(
    json.decode(File('assets/tax_presets/us-co-denver.json').readAsStringSync())
        as Map<String, Object?>,
  );

  test('пресет доезжает до базы и оттуда даёт ту же ставку', () async {
    await db.taxSettingsDao.applyPreset(denver());

    final config = await db.taxSettingsDao.load();
    expect(config.isConfigured, isTrue);
    expect(
      config.resolve(on: DateTime.utc(2026, 3)).totalRatePercent,
      Decimal.parse('9.15'),
      reason:
          'между файлом и кассой три таблицы и два преобразования; '
          'потеряться может любая доля',
    );
  });

  test('иерархия переживает запись: штат остаётся родителем города', () async {
    await db.taxSettingsDao.applyPreset(denver());

    final saved = await db.taxSettingsDao.allJurisdictions();
    final state = saved.firstWhere((j) => j.name == 'CO State');
    final city = saved.firstWhere((j) => j.name == 'Denver');

    expect(
      city.parentId,
      state.id,
      reason:
          'без связи доля штата не взимется: касса посчитала бы 6,25 % '
          'вместо 9,15 %',
    );
    expect(
      state.isTillLocation,
      isFalse,
      reason: 'штат добирается предком, отмечать его незачем',
    );
    expect(city.isTillLocation, isTrue);
  });

  test('освобождение штата от еды переживает запись', () async {
    final ids = await db.taxSettingsDao.applyPreset(denver());
    final config = await db.taxSettingsDao.load();

    final food = config.resolve(
      categoryId: ids['food-home'],
      on: DateTime.utc(2026, 3),
    );

    expect(food.totalRatePercent, Decimal.parse('6.25'));
    expect(
      food.shares.map((s) => s.name),
      isNot(contains('CO State')),
      reason: 'штат не облагает еду для дома — вид правила обязан доехать',
    );
  });

  test('применение второго пресета ЗАМЕНЯЕТ, а не доливает', () async {
    await db.taxSettingsDao.applyPreset(denver());
    await db.taxSettingsDao.applyPreset(
      TaxPreset.fromJson(
        json.decode(File('assets/tax_presets/kz.json').readAsStringSync())
            as Map<String, Object?>,
      ),
    );

    final config = await db.taxSettingsDao.load();
    expect(
      config.resolve(on: DateTime.utc(2026, 3)).totalRatePercent,
      Decimal.parse('16'),
      reason:
          'долить пресет к существующему значило бы сложить доли двух '
          'стран, и касса молча взяла бы двойной налог',
    );
    expect(await db.taxSettingsDao.allJurisdictions(), hasLength(1));

    // Отдельно: правил от прежнего набора не остаётся ни одного.
    //
    // Ставка без этой проверки всё равно выходит верной — осиротевшее
    // правило не применяется, потому что его юрисдикции больше нет. Но оно
    // лежит в базе, показывается в списке правил ничьим и копится с каждым
    // применением набора. Саботаж, снимающий чистку правил, проверку по
    // одной лишь ставке проходил насквозь — отсюда эта строка.
    final jurisdictionIds = (await db.taxSettingsDao.allJurisdictions())
        .map((j) => j.id)
        .toSet();
    expect(
      (await db.taxSettingsDao.allRules())
          .where((r) => !jurisdictionIds.contains(r.jurisdictionId)),
      isEmpty,
      reason: 'правила прежнего набора остались ничьими и будут копиться',
    );
  });

  test('категория по умолчанию подставляется, а не понимается как «без категории»', () async {
    await db.taxSettingsDao.applyPreset(denver());
    final config = await db.taxSettingsDao.load();

    expect(
      config.defaultCategoryId,
      isNotNull,
      reason: 'ровно одна категория обязана быть по умолчанию',
    );
    expect(
      config.resolve(on: DateTime.utc(2026, 3)).totalRatePercent,
      Decimal.parse('9.15'),
    );
  });

  test('ненастроенная касса не считает налог и говорит об этом', () async {
    final config = await db.taxSettingsDao.load();
    expect(config.isConfigured, isFalse);
    expect(config.resolve().totalRatePercent, Decimal.zero);
  });

  test('удаление юрисдикции уносит её правила и потомков', () async {
    await db.taxSettingsDao.applyPreset(denver());
    final state = (await db.taxSettingsDao.allJurisdictions()).firstWhere(
      (j) => j.name == 'CO State',
    );

    await db.taxSettingsDao.removeJurisdiction(state.id);

    expect(
      await db.taxSettingsDao.allJurisdictions(),
      isEmpty,
      reason: 'все юрисдикции пресета висят на штате — уйти обязаны все',
    );
    expect(
      await db.taxSettingsDao.allRules(),
      isEmpty,
      reason:
          'осиротевшее правило не применяется, но остаётся; следующая '
          'юрисдикция с тем же id получила бы чужую ставку',
    );
  });

  test('противоречивое правило не записывается', () async {
    final id = await db.taxSettingsDao.addJurisdiction(name: 'Проба');
    expect(
      () => db.taxSettingsDao.addRule(
        jurisdictionId: id,
        kind: TaxRuleKind.exempt,
        ratePercent: Decimal.parse('5'),
        validFrom: DateTime.utc(2026),
      ),
      throwsArgumentError,
      reason:
          'попав в базу, оно всплыло бы у кассира на чеке, а не здесь',
    );
    expect(await db.taxSettingsDao.allRules(), isEmpty);
  });

  test('правило со сроком перестаёт действовать после его конца', () async {
    final id = await db.taxSettingsDao.addJurisdiction(
      name: 'Город',
      isTillLocation: true,
    );
    await db.taxSettingsDao.addRule(
      jurisdictionId: id,
      ratePercent: Decimal.parse('4.00'),
      validFrom: DateTime.utc(2026),
      validTo: DateTime.utc(2026, 6, 30),
    );
    await db.taxSettingsDao.addRule(
      jurisdictionId: id,
      ratePercent: Decimal.parse('4.81'),
      validFrom: DateTime.utc(2026, 7),
    );

    final config = await db.taxSettingsDao.load();

    expect(
      config.resolve(on: DateTime.utc(2026, 5)).totalRatePercent,
      Decimal.parse('4.00'),
    );
    expect(
      config.resolve(on: DateTime.utc(2026, 8)).totalRatePercent,
      Decimal.parse('4.81'),
      reason:
          'перепечатанный задним числом чек обязан считаться по ставке '
          'своего дня; в Колорадо ставки меняются дважды в год',
    );
  });
}
