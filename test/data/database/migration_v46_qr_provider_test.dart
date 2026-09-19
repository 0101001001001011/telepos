/// Миграция v45→v46: настройка провайдера QR.
///
/// Таблица проверяется **работой** — запись, чтение, перезапись одной
/// строки, — а не строкой в `sqlite_master`.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/payment/qr_provider_settings.dart';

void main() {
  Future<AppDatabase> openFromV45() async {
    final probe = AppDatabase.forTesting(NativeDatabase.memory());
    final ddl =
        (await probe
                .customSelect(
                  'SELECT sql FROM sqlite_master '
                  "WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%'",
                )
                .get())
            .map((r) => r.read<String>('sql'))
            .toList();
    await probe.close();

    final raw = sqlite3.sqlite3.openInMemory();
    for (final statement in ddl) {
      raw.execute(statement);
    }
    raw.execute('DROP TABLE IF EXISTS qr_provider_configs');
    raw.execute('PRAGMA user_version = 45');
    expect(
      raw.select(
        "SELECT name FROM sqlite_master WHERE name = 'qr_provider_configs'",
      ),
      isEmpty,
      reason: 'фикстура уже содержит таблицу v46 — мерить нечего',
    );
    return AppDatabase.forTesting(NativeDatabase.opened(raw));
  }

  test('свежая база: версия схемы — текущая, настройки нет — провайдер не выдуман', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    // Утверждения о номере версии здесь нет намеренно. И `expect(db.schemaVersion,
    // 52)`, и «свежая база создана на объявленной версии» сверяют число или
    // с собой, или с тем, что drift выставляет сам после `onCreate`: обе
    // проверки **не краснеют** (второе измерено диверсией 2026-09-19 —
    // `PRAGMA user_version = 40` внутри `onCreate` прошло незамеченным).
    // Настоящий инвариант — «у каждого подъёма есть своя ветвь `if (from <
    // N)`» — стоит в `app_database_test.dart`, и он краснеет.
    expect(await db.qrProviderConfigDao.read(), isNull);
  });

  test('база v45 доезжает до v46, и в таблицу пишется одна строка', () async {
    final db = await openFromV45();
    addTearDown(db.close);

    expect(await db.qrProviderConfigDao.read(), isNull);

    const first = QrProviderSettings(
      baseUrl: 'http://127.0.0.1:8890',
      code: 'sbp',
      apiKey: 'k-1',
      patience: Duration(seconds: 90),
    );
    await db.qrProviderConfigDao.save(first, at: DateTime(2026, 9, 13));
    expect(await db.qrProviderConfigDao.read(), first);

    // Перезапись, а не вторая строка.
    await db.qrProviderConfigDao.save(
      const QrProviderSettings(baseUrl: ' http://x ', code: 'sbp2', apiKey: ''),
      at: DateTime(2026, 9, 14),
    );
    final second = (await db.qrProviderConfigDao.read())!;
    expect(second.baseUrl, 'http://x', reason: 'адрес без пробелов по краям');
    expect(second.apiKey, isNull, reason: 'пустой ключ — «ключа нет»');
    expect(second.patience, QrProviderSettings.defaultPatience);
    expect(await db.select(db.qrProviderConfigs).get(), hasLength(1));
  });

  test('настройка в журнале не печатает ключ', () {
    const s = QrProviderSettings(
      baseUrl: 'http://p',
      code: 'sbp',
      apiKey: 'sk-SECRET',
    );
    expect('$s', isNot(contains('sk-SECRET')));
    expect('$s', contains('задан'));
  });
}
